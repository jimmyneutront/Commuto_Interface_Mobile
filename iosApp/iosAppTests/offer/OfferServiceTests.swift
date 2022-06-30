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
        
        class TestDatabaseService: DatabaseService {
            
            override init() throws {
                try super.init()
            }
            
            var storedDatabaseOfferOpenedEvent: DatabaseOfferOpenedEvent? = nil
            var wasDeleteOfferOpenedEventCalled = false
            
            override func storeOfferOpenedEvent(id: String, interfaceId: String) throws {
                storedDatabaseOfferOpenedEvent = DatabaseOfferOpenedEvent(id: id, interfaceId: interfaceId)
                try super.storeOfferOpenedEvent(id: id, interfaceId: interfaceId)
            }
            
            //TODO: check that the id matches that in storeOfferOpenedEvent cal
            override func deleteOfferOpenedEvents(id: String) throws {
                wasDeleteOfferOpenedEventCalled = true
                try super.deleteOfferOpenedEvents(id: id)
            }
            
        }
        
        let databaseService = try! TestDatabaseService()
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
                super.append(elementToRemove)
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
        XCTAssertEqual(databaseService.storedDatabaseOfferOpenedEvent!.id, expectedOfferID.asData().base64EncodedString())
        XCTAssertTrue(databaseService.wasDeleteOfferOpenedEventCalled)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertTrue(offerInDatabase!.isCreated)
        XCTAssertFalse(offerInDatabase!.isTaken)
        XCTAssertEqual(offerInDatabase!.interfaceId, Data("maker interface Id here".utf8).base64EncodedString())
        XCTAssertEqual(offerInDatabase!.amountLowerBound, "10000")
        XCTAssertEqual(offerInDatabase!.amountUpperBound, "10000")
        XCTAssertEqual(offerInDatabase!.securityDepositAmount, "1000")
        XCTAssertEqual(offerInDatabase!.serviceFeeRate, "100")
        XCTAssertEqual(offerInDatabase!.onChainDirection, "1")
        XCTAssertEqual(offerInDatabase!.onChainPrice, Data("a price here".utf8).base64EncodedString())
        XCTAssertEqual(offerInDatabase!.protocolVersion, "1")
    }
}
