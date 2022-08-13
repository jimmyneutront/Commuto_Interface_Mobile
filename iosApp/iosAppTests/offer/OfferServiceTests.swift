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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService, offerOpenedEventRepository: offerOpenedEventRepository)
        
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
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
        let settlementMethodsInDatabase = try! databaseService.getSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerInDatabase!.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0], Data("USD-SWIFT|a price here".utf8).base64EncodedString())
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
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer]
            
        }
        let offerTruthSource = TestOfferTruthSource()
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferOpenedEvent> {
            
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when remove is called")
            
            override func append(_ element: OfferOpenedEvent) {                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferOpenedEvent) {
                eventRemovedExpectation.fulfill()
                super.remove(elementToRemove)
            }
            
        }
        let offerOpenedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            offerOpenedEventRepository: offerOpenedEventRepository
        )
        offerService.offerTruthSource = offerTruthSource
        
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
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
        let testP2PService = TestP2PService(errorHandler: p2pErrorHandler, offerService: offerService, switrixClient: switrixClient)
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
            state: OfferState.openOfferTransactionBroadcast.asString
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService, offerCanceledEventRepository: offerCanceledEventRepository)
        
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
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
        XCTAssertEqual(openedOffer?.state, .canceled)
        XCTAssertEqual(offerCanceledEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerCanceledEventRepository.removedEvent!.id, expectedOfferID)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(offerInDatabase, nil)
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly.
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService, offerTakenEventRepository: offerTakenEventRepository)
        
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
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService, offerEditedEventRepository: offerEditedEventRepository)
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer]
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerEditedEventRepository.eventRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 1)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID]!.id == expectedOfferID)
        XCTAssertEqual(offerEditedEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerEditedEventRepository.removedEvent!.id, expectedOfferID)
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
        XCTAssertFalse(offerInDatabase!.havePublicKey)
        XCTAssertFalse(offerInDatabase!.isUserMaker)
        XCTAssertEqual(offerInDatabase!.state, OfferState.awaitingPublicKeyAnnouncement.asString)
        let settlementMethodsInDatabase = try! databaseService.getSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerInDatabase!.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0], Data("{\"f\":\"EUR\",\"p\":\"SEPA\",\"m\":\"0.98\"}".utf8).base64EncodedString())
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
        
        let offerService = OfferService<PreviewableOfferTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService
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
            state: offer.state.asString
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService)
        
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
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService)
        
        class TestOfferTruthSource: OfferTruthSource {
            init() {
                offers = [:]
            }
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
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
            state: "openOfferTxPublished"
        )
        XCTAssertEqual(offerInDatabase, expectedOfferInDatabase)
        
        let settlementMethodsInDatabase = try! databaseService.getSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: offerInDatabase.chainID)
        var expectedSettlementMethodsInDatabase: [String] = []
        for settlementMethod in offerInTruthSource.onChainSettlementMethods {
            expectedSettlementMethodsInDatabase.append(settlementMethod.base64EncodedString())
        }
        XCTAssertEqual(expectedSettlementMethodsInDatabase, settlementMethodsInDatabase)
        
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService)
        
        class TestOfferTruthSource: OfferTruthSource {
            var serviceFeeRate: BigUInt? = BigUInt(1)
            var offers: [UUID : Offer] = [:]
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
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
            state: offer.state.asString
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
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
        
        let offerService = OfferService<TestOfferTruthSource>(databaseService: databaseService, keyManagerService: keyManagerService)
        
        class TestOfferTruthSource: OfferTruthSource {
            var serviceFeeRate: BigUInt? = BigUInt(1)
            var offers: [UUID : Offer] = [:]
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let editingExpectation = XCTestExpectation(description: "Fulfilled when offerService.editOffer returns")
        
        offerService.editOffer(offerID: offerID, newSettlementMethods: [
            SettlementMethod(currency: "USD", price: "1.23", method: "a_method")
        ]).done {
            editingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [editingExpectation], timeout: 30.0)
        
        let expectedSettlementMethods = [
            try! JSONEncoder().encode(SettlementMethod(currency: "USD", price: "1.23", method: "a_method"))
        ]
        
        let offerStruct = try! blockchainService.getOffer(id: offerID)
        XCTAssertEqual(expectedSettlementMethods, offerStruct?.settlementMethods)
        
    }
    
}
