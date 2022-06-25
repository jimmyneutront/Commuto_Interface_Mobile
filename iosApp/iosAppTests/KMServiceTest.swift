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

class KMServiceTest: XCTestCase {
    
    let dbService: DatabaseService = DatabaseService()
    var kmService: KMService?
     

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        kmService = KMService(dbService: dbService)
        try dbService.connectToDb()
        try dbService.createTables()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testGenerateAndRetrieveKeyPair() throws {
        let keyPair = try kmService!.generateKeyPair()
        let retrievedKeyPair = try kmService!.getKeyPair(interfaceId: keyPair.interfaceId)
        XCTAssertEqual(keyPair.interfaceId, retrievedKeyPair!.interfaceId)
        XCTAssertEqual(keyPair.publicKey, retrievedKeyPair!.publicKey)
        XCTAssertEqual(keyPair.privateKey, retrievedKeyPair!.privateKey)
    }
    
    func testStoreAndRetrievePublicKey() throws {
        let keyPair = try kmService!.generateKeyPair()
        let publicKey = try PublicKey(publicKey: keyPair.publicKey)
        try kmService!.storePublicKey(pubKey: publicKey)
        let retrievedPublicKey = try kmService!.getPublicKey(interfaceId: publicKey.interfaceId)
        XCTAssertEqual(publicKey.interfaceId, retrievedPublicKey?.interfaceId)
        XCTAssertEqual(publicKey.publicKey, publicKey.publicKey)
    }

}
