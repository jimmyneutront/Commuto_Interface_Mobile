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
     Ensure `SwapService` handles failed reporting payment sent transactions properly.
     */
    func testHandleFailedReportPaymentSentTransaction() {
        let swapID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapTruthSource = TestSwapTruthSource()
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: true,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
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
            state: SwapState.awaitingPaymentSent,
            role: SwapRole.makerAndBuyer
        )
        let reportPaymentSentTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentSent)
        swap.reportPaymentSentTransaction = reportPaymentSentTransaction
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
            makerPrivateSettlementMethodData: swap.makerPrivateSettlementMethodData,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        swapService.swapTruthSource = swapTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! swapService.handleFailedTransaction(reportPaymentSentTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(SwapState.awaitingPaymentSent, swap.state)
        XCTAssertEqual(ReportingPaymentSentState.error, swap.reportingPaymentSentState)
        XCTAssertNotNil(swap.reportingPaymentSentError)
        let swapInDatabase = try! databaseService.getSwap(id: swapID.asData().base64EncodedString())
        XCTAssertEqual(SwapState.awaitingPaymentSent.asString, swapInDatabase?.state)
        XCTAssertEqual(ReportingPaymentSentState.error.asString, swapInDatabase?.reportPaymentSentState)
        
    }
    
    /**
     Ensure `SwapService` handles failed reporting payment received transactions properly.
     */
    func testHandleFailedReportPaymentReceivedTransaction() {
        let swapID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapTruthSource = TestSwapTruthSource()
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: true,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
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
            state: SwapState.reportPaymentReceivedTransactionBroadcast,
            role: SwapRole.makerAndSeller
        )
        let reportPaymentReceivedTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentReceived)
        swap.reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
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
            makerPrivateSettlementMethodData: swap.makerPrivateSettlementMethodData,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        swapService.swapTruthSource = swapTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! swapService.handleFailedTransaction(reportPaymentReceivedTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(SwapState.awaitingPaymentReceived, swap.state)
        XCTAssertEqual(ReportingPaymentReceivedState.error, swap.reportingPaymentReceivedState)
        XCTAssertNotNil(swap.reportingPaymentReceivedError)
        let swapInDatabase = try! databaseService.getSwap(id: swapID.asData().base64EncodedString())
        XCTAssertEqual(SwapState.awaitingPaymentReceived.asString, swapInDatabase?.state)
        XCTAssertEqual(ReportingPaymentReceivedState.error.asString, swapInDatabase?.reportPaymentReceivedState)
        
    }
    
    /**
     Ensure `SwapService` handles failed swap closing transactions properly.
     */
    func testHandleFailedCloseSwapTransaction() {
        let swapID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapTruthSource = TestSwapTruthSource()
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
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
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.closeSwapTransactionBroadcast,
            role: SwapRole.takerAndBuyer
        )
        let closeSwapTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .closeSwap)
        swap.closeSwapTransaction = closeSwapTransaction
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
            makerPrivateSettlementMethodData: swap.makerPrivateSettlementMethodData,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        swapService.swapTruthSource = swapTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! swapService.handleFailedTransaction(closeSwapTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(SwapState.awaitingClosing, swap.state)
        XCTAssertEqual(ClosingSwapState.error, swap.closingSwapState)
        XCTAssertNotNil(swap.closingSwapError)
        let swapInDatabase = try! databaseService.getSwap(id: swapID.asData().base64EncodedString())
        XCTAssertEqual(SwapState.awaitingClosing.asString, swapInDatabase?.state)
        XCTAssertEqual(ClosingSwapState.error.asString, swapInDatabase?.closeSwapState)
        
    }
    
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
        let swapTruthSource = TestSwapTruthSource()
        swapService.swapTruthSource = swapTruthSource
        
        // The ID of the swap for which taker information will be sent
        let swapID = UUID()
        
        // The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to store the whole key pair persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        // We store the maker's public key, as if we received it via the P2P network
        try! keyManagerService.storePublicKey(pubKey: try! makerKeyPair.getPublicKey())
        // This is the taker's (user's) key pair, so we do want to store it persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
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
            state: SwapState.awaitingTakerInformation,
            role: SwapRole.takerAndSeller
        )
        swap.takerPrivateSettlementMethodData = "some_SWIFT_data"
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            var makerPublicKey: iosApp.PublicKey? = nil
            var takerKeyPair: KeyPair? = nil
            var swapID: UUID? = nil
            var paymentDetails: String? = nil
            override func sendTakerInformation(makerPublicKey: iosApp.PublicKey, takerKeyPair: KeyPair, swapID: UUID, paymentDetails: String?) throws {
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
        
        let expectation = XCTestExpectation(description: "Fulfilled after sendTakerInformationMessage is executed")
        
        // Call sendTakerInformationMessage on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            let didSendTakerInfoMessage = try! swapService.sendTakerInformationMessage(swapID: swapID, chainID: BigUInt(31337))
            XCTAssert(didSendTakerInfoMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
        XCTAssertEqual(p2pService.makerPublicKey!.interfaceId, makerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.takerKeyPair!.interfaceId, takerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.swapID, swapID)
        XCTAssertEqual(p2pService.paymentDetails, "some_SWIFT_data")
        
        XCTAssertEqual(swap.state, SwapState.awaitingMakerInformation)
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
        
        // We need this TestSwapTruthSource declaration to track when swaps are added
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
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: newOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [
                SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", privateData: "SWIFT_private_data")
            ],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )
        
        try! swapService.handleNewSwap(takenOffer: offer)
        
        wait(for: [swapTruthSource.swapAddedExpectation], timeout: 60.0)
        XCTAssertEqual(newOfferID, swapTruthSource.swaps.keys.first!)
        XCTAssertEqual("SWIFT_private_data", swapTruthSource.swaps[newOfferID]?.makerPrivateSettlementMethodData)
        
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
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        // A test P2PService that will allow us to get the maker information that will be sent
        class TestP2PService: P2PService {
            var takerPublicKey: iosApp.PublicKey? = nil
            var makerKeyPair: KeyPair? = nil
            var swapID: UUID? = nil
            var settlementMethodDetails: String? = nil
            override func sendMakerInformation(takerPublicKey: iosApp.PublicKey, makerKeyPair: KeyPair, swapID: UUID, settlementMethodDetails: String?) throws {
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
            state: SwapState.awaitingTakerInformation,
            role: SwapRole.makerAndSeller
        )
        swap.makerPrivateSettlementMethodData = "maker_settlement_method_details"
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
            makerPrivateSettlementMethodData: swap.makerPrivateSettlementMethodData,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
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
        XCTAssertEqual("maker_settlement_method_details", p2pService.settlementMethodDetails)
        
        // Ensure that SwapService updates swap state and taker private data in swapTruthSource
        XCTAssertEqual(SwapState.awaitingFilling, swap.state)
        XCTAssertEqual("taker_settlement_method_details", swap.takerPrivateSettlementMethodData)
        
        // Ensure that SwapService persistently updates swap state and taker private data
        let swapInDatabase = try! databaseService.getSwap(id: swapForDatabase.id)
        XCTAssertEqual(SwapState.awaitingFilling.asString, swapInDatabase!.state)
        XCTAssertEqual("taker_settlement_method_details", swapInDatabase!.takerPrivateSettlementMethodData)
        
    }
    
    /**
     Ensure that `SwapService` handles `MakerInformationMessage`s properly.
     */
    func testHandleMakerInformationMessage() {
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // The ID of the swap for which maker information is being received
        let swapID = UUID()
        
        // The maker's key pair. Since we are the taker, this is NOT stored persistently.
        let makerKeyPair = try! KeyPair()
        try! keyManagerService.storePublicKey(pubKey: makerKeyPair.getPublicKey())
        // The taker's key pair. Since we are the taker, this is stored persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // The maker's information that the taker must handle
        let message = MakerInformationMessage(swapID: swapID, settlementMethodDetails: "maker_settlement_method_details")
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
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
            state: SwapState.awaitingMakerInformation,
            role: SwapRole.takerAndBuyer
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after handleMakerInformationMessage and test assertions are executed")
        
        // Call handleMakerInformationMessage on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            // call swapService.handleMakerInformationMessage
            try! swapService.handleMakerInformationMessage(message, senderInterfaceID: makerKeyPair.interfaceId, recipientInterfaceID: takerKeyPair.interfaceId)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handleMakerInformationMessage passes to DispatchQueue.main.async are executed
            DispatchQueue.main.async {
                // Ensure that SwapService updates swap state in swapTruthSource
                XCTAssertEqual(SwapState.awaitingFilling, swap.state)
                XCTAssertEqual("maker_settlement_method_details", swap.makerPrivateSettlementMethodData)
                
                // Ensure that SwapService persistently updates swap state
                let swapInDatabase = try! databaseService.getSwap(id: swapForDatabase.id)
                XCTAssertEqual(SwapState.awaitingFilling.asString, swapInDatabase!.state)
                XCTAssertEqual("maker_settlement_method_details", swapInDatabase!.makerPrivateSettlementMethodData)
                
                expectation.fulfill()
            }
            
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    /**
     Ensures that `SwapService.fillSwap` and `BlockchainService.fillSwap` function properly.
     */
    func testFillSwap() {
        
        let swapID = UUID()
        
        struct TestingServerResponse: Decodable {
            let stablecoinAddress: String
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_swapservice_fillSwap")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "swapID", value: swapID.uuidString)
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
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: true,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            takenSwapAmount: BigUInt(10000),
            serviceFeeAmount: BigUInt(100),
            serviceFeeRate: BigUInt(100),
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
            state: SwapState.awaitingFilling,
            role: SwapRole.makerAndSeller
        )
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after fillSwap is executed")
        
        swapService.fillSwap(swapToFill: swap).done {
            expectation.fulfill()
        }.cauterize()
        
        wait(for: [expectation], timeout: 20.0)
        
        XCTAssertEqual(SwapState.fillSwapTransactionBroadcast, swap.state)
        XCTAssertFalse(swap.requiresFill)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertEqual(SwapState.fillSwapTransactionBroadcast.asString, swapInDatabase?.state)
        XCTAssertFalse(swapInDatabase!.requiresFill)
        
    }
    
    /**
     Ensure that `SwapService` handles `SwapFilledEvent`s properly.
     */
    func testHandleSwapFilledEvent() {
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // The ID of the swap being filled
        let swapID = UUID()
        
        // The SwapFilled event to be handled
        let event = SwapFilledEvent(id: swapID, chainID: BigUInt(31337))
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        let swap = try! Swap(
            isCreated: true,
            requiresFill: true,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
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
            state: SwapState.fillSwapTransactionBroadcast,
            role: SwapRole.makerAndSeller
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after handleSwapFilledEvent and test assertions are executed")
        
        // Call handleSwapFilledEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handleSwapFilledEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handleSwapFilledEvent passes to DispatchQueue.main.async are executed
            DispatchQueue.main.async {
                // Ensure that SwapService updates swap state and requiresFill in swapTruthSource
                XCTAssertEqual(SwapState.awaitingPaymentSent, swap.state)
                XCTAssertFalse(swap.requiresFill)
                
                // Ensure that SwapService persistently updates swap state and requiresFill
                let swapInDatabase = try! databaseService.getSwap(id: swapForDatabase.id)
                XCTAssertEqual(SwapState.awaitingPaymentSent.asString, swapInDatabase!.state)
                XCTAssertFalse(swapInDatabase!.requiresFill)
                
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
            
    }
    
    /**
     Ensures that `BlockchainService.createReportPaymentSentTransaction`,  `SwapService.createReportPaymentSentTransaction`, `SwapService.reportPaymentSent` and `BlockchainService.sendTransaction` function properly.
     */
    func testReportPaymentSent() {
        
        let swapID = UUID()
        
        struct TestingServerResponse: Decodable {
            let stablecoinAddress: String
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_swapservice_reportPaymentSent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "swapID", value: swapID.uuidString)
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
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            takenSwapAmount: BigUInt(10000),
            serviceFeeAmount: BigUInt(100),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
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
            state: SwapState.awaitingPaymentSent,
            role: SwapRole.makerAndBuyer
        )
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after reportPaymentSent is executed")
        
        swapService.createReportPaymentSentTransaction(swap: swap)
            .then { transaction in
                return swapService.reportPaymentSent(swap: swap, reportPaymentSentTransaction: transaction)
            }.done{
                expectation.fulfill()
            }.cauterize()
        
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(ReportingPaymentSentState.awaitingTransactionConfirmation, swap.reportingPaymentSentState)
        XCTAssertEqual(SwapState.reportPaymentSentTransactionBroadcast, swap.state)
        XCTAssertNotNil(swap.reportPaymentSentTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertEqual(ReportingPaymentSentState.awaitingTransactionConfirmation.asString, swapInDatabase?.reportPaymentSentState)
        XCTAssertEqual(SwapState.reportPaymentSentTransactionBroadcast.asString, swapInDatabase?.state)
        XCTAssertNotNil(swapInDatabase?.reportPaymentSentTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `PaymentSentEvent`s properly for swaps in which the user of this interface is the seller.
     */
    func testHandlePaymentSentEventForUserIsSeller() {
        // The ID of the swap for which payment is being sent
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
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
            state: SwapState.awaitingPaymentSent,
            role: SwapRole.takerAndSeller
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The PaymentSentEvent to be handled
        let event = PaymentSentEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "reporting_payment_sent_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handlePaymentSentEvent and test assertions are executed")
        
        // Call handlePaymentSentEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handlePaymentSentEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handlePaymentSentEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(swap.isPaymentSent)
        XCTAssertEqual(SwapState.awaitingPaymentReceived, swap.state)
        XCTAssertEqual("0xreporting_payment_sent_tx_hash", swap.reportPaymentSentTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.isPaymentSent)
        XCTAssertEqual(SwapState.awaitingPaymentReceived.asString, swapInDatabase!.state)
        XCTAssertEqual("0xreporting_payment_sent_tx_hash", swapInDatabase!.reportPaymentSentTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `PaymentSentEvent`s properly for swaps in which the user of this interface is the buyer.
     */
    func testHandlePaymentSentEventForUserIsBuyer() {
        // The ID of the swap for which payment is being sent
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
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
            state: SwapState.awaitingPaymentSent,
            role: SwapRole.makerAndBuyer
        )
        swap.reportingPaymentSentState = .awaitingTransactionConfirmation
        swap.reportPaymentSentTransaction = BlockchainTransaction(transactionHash: "reporting_payment_sent_tx_hash", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentSent)
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The PaymentSentEvent to be handled
        let event = PaymentSentEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "reporting_payment_sent_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handlePaymentSentEvent and test assertions are executed")
        
        // Call handlePaymentSentEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handlePaymentSentEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handlePaymentSentEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(swap.isPaymentSent)
        XCTAssertEqual(SwapState.awaitingPaymentReceived, swap.state)
        XCTAssertEqual(ReportingPaymentSentState.completed, swap.reportingPaymentSentState)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.isPaymentSent)
        XCTAssertEqual(SwapState.awaitingPaymentReceived.asString, swapInDatabase!.state)
        XCTAssertEqual(ReportingPaymentSentState.completed.asString, swapInDatabase!.reportPaymentSentState)
        
    }
    
    /**
     Ensures that `BlockchainService.createReportPaymentReceivedTransaction`,  `SwapService.createReportPaymentReceivedTransaction`, `SwapService.reportPaymentReceived` and `BlockchainService.sendTransaction` function properly.
     */
    func testReportPaymentReceived() {
    
        let swapID = UUID()
        
        struct TestingServerResponse: Decodable {
            let stablecoinAddress: String
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_swapservice_reportPaymentReceived")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken-PaymentSent"),
            URLQueryItem(name: "swapID", value: swapID.uuidString)
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
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            takenSwapAmount: BigUInt(10000),
            serviceFeeAmount: BigUInt(100),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: true,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingPaymentReceived,
            role: SwapRole.takerAndSeller
        )
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after reportPaymentReceived is executed")
        
        swapService.createReportPaymentReceivedTransaction(swap: swap)
            .then { transaction in
                return swapService.reportPaymentReceived(swap: swap, reportPaymentReceivedTransaction: transaction)
            }.done {
                expectation.fulfill()
            }.cauterize()
        
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(ReportingPaymentReceivedState.awaitingTransactionConfirmation, swap.reportingPaymentReceivedState)
        XCTAssertEqual(SwapState.reportPaymentReceivedTransactionBroadcast, swap.state)
        XCTAssertNotNil(swap.reportPaymentReceivedTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertEqual(ReportingPaymentReceivedState.awaitingTransactionConfirmation.asString, swapInDatabase?.reportPaymentReceivedState)
        XCTAssertEqual(SwapState.reportPaymentReceivedTransactionBroadcast.asString, swapInDatabase?.state)
        XCTAssertNotNil(swapInDatabase?.reportPaymentReceivedTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `PaymentReceivedEvent`s properly for swaps in which the user of this interface is the buyer.
     */
    func testHandlePaymentReceivedEventForUserIsBuyer() {
        // The ID of the swap for which payment is being received
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: true,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingPaymentReceived,
            role: SwapRole.makerAndBuyer
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The PaymentReceivedEvent to be handled
        let event = PaymentReceivedEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "reporting_payment_received_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handlePaymentReceivedEvent and test assertions are executed")
        
        // Call handlePaymentReceivedEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handlePaymentReceivedEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handlePaymentReceivedEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(swap.isPaymentReceived)
        XCTAssertEqual(SwapState.awaitingClosing, swap.state)
        XCTAssertEqual("0xreporting_payment_received_tx_hash", swap.reportPaymentReceivedTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.isPaymentReceived)
        XCTAssertEqual(SwapState.awaitingClosing.asString, swapInDatabase!.state)
        XCTAssertEqual("0xreporting_payment_received_tx_hash", swapInDatabase!.reportPaymentReceivedTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `PaymentReceivedEvent`s properly for swaps in which the user of this interface is the seller.
     */
    func testHandlePaymentReceivedEventForUserIsSeller() {
        // The ID of the swap for which payment is being received
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: true,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.reportPaymentReceivedTransactionBroadcast,
            role: SwapRole.takerAndSeller
        )
        swap.reportingPaymentReceivedState = .awaitingTransactionConfirmation
        swap.reportPaymentReceivedTransaction = BlockchainTransaction(transactionHash: "reporting_payment_received_tx_hash", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentSent)
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The PaymentReceivedEvent to be handled
        let event = PaymentReceivedEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "reporting_payment_received_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handlePaymentSentEvent and test assertions are executed")
        
        // Call handlePaymentReceivedEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handlePaymentReceivedEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handlePaymentReceivedEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(swap.isPaymentReceived)
        XCTAssertEqual(SwapState.awaitingClosing, swap.state)
        XCTAssertEqual(ReportingPaymentReceivedState.completed, swap.reportingPaymentReceivedState)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.isPaymentReceived)
        XCTAssertEqual(SwapState.awaitingClosing.asString, swapInDatabase!.state)
        XCTAssertEqual(ReportingPaymentReceivedState.completed.asString, swapInDatabase!.reportPaymentReceivedState)
        
    }
    
    /**
     Ensures that `BlockchainService.createCloseSwapTransaction`,  `SwapService.createCloseSwapTransaction`, `SwapService.closeSwap` and `BlockchainService.sendTransaction` function properly.
     */
    func testCloseSwap() {
        
        let swapID = UUID()
        
        struct TestingServerResponse: Decodable {
            let stablecoinAddress: String
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_swapservice_closeSwap")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken-PaymentSent-Received"),
            URLQueryItem(name: "swapID", value: swapID.uuidString)
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
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        swapService.blockchainService = blockchainService
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            takenSwapAmount: BigUInt(10000),
            serviceFeeAmount: BigUInt(100),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingClosing,
            role: SwapRole.makerAndBuyer
        )
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let expectation = XCTestExpectation(description: "Fulfilled after reportPaymentReceived is executed")
        
        swapService.createCloseSwapTransaction(swap: swap)
            .then { transaction in
                return swapService.closeSwap(swap: swap, closeSwapTransaction: transaction)
            }.done {
                expectation.fulfill()
            }.cauterize()
        
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertEqual(ClosingSwapState.awaitingTransactionConfirmation, swap.closingSwapState)
        XCTAssertEqual(SwapState.closeSwapTransactionBroadcast, swap.state)
        XCTAssertNotNil(swap.closeSwapTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertEqual(ClosingSwapState.awaitingTransactionConfirmation.asString, swapInDatabase?.closeSwapState)
        XCTAssertEqual(SwapState.closeSwapTransactionBroadcast.asString, swapInDatabase?.state)
        XCTAssertNotNil(swapInDatabase?.closeSwapTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `BuyerClosedEvent`s properly for swaps in which the user of this interface is the buyer. (Handling when the user is the seller is trivial, and thus not tested.)
     */
    func testHandleBuyerClosedEvent() {
        // The ID of the swap that the buyer has closed
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            takenSwapAmount: BigUInt.zero,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingClosing,
            role: SwapRole.makerAndBuyer
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The BuyerClosedEvent to be handled
        let event = BuyerClosedEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "close_swap_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handlePaymentReceivedEvent and test assertions are executed")
        
        // Call handleBuyerClosedEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handleBuyerClosedEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handleBuyerClosedEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(swap.hasBuyerClosed)
        XCTAssertEqual(SwapState.closed, swap.state)
        XCTAssertEqual(ClosingSwapState.completed, swap.closingSwapState)
        XCTAssertEqual("0xclose_swap_tx_hash", swap.closeSwapTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.hasBuyerClosed)
        XCTAssertEqual(SwapState.closed.asString, swapInDatabase?.state)
        XCTAssertEqual(ClosingSwapState.completed.asString, swapInDatabase?.closeSwapState)
        XCTAssertEqual("0xclose_swap_tx_hash", swapInDatabase?.closeSwapTransactionHash)
        
    }
    
    /**
     Ensure that `SwapService` handles `SellerClosedEvent`s properly for swaps in which the user of this interface is the seller. (Handling when the user is the buyer is trivial, and thus not tested.)
     */
    func testHandleSellerClosedEvent() {
        // The ID of the swap that the seller has closed
        let swapID = UUID()
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // Create swap, add it to swapTruthSource, and save it persistently
        let swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.swapTruthSource = swapTruthSource
        
        let swap = try! Swap(
            isCreated: true,
            requiresFill: false,
            id: swapID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
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
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337),
            state: SwapState.awaitingClosing,
            role: SwapRole.makerAndSeller
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
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        // The SellerClosedEvent to be handled
        let event = SellerClosedEvent(id: swapID, chainID: BigUInt(31337), transactionHash: "close_swap_tx_hash")
        
        let expectation = XCTestExpectation(description: "Fulfilled after handleSellerClosedEvent and test assertions are executed")
        
        // Call handleSellerClosedEvent on background DispatchQueue so that the closures it runs on the main DispatchQueue are executed in time for us to test their results
        DispatchQueue.global().async {
            try! swapService.handleSellerClosedEvent(event)
            
            // We run this in the main DispatchQueue because queues are FIFO and this must be run after the closures that handleSellerClosedEvent passes to DispatchQueue.main.sync are executed
            DispatchQueue.main.sync {
                expectation.fulfill()
            }
        }
        
        // Wait for our assertions to be executed
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(swap.hasSellerClosed)
        XCTAssertEqual(SwapState.closed, swap.state)
        XCTAssertEqual(ClosingSwapState.completed, swap.closingSwapState)
        XCTAssertEqual("0xclose_swap_tx_hash", swap.closeSwapTransaction?.transactionHash)
        
        let swapInDatabase = try! databaseService.getSwap(id: swap.id.asData().base64EncodedString())
        XCTAssertTrue(swapInDatabase!.hasSellerClosed)
        XCTAssertEqual(SwapState.closed.asString, swapInDatabase?.state)
        XCTAssertEqual(ClosingSwapState.completed.asString, swapInDatabase?.closeSwapState)
        XCTAssertEqual("0xclose_swap_tx_hash", swapInDatabase?.closeSwapTransactionHash)
        
    }
    
}
