//
//  DBServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest
@testable import iosApp

class DBServiceTest: XCTestCase {
    
    let dbService = DBService()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try dbService.connectToDb()
        try dbService.createTables()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStoreAndGetKeyPair() throws {
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        let expectedKeyPair = DBKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        let keyPair: DBKeyPair? = try dbService.getKeyPair(interfaceId: "interf_id")
        XCTAssertEqual(expectedKeyPair, keyPair!)
    }
    
    func testStoreAndGetPublicKey() throws {
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        let expectedPublicKey = DBPublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        let publicKey: DBPublicKey? = try dbService.getPublicKey(interfaceId: "interf_id")
        XCTAssertEqual(expectedPublicKey, publicKey!)
    }
    
    func testDuplicateKeyPairProtection() throws {
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        do {
            try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        } catch DBService.DBServiceError.unexpectedDbResult(let message) where message == "Database query for key pair with interface id interf_id returned result" {
            
        }
    }
    
    func testDuplicatePublicKeyProtection() throws {
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        do {
            try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        } catch DBService.DBServiceError.unexpectedDbResult(let message) where message == "Database query for public key with interface id interf_id returned result" {
            
        }
    }

}
