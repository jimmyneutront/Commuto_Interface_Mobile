//
//  SwapServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Switrix
import web3swift
import XCTest

@testable import iosApp

/**
 Tests for `SwapService`
 */
class SwapServiceTests: XCTestCase {
    /**
     Ensures that `SwapService` sends taker information correctly.
     */
    func testSendTakerInformation() {
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // Set up SwapService
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // The ID of the swap for which taker information will be sent
        let swapID = UUID()
        
        // The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to store the whole key pair persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        // We store the maker's public key, as if we received it via the P2P network
        try! keyManagerService.storePublicKey(pubKey: try! makerKeyPair.getPublicKey())
        // This is the taker's (user's) key pair, so we do want to store it persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // We must persistently store a swap with an ID equal to swapID and the maker and taker interface IDs from the keys created above, otherwise SwapService won't be able to get the keys necessary to make the taker info message
        let swapForDatabase = DatabaseSwap(
            id: swapID.asData().base64EncodedString(),
            isCreated: true,
            requiresFill: false,
            maker: "",
            makerInterfaceID: makerKeyPair.interfaceId.base64EncodedString(),
            taker: "",
            takerInterfaceID: takerKeyPair.interfaceId.base64EncodedString(),
            stablecoin: "",
            amountLowerBound: "",
            amountUpperBound: "",
            securityDepositAmount: "",
            takenSwapAmount: "",
            serviceFeeAmount: "",
            serviceFeeRate: "",
            onChainDirection: "",
            onChainSettlementMethod: "",
            protocolVersion: "",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "",
            chainID: "31337",
            state: ""
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            var makerPublicKey: iosApp.PublicKey? = nil
            var takerKeyPair: KeyPair? = nil
            var swapID: UUID? = nil
            var paymentDetails: String? = nil
            override func sendTakerInformation(makerPublicKey: iosApp.PublicKey, takerKeyPair: KeyPair, swapID: UUID, paymentDetails: String) throws {
                self.makerPublicKey = makerPublicKey
                self.takerKeyPair = takerKeyPair
                self.swapID = swapID
                self.paymentDetails = paymentDetails
            }
        }
        let p2pService = TestP2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        swapService.p2pService = p2pService
        swapService.swapTruthSource = TestSwapTruthSource()
        
        try! swapService.sendTakerInformationMessage(swapID: swapID, chainID: BigUInt(31337))
        
        XCTAssertEqual(p2pService.makerPublicKey!.interfaceId, makerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.takerKeyPair!.interfaceId, takerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.swapID, swapID)
        #warning("TODO: update this once SettlementMethodService is added")
        XCTAssertEqual(p2pService.paymentDetails, "TEMPORARY")
        
        let swapInDatabase = try! databaseService.getSwap(id: swapID.asData().base64EncodedString())
        XCTAssertEqual(swapInDatabase!.state, "awaitingMakerInfo")
        
    }
    
    /**
     Ensures that `SwapService` handles new swaps made by the user of the interface properly.
     */
    func testHandleNewSwap() {
        let newOfferID = UUID()
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_swapservice_handleNewSwap")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "offerID", value: newOfferID.uuidString),
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        class TestSwapTruthSource: SwapTruthSource {
            let swapAddedExpectation = XCTestExpectation(description: "Fulfilled when a swap is added to the swaps dictionary")
            var swaps: [UUID : Swap] = [:] {
                didSet {
                    // We want to ignore initialization and only fulfill when a new swap is added
                    if swaps.keys.count != 0 {
                        swapAddedExpectation.fulfill()
                    }
                }
            }
        }
        let swapTruthSource = TestSwapTruthSource()
        swapService.swapTruthSource = swapTruthSource
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        #warning("TODO: move this to its own class")
        class TestOfferService: OfferNotifiable {
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {}
            func handleOfferEditedEvent(_ event: OfferEditedEvent) {}
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {}
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {}
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) {}
        }
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        try! swapService.handleNewSwap(swapID: newOfferID, chainID: BigUInt(31337))
        
