//
//  BlockchainServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import PromiseKit
import web3swift
import XCTest

@testable import iosApp

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
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let databaseService = try! DatabaseService()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        #warning("TODO: use previewable offer truth source here")
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: OfferService<OffersViewModel, SwapViewModel>(
                databaseService: databaseService,
                keyManagerService: keyManagerService,
                swapService: TestSwapService()
            ),
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress("0x687F36336FCAB8747be1D41366A416b41E7E1a96")!
        )
        blockchainService.listenLoop()
    }
    
    /**
     Ensure `BlockchainService`'s `getServiceFeeRate`  method works properly.
     */
    func testGetServiceFeeRate() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        let testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_getServiceFeeRate")!
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
        
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestOfferService: OfferNotifiable {
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {}
            func handleOfferEditedEvent(_ event: OfferEditedEvent) {}
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {}
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {}
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) {}
        }
        let offerService = TestOfferService()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        
        let serviceFeeRateExpectation = XCTestExpectation(description: "Get current Service Fee Rate from CommutoSwap")
        
        firstly {
            blockchainService.getServiceFeeRate()
        }.done { serviceFeeRate in
            if (serviceFeeRate == BigUInt(100)) {
                serviceFeeRateExpectation.fulfill()
            }
        }.cauterize()
        
        wait(for: [serviceFeeRateExpectation], timeout: 10.0)
        
    }
    
    /**
     `BlockchainService.approveTokenTransfer` is  tested by `OfferServiceTests.testOpenOffer`.
     */
    
    /**
     `BlockchainService.openOffer` is tested by `OfferServiceTests.testOpenOffer`.
     */
    
    /**
     `BlockchainService.cancelOffer` is tested by `OfferServiceTests.testCancelOffer`.
     */
    
    /**
     `BlockchainService.editOffer` is tested by `OfferServiceTests.testEditOffer`.
     */
    
    /**
     `BlockchainService.takeOffer` is tested by `OfferServiceTests.testTakeOffer`.
     */
    
    /**
     `BlockchainService.fillSwap` is tested by `SwapServiceTests.testFillSwap`.
     */
    
    /**
     `BlockchainService.reportPaymentSent` is tested by `SwapServiceTests.testReportPaymentSent`.
     */
    
    /**
     `BlockchainService.reportPaymentReceived` is tested by `SwapServiceTests.testReportPaymentReceived`.
     */
    
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
            var gotOfferEditedEvent = false
            var gotOfferCanceledEvent = false
            var gotServiceFeeRateChangedEvent = false
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerOpenedExpectation.fulfill()
                }
            }
            func handleOfferEditedEvent(_ event: OfferEditedEvent) throws {
                gotOfferEditedEvent = true
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
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) throws {
                gotServiceFeeRateChangedEvent = true
            }
        }
        
        let offerOpenedExpectation = XCTestExpectation(description: "handleOfferOpenedEvent was called")
        let offerTakenExpectation = XCTestExpectation(description: "handleOfferTakenEvent was called")
        let offerService = TestOfferService(offerOpenedExpectation, offerTakenExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainService.listen()
        wait(for: [offerOpenedExpectation, offerTakenExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerTakenEventPromise!.wait().id)
        XCTAssertFalse(offerService.gotOfferEditedEvent)
        XCTAssertFalse(offerService.gotOfferCanceledEvent)
        XCTAssertFalse(offerService.gotServiceFeeRateChangedEvent)
        XCTAssertFalse(errorHandler.gotError)
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
            var gotOfferEditedEvent = false
            var gotOfferTakenEvent = false
            var gotServiceFeeRateChangedEvent = false
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerOpenedExpectation.fulfill()
                }
            }
            func handleOfferEditedEvent(_ event: OfferEditedEvent) throws {
                gotOfferEditedEvent = true
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
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) throws {
                gotServiceFeeRateChangedEvent = true
            }
        }
        
        let offerOpenedExpectation = XCTestExpectation(description: "handleOfferOpenedEvent was called")
        let offerCanceledExpectation = XCTestExpectation(description: "handleOfferCanceledEvent was called")
        let offerService = TestOfferService(offerOpenedExpectation, offerCanceledExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainService.listen()
        wait(for: [offerOpenedExpectation, offerCanceledExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerCanceledEventPromise!.wait().id)
        XCTAssertFalse(offerService.gotOfferEditedEvent)
        XCTAssertFalse(offerService.gotOfferTakenEvent)
        XCTAssertFalse(offerService.gotServiceFeeRateChangedEvent)
        XCTAssertFalse(errorHandler.gotError)
        
    }
    
    /**
     Tests `BlockchainService` by ensuring it detects and handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) and [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) events for a specific offer properly.
     */
    func testListenOfferOpenedEdited() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get new CommutoSwap contract address from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_listen")!
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
                gotError = false
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        let expectedOfferId = UUID(uuidString: testingServerResponse!.offerId)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestOfferService: OfferNotifiable {
            init(_ oOE: XCTestExpectation,
                 _ oEE: XCTestExpectation) {
                offerOpenedExpectation = oOE
                offerEditedExpectation = oEE
            }
            let offerOpenedExpectation: XCTestExpectation
            let offerEditedExpectation: XCTestExpectation
            var offerOpenedEventPromise: Promise<OfferOpenedEvent>? = nil
            var offerEditedEventPromise: Promise<OfferEditedEvent>? = nil
            var gotOfferCanceledEvent = false
            var gotOfferTakenEvent = false
            var gotServiceFeeRateChangedEvent = false
            func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
                offerOpenedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerOpenedExpectation.fulfill()
                }
            }
            func handleOfferEditedEvent(_ event: OfferEditedEvent) throws {
                offerEditedEventPromise = Promise { seal in
                    seal.fulfill(event)
                }
                DispatchQueue.main.async {
                    self.offerEditedExpectation.fulfill()
                }
            }
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
                gotOfferCanceledEvent = true
            }
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {
                gotOfferTakenEvent = true
            }
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) throws {
                gotServiceFeeRateChangedEvent = true
            }
        }
        
        let offerOpenedExpectation = XCTestExpectation(description: "handleOfferOpenedEvent was called")
        let offerEditedExpectation = XCTestExpectation(description: "handleOfferEditedEvent was called")
        let offerService = TestOfferService(offerOpenedExpectation, offerEditedExpectation)
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainService.listen()
        wait(for: [offerOpenedExpectation, offerEditedExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferId, try! offerService.offerOpenedEventPromise!.wait().id)
        XCTAssertEqual(expectedOfferId, try! offerService.offerEditedEventPromise!.wait().id)
        XCTAssertFalse(offerService.gotOfferCanceledEvent)
        XCTAssertFalse(offerService.gotOfferTakenEvent)
        XCTAssertFalse(offerService.gotServiceFeeRateChangedEvent)
        XCTAssertFalse(errorHandler.gotError)
        
    }
    
    /**
     Tests `BlockchainService` to  ensure it detects and handles [SwapFilled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swapfilled) events properly.
     */
    func testListenSwapFilled() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let swapID: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_listen")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken-swapFilled")
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
        XCTAssertFalse(gotError)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.swapID)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestSwapService: SwapNotifiable {
            
            let swapFilledExpectation = XCTestExpectation(description: "Fulfilled when handleSwapFilledEvent is called")
            var swapFilledEvent: SwapFilledEvent? = nil
            
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws {}
            
            func handleNewSwap(swapID: UUID, chainID: BigUInt) throws {}
            
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {
                swapFilledEvent = event
                swapFilledExpectation.fulfill()
            }
            
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
            
        }
        
        let swapService = TestSwapService()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainService.listen()
        
        wait(for: [swapService.swapFilledExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferID, swapService.swapFilledEvent!.id)
        
    }
    
    /**
     Tests `BlockchainService` to  ensure it detects and handles [PaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#paymentsent) events properly.
     */
    func testListenPaymentSent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let swapID: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_blockchainservice_listen")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken-SwapFilled-PaymentSent")
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
        XCTAssertFalse(gotError)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.swapID)!
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        class TestSwapService: SwapNotifiable {
            
            let paymentSentExpectation = XCTestExpectation(description: "Fulfilled when handlePaymentSentEvent is called")
            var paymentSentEvent: PaymentSentEvent? = nil
            
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws {}
            
            func handleNewSwap(swapID: UUID, chainID: BigUInt) throws {}
            
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
            
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {
                paymentSentEvent = event
                paymentSentExpectation.fulfill()
            }
            
        }
        
        let swapService = TestSwapService()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainService.listen()
        
        wait(for: [swapService.paymentSentExpectation], timeout: 60.0)
        XCTAssertEqual(expectedOfferID, swapService.paymentSentEvent!.id)
        
    }
    
    /**
     Tests `BlockchainService`'s error handling logic by ensuring that it handles empty node response errors properly.
     */
    func testListenErrorHandling() {
        /*
         Yes, we want to create a web3 instance connected to the Commuto Testing Server, NOT a local Ethereum node. When a web3 instance is created, it attempts to call the "net_version" endpoint of the node it is to connect to. The Commuto Testing Server responds to this Ethereum endpoint in order to trick this web3 instance into thinking it is connected to a real Ethereum node, so that when it calls any other endpoint it throws an error and lets us test BlockchainService's error handling code.
         */
        let w3 = web3(provider: Web3HttpProvider(URL(string: "http://localhost:8546")!)!)
        
        // We need this TestBlockchainErrorHandler implementation to test handling of errors
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
            func handleOfferEditedEvent(_ event: OfferEditedEvent) {}
            func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {}
            func handleOfferTakenEvent(_ event: OfferTakenEvent) {}
            func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) {}
        }
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: TestOfferService(),
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress("0x0000000000000000000000000000000000000000")!
        )
        blockchainService.listen()
        wait(for: [errorExpectation], timeout: 20.0)
        assert(try! (errorHandler.errorPromise!.wait() as! Web3Error).errorDescription == "Node response is empty")
    }
}
