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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
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
            protocolVersion: "some_other_version",
            chainID: "another_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        // This should do nothing and not throw
        try dbService.storeOffer(offer: anotherOfferToStore)
        // This should not throw since only one such Offer should exist in the database
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer, offerToStore)
        try dbService.deleteOffers(offerID: "a_uuid", _chainID: "a_chain_id")
        let returnedOfferAfterDeletion = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOfferAfterDeletion, nil)
    }
    
    func testUpdateOfferHavePublicKey() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateOfferHavePublicKey(offerID: "a_uuid", _chainID: "a_chain_id", _havePublicKey: true)
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertTrue(returnedOffer!.havePublicKey)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `state` property works properly.
     */
    func testUpdateOfferState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "an_outdated_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateOfferState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_state_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.state, "a_new_state_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.approveToOpenState` property works properly.
     */
    func testUpdateApproveToOpenState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "an_outdated_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateOfferApproveToOpenState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_tokenTransferApprovalState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.approveToOpenState, "a_new_tokenTransferApprovalState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.approveToOpenTransactionHash` and related properties works properly.
     */
    func testUpdateApproveToOpenData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToOpenTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToOpenTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToOpenTransactionCreationBlockNumber)
        try dbService.updateOfferApproveToOpenData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.approveToOpenTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.approveToOpenTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.approveToOpenTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.openingOfferState` property works properly.
     */
    func testUpdateOpeningOfferState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateOpeningOfferState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_openingOfferState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.openingOfferState, "a_new_openingOfferState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.openingOfferTransactionHash` and related properties works properly.
     */
    func testUpdateOfferOpeningData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.openingOfferTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.openingOfferTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.openingOfferTransactionCreationBlockNumber)
        try dbService.updateOpeningOfferData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.openingOfferTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.openingOfferTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.openingOfferTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.cancelingOfferState` property works properly.
     */
    func testUpdateCancelingOfferState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "an_outdated_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateCancelingOfferState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_cancelingOfferState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.cancelingOfferState, "a_new_cancelingOfferState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.offerCancellationTransactionHash` and related properties works properly.
     */
    func testUpdateOfferCancellationData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.offerCancellationTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.offerCancellationTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.offerCancellationTransactionCreationBlockNumber)
        try dbService.updateOfferCancellationData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.offerCancellationTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.offerCancellationTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.offerCancellationTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.editingOfferState` property works properly.
     */
    func testUpdateEditingOfferState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_outdated_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateEditingOfferState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_editingOfferState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.editingOfferState, "a_new_editingOfferState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.offerEditingTransactionHash` and related properties works properly.
     */
    func testUpdateOfferEditingData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.offerEditingTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.offerEditingTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.offerEditingTransactionCreationBlockNumber)
        try dbService.updateOfferEditingData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.offerEditingTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.offerEditingTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.offerEditingTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.approveToTakeState` property works properly.
     */
    func testUpdateApproveToTakeState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateOfferApproveToTakeState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_tokenTransferApprovalState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.approveToTakeState, "a_new_tokenTransferApprovalState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.approveToTakeTransactionHash` and related properties works properly.
     */
    func testUpdateApproveToTakeData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToTakeTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToTakeTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.approveToTakeTransactionCreationBlockNumber)
        try dbService.updateOfferApproveToTakeData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.approveToTakeTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.approveToTakeTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.approveToTakeTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.takingOfferState` property works properly.
     */
    func testUpdateTakingOfferState() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: "a_tx_hash_here",
            takingOfferTransactionCreationTime: "a_time_here",
            takingOfferTransactionCreationBlockNumber: -1
        )
        try dbService.storeOffer(offer: offerToStore)
        try dbService.updateTakingOfferState(offerID: "a_uuid", _chainID: "a_chain_id", state: "a_new_takingOfferState_here")
        let returnedOffer = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual(returnedOffer!.takingOfferState, "a_new_takingOfferState_here")
    }
    
    /**
     Ensures that code to update a persistently stored offer's `Offer.takingOfferTransactionHash` and related properties works properly.
     */
    func testUpdateOfferTakingData() throws {
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
            protocolVersion: "some_version",
            chainID: "a_chain_id",
            havePublicKey: false,
            isUserMaker: false,
            state: "a_state_here",
            approveToOpenState: "a_tokenTransferApprovalState_here",
            approveToOpenTransactionHash: "a_tx_hash_here",
            approveToOpenTransactionCreationTime: "a_time_here",
            approveToOpenTransactionCreationBlockNumber: -1,
            openingOfferState: "an_openingOfferState_here",
            openingOfferTransactionHash: "a_tx_hash_here",
            openingOfferTransactionCreationTime: "a_time_here",
            openingOfferTransactionCreationBlockNumber: -1,
            cancelingOfferState: "a_cancelingOfferState_here",
            offerCancellationTransactionHash: "a_tx_hash_here",
            offerCancellationTransactionCreationTime: "a_time_here",
            offerCancellationTransactionCreationBlockNumber: -1,
            editingOfferState: "an_editingOfferState_here",
            offerEditingTransactionHash: "a_tx_hash_here",
            offerEditingTransactionCreationTime: "a_time_here",
            offerEditingTransactionCreationBlockNumber: -1,
            approveToTakeState: "a_tokenTransferApprovalState_here",
            approveToTakeTransactionHash: "a_tx_hash_here",
            approveToTakeTransactionCreationTime: "a_time_here",
            approveToTakeTransactionCreationBlockNumber: -1,
            takingOfferState: "an_openingOfferState_here",
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try dbService.storeOffer(offer: offerToStore)
        let returnedOfferBeforeUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertNil(returnedOfferBeforeUpdate!.takingOfferTransactionHash)
        XCTAssertNil(returnedOfferBeforeUpdate!.takingOfferTransactionCreationTime)
        XCTAssertNil(returnedOfferBeforeUpdate!.takingOfferTransactionCreationBlockNumber)
        try dbService.updateTakingOfferData(offerID: "a_uuid", _chainID: "a_chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedOfferAfterUpdate = try dbService.getOffer(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedOfferAfterUpdate!.takingOfferTransactionHash)
        XCTAssertEqual("a_time_here", returnedOfferAfterUpdate!.takingOfferTransactionCreationTime)
        XCTAssertEqual(-1, returnedOfferAfterUpdate!.takingOfferTransactionCreationBlockNumber)
    }
    
    /**
     Ensures code to store, get and delete settlement methods works properly.
     */
    func testStoreAndGetAndDeleteSettlementMethods() throws {
        let offerId = "an_offer_id"
        let chainID = "a_chain_id"
        let differentChainID = "different_chain_id"
        let settlementMethods = [
            ("settlement_method_zero", "private_data_zero"),
            ("settlement_method_one", "private_data_one"),
            ("settlement_method_two", "private_data_two")
        ]
        try dbService.storeOfferSettlementMethods(offerID: offerId, _chainID: chainID, settlementMethods: settlementMethods)
        try dbService.storeOfferSettlementMethods(offerID: offerId, _chainID: differentChainID, settlementMethods: settlementMethods)
        let returnedSettlementMethods = try dbService.getOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertEqual(returnedSettlementMethods!.count, 3)
        XCTAssertEqual(returnedSettlementMethods![0].0, "settlement_method_zero")
        XCTAssertEqual(returnedSettlementMethods![0].1, "private_data_zero")
        XCTAssertEqual(returnedSettlementMethods![1].0, "settlement_method_one")
        XCTAssertEqual(returnedSettlementMethods![1].1, "private_data_one")
        XCTAssertEqual(returnedSettlementMethods![2].0, "settlement_method_two")
        XCTAssertEqual(returnedSettlementMethods![2].1, "private_data_two")
        let newSettlementMethods = [
            ("settlement_method_three", "private_data_three"),
            ("settlement_method_four", "private_data_four"),
            ("settlement_method_five", "private_data_five")
        ]
        try dbService.storeOfferSettlementMethods(offerID: offerId, _chainID: chainID, settlementMethods: newSettlementMethods)
        let newReturnedSettlementMethods = try dbService.getOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertEqual(newReturnedSettlementMethods!.count, 3)
        XCTAssertEqual(newReturnedSettlementMethods![0].0, "settlement_method_three")
        XCTAssertEqual(newReturnedSettlementMethods![0].1, "private_data_three")
        XCTAssertEqual(newReturnedSettlementMethods![1].0, "settlement_method_four")
        XCTAssertEqual(newReturnedSettlementMethods![1].1, "private_data_four")
        XCTAssertEqual(newReturnedSettlementMethods![2].0, "settlement_method_five")
        XCTAssertEqual(newReturnedSettlementMethods![2].1, "private_data_five")
        try dbService.deleteOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        let returnedSettlementMethodsAfterDeletion = try dbService.getOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertNil(returnedSettlementMethodsAfterDeletion)
        let differentReturnedSettlementMethods = try dbService.getOfferSettlementMethods(offerID: offerId, _chainID: differentChainID)
        XCTAssertEqual(differentReturnedSettlementMethods!.count, 3)
        XCTAssertEqual(differentReturnedSettlementMethods![0].0, "settlement_method_zero")
        XCTAssertEqual(differentReturnedSettlementMethods![0].1, "private_data_zero")
        XCTAssertEqual(differentReturnedSettlementMethods![1].0, "settlement_method_one")
        XCTAssertEqual(differentReturnedSettlementMethods![1].1, "private_data_one")
        XCTAssertEqual(differentReturnedSettlementMethods![2].0, "settlement_method_two")
        XCTAssertEqual(differentReturnedSettlementMethods![2].1, "private_data_two")
    }
    
    /**
     Ensures code to store, get and delete pending settlement methods works properly.
     */
    func testStoreAndGetAndDeletePendingSettlementMethods() throws {
        let offerId = "an_offer_id"
        let chainID = "a_chain_id"
        let differentChainID = "different_chain_id"
        let settlementMethods = [
            ("settlement_method_zero", "private_data_zero"),
            ("settlement_method_one", "private_data_one"),
            ("settlement_method_two", "private_data_two")
        ]
        try dbService.storePendingOfferSettlementMethods(offerID: offerId, _chainID: chainID, pendingSettlementMethods: settlementMethods)
        try dbService.storePendingOfferSettlementMethods(offerID: offerId, _chainID: differentChainID, pendingSettlementMethods: settlementMethods)
        let returnedSettlementMethods = try dbService.getPendingOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertEqual(returnedSettlementMethods!.count, 3)
        XCTAssertEqual(returnedSettlementMethods![0].0, "settlement_method_zero")
        XCTAssertEqual(returnedSettlementMethods![0].1, "private_data_zero")
        XCTAssertEqual(returnedSettlementMethods![1].0, "settlement_method_one")
        XCTAssertEqual(returnedSettlementMethods![1].1, "private_data_one")
        XCTAssertEqual(returnedSettlementMethods![2].0, "settlement_method_two")
        XCTAssertEqual(returnedSettlementMethods![2].1, "private_data_two")
        let newSettlementMethods = [
            ("settlement_method_three", "private_data_three"),
            ("settlement_method_four", "private_data_four"),
            ("settlement_method_five", "private_data_five")
        ]
        try dbService.storePendingOfferSettlementMethods(offerID: offerId, _chainID: chainID, pendingSettlementMethods: newSettlementMethods)
        let newReturnedSettlementMethods = try dbService.getPendingOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertEqual(newReturnedSettlementMethods!.count, 3)
        XCTAssertEqual(newReturnedSettlementMethods![0].0, "settlement_method_three")
        XCTAssertEqual(newReturnedSettlementMethods![0].1, "private_data_three")
        XCTAssertEqual(newReturnedSettlementMethods![1].0, "settlement_method_four")
        XCTAssertEqual(newReturnedSettlementMethods![1].1, "private_data_four")
        XCTAssertEqual(newReturnedSettlementMethods![2].0, "settlement_method_five")
        XCTAssertEqual(newReturnedSettlementMethods![2].1, "private_data_five")
        try dbService.deletePendingOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        let returnedSettlementMethodsAfterDeletion = try dbService.getPendingOfferSettlementMethods(offerID: offerId, _chainID: chainID)
        XCTAssertNil(returnedSettlementMethodsAfterDeletion)
        let differentReturnedSettlementMethods = try dbService.getPendingOfferSettlementMethods(offerID: offerId, _chainID: differentChainID)
        XCTAssertEqual(differentReturnedSettlementMethods!.count, 3)
        XCTAssertEqual(differentReturnedSettlementMethods![0].0, "settlement_method_zero")
        XCTAssertEqual(differentReturnedSettlementMethods![0].1, "private_data_zero")
        XCTAssertEqual(differentReturnedSettlementMethods![1].0, "settlement_method_one")
        XCTAssertEqual(differentReturnedSettlementMethods![1].1, "private_data_one")
        XCTAssertEqual(differentReturnedSettlementMethods![2].0, "settlement_method_two")
        XCTAssertEqual(differentReturnedSettlementMethods![2].1, "private_data_two")
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
    
    func testStoreAndGetAndDeleteSwap() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        let anotherSwapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "another_maker_address",
            makerInterfaceID: "another_maker_interface_id",
            taker: "another_taker_address",
            takerInterfaceID: "another_taker_interface_id",
            stablecoin: "another_stablecoin_address",
            amountLowerBound: "another_lower_bound_amount",
            amountUpperBound: "another_upper_bound_amount",
            securityDepositAmount: "another_security_deposit_amount",
            takenSwapAmount: "another_taken_swap_amount",
            serviceFeeAmount: "another_service_fee_amount",
            serviceFeeRate: "another_service_fee_rate",
            onChainDirection: "another_direction",
            onChainSettlementMethod: "another_settlement_method",
            makerPrivateSettlementMethodData: "different_maker_private_data",
            takerPrivateSettlementMethodData: "different_taker_private_data",
            protocolVersion: "another_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "another_dispute_raiser",
            chainID: "another_chain_id",
            state: "another_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        // This should do nothing and not throw
        try dbService.storeSwap(swap: anotherSwapToStore)
        // This should not throw since only one such Swap should exist in the database
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(swapToStore, returnedSwap)
        try dbService.deleteSwaps(swapID: "a_uuid", chainID: "chain_id")
        let returnedSwapAfterDeletion = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwapAfterDeletion, nil)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `requiresFill` property works properly.
     */
    func testUpdateSwapRequiresFill() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: true,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapRequiresFill(swapID: "a_uuid", chainID: "chain_id", requiresFill: false)
        XCTAssertFalse(try dbService.getSwap(id: "a_uuid")!.requiresFill)
    }
    
    /**
     Ensures that code to update a persistently stored swap's maker private settlement method data related properties works properly.
     */
    func testUpdateSwapMakerPrivateSettlementMethodData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: true,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapMakerPrivateSettlementMethodData(swapID: "a_uuid", chainID: "chain_id", data: "new_maker_private_data")
        XCTAssertEqual("new_maker_private_data", try dbService.getSwap(id: "a_uuid")!.makerPrivateSettlementMethodData)
    }
    
    /**
     Ensures that code to update a persistently stored swap's taker private settlement method data related properties works properly.
     */
    func testUpdateSwapTakerPrivateSettlementMethodData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: true,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapTakerPrivateSettlementMethodData(swapID: "a_uuid", chainID: "chain_id", data: "new_taker_private_data")
        XCTAssertEqual("new_taker_private_data", try dbService.getSwap(id: "a_uuid")!.takerPrivateSettlementMethodData)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `isPaymentSent` property works properly.
     */
    func testUpdateSwapIsPaymentSent() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: true,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapIsPaymentSent(swapID: "a_uuid", chainID: "chain_id", isPaymentSent: true)
        XCTAssertTrue(try dbService.getSwap(id: "a_uuid")!.isPaymentSent)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `isPaymentReceived` property works properly.
     */
    func testUpdateSwapIsPaymentReceived() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: true,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: true,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapIsPaymentReceived(swapID: "a_uuid", chainID: "chain_id", isPaymentReceived: true)
        XCTAssertTrue(try dbService.getSwap(id: "a_uuid")!.isPaymentReceived)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `hasBuyerClosed` property works properly.
     */
    func testUpdateSwapHasBuyerClosed() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapHasBuyerClosed(swapID: "a_uuid", chainID: "chain_id", hasBuyerClosed: true)
        XCTAssertTrue(try dbService.getSwap(id: "a_uuid")!.hasBuyerClosed)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `hasSellerClosed` property works properly.
     */
    func testUpdateSwapHasSellerClosed() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: true,
            isPaymentReceived: true,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapHasSellerClosed(swapID: "a_uuid", chainID: "chain_id", hasSellerClosed: true)
        XCTAssertTrue(try dbService.getSwap(id: "a_uuid")!.hasSellerClosed)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `state` property works properly.
     */
    func testUpdateSwapState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapState(swapID: "a_uuid", chainID: "chain_id", state: "a_new_state_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_new_state_here", returnedSwap!.state)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.approveToFillState` property works properly.
     */
    func testUpdateSwapApproveToFillState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "an_outdated_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapApproveToFillState(swapID: "a_uuid", _chainID: "chain_id", state: "a_new_approveToFillState_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwap!.approveToFillState, "a_new_approveToFillState_here")
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.approveToFillTransactionHash`, `Swap.approveToFillTransactionCreationTime` and `Swap.approveToFillTransactionCreationBlockNumber`  properties work properly.
     */
    func testUpdateSwapApproveToFillData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "an_outdated_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateSwapApproveToFillData(swapID: "a_uuid", _chainID: "chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedSwapAfterUpdate = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedSwapAfterUpdate!.approveToFillTransactionHash)
        XCTAssertEqual("a_time_here", returnedSwapAfterUpdate!.approveToFillTransactionCreationTime)
        XCTAssertEqual(-1, returnedSwapAfterUpdate!.approveToFillTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.fillingSwapState` property works properly.
     */
    func testUpdateFillingSwapState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "an_outdated_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateFillingSwapState(swapID: "a_uuid", _chainID: "chain_id", state: "a_new_fillingSwapState_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwap!.fillingSwapState, "a_new_fillingSwapState_here")
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.fillingSwapTransactionHash`, `Swap.fillingSwapTransactionCreationTime` and `Swap.fillingSwapTransactionCreationBlockNumber`  properties work properly.
     */
    func testUpdateFillingSwapData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: nil,
            fillingSwapTransactionCreationTime: nil,
            fillingSwapTransactionCreationBlockNumber: nil,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateFillingSwapData(swapID: "a_uuid", _chainID: "chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedSwapAfterUpdate = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedSwapAfterUpdate!.fillingSwapTransactionHash)
        XCTAssertEqual("a_time_here", returnedSwapAfterUpdate!.fillingSwapTransactionCreationTime)
        XCTAssertEqual(-1, returnedSwapAfterUpdate!.fillingSwapTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.reportPaymentSentState` property works properly.
     */
    func testUpdateReportingPaymentSentState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "an_outdated_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateReportPaymentSentState(swapID: "a_uuid", _chainID: "chain_id", state: "a_new_reportingPaymentSentState_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwap!.reportPaymentSentState, "a_new_reportingPaymentSentState_here")
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.reportPaymentSentTransactionHash`, `Swap.reportPaymentSentTransactionCreationTime` and `Swap.reportPaymentSentTransactionCreationBlockNumber`  properties work properly.
     */
    func testUpdateReportingPaymentSentData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "an_outdated_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateReportPaymentSentData(swapID: "a_uuid", _chainID: "chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedSwapAfterUpdate = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedSwapAfterUpdate!.reportPaymentSentTransactionHash)
        XCTAssertEqual("a_time_here", returnedSwapAfterUpdate!.reportPaymentSentTransactionCreationTime)
        XCTAssertEqual(-1, returnedSwapAfterUpdate!.reportPaymentSentTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.reportPaymentReceivedState` property works properly.
     */
    func testUpdateReportingPaymentReceivedState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "an_outdated_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateReportPaymentReceivedState(swapID: "a_uuid", _chainID: "chain_id", state: "a_new_reportingPaymentReceivedState_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwap!.reportPaymentReceivedState, "a_new_reportingPaymentReceivedState_here")
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.reportPaymentReceivedTransactionHash`, `Swap.reportPaymentReceivedTransactionCreationTime` and `Swap.reportPaymentReceivedTransactionCreationBlockNumber`  properties work properly.
     */
    func testUpdateReportingPaymentReceivedData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateReportPaymentReceivedData(swapID: "a_uuid", _chainID: "chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedSwapAfterUpdate = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedSwapAfterUpdate!.reportPaymentReceivedTransactionHash)
        XCTAssertEqual("a_time_here", returnedSwapAfterUpdate!.reportPaymentReceivedTransactionCreationTime)
        XCTAssertEqual(-1, returnedSwapAfterUpdate!.reportPaymentReceivedTransactionCreationBlockNumber)
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.closeSwapState` property works properly.
     */
    func testUpdateCloseSwapState() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_tx_hash_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "an_outdated_closeSwapState_here",
            closeSwapTransactionHash: "a_tx_hash_here",
            closeSwapTransactionCreationTime: "a_time_here",
            closeSwapTransactionCreationBlockNumber: -1
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateCloseSwapState(swapID: "a_uuid", _chainID: "chain_id", state: "a_new_closeSwapState_here")
        let returnedSwap = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual(returnedSwap!.closeSwapState, "a_new_closeSwapState_here")
    }
    
    /**
     Ensures that code to update a persistently stored swap's `Swap.closeSwapTransactionHash`, `Swap.closeSwapTransactionCreationTime` and `Swap.closeSwapTransactionCreationBlockNumber`  properties work properly.
     */
    func testUpdateCloseSwapData() throws {
        let swapToStore = DatabaseSwap(
            id: "a_uuid",
            isCreated: true,
            requiresFill: false,
            maker: "maker_address",
            makerInterfaceID: "maker_interface_id",
            taker: "taker_address",
            takerInterfaceID: "taker_interface_id",
            stablecoin: "stablecoin_address",
            amountLowerBound: "lower_bound_amount",
            amountUpperBound: "upper_bound_amount",
            securityDepositAmount: "security_deposit_amount",
            takenSwapAmount: "taken_swap_amount",
            serviceFeeAmount: "service_fee_amount",
            serviceFeeRate: "service_fee_rate",
            onChainDirection: "direction",
            onChainSettlementMethod: "settlement_method",
            makerPrivateSettlementMethodData: "maker_private_data",
            takerPrivateSettlementMethodData: "taker_private_data",
            protocolVersion: "some_version",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "dispute_raiser",
            chainID: "chain_id",
            state: "a_state_here",
            role: "a_role_here",
            approveToFillState: "a_tokenTransferApprovalState_here",
            approveToFillTransactionHash: "a_tx_hash_here",
            approveToFillTransactionCreationTime: "a_time_here",
            approveToFillTransactionCreationBlockNumber: -1,
            fillingSwapState: "a_fillingSwapState_here",
            fillingSwapTransactionHash: "a_tx_hash_here",
            fillingSwapTransactionCreationTime: "a_time_here",
            fillingSwapTransactionCreationBlockNumber: -1,
            reportPaymentSentState: "a_reportingPaymentSentState_here",
            reportPaymentSentTransactionHash: "a_tx_hash_here",
            reportPaymentSentTransactionCreationTime: "a_time_here",
            reportPaymentSentTransactionCreationBlockNumber: -1,
            reportPaymentReceivedState: "a_reportingPaymentReceivedState_here",
            reportPaymentReceivedTransactionHash: "a_new_closeSwapState_here",
            reportPaymentReceivedTransactionCreationTime: "a_time_here",
            reportPaymentReceivedTransactionCreationBlockNumber: -1,
            closeSwapState: "a_closeSwapState_here",
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try dbService.storeSwap(swap: swapToStore)
        try dbService.updateCloseSwapData(swapID: "a_uuid", _chainID: "chain_id", transactionHash: "a_tx_hash_here", transactionCreationTime: "a_time_here", latestBlockNumberAtCreationTime: -1)
        let returnedSwapAfterUpdate = try dbService.getSwap(id: "a_uuid")
        XCTAssertEqual("a_tx_hash_here", returnedSwapAfterUpdate!.closeSwapTransactionHash)
        XCTAssertEqual("a_time_here", returnedSwapAfterUpdate!.closeSwapTransactionCreationTime)
        XCTAssertEqual(-1, returnedSwapAfterUpdate!.closeSwapTransactionCreationBlockNumber)
    }
    
    /**
     Ensures code to store, get, update and delete user settlement methods in persistent storage works properly.
     */
    func  testStoreAndGetAndUpdateAndDeleteUserSettlementMethods() throws {
        let settlementMethodID = UUID()
        let settlementMethod = "a_settlement_method"
        let privateData = "some_private_data"
        
        try dbService.storeUserSettlementMethod(id: settlementMethodID.uuidString, settlementMethod: settlementMethod, privateData: privateData)
        
        let returnedSettlementMethod = try dbService.getUserSettlementMethod(id: settlementMethodID.uuidString)
        
        XCTAssertEqual(settlementMethod, returnedSettlementMethod?.0)
        XCTAssertEqual("some_private_data", returnedSettlementMethod?.1)
        
        try dbService.updateUserSettlementMethod(id: settlementMethodID.uuidString, privateData: "updated_private_data")
        
        let updatedReturnedSettlementMethod = try dbService.getUserSettlementMethod(id: settlementMethodID.uuidString)
        
        XCTAssertEqual(settlementMethod, updatedReturnedSettlementMethod?.0)
        XCTAssertEqual("updated_private_data", updatedReturnedSettlementMethod?.1)
        
        try dbService.deleteUserSettlementMethod(id: settlementMethodID.uuidString)
        
        let returnedSettlementMethodAfterDeletion = try dbService.getUserSettlementMethod(id: settlementMethodID.uuidString)
        
        XCTAssertNil(returnedSettlementMethodAfterDeletion)
    }

}
