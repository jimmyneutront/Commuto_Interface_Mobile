//
//  KMServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 11/8/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import XCTest
@testable import iosApp

class KeyManagerServiceTest: XCTestCase {
    
    let databaseService = try! DatabaseService()
    var keyManagerService: KeyManagerService?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        keyManagerService = KeyManagerService(databaseService: databaseService)
        try databaseService.createTables()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testGenerateAndGetKeyPair() throws {
        let keyPair = try keyManagerService!.generateKeyPair()
        let retrievedKeyPair = try keyManagerService!.getKeyPair(interfaceId: keyPair.interfaceId)
        XCTAssertEqual(keyPair.interfaceId, retrievedKeyPair!.interfaceId)
        XCTAssertEqual(try! keyPair.getPublicKey().publicKey, try! retrievedKeyPair!.getPublicKey().publicKey)
        XCTAssertEqual(keyPair.privateKey, retrievedKeyPair!.privateKey)
    }
    
    func testStoreAndGetPublicKey() throws {
        let keyPair = try keyManagerService!.generateKeyPair()
        let publicKey = try keyPair.getPublicKey()
        try keyManagerService!.storePublicKey(pubKey: publicKey)
        let retrievedPublicKey = try keyManagerService!.getPublicKey(interfaceId: publicKey.interfaceId)
        XCTAssertEqual(publicKey.interfaceId, retrievedPublicKey?.interfaceId)
        XCTAssertEqual(publicKey.publicKey, publicKey.publicKey)
    }

}
