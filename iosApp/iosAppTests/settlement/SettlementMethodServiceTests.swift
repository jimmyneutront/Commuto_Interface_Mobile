//
//  SettlementMethodServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 10/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest

@testable import iosApp

class SettlementMethodServiceTests: XCTestCase {
    
    /**
     Ensures `SettlementMethodService.addSettlementMethod` functions properly.
     */
    func testAddSettlementMethod() {
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        
        let settlementMethodTruthSource = PreviewableSettlementMethodTruthSource()
        
        let settlementMethodService = SettlementMethodService<PreviewableSettlementMethodTruthSource>(databaseService: databaseService)
        settlementMethodService.settlementMethodTruthSource = settlementMethodTruthSource
        
        let settlementMethodAddedExpectation = XCTestExpectation(description: "Fulfilled immediately after addSettlementMethod call is completed")
        
        var settlementMethodToAdd = SettlementMethod(currency: "EUR", price: "", method: "SEPA")
        let privateData = PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")
        settlementMethodToAdd.privateData = String(decoding: try! JSONEncoder().encode(privateData), as: UTF8.self)
        
        settlementMethodService.addSettlementMethod(settlementMethod: settlementMethodToAdd, newPrivateData: privateData).done {
            settlementMethodAddedExpectation.fulfill()
        }.cauterize()
        
        wait(for: [settlementMethodAddedExpectation], timeout: 20.0)
        
        XCTAssertEqual(1, settlementMethodTruthSource.settlementMethods.count)
        let addedSettlementMethod = settlementMethodTruthSource.settlementMethods.first!
        XCTAssertEqual("EUR", addedSettlementMethod.currency)
        XCTAssertEqual("SEPA", addedSettlementMethod.method)
        XCTAssertEqual(String(decoding: try! JSONEncoder().encode(privateData), as: UTF8.self), addedSettlementMethod.privateData)
        
    }
    
}