        wait(for: [swapTruthSource.swapAddedExpectation], timeout: 60.0)
        XCTAssertEqual(newOfferID, swapTruthSource.swaps.keys.first!)
        
    }
    
    /**
     Ensure that `SwapService` handles `TakerInformationMessage`s properly.
     */
    func testHandleTakerInformationMessage() {
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // The ID of the swap for which taker information is being received
        let swapID = UUID()
        // The taker's key pair. Since we are the maker, this is NOT stored persistently.
        let takerKeyPair = try! KeyPair()
        // The maker's key pair. Since we are the maker, this is stored persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // The taker's information that the maker must handle
        let message = TakerInformationMessage(swapID: swapID, publicKey: try! takerKeyPair.getPublicKey(), settlementMethodDetails: "taker_settlement_method_details")
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        #warning("TODO: move this to its own class")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        // A test P2PService that will allow us to get the maker information that will be sent
        class TestP2PService: P2PService {
            var takerPublicKey: iosApp.PublicKey? = nil
            var makerKeyPair: KeyPair? = nil
            var swapID: UUID? = nil
            var settlementMethodDetails: String? = nil
            override func sendMakerInformation(takerPublicKey: iosApp.PublicKey, makerKeyPair: KeyPair, swapID: UUID, settlementMethodDetails: String) throws {
                self.takerPublicKey = takerPublicKey
                self.makerKeyPair = makerKeyPair
                self.swapID = swapID
                self.settlementMethodDetails = settlementMethodDetails
            }
        }
        let p2pService = TestP2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        // Provide TestP2PService to swapService
        swapService.p2pService = p2pService
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        let swap = try! Swap(
            isCreated: true,
            requiresFill: true,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: makerKeyPair.interfaceId,
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: takerKeyPair.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .sell,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingTakerInformation
        )
        swapTruthSource.swaps[swapID] = swap
        let swapForDatabase = DatabaseSwap(
            id: swap.id.asData().base64EncodedString(),
            isCreated: swap.isCreated,
            requiresFill: swap.requiresFill,
            maker: swap.maker.addressData.toHexString(),
            makerInterfaceID: swap.makerInterfaceID.base64EncodedString(),
            taker: swap.taker.addressData.toHexString(),
            takerInterfaceID: swap.takerInterfaceID.base64EncodedString(),
            stablecoin: swap.stablecoin.addressData.toHexString(),
            amountLowerBound: String(swap.amountLowerBound),
            amountUpperBound: String(swap.amountUpperBound),
            securityDepositAmount: String(swap.securityDepositAmount),
            takenSwapAmount: String(swap.takenSwapAmount),
            serviceFeeAmount: String(swap.serviceFeeAmount),
            serviceFeeRate: String(swap.serviceFeeRate),
            onChainDirection: String(swap.onChainDirection),
            onChainSettlementMethod: swap.onChainSettlementMethod.base64EncodedString(),
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after handleTakerInformationMessage is executed")
        
        // Call handleTakerInformationMessage on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            // call swapService.handleTakerInformationMessage
            try! swapService.handleTakerInformationMessage(message)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Ensure that SwapService calls p2pService properly
        XCTAssertEqual(takerKeyPair.interfaceId, p2pService.takerPublicKey!.interfaceId)
        XCTAssertEqual(makerKeyPair.interfaceId, p2pService.makerKeyPair!.interfaceId)
        XCTAssertEqual(swapID, p2pService.swapID)
        #warning("TODO: update this once SettlementMethodService is implemented")
        XCTAssertEqual("TEMPORARY", p2pService.settlementMethodDetails)
        
        // Ensure that SwapService updates swap state in swapTruthSource
        XCTAssertEqual(SwapState.awaitingFilling, swap.state)
        
        // Ensure that SwapService persistently updates swap state
        let swapInDatabase = try! databaseService.getSwap(id: swapForDatabase.id)
        XCTAssertEqual(SwapState.awaitingFilling.asString, swapInDatabase!.state)
        
    }
    
}
