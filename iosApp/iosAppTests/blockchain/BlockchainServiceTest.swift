//
//  BlockchainServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp
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
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        let invertedExpectation = XCTestExpectation(description: "Indicates something unexpected has happened, test should fail immediately")
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
        
        class TestOfferService: OfferNotifiable {
            init(_ oOE: XCTestExpectation, _ oTE: XCTestExpectation) {
                offerOpenedExpectation = oOE
                offerTakenExpectation = oTE
            }
            let offerOpenedExpectation: XCTestExpectation
            let offerTakenExpectation: XCTestExpectation
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedExpectation.fulfill()
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
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
    }
}
