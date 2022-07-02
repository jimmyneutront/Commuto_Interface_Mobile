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
    
    func testStoreAndGetAndDeleteOffer() throws {
        let offerToStore = DatabaseOffer(
            id: "a_uuid",
            isCreated: true,
            isTaken: false,
            maker: "maker_address",
            interfaceId: "interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainPrice: "a_price",
            protocolVersion: "some_version"
        )
        try dbService.storeOffer(offer: offerToStore)
        let anotherOfferToStore = DatabaseOffer(
            id: "a_uuid",
            isCreated: true,
            isTaken: false,
            maker: "another_maker_address",
            interfaceId: "another_interface_id",
            stablecoin: "another_stablecoin_address",
            amountLowerBound: "another_lower_bound_amount",
            amountUpperBound: "another_upper_bound_amount",
            securityDepositAmount: "another_security_deposit_amount",
            serviceFeeRate: "another_service_fee_rate",
            onChainDirection: "opposite_direction",
            onChainPrice: "a_different_price",
            protocolVersion: "some_other_version"
        )
        // This should do nothing and not throw
        try dbService.storeOffer(offer: anotherOfferToStore)
        // This should not throw since only one such Offer should exist in the database
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer, offerToStore)
        try dbService.deleteOffers(id: "a_uuid")
        let returnedOfferAfterDeletion = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOfferAfterDeletion, nil)
    }
    
    func testUpdateOfferPrice() throws {
        let offerToUpdate = DatabaseOffer(
            id: "a_uuid",
            isCreated: true,
            isTaken: false,
            maker: "maker_address",
            interfaceId: "interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainPrice: "a_price",
            protocolVersion: "some_version"
        )
        try dbService.storeOffer(offer: offerToUpdate)
        try dbService.updateOfferPrice(id: "a_uuid", price: "an_updated_price")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.onChainPrice, "an_updated_price")
    }
    
    func testStoreAndGetAndDeleteSettlementMethods() throws {
        let offerId = "an_offer_id"
        let settlementMethods = [
            "settlement_method_zero",
            "settlement_method_one",
            "settlement_method_two"
        ]
        try dbService.storeSettlementMethods(id: offerId, settlementMethods: settlementMethods)
        let returnedSettlementMethods = try dbService.getSettlementMethods(id: offerId)
        XCTAssertEqual(returnedSettlementMethods!.count, 3)
        XCTAssertEqual(returnedSettlementMethods![0], "settlement_method_zero")
        XCTAssertEqual(returnedSettlementMethods![1], "settlement_method_one")
        XCTAssertEqual(returnedSettlementMethods![2], "settlement_method_two")
        let newSettlementMethods = [
            "settlement_method_three",
            "settlement_method_four",
            "settlement_method_five"
        ]
        try dbService.storeSettlementMethods(id: offerId, settlementMethods: newSettlementMethods)
        let newReturnedSettlementMethods = try dbService.getSettlementMethods(id: offerId)
        XCTAssertEqual(newReturnedSettlementMethods!.count, 3)
        XCTAssertEqual(newReturnedSettlementMethods![0], "settlement_method_three")
        XCTAssertEqual(newReturnedSettlementMethods![1], "settlement_method_four")
        XCTAssertEqual(newReturnedSettlementMethods![2], "settlement_method_five")
        try dbService.deleteSettlementMethods(id: offerId)
        let returnedSettlementMethodsAfterDeletion = try dbService.getSettlementMethods(id: offerId)
        XCTAssertEqual(returnedSettlementMethodsAfterDeletion, nil)
    }
    
    func testStoreAndGetKeyPair() throws {
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        // This should do nothing and not throw
        try dbService.storeKeyPair(interfaceId: "interf_id", publicKey: "another_pub_key", privateKey: "another_priv_key")
        let expectedKeyPair = DatabaseKeyPair(interfaceId: "interf_id", publicKey: "pub_key", privateKey: "priv_key")
        // This should not throw since only one such key pair should exist in the database
        let keyPair = try dbService.getKeyPair(interfaceId: "interf_id")
        XCTAssertEqual(expectedKeyPair, keyPair)
    }
    
    func testStoreAndGetPublicKey() throws {
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        // This should do nothing and not throw
        try dbService.storePublicKey(interfaceId: "interf_id", publicKey: "another_pub_key")
        let expectedPublicKey = DatabasePublicKey(interfaceId: "interf_id", publicKey: "pub_key")
        // This should not throw since only one such public key should exist in the database
        let publicKey = try dbService.getPublicKey(interfaceId: "interf_id")
        XCTAssertEqual(expectedPublicKey, publicKey)
    }

}
