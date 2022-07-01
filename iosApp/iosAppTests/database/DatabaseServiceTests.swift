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
        try dbService.deleteSettlementMethods(id: offerId)
        let returnedSettlementMethodsAfterDeletion = try dbService.getSettlementMethods(id: offerId)
        XCTAssertEqual(returnedSettlementMethodsAfterDeletion, nil)
    }
    
    func testStoreAndGetAndDeleteOfferOpenedEvent() throws {
        try dbService.storeOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        // This should do nothing and not throw
        try dbService.storeOfferOpenedEvent(id: "offer_id", interfaceId: "different_interface_id")
        let expectedOfferOpenedEvent = DatabaseOfferOpenedEvent(id: "offer_id", interfaceId: "interf_id")
        // This should not throw since only one such OfferOpened event should exist in the database
        let offerOpenedEvent = try dbService.getOfferOpenedEvent(id: "offer_id")
        XCTAssertEqual(expectedOfferOpenedEvent, offerOpenedEvent)
        try dbService.deleteOfferOpenedEvents(id: "offer_id")
        let offerOpenedEventAfterDeletion = try dbService.getOfferOpenedEvent(id: "offer_id")
        XCTAssertEqual(offerOpenedEventAfterDeletion, nil)
    }
    
    func testStoreAndGetAndDeleteOfferCanceledEvent() throws {
        try dbService.storeOfferCanceledEvent(id: "offer_id")
        // This should do nothing and not throw
        try dbService.storeOfferCanceledEvent(id: "offer_id")
        let expectedOfferCanceledEvent = DatabaseOfferCanceledEvent(id: "offer_id")
        // This should not throw since only one such OfferCanceled event should exist in the database
        let offerCanceledEvent = try dbService.getOfferCanceledEvent(id: "offer_id")
        XCTAssertEqual(expectedOfferCanceledEvent, offerCanceledEvent)
        try dbService.deleteOfferCanceledEvents(id: "offer_id")
        let offerCanceledEventAfterDeletion = try dbService.getOfferCanceledEvent(id: "offer_id")
        XCTAssertEqual(offerCanceledEventAfterDeletion, nil)
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
