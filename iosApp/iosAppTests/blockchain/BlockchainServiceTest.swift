//
//  BlockchainServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp

class BlockchainServiceTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBlockchainService() {
        let blockchainService = BlockchainService()
        blockchainService.listenLoop()
    }
    
}
