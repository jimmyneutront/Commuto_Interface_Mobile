//
//  BlockchainServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp
@testable import PromiseKit
@testable import web3swift

/**
 Tests for `BlockchainService`.
 */
class BlockchainServiceTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /**
     Runs the listen loop in the current thread. This doesn't actually test anything.
     */
    func runBlockchainService() {
        let w3 = web3(provider: Web3HttpProvider(URL(string: "")!)!)
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        let databaseService = DBService()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: OfferService(databaseService: databaseService),
            web3Instance: w3,
            commutoSwapAddress: ""
        )
        blockchainService.listenLoop()
    }
    
    /**
     Tests `BlockchainService` by ensuring it detects and handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) and [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events for a specific offer properly.
     */
    func testListenOfferOpenedTaken() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_listen")!
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
        XCTAssertTrue(!gotError)
        let expectedOfferId = UUID(uuidString: testingServerResponse!.offerId)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestOfferService: OfferNotifiable {
            init(_ oOE: XCTestExpectation,
                 _ oTE: XCTestExpectation) {
                offerOpenedExpectation = oOE
                offerTakenExpectation = oTE
            }
            let offerOpenedExpectation: XCTestExpectation
            let offerTakenExpectation: XCTestExpectation
            var offerOpenedEventPromise: Promise<OfferOpenedEvent>? = nil
            var offerTakenEventPromise: Promise<OfferTakenEvent>? = nil
            var gotOfferCanceledEvent = false
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerOpenedExpectation.fulfill()
                }
            }
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
                gotOfferCanceledEvent = true
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
                offerTakenEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerTakenExpectation.fulfill()
                }
            }
        }
        
        let offerOpenedExpectation = XCTestExpectation(description: "handleOfferOpenedEvent was called")
        let offerTakenExpectation = XCTestExpectation(description: "handleOfferTakenEvent was called")
        let offerService = TestOfferService(offerOpenedExpectation, offerTakenExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            web3Instance: w3,
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
        )
        blockchainService.listen()
        wait(for: [offerOpenedExpectation, offerTakenExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerTakenEventPromise!.wait().id)
        XCTAssertTrue(!offerService.gotOfferCanceledEvent)
        XCTAssertTrue(!errorHandler.gotError)
    }
    
    /**
     Tests `BlockchainService` by ensuring it detects and handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) and [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events for a specific offer properly.
     */
    func testListenOfferOpenedCanceled() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_listen")!
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
                gotError = false
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        let expectedOfferId = UUID(uuidString: testingServerResponse!.offerId)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            var gotError = false
            func handleBlockchainError(_ error: Error) {
                gotError = true
            }
        }
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestOfferService: OfferNotifiable {
            init(_ oOE: XCTestExpectation,
                 _ oCE: XCTestExpectation) {
                offerOpenedExpectation = oOE
                offerCanceledExpectation = oCE
            }
            let offerOpenedExpectation: XCTestExpectation
            let offerCanceledExpectation: XCTestExpectation
            var offerOpenedEventPromise: Promise<OfferOpenedEvent>? = nil
            var offerCanceledEventPromise: Promise<OfferCanceledEvent>? = nil
            var gotOfferTakenEvent = false
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerOpenedExpectation.fulfill()
                }
            }
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
                offerCanceledEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerCanceledExpectation.fulfill()
                }
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
                gotOfferTakenEvent = true
            }
        }
        
        let offerOpenedExpectation = XCTestExpectation(description: "handleOfferOpenedEvent was called")
        let offerCanceledExpectation = XCTestExpectation(description: "handleOfferCanceledEvent was called")
        let offerService = TestOfferService(offerOpenedExpectation, offerCanceledExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            web3Instance: w3,
            commutoSwapAddress: testingServerResponse!.commutoSwapAddress
        )
        blockchainService.listen()
        wait(for: [offerOpenedExpectation, offerCanceledExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerCanceledEventPromise!.wait().id)
        XCTAssertTrue(!offerService.gotOfferTakenEvent)
        XCTAssertTrue(!errorHandler.gotError)
        
    }
    
    /**
     Tests `BlockchainService`'s error handling logic by ensuring that it handles empty node response errors properly.
     */
    func testListenErrorHandling() {
        /*
         Yes, we want to create a web3 instance connected to the Commuto Testing Server, NOT a local Ethereum node. When a web3 instance is created, it attempts to call the "net_version" endpoint of the node it is to connect to. The Commuto Testing Server responds to this Ethereum endpoint in order to trick this web3 instance into thinking it is connected to a real Ethereum node, so that when it calls any other endpoint it throws an error and lets us test BlockchainService's error handling code.
         */
        let w3 = web3(provider: Web3HttpProvider(URL(string: "http://localhost:8546")!)!)
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            init(_ eE: XCTestExpectation) {
                errorExpectation = eE
            }
            var errorPromise: Promise<Error>? = nil
            let errorExpectation: XCTestExpectation
            func handleBlockchainError(_ error: Error) {
                errorPromise = Promise { seal in
                    seal.fulfill(error)
                }
                errorExpectation.fulfill()
            }
        }
        let errorExpectation = XCTestExpectation(description: "We expect to get an error here")
        let errorHandler = TestBlockchainErrorHandler(errorExpectation)
        
        class TestOfferService: OfferNotifiable {
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {}
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {}
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {}
        }
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            web3Instance: w3,
            commutoSwapAddress: "0x0000000000000000000000000000000000000000"
        )
        blockchainService.listen()
        wait(for: [errorExpectation], timeout: 20.0)
        assert(try! (errorHandler.errorPromise!.wait() as! Web3Error).errorDescription == "Node response is empty")
    }
}
