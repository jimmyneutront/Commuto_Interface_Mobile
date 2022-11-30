//
//  OfferServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 6/23/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Switrix
import web3swift
import XCTest

@testable import iosApp

/**
 Tests for OfferService
 */
class OfferServiceTests: XCTestCase {
    /**
     Ensures that `OfferService` handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly for offers NOT made by the interface user.
     */
    func testHandleOfferOpenedEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferOpenedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened")
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
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferOpenedEvent> {
            
            var appendedEvent: OfferOpenedEvent? = nil
            var removedEvent: OfferOpenedEvent? = nil
            
            override func append(_ element: OfferOpenedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferOpenedEvent) {
                removedEvent = elementToRemove
                super.remove(elementToRemove)
            }
            
        }
        
        let offerOpenedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerOpenedEventRepository: offerOpenedEventRepository
        )
        
        // We need this new TestOfferTruthSource declaration because we need to track added offers
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerAddedExpectation = XCTestExpectation(description: "Fulfilled when an offer is added to the offers dictionary")
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and only fulfill when a new offer is actually added
                    if offers.keys.count != 0 {
                        offerAddedExpectation.fulfill()
                    }
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.offerAddedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 1)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID]!.id == expectedOfferID)
        XCTAssertEqual(offerOpenedEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerOpenedEventRepository.removedEvent!.id, expectedOfferID)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertTrue(offerInDatabase!.isCreated)
        XCTAssertFalse(offerInDatabase!.isTaken)
        XCTAssertEqual(offerInDatabase!.interfaceId, Data("maker interface Id here".utf8).base64EncodedString())
        XCTAssertEqual(offerInDatabase!.amountLowerBound, "10000")
        XCTAssertEqual(offerInDatabase!.amountUpperBound, "10000")
        XCTAssertEqual(offerInDatabase!.securityDepositAmount, "1000")
        XCTAssertEqual(offerInDatabase!.serviceFeeRate, "100")
        XCTAssertEqual(offerInDatabase!.onChainDirection, "1")
        XCTAssertEqual(offerInDatabase!.protocolVersion, "1")
        XCTAssertEqual(offerInDatabase!.state, OfferState.awaitingPublicKeyAnnouncement.asString)
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerInDatabase!.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0].0, Data("USD-SWIFT|a price here".utf8).base64EncodedString())
    }
    
    /**
     Ensures that `OfferService` handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly for offers made by the interface user.
     */
    func testHandleOfferOpenedEventForUserIsMakerOffer() {
        
        let newOfferID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let keyPairForOffer = try! keyManagerService.generateKeyPair(storeResult: true)
        
        let interfaceIDString = keyPairForOffer.interfaceId.base64EncodedString()
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsMakerOffer_handleOfferOpenedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: newOfferID.uuidString),
            URLQueryItem(name: "interfaceID", value: interfaceIDString)
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
        
        let offerTruthSource = TestOfferTruthSource()
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferOpenedEvent> {
            
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when remove is called")
            
            override func append(_ element: OfferOpenedEvent) {
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferOpenedEvent) {
                eventRemovedExpectation.fulfill()
                super.remove(elementToRemove)
            }
            
        }
        let offerOpenedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerOpenedEventRepository: offerOpenedEventRepository
        )
        offerService.offerTruthSource = offerTruthSource
        
        let p2pErrorHandler = TestP2PErrorHandler()
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            var offerIDForAnnouncement: UUID?
            var keyPairForAnnouncement: KeyPair?
            override func announcePublicKey(offerID: UUID, keyPair: KeyPair) {
                offerIDForAnnouncement = offerID
                keyPairForAnnouncement = keyPair
            }
        }
        let testP2PService = TestP2PService(
            errorHandler: p2pErrorHandler,
            offerService: offerService,
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        offerService.p2pService = testP2PService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: newOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt("31337"),
            havePublicKey: true,
            isUserMaker: true,
            state: .openOfferTransactionBroadcast
        )
        offerTruthSource.offers[newOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: newOfferID.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.address,
            interfaceId: keyPairForOffer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.address,
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: offer.direction.string,
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: OfferState.openOfferTransactionBroadcast.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        
        wait(for: [offerOpenedEventRepository.eventRemovedExpectation], timeout: 60.0)
        XCTAssertFalse(errorHandler.gotError)
        XCTAssertEqual(testP2PService.offerIDForAnnouncement, newOfferID)
        XCTAssertEqual(testP2PService.keyPairForAnnouncement!.interfaceId, keyPairForOffer.interfaceId)
        XCTAssertEqual(OfferState.offerOpened, offerTruthSource.offers[newOfferID]!.state)
        let offerInDatabase = try! databaseService.getOffer(id: offerForDatabase.id)
        XCTAssertEqual(offerInDatabase!.state, OfferState.offerOpened.asString)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) events properly.
     */
    func testHandleOfferCanceledEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        let openOfferResponseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferCanceledEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened")
        ]
        var offerOpenRequest = URLRequest(url: testingServerUrlComponents.url!)
        offerOpenRequest.httpMethod = "GET"
        offerOpenRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotErrorForOpenRequest = false
        let offerOpenRequestTask = URLSession.shared.dataTask(with: offerOpenRequest) { data, response, error in
            if let error = error {
                print(error)
                gotErrorForOpenRequest = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                openOfferResponseExpectation.fulfill()
            } else {
                print(response!)
                gotErrorForOpenRequest = true
            }
        }
        offerOpenRequestTask.resume()
        wait(for: [openOfferResponseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotErrorForOpenRequest)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository<Event: Equatable>: BlockchainEventRepository<Event> {
            
            var appendedEvent: Event? = nil
            var removedEvent: Event? = nil
            
            override func append(_ element: Event) {
                super.append(element)
                appendedEvent = element
            }
            
            override func remove(_ elementToRemove: Event) {
                super.remove(elementToRemove)
                removedEvent = elementToRemove
            }
            
        }
        
        let offerCanceledEventRepository = TestBlockchainEventRepository<OfferCanceledEvent>()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerCanceledEventRepository: offerCanceledEventRepository
        )
        
        // We need this TestOfferTruthSource declaration because we need to track added and removed offers
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerAddedExpectation = XCTestExpectation(description: "Fulfuilled when an offer is added to the offers dictionary")
            let offerRemovedExpectation = XCTestExpectation(description: "Fulfilled when an offer is removed to the offers dictionary")
            var hasOfferBeenAdded = false
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and offer addition and only fulfill when a new offer is actually removed
                    if offers.keys.count != 0 {
                        hasOfferBeenAdded = true
                        offerAddedExpectation.fulfill()
                    } else {
                        if hasOfferBeenAdded {
                            offerRemovedExpectation.fulfill()
                        }
                    }
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        
        wait(for: [offerTruthSource.offerAddedExpectation], timeout: 60.0)
        let openedOffer = offerTruthSource.offers[expectedOfferID]
        
        let cancelOfferResponseExpectation = XCTestExpectation(description: "Fulfilled when testing server responds to request for offer cancellation")
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-canceled"),
            URLQueryItem(name: "commutoSwapAddress", value: testingServerResponse!.commutoSwapAddress)
        ]
        var offerCancellationRequest = URLRequest(url: testingServerUrlComponents.url!)
        offerCancellationRequest.httpMethod = "GET"
        offerCancellationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var gotErrorForCancellationRequest = false
        let cancellationRequestTask = URLSession.shared.dataTask(with: offerCancellationRequest) { data, response, error in
            if let error = error {
                print(error)
                gotErrorForCancellationRequest = true
            } else if data != nil {
                cancelOfferResponseExpectation.fulfill()
            } else {
                print(response!)
                gotErrorForCancellationRequest = true
            }
        }
        cancellationRequestTask.resume()
        wait(for: [cancelOfferResponseExpectation], timeout: 10.0)
        XCTAssertTrue(!gotErrorForCancellationRequest)
        
        wait(for: [offerTruthSource.offerRemovedExpectation], timeout: 20.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 0)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID] == nil)
        XCTAssertFalse(openedOffer!.isCreated)
        XCTAssertEqual(openedOffer?.state, .canceled)
        XCTAssertEqual(offerCanceledEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerCanceledEventRepository.removedEvent!.id, expectedOfferID)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(offerInDatabase, nil)
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers neither made nor taken by the interface user.
     */
    func testHandleOfferTakenEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken")
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
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferTakenEvent> {
            
            var appendedEvent: OfferTakenEvent? = nil
            var removedEvent: OfferTakenEvent? = nil
            
            override func append(_ element: OfferTakenEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferTakenEvent) {
                removedEvent = elementToRemove
                super.remove(elementToRemove)
            }
            
        }
        
        let offerTakenEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerTakenEventRepository: offerTakenEventRepository
        )
        
        // We need this TestOfferTruthSource declaration because we have to track removed offers
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerRemovedExpectation = XCTestExpectation(description: "Fulfilled when an offer is removed to the offers dictionary")
            var hasOfferBeenAdded = false
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and offer addition and only fulfill when a new offer is actually removed
                    if offers.keys.count != 0 {
                        hasOfferBeenAdded = true
                    } else {
                        if hasOfferBeenAdded {
                            offerRemovedExpectation.fulfill()
                        }
                    }
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.offerRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 0)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID] == nil)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(offerInDatabase, nil)
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers taken by the interface user.
     */
    func testHandleOfferTakenEventForUserIsTaker() {
        
        let newOfferID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to store the whole key pair persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        let makerInterfaceID = makerKeyPair.interfaceId
        // We store the maker's public key, as if we received it via the P2P network
        try! keyManagerService.storePublicKey(pubKey: try! makerKeyPair.getPublicKey())
        
        // This is the taker's (user's) key pair, so we do want to store it persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        let makerInterfaceIDString = makerInterfaceID.base64EncodedString()
        let takerInterfaceIDString = takerKeyPair.interfaceId.base64EncodedString()
        
        // Make testing server set up the proper test environment
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsTaker_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "offerID", value: newOfferID.uuidString),
            URLQueryItem(name: "makerInterfaceID", value: makerInterfaceIDString),
            URLQueryItem(name: "takerInterfaceID", value: takerInterfaceIDString)
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
        
        // Set up node connection
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        // OfferService should call the sendTakerInformationMessage method of this class, passing a UUID equal to newOfferID to begin the process of sending taker information
        class TestSwapService: SwapNotifiable {
            let expectation = XCTestExpectation(description: "Fulfilled when sendTakerInformationMessage is called")
            let expectedSwapIDForMessage: UUID
            var chainIDForMessage: BigUInt? = nil
            init(expectedSwapIDForMessage: UUID) {
                self.expectedSwapIDForMessage = expectedSwapIDForMessage
            }
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool {
                if swapID == expectedSwapIDForMessage {
                    chainIDForMessage = chainID
                    expectation.fulfill()
                    return true
                } else {
                    return false
                }
            }
            func handleNewSwap(takenOffer: Offer) throws {}
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
            func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {}
            func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {}
            func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {}
        }
        let swapService = TestSwapService(expectedSwapIDForMessage: newOfferID)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: swapService
        )
        offerService.offerTruthSource = TestOfferTruthSource()
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        
        wait(for: [swapService.expectation], timeout: 60.0)
        XCTAssertEqual(BigUInt(31337), swapService.chainIDForMessage)
        XCTAssertFalse(errorHandler.gotError)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers made by the interface user.
     */
    func testHandleOfferTakenEventForUserIsMaker() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let keyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // Make testing server set up the proper test environment
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsMaker_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "offerID", value: offerID.uuidString),
            URLQueryItem(name: "interfaceID", value: keyPair.interfaceId.base64EncodedString())
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
        
        // Set up node connection
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let offerTruthSource = TestOfferTruthSource()
        
        // OfferService should call the handleNewSwap method of this class, passing an offer with an ID equal to offerID. We need this new TestSwapService declaration to track when handleNewSwap is called
        class TestSwapService: SwapNotifiable {
            let handleNewSwapExpectation = XCTestExpectation(description: "Fulfilled when handleNewSwap is called")
            var swapID: UUID? = nil
            var chainID: BigUInt? = nil
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool { return false }
            func handleNewSwap(takenOffer: Offer) throws {
                self.swapID = takenOffer.id
                self.chainID = takenOffer.chainID
                handleNewSwapExpectation.fulfill()
            }
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
            func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {}
            func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {}
            func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {}
        }
        let swapService = TestSwapService()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: swapService
        )
        offerService.offerTruthSource = offerTruthSource
        
        let p2pErrorHandler = TestP2PErrorHandler()
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            override func announcePublicKey(offerID: UUID, keyPair: KeyPair) {}
        }
        let testP2PService = TestP2PService(
            errorHandler: p2pErrorHandler,
            offerService: offerService,
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        offerService.p2pService = testP2PService
        
        // We have to persistently store an offer with an ID equal to offerID and isUserMaker set to true, so that OfferService calls handleNewSwap
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: keyPair.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        
        wait(for: [swapService.handleNewSwapExpectation], timeout: 60.0)
        XCTAssertEqual(offerID, swapService.swapID)
        XCTAssertEqual(BigUInt(31337), swapService.chainID)
        XCTAssertFalse(errorHandler.gotError)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferrEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) events properly.
     */
    func testHandleOfferEditedEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferEditedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-edited")
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
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferEditedEvent> {
            
            var appendedEvent: OfferEditedEvent? = nil
            var removedEvent: OfferEditedEvent? = nil
            
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when eventRemovedExpectation is called")
            
            override func append(_ element: OfferEditedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferEditedEvent) {
                removedEvent = elementToRemove
                eventRemovedExpectation.fulfill()
                super.remove(elementToRemove)
            }
            
        }
        
        let offerEditedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerEditedEventRepository: offerEditedEventRepository
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: expectedOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .awaitingPublicKeyAnnouncement
        )!
        try! offer.updateSettlementMethods(settlementMethods: [
            SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", privateData: "some_swift_data")
        ])
        offerTruthSource.offers[expectedOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        let serializedSettlementMethodsAndPrivateDetails = offer.settlementMethods.compactMap { settlementMethod in
            return (try! JSONEncoder().encode(settlementMethod).base64EncodedString(), settlementMethod.privateData)
        }
        try! databaseService.storeOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID, settlementMethods: serializedSettlementMethodsAndPrivateDetails)
        
        let pendingSettlementMethods = [
            SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: "some_sepa_data"),
            SettlementMethod(currency: "BSD", price: "1.00", method: "SANDDOLLAR", privateData: "some_sanddollar_data")
        ]
        let serializedPendingSettlementMethodsAndPrivateDetails = pendingSettlementMethods.compactMap { pendingSettlementMethod in
            return (try! JSONEncoder().encode(pendingSettlementMethod).base64EncodedString(), pendingSettlementMethod.privateData)
        }
        try! databaseService.storePendingOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID, pendingSettlementMethods: serializedPendingSettlementMethodsAndPrivateDetails)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerEditedEvent = OfferEditedEvent(id: expectedOfferID, chainID: BigUInt(31337))
        
        // handleOfferEditedEvent runs code synchronously on the main DispatchQueue, so we must call it like this to avoid deadlock
        DispatchQueue.global().async {
            try! offerService.handleOfferEditedEvent(offerEditedEvent)
        }
        
        wait(for: [offerEditedEventRepository.eventRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 1)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID]!.id == expectedOfferID)
        XCTAssertEqual(offerEditedEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerEditedEventRepository.removedEvent!.id, expectedOfferID)
        
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 2)
        XCTAssertEqual(settlementMethodsInDatabase![0].0, Data("{\"f\":\"EUR\",\"p\":\"0.98\",\"m\":\"SEPA\"}".utf8).base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase![0].1, "some_sepa_data")
        XCTAssertEqual(settlementMethodsInDatabase![1].0, Data("{\"f\":\"BSD\",\"p\":\"1.00\",\"m\":\"SANDDOLLAR\"}".utf8).base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase![1].1, "some_sanddollar_data")
        
        let pendingSettlementMethodsInDatabase = try! databaseService.getPendingOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertNil(pendingSettlementMethodsInDatabase)
    }
    
    /**
     Ensures that `OfferService` handles [Public Key Announcements](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) properly.
     */
    func testHandlePublicKeyAnnouncement() {
        
        class TestDatabaseService: DatabaseService {
            
            let offerHavePublicKeyUpdatedExpectation = XCTestExpectation(description: "Fulfilled when updateOfferHavePublicKey is called")
            
            override func updateOfferHavePublicKey(offerID: String, _chainID: String, _havePublicKey: Bool) throws {
                try super.updateOfferHavePublicKey(offerID: offerID, _chainID: _chainID, _havePublicKey: _havePublicKey)
                offerHavePublicKeyUpdatedExpectation.fulfill()
            }
        }
        
        let databaseService = try! TestDatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<PreviewableOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = PreviewableOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let keyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        let publicKey = try! keyPair.getPublicKey()
        
        let offerID = UUID()
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: publicKey.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: false,
            isUserMaker: false,
            state: .awaitingPublicKeyAnnouncement
        )!
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let publicKeyAnnouncement = PublicKeyAnnouncement(
            offerId: offerID,
            pubKey: publicKey
        )
        
        // handlePublicKeyAnnouncement runs code synchronously on the main DispatchQueue, so we must call it like this to avoid deadlock
        DispatchQueue.global().async {
            try! offerService.handlePublicKeyAnnouncement(publicKeyAnnouncement)
        }
        
        wait(for: [databaseService.offerHavePublicKeyUpdatedExpectation], timeout: 30)
        XCTAssertTrue(offerTruthSource.offers[offerID]!.havePublicKey)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertTrue(offerInDatabase!.havePublicKey)
        XCTAssertEqual(offerInDatabase!.state, "offerOpened")
        let keyInDatabase = try! keyManagerService.getPublicKey(interfaceId: publicKey.interfaceId)
        XCTAssertEqual(keyInDatabase?.publicKey, publicKey.publicKey)
    }
    
    /**
     Ensures that `OfferService` handles [ServiceFeeRateChanged](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#servicefeeratechanged) events properly.
     */
    func testHandleServiceFeeRateChangedEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleServiceFeeRateChangedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "ServiceFeeRateChanged")
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
        wait(for: [responseExpectation], timeout: 40.0)
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        // We need this TestOfferTruthSource declaration in order to track setting of the service fee rate
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            var offers: [UUID : Offer] = [:]
            
            let serviceFeeRateSetExpectation = XCTestExpectation(description: "Fulfilled when the service fee rate is set")
            
            var serviceFeeRate: BigUInt? {
                didSet {
                    serviceFeeRateSetExpectation.fulfill()
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.serviceFeeRateSetExpectation], timeout: 60.0)
        XCTAssertFalse(errorHandler.gotError)
        XCTAssertEqual(offerTruthSource.serviceFeeRate, BigUInt(200))
        
    }
    
    /**
     Ensures that `OfferService.openOffer`, `BlockchainService.approveTokenTransfer` and `BlockchainService.openOffer` function properly.
     */
    func testOpenOffer() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let stablecoinAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        let testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_openOffer")!
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
        wait(for: [responseExpectation], timeout: 40.0)
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        // We need this TestOfferTruthSource in order to track added offers
        class TestOfferTruthSource: OfferTruthSource {
            let offerAddedExpectation = XCTestExpectation(description: "Fulfilled when an offer is added to the offers dictionary")
            var offers: [UUID : Offer] = [:] {
                didSet {
                    // We want to ignore initialization and only fulfill when a new offer is actually added
                    if offers.keys.count != 0 {
                        offerAddedExpectation.fulfill()
                    }
                }
            }
            var serviceFeeRate: BigUInt?
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let settlementMethods = [SettlementMethod(currency: "FIAT", price: "1.00", method: "Bank Transfer")]
        let offerData = try! validateNewOfferData(
            chainID: BigUInt(1),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            stablecoinInformation: StablecoinInformation(currencyCode: "STBL", name: "Basic Stablecoin", decimal: 3),
            minimumAmount: NSNumber(floatLiteral: 100.00).decimalValue,
            maximumAmount: NSNumber(floatLiteral: 200.00).decimalValue,
            securityDepositAmount: NSNumber(floatLiteral: 20.00).decimalValue,
            serviceFeeRate: BigUInt(100),
            direction: .sell,
            settlementMethods: settlementMethods
        )
        _ = offerService.openOffer(offerData: offerData)
        
        wait(for: [offerTruthSource.offerAddedExpectation], timeout: 30.0)
        
        let offerID = offerTruthSource.offers.keys.first!
        let offerInTruthSource = offerTruthSource.offers[offerID]!
        XCTAssertTrue(offerInTruthSource.isCreated)
        XCTAssertFalse(offerInTruthSource.isTaken)
        XCTAssertEqual(offerInTruthSource.id, offerID)
        #warning("TODO: check proper maker address once WalletService is implemented")
        //XCTAssertEqual(offerInTruthSource.maker, blockchainService.ethKeyStore.addresses!.first!)
        XCTAssertEqual(offerInTruthSource.stablecoin, EthereumAddress(testingServerResponse!.stablecoinAddress)!)
        XCTAssertEqual(offerInTruthSource.amountLowerBound, BigUInt(100_000))
        XCTAssertEqual(offerInTruthSource.amountUpperBound, BigUInt(200_000))
        XCTAssertEqual(offerInTruthSource.securityDepositAmount, BigUInt(20_000))
        XCTAssertEqual(offerInTruthSource.serviceFeeRate, BigUInt(100))
        XCTAssertEqual(offerInTruthSource.serviceFeeAmountLowerBound, BigUInt(1_000))
        XCTAssertEqual(offerInTruthSource.serviceFeeAmountUpperBound, BigUInt(2_000))
        XCTAssertEqual(offerInTruthSource.onChainDirection, BigUInt(1))
        XCTAssertEqual(offerInTruthSource.direction, .sell)
        XCTAssertEqual(
            offerInTruthSource.onChainSettlementMethods,
            settlementMethods.compactMap { settlementMethod in
                return try? JSONEncoder().encode(settlementMethod)
            }
        )
        XCTAssertEqual(offerInTruthSource.settlementMethods, settlementMethods)
        XCTAssertEqual(offerInTruthSource.protocolVersion, BigUInt.zero)
        XCTAssertTrue(offerInTruthSource.havePublicKey)
        
        XCTAssertNotNil(try! keyManagerService.getKeyPair(interfaceId: offerInTruthSource.interfaceId))
        
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())!
        #warning("TODO: check proper maker address once WalletService is implemented")
        let expectedOfferInDatabase = DatabaseOffer(
            id: offerInTruthSource.id.asData().base64EncodedString(),
            isCreated: true,
            isTaken: false,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!.addressData.toHexString(),
            interfaceId: offerInTruthSource.interfaceId.base64EncodedString(),
            stablecoin: offerInTruthSource.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offerInTruthSource.amountLowerBound),
            amountUpperBound: String(offerInTruthSource.amountUpperBound),
            securityDepositAmount: String(offerInTruthSource.securityDepositAmount),
            serviceFeeRate: String(offerInTruthSource.serviceFeeRate),
            onChainDirection: String(BigUInt(1)),
            protocolVersion: String(BigUInt.zero),
            chainID: String(BigUInt(31337)),
            havePublicKey: true,
            isUserMaker: true,
            state: "openOfferTxPublished",
            offerCancellationTransactionHash: offerInTruthSource.offerCancellationTransactionHash
        )
        XCTAssertEqual(offerInDatabase, expectedOfferInDatabase)
        
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: offerInDatabase.chainID)
        var expectedSettlementMethodsInDatabase: [String] = []
        for settlementMethod in offerInTruthSource.onChainSettlementMethods {
            expectedSettlementMethodsInDatabase.append(settlementMethod.base64EncodedString())
        }
        
        for (index, element) in expectedSettlementMethodsInDatabase.enumerated() {
            XCTAssertEqual(element, settlementMethodsInDatabase![index].0)
        }
        
        let offerStructOnChain = try! blockchainService.getOffer(id: offerInTruthSource.id)!
        XCTAssertTrue(offerStructOnChain.isCreated)
        XCTAssertFalse(offerStructOnChain.isTaken)
        #warning("TODO: check proper maker address once WalletService is implemented")
        XCTAssertEqual(offerStructOnChain.interfaceId, offerInTruthSource.interfaceId)
        XCTAssertEqual(offerStructOnChain.stablecoin, offerInTruthSource.stablecoin)
        XCTAssertEqual(offerStructOnChain.amountLowerBound, offerInTruthSource.amountLowerBound)
        XCTAssertEqual(offerStructOnChain.amountUpperBound, offerInTruthSource.amountUpperBound)
        XCTAssertEqual(offerStructOnChain.securityDepositAmount, offerInTruthSource.securityDepositAmount)
        XCTAssertEqual(offerStructOnChain.serviceFeeRate, offerInTruthSource.serviceFeeRate)
        XCTAssertEqual(offerStructOnChain.direction, offerInTruthSource.onChainDirection)
        XCTAssertEqual(offerStructOnChain.settlementMethods, offerInTruthSource.onChainSettlementMethods)
        XCTAssertEqual(offerStructOnChain.protocolVersion, offerInTruthSource.protocolVersion)
        #warning("TODO: re-enable this once we get accurate chain IDs")
        //XCTAssertEqual(offerStructOnChain.chainID, offerInTruthSource.chainID)
        
    }
    
    /**
     Ensures that `OfferService.cancelOffer` and `BlockchainService.cancelOffer` function properly.
     */
    func testCancelOffer() {
        
        let offerID = UUID()
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_cancelOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString)
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
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerInDatabaseBeforeCancellation = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(offerForDatabase, offerInDatabaseBeforeCancellation)
        
        let cancellationExpectation = XCTestExpectation(description: "Fulfilled when offerService.cancelOffer returns")
        
        offerService.cancelOffer(offerID: offerID, chainID: BigUInt(31337)).done {
            cancellationExpectation.fulfill()
        }.cauterize()
        
        wait(for: [cancellationExpectation], timeout: 30.0)
        
        XCTAssertEqual(offerTruthSource.offers[offerID]?.state, .cancelOfferTransactionBroadcast)
        
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())!
        XCTAssertEqual(offerInDatabase.state, "cancelOfferTxBroadcast")
        
        let offerStruct = try! blockchainService.getOffer(id: offerID)
        XCTAssertNil(offerStruct)
        
    }
    
    /**
     Ensures that `OfferService.editOffer` and `BlockchainService.editOffer` function properly.
     */
    func testEditOffer() {
        
        let offerID = UUID()
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_editOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString)
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
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerTruthSource.serviceFeeRate = BigUInt(1)
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 2_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337), // Hardhat blockchain ID,
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let editingExpectation = XCTestExpectation(description: "Fulfilled when offerService.editOffer returns")
        
        offerService.editOffer(offerID: offerID, newSettlementMethods: [
            SettlementMethod(currency: "USD", price: "1.23", method: "a_method", privateData: "some_private_data")
        ]).done {
            editingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [editingExpectation], timeout: 30.0)
        
        let expectedSettlementMethods = [
            try! JSONEncoder().encode(SettlementMethod(currency: "USD", price: "1.23", method: "a_method"))
        ]
        
        let offerStruct = try! blockchainService.getOffer(id: offerID)
        XCTAssertEqual(expectedSettlementMethods, offerStruct?.settlementMethods)
        
        let pendingSettlementMethodsInDatabase = try! databaseService.getPendingOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: String(BigUInt(31337)))
        XCTAssertEqual(1, pendingSettlementMethodsInDatabase!.count)
        XCTAssertEqual("some_private_data", pendingSettlementMethodsInDatabase?[0].1)
        
    }
    
    /**
     Ensures that `OfferService.takeOffer`, `BlockchainService.approveTokenTransfer` and `BlockchainService.takeOffer` function properly.
     */
    func testTakeOffer() {
        
        let offerID = UUID()
        
        let encodedSettlementMethod = try! JSONEncoder().encode(SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA"))
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let stablecoinAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_takeOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString),
            URLQueryItem(name: "settlement_method_string", value: String(bytes: encodedSettlementMethod, encoding: .utf8)),
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
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerTruthSource.serviceFeeRate = BigUInt(1)
        offerService.offerTruthSource = offerTruthSource
        
        let swapTruthSource = TestSwapTruthSource()
        offerService.swapTruthSource = swapTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 2_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337), // Hardhat blockchain ID,
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            offerCancellationTransactionHash: offer.offerCancellationTransactionHash
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerInDatabaseBeforeCancellation = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(offerForDatabase, offerInDatabaseBeforeCancellation)
        
        let takingExpectation = XCTestExpectation(description: "Fulfilled when offerService.takeOffer returns")
        
        let swapData = ValidatedNewSwapData(takenSwapAmount: 15_000 * BigUInt(10).power(18), makerSettlementMethod: SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: ""), takerSettlementMethod: SettlementMethod(currency: "EUR", price: "", method: "SEPA", privateData: "Taker_EUR_SEPA_Private_Data"))
        
        offerService.takeOffer(offerToTake: offer, swapData: swapData).done {
            takingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [takingExpectation], timeout: 30.0)
        
        let swapOnChain = try! blockchainService.getSwap(id: offerID)!
        XCTAssertTrue(swapOnChain.isCreated)
        
        let keyPair = try! keyManagerService.getKeyPair(interfaceId: swapOnChain.takerInterfaceID)
        XCTAssertNotNil(keyPair)
        
        // Test the Swap in swapTruthSource
        let swapInTruthSource = swapTruthSource.swaps[offerID]!
        XCTAssertTrue(swapInTruthSource.isCreated)
        XCTAssertFalse(swapInTruthSource.requiresFill)
        XCTAssertEqual(offerID, swapInTruthSource.id)
        XCTAssertEqual(EthereumAddress("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")!, swapInTruthSource.maker)
        XCTAssertEqual(Data(), swapInTruthSource.makerInterfaceID)
        #warning("TODO: check taker address once walletService is implemented")
        XCTAssertEqual(swapInTruthSource.takerInterfaceID, swapOnChain.takerInterfaceID)
        XCTAssertEqual(EthereumAddress(testingServerResponse!.stablecoinAddress)!, swapInTruthSource.stablecoin)
        XCTAssertEqual(10_000 * BigUInt(10).power(18), swapInTruthSource.amountLowerBound)
        XCTAssertEqual(20_000 * BigUInt(10).power(18), swapInTruthSource.amountUpperBound)
        XCTAssertEqual(2_000 * BigUInt(10).power(18), swapInTruthSource.securityDepositAmount)
        XCTAssertEqual(15_000 * BigUInt(10).power(18), swapInTruthSource.takenSwapAmount)
        XCTAssertEqual(150 * BigUInt(10).power(18), swapInTruthSource.serviceFeeAmount)
        XCTAssertEqual(BigUInt(100), swapInTruthSource.serviceFeeRate)
        XCTAssertEqual(BigUInt(0), swapInTruthSource.onChainDirection)
        XCTAssertEqual(.buy, swapInTruthSource.direction)
        XCTAssertEqual(try! JSONEncoder().encode(SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")), swapInTruthSource.onChainSettlementMethod)
        XCTAssertEqual("EUR", swapInTruthSource.settlementMethod.currency)
        XCTAssertEqual("0.98", swapInTruthSource.settlementMethod.price)
        XCTAssertEqual("SEPA", swapInTruthSource.settlementMethod.method)
        XCTAssertEqual("Taker_EUR_SEPA_Private_Data", swapInTruthSource.takerPrivateSettlementMethodData)
        XCTAssertEqual(BigUInt(1), swapInTruthSource.protocolVersion)
        XCTAssertFalse(swapInTruthSource.isPaymentSent)
        XCTAssertFalse(swapInTruthSource.isPaymentReceived)
        XCTAssertFalse(swapInTruthSource.hasBuyerClosed)
        XCTAssertFalse(swapInTruthSource.hasSellerClosed)
        XCTAssertEqual(BigUInt(0), swapInTruthSource.onChainDisputeRaiser)
        XCTAssertEqual(BigUInt(31337), swapInTruthSource.chainID)
        XCTAssertEqual(.takeOfferTransactionBroadcast, swapInTruthSource.state)
        
        // Test the persistently stored swap
        let swapInDatabase = try! databaseService.getSwap(id: offerID.asData().base64EncodedString())!
        #warning("TODO: check proper taker address once WalletService is implemented")
        let expectedSwapInDatabase = DatabaseSwap(
            id: swapInTruthSource.id.asData().base64EncodedString(),
            isCreated: swapInTruthSource.isCreated,
            requiresFill: swapInTruthSource.requiresFill,
            maker: swapInTruthSource.maker.addressData.toHexString(),
            makerInterfaceID: swapInTruthSource.makerInterfaceID.base64EncodedString(),
            taker: swapInTruthSource.taker.addressData.toHexString(),
            takerInterfaceID: swapInTruthSource.takerInterfaceID.base64EncodedString(),
            stablecoin: swapInTruthSource.stablecoin.addressData.toHexString(),
            amountLowerBound: String(swapInTruthSource.amountLowerBound),
            amountUpperBound: String(swapInTruthSource.amountUpperBound),
            securityDepositAmount: String(swapInTruthSource.securityDepositAmount),
            takenSwapAmount: String(swapInTruthSource.takenSwapAmount),
            serviceFeeAmount: String(swapInTruthSource.serviceFeeAmount),
            serviceFeeRate: String(swapInTruthSource.serviceFeeRate),
            onChainDirection: String(swapInTruthSource.onChainDirection),
            onChainSettlementMethod: swapInTruthSource.onChainSettlementMethod.base64EncodedString(),
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: "Taker_EUR_SEPA_Private_Data",
            protocolVersion: String(swapInTruthSource.protocolVersion),
            isPaymentSent: swapInTruthSource.isPaymentSent,
            isPaymentReceived: swapInTruthSource.isPaymentReceived,
            hasBuyerClosed: swapInTruthSource.hasBuyerClosed,
            hasSellerClosed: swapInTruthSource.hasSellerClosed,
            onChainDisputeRaiser: String(swapInTruthSource.onChainDisputeRaiser),
            chainID: String(swapInTruthSource.chainID),
            state: swapInTruthSource.state.asString,
            role: "takerAndSeller"
        )
        XCTAssertEqual(expectedSwapInDatabase, swapInDatabase)
        
        // Ensure the Offer is in the "taken" state
        XCTAssertEqual(.taken, offer.state)
        
        // Check that the offer has been deleted from persistent storage
        XCTAssertNil(try! databaseService.getOffer(id: offerID.asData().base64EncodedString()))
        
        // Check that the offer's settlement methods have been deleted from persistent storage
        XCTAssertNil(try! databaseService.getOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: String(BigUInt(31337))))
    }
    
}
