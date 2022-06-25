//
//  DatabaseServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest
@testable import iosApp
@testable import SQLite

class DatabaseServiceTests: XCTestCase {
    
    let dbService = try! DatabaseService()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try dbService.createTables()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStoreAndGetOfferOpenedEvent() throws {
        try dbService.storeOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        let expectedOfferOpenedEvent = DatabaseOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        let offerOpenedEvent = try dbService.getOfferOpenedEvent(id: "offer_id")
        XCTAssertEqual(expectedOfferOpenedEvent, offerOpenedEvent)
    }
    
    func testStoreAndGetKeyPair() throws {
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        let expectedKeyPair = DatabaseKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        let keyPair: DatabaseKeyPair? = try dbService.getKeyPair(interfaceId: "interf_id")
        XCTAssertEqual(expectedKeyPair, keyPair!)
    }
    
    func testStoreAndGetPublicKey() throws {
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        let expectedPublicKey = DatabasePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        let publicKey: DatabasePublicKey? = try dbService.getPublicKey(interfaceId: "interf_id")
        XCTAssertEqual(expectedPublicKey, publicKey!)
    }
    
    func testDuplicateKeyPairProtection() throws {
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        // This should do nothing and not throw
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        // This should not throw, since only one such key pair should exist in the database
        _ = try dbService.getKeyPair(interfaceId: "interf_id")
    }
    
    func testDuplicatePublicKeyProtection() throws {
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        // This should do nothing and not throw
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        // This should not throw, since only one such public key should exist in the database
        _ = try dbService.getPublicKey(interfaceId: "interf_id")
    }
    
    func testDuplicateOfferOpenedEventProtection() throws {
        try dbService.storeOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        // This should do nothing and not throw
        try dbService.storeOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        // This should not throw, since only one such OfferOpened event should exist in the database
        _ = try dbService.getOfferOpenedEvent(id: "offer_id")
    }

}
