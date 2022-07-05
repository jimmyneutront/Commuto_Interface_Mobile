//
//  OfferServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 6/23/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp
@testable import web3swift
import SwiftUI

/**
 Tests for OfferService
 */
class OfferServiceTests: XCTestCase {
    /**
     Ensures that `OfferService` handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly.
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
        
        let offerService = OfferService(databaseService: databaseService, offerOpenedEventRepository: offerOpenedEventRepository)
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerAddedExpectation = XCTestExpectation(description: "Fulfilled when an offer is added to the offers dictionary")
            
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
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
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
        let settlementMethodsInDatabase = try! databaseService.getSettlementMethods(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0], Data("USD-SWIFT|a price here".utf8).base64EncodedString())
    }
    
    /**
     Ensures that `OfferService` handles [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) events properly.
     */
    func testHandleOfferCanceledEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferCanceledEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-canceled")
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
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferCanceledEvent> {
            
            var appendedEvent: OfferCanceledEvent? = nil
            var removedEvent: OfferCanceledEvent? = nil
            
            override func append(_ element: OfferCanceledEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferCanceledEvent) {
                removedEvent = elementToRemove
                super.remove(elementToRemove)
            }
            
        }
        
        let offerCanceledEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService(databaseService: databaseService, offerCanceledEventRepository: offerCanceledEventRepository)
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerRemovedExpectation = XCTestExpectation(description: "Fulfilled when an offer is removed to the offers dictionary")
            var hasOfferBeenAdded = false
            
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
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.offerRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 0)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID] == nil)
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
        
        let offerService = OfferService(databaseService: databaseService, offerTakenEventRepository: offerTakenEventRepository)
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerRemovedExpectation = XCTestExpectation(description: "Fulfilled when an offer is removed to the offers dictionary")
            var hasOfferBeenAdded = false
            
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
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
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
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferEditedEvent> {
            
            var appendedEvent: OfferEditedEvent? = nil
            var removedEvent: OfferEditedEvent? = nil
            
            override func append(_ element: OfferEditedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferEditedEvent) {
                removedEvent = elementToRemove
                super.remove(elementToRemove)
            }
            
        }
        
        let offerEditedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService(databaseService: databaseService, offerEditedEventRepository: offerEditedEventRepository)
        
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let editedOfferAddedExpectation = XCTestExpectation(description: "Fulfilled when the edited offer is added to the offers dictionary")
            
            var offersAddedCounter = 0
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and only fulfill when two `Offer`s have been added.
                    if offers.keys.count != 0 {
                        offersAddedCounter += 1
                        if offersAddedCounter == 2 {
                            editedOfferAddedExpectation.fulfill()
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
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.editedOfferAddedExpectation], timeout: 60.0)
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
        let settlementMethodsInDatabase = try! databaseService.getSettlementMethods(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0], Data("EUR-SEPA|an edited price here".utf8).base64EncodedString())
    }
}
