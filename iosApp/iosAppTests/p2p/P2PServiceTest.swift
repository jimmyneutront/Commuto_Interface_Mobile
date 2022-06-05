//
//  P2PServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp
@testable import PromiseKit
@testable import MatrixSDK

class P2PServiceTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testP2PServiceExpectation() {
        let p2pService = P2PService()
        let syncExpectation = XCTestExpectation(description: "Sync with Matrix homeserver")
        p2pService.mxClient.sync(fromToken: nil, serverTimeout: 60000, clientTimeout: 60000, setPresence: nil) { response in
            print(response)
            syncExpectation.fulfill()
        }
        wait(for: [syncExpectation], timeout: 60.0)
    }
    
    func testListenLoop() {
        let unfulfillableExpectation = XCTestExpectation(description: "Test the listen loop")
        let p2pService = P2PService()
        p2pService.listenLoop()
        wait(for: [unfulfillableExpectation], timeout: 60.0)
    }
}
