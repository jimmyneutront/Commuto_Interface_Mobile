//
//  KMServiceUtilsTest.swift
//  iosAppTests
//
//  Created by jimmyt on 11/30/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest
@testable import iosApp

class KMServiceUtilsTest: XCTestCase {
    
    let dbService: DBService = DBService()
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
    
    func testSignatureUtils() throws {
        let keyPair = try kmService!.generateKeyPair()
        let signature = try keyPair.sign(data: "test".data(using: .utf16)!)
        XCTAssert(try keyPair.verifySignature(signedData: "test".data(using: .utf16)!, signature: signature))
    }
    
    func testAsymmetricEncryption() throws {
        let keyPair = try kmService!.generateKeyPair()
        let originalString = "test"
        let originalMessage = originalString.data(using: .utf16)
        let encryptedMessage = try keyPair.encrypt(clearData: originalMessage!)
        let decryptedData = try keyPair.decrypt(cipherData: encryptedMessage)
        let restoredString = String(bytes: decryptedData, encoding: .utf16)
        XCTAssertEqual(originalString, restoredString)
    }

}
