//
//  DatabaseKeyDeriverTests.swift
//  iosAppTests
//
//  Created by jimmyt on 9/17/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest
@testable import iosApp

/**
 Tests for `DatabaseKeyDeriver`.
 */
class DatabaseKeyDeriverTests: XCTestCase {
    
    /**
     Ensure `DatabaseKeyDeriver` consistently derives keys from a specific password and salt.
     */
    func testKeyDerivation() {
        let password = "an_example_password"
        let salt = "some_salt".data(using: .utf8)!
        
        let databaseKeyDeriver = try! DatabaseKeyDeriver(password: password, salt: salt)
        
        let encryptedData = try! databaseKeyDeriver.key.encrypt(data: "test".data(using: .utf8)!)
        
        let anotherDatabaseKeyDeriver = try! DatabaseKeyDeriver(password: password, salt: salt)
        
        XCTAssertEqual("test".data(using: .utf8)!, try anotherDatabaseKeyDeriver.key.decrypt(data: encryptedData))
    }
    
}
