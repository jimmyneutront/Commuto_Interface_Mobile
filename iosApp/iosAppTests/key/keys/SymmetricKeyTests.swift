//
//  SymmetricKeyTests.swift
//  iosAppTests
//
//  Created by jimmyt on 7/13/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest
@testable import iosApp

class SymmetricKeyTests: XCTestCase {
    
    func testSymmetricEncryption() throws {
        let key = try newSymmetricKey()
        let encryptedData = try key.encrypt(data: "test".data(using: .utf16)!)
        XCTAssertEqual("test".data(using: .utf16)!, try key.decrypt(data: encryptedData))
    }

}
