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
     Ensures `SettlementMethodService.addSettlementMethod` and `SettlementMethodService.deleteSettlementMethod` function properly.
     */
    func testAddSettlementMethodAndDeleteSettlementMethod() {
        
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
        
        let encodedSettlementMethodInDatabase = try! databaseService.getUserSettlementMethod(id: settlementMethodToAdd.id)
        let settlementMethodInDatabase = try! JSONDecoder().decode(SettlementMethod.self, from: encodedSettlementMethodInDatabase!.0.data(using: .utf8)!)
        let privateDataInDatabase = try! JSONDecoder().decode(PrivateSEPAData.self, from: encodedSettlementMethodInDatabase!.1!.data(using: .utf8)!)
        
        XCTAssertEqual("EUR", settlementMethodInDatabase.currency)
        XCTAssertEqual("SEPA", settlementMethodInDatabase.method)
        
        XCTAssertEqual("account_holder", privateDataInDatabase.accountHolder)
        XCTAssertEqual("bic", privateDataInDatabase.bic)
        XCTAssertEqual("iban", privateDataInDatabase.iban)
        XCTAssertEqual("address", privateDataInDatabase.address)
        
        let settlementMethodDeletedExpectation = XCTestExpectation(description: "Fulfilled immediately after deleteSettlementMethod call is completed")
        
        settlementMethodService.deleteSettlementMethod(settlementMethod: settlementMethodToAdd).done {
            settlementMethodDeletedExpectation.fulfill()
        }.cauterize()
        
        wait(for: [settlementMethodDeletedExpectation], timeout: 20.0)
        
        XCTAssertEqual(0, settlementMethodTruthSource.settlementMethods.count)
        
    }
    
    /**
     Ensures `SettlementMethodService.editSettlementMethod` functions properly.
     */
    func testEditSettlementMethod() {
        
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
        
        let settlementMethodEditedExpectation = XCTestExpectation(description: "Fulfilled immediately after editSettlementMethod call is completed")
        
        let editedPrivateData = PrivateSEPAData(accountHolder: "different_account_holder", bic: "different_bic", iban: "different_iban", address: "different_address")
        
        settlementMethodService.editSettlementMethod(settlementMethod: settlementMethodToAdd, newPrivateData: editedPrivateData).done {
            settlementMethodEditedExpectation.fulfill()
        }.cauterize()
        
        wait(for: [settlementMethodEditedExpectation], timeout: 20.0)
        
        let editedSettlementMethod = settlementMethodTruthSource.settlementMethods.first!
        XCTAssertEqual(String(decoding: try! JSONEncoder().encode(editedPrivateData), as: UTF8.self), editedSettlementMethod.privateData)
        
        let editedSettlementMethodInDatabase = try! databaseService.getUserSettlementMethod(id: settlementMethodToAdd.id)
        
        let editedPrivateDataInDatabase = try! JSONDecoder().decode(PrivateSEPAData.self, from: editedSettlementMethodInDatabase!.1!.data(using: .utf8)!)
        
        XCTAssertEqual("different_account_holder", editedPrivateDataInDatabase.accountHolder)
        XCTAssertEqual("different_bic", editedPrivateDataInDatabase.bic)
        XCTAssertEqual("different_iban", editedPrivateDataInDatabase.iban)
        XCTAssertEqual("different_address", editedPrivateDataInDatabase.address)
        
    }
    
}
