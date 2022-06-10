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

class BlockchainServiceTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func runBlockchainService() {
        let w3 = web3(provider: Web3HttpProvider(URL(string: "")!)!)
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            init(_ exp: XCTestExpectation) {
                if !exp.isInverted {
                    exp.isInverted = true
                }
                blockchainErrorInvertedExpectation = exp
            }
            let blockchainErrorInvertedExpectation: XCTestExpectation
            func handleBlockchainError(_ error: Error) {
                blockchainErrorInvertedExpectation.fulfill()
            }
        }
        let blockchainErrorExpectation = XCTestExpectation(description: "BlockchainService encountered an unexpected error")
        let errorHandler = TestBlockchainErrorHandler(blockchainErrorExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: OfferService(),
            web3Instance: w3,
            commutoSwapAddress: ""
        )
        blockchainService.listenLoop()
    }
    
    func testListen() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        let invertedExpectation = XCTestExpectation(description: "Something unexpected happened")
        invertedExpectation.isInverted = true
        let testingServerUrl = URL(string: "http://localhost:8546/test_blockchainservice_listen")!
        var request = URLRequest(url: testingServerUrl)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                invertedExpectation.fulfill()
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                invertedExpectation.fulfill()
            }
        }
        task.resume()
        wait(for: [responseExpectation, invertedExpectation], timeout: 60.0)
        let expectedOfferId = UUID(uuidString: testingServerResponse!.offerId)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: "http://192.168.1.13:8545")!)!)
        
        class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
            init(_ exp: XCTestExpectation) {
                if !exp.isInverted {
                    exp.isInverted = true
                }
                blockchainErrorInvertedExpectation = exp
            }
            let blockchainErrorInvertedExpectation: XCTestExpectation
            func handleBlockchainError(_ error: Error) {
                blockchainErrorInvertedExpectation.fulfill()
            }
        }
        let blockchainErrorExpectation = XCTestExpectation(description: "BlockchainService encountered an unexpected error")
        blockchainErrorExpectation.isInverted = true
        let errorHandler = TestBlockchainErrorHandler(blockchainErrorExpectation)
        
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
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                offerOpenedExpectation.fulfill()
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
                offerTakenEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                offerTakenExpectation.fulfill()
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
        wait(for: [offerOpenedExpectation, offerTakenExpectation, blockchainErrorExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerTakenEventPromise!.wait().id)
    }
    
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
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
            }
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
