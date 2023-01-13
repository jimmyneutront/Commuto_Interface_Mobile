//
//  OfferServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 6/23/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import PromiseKit
import Switrix
import web3swift
import XCTest

@testable import iosApp

/**
 Tests for OfferService
 */
class OfferServiceTests: XCTestCase {
    
    /**
     Ensure `OfferService` properly handles failed transactions that approve token transfers in order to open a new offer.
     */
    func testHandleFailedApproveToOpenTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .approvingTransfer
        )!
        offer.approvingToOpenState = .awaitingTransactionConfirmation
        let approvingToOpenTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .approveTokenTransferToOpenOffer)
        offer.approvingToOpenTransaction = approvingToOpenTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(approvingToOpenTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(OfferState.transferApprovalFailed, offer.state)
        XCTAssertEqual(TokenTransferApprovalState.error, offer.approvingToOpenState)
        XCTAssertNotNil(offer.approvingToOpenError)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(OfferState.transferApprovalFailed.asString, offerInDatabase?.state)
        XCTAssertEqual(TokenTransferApprovalState.error.asString, offerInDatabase?.approveToOpenState)
        
    }
    
    /**
     Ensure `OfferService` properly handles failed offer opening transactions.
     */
    func testHandleFailedOfferOpeningTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .openOfferTransactionSent
        )!
        offer.openingOfferState = .awaitingTransactionConfirmation
        let offerOpeningTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .openOffer)
        offer.offerOpeningTransaction = offerOpeningTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(offerOpeningTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(OfferState.awaitingOpening, offer.state)
        XCTAssertEqual(OpeningOfferState.error, offer.openingOfferState)
        XCTAssertNotNil(offer.openingOfferError)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(OfferState.awaitingOpening.asString, offerInDatabase?.state)
        XCTAssertEqual(OpeningOfferState.error.asString, offerInDatabase?.openingOfferState)
        
    }
    
    /**
     Ensure `OfferService` handles failed offer cancellation transactions properly.
     */
    func testHandleFailedOfferCancellationTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        offer.cancelingOfferState = .awaitingTransactionConfirmation
        let offerCancellationTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .cancelOffer)
        offer.offerCancellationTransaction = offerCancellationTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(offerCancellationTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        let offerInTruthSource = offerTruthSource.offers[offerID]
        XCTAssertEqual(CancelingOfferState.error, offerInTruthSource?.cancelingOfferState)
        XCTAssertNotNil(offerInTruthSource?.cancelingOfferError)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(CancelingOfferState.error.asString, offerInDatabase?.cancelingOfferState)
        
    }
    
    /**
     Ensure `OfferService` handles failed offer editing transactions properly.
     */
    func testHandleFailedOfferEditingTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        let offerEditingTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .editOffer)
        offer.offerEditingTransaction = offerEditingTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let pendingSettlementMethods = [
            SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: "some_sepa_data"),
            SettlementMethod(currency: "BSD", price: "1.00", method: "SANDDOLLAR", privateData: "some_sanddollar_data")
        ]
        offer.selectedSettlementMethods = pendingSettlementMethods
        let serializedPendingSettlementMethodsAndPrivateDetails = pendingSettlementMethods.compactMap { pendingSettlementMethod in
            return (try! JSONEncoder().encode(pendingSettlementMethod).base64EncodedString(), pendingSettlementMethod.privateData)
        }
        try! databaseService.storePendingOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID, pendingSettlementMethods: serializedPendingSettlementMethodsAndPrivateDetails)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(offerEditingTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 10.0)
        XCTAssertEqual(EditingOfferState.error, offer.editingOfferState)
        XCTAssertNotNil(offer.editingOfferError)
        XCTAssertEqual(0, offer.selectedSettlementMethods.count)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(EditingOfferState.error.asString, offerInDatabase?.editingOfferState)
        
        let pendingSettlementMethodsInDatabase = try! databaseService.getPendingOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertNil(pendingSettlementMethodsInDatabase)
        
    }
    
    /**
     Ensure `OfferService` properly handles failed transactions that approve token transfers in order to take an offer.
     */
    func testHandleFailedApproveToTakeTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )!
        offer.approvingToTakeState = .awaitingTransactionConfirmation
        let approvingToTakeTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .approveTokenTransferToTakeOffer)
        offer.approvingToTakeTransaction = approvingToTakeTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(approvingToTakeTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(TokenTransferApprovalState.error, offer.approvingToTakeState)
        XCTAssertNotNil(offer.approvingToTakeError)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(TokenTransferApprovalState.error.asString, offerInDatabase?.approveToTakeState)
        
    }
    
    /**
     Ensure `OfferService` properly handles failed offer taking transactions.
     */
    func testHandleFailedOfferTakingTransaction() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )!
        offer.takingOfferState = .awaitingTransactionConfirmation
        let takingOfferTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .takeOffer)
        offer.takingOfferTransaction = takingOfferTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let swapTruthSource = TestSwapTruthSource()
        
        let swap = try! Swap(
            isCreated: offer.isCreated,
            requiresFill: false,
            id: offer.id,
            maker: offer.maker,
            makerInterfaceID: offer.interfaceId,
            taker: EthereumAddress.zero,
            takerInterfaceID: Data(),
            stablecoin: offer.stablecoin,
            amountLowerBound: offer.amountLowerBound,
            amountUpperBound: offer.amountUpperBound,
            securityDepositAmount: offer.securityDepositAmount,
            takenSwapAmount: offer.amountLowerBound,
            serviceFeeAmount: BigUInt.zero,
            serviceFeeRate: offer.serviceFeeRate,
            direction: offer.direction,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: offer.chainID,
            state: .takeOfferTransactionSent,
            role: .takerAndSeller
        )
        swapTruthSource.swaps[offerID] = swap
        let swapForDatabase = DatabaseSwap(
            id: swap.id.asData().base64EncodedString(),
            isCreated: swap.isCreated,
            requiresFill: swap.requiresFill,
            maker: swap.maker.addressData.toHexString(),
            makerInterfaceID: swap.makerInterfaceID.base64EncodedString(),
            taker: swap.taker.addressData.toHexString(),
            takerInterfaceID: swap.takerInterfaceID.base64EncodedString(),
            stablecoin: swap.stablecoin.addressData.toHexString(),
            amountLowerBound: String(swap.amountLowerBound),
            amountUpperBound: String(swap.amountUpperBound),
            securityDepositAmount: String(swap.securityDepositAmount),
            takenSwapAmount: String(swap.takenSwapAmount),
            serviceFeeAmount: String(swap.serviceFeeAmount),
            serviceFeeRate: String(swap.serviceFeeRate),
            onChainDirection: String(swap.onChainDirection),
            onChainSettlementMethod: swap.onChainSettlementMethod.base64EncodedString(),
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: nil,
            protocolVersion: String(swap.protocolVersion),
            isPaymentSent: swap.isPaymentSent,
            isPaymentReceived: swap.isPaymentReceived,
            hasBuyerClosed: swap.hasBuyerClosed,
            hasSellerClosed: swap.hasSellerClosed,
            onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
            chainID: String(swap.chainID),
            state: swap.state.asString,
            role: swap.role.asString,
            approveToFillState: swap.approvingToFillState.asString,
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: swap.fillingSwapState.asString,
            fillingSwapTransactionHash: nil,
            fillingSwapTransactionCreationTime: nil,
            fillingSwapTransactionCreationBlockNumber: nil,
            reportPaymentSentState: swap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        offerService.swapTruthSource = swapTruthSource
        let failureHandledExpectation = XCTestExpectation(description: "Fulfilled when failed transaction has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleFailedTransaction(takingOfferTransaction, error: BlockchainTransactionError(errorDescription: "tx failed"))
            failureHandledExpectation.fulfill()
        }
        
        wait(for: [failureHandledExpectation], timeout: 30.0)
        XCTAssertEqual(TakingOfferState.error, offer.takingOfferState)
        XCTAssertNotNil(offer.takingOfferError)
        XCTAssertEqual(SwapState.takeOfferTransactionFailed, swap.state)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(TakingOfferState.error.asString, offerInDatabase?.takingOfferState)
        let swapInDatabase = try! databaseService.getSwap(id: offerID.asData().base64EncodedString())
        XCTAssertEqual(SwapState.takeOfferTransactionFailed.asString, swapInDatabase?.state)
        
    }
    
    /**
     Ensures that `OfferService` handles [Approval](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-Approval-address-address-uint256-) events properly, when such events indicate the approval of a token transfer in order to open an offer made by the interface user.
     */
    func testHandleApprovalToOpenOfferEvent() {
        
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt("31337"),
            havePublicKey: true,
            isUserMaker: true,
            state: .approveTransferTransactionSent
        )
        offer.approvingToOpenState = .awaitingTransactionConfirmation
        let approvingToOpenTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .approveTokenTransferToOpenOffer)
        offer.approvingToOpenTransaction = approvingToOpenTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offerID.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.address,
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.address,
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: offer.direction.string,
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: OfferState.openOfferTransactionSent.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let approvalEvent = ApprovalEvent(owner: EthereumAddress.zero, spender: EthereumAddress.zero, amount: BigUInt.zero, purpose: .openOffer, transactionHash: "0xa_transaction_hash_here", chainID: offer.chainID)
        
        let eventHandlingExpectation = XCTestExpectation(description: "Fulfilled when event has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleTokenTransferApprovalEvent(approvalEvent)
            eventHandlingExpectation.fulfill()
        }
        
        wait(for: [eventHandlingExpectation], timeout: 30.0)
        XCTAssertEqual(OfferState.awaitingOpening, offer.state)
        XCTAssertEqual(TokenTransferApprovalState.completed, offer.approvingToOpenState)
        XCTAssertNil(offer.approvingToOpenError)
        let offerInDatabase = try! databaseService.getOffer(id: offerForDatabase.id)
        XCTAssertEqual(OfferState.awaitingOpening.asString, offerInDatabase?.state)
        XCTAssertEqual(TokenTransferApprovalState.completed.asString, offerInDatabase?.approveToOpenState)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly for offers NOT made by the interface user.
     */
    func testHandleOfferOpenedEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferOpenedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened")
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferOpenedEvent> {
            
            var appendedEvent: OfferOpenedEvent? = nil
            var removedEvent: OfferOpenedEvent? = nil
            
            override func append(_ element: OfferOpenedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferOpenedEvent) {
                removedEvent = elementToRemove
                super.remove(elementToRemove)
            }
            
        }
        
        let offerOpenedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerOpenedEventRepository: offerOpenedEventRepository
        )
        
        // We need this new TestOfferTruthSource declaration because we need to track added offers
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerAddedExpectation = XCTestExpectation(description: "Fulfilled when an offer is added to the offers dictionary")
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and only fulfill when a new offer is actually added
                    if offers.keys.count != 0 {
                        offerAddedExpectation.fulfill()
                    }
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.offerAddedExpectation], timeout: 180.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 1)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID]!.id == expectedOfferID)
        XCTAssertEqual(offerOpenedEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerOpenedEventRepository.removedEvent!.id, expectedOfferID)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertTrue(offerInDatabase!.isCreated)
        XCTAssertFalse(offerInDatabase!.isTaken)
        XCTAssertEqual(offerInDatabase!.interfaceId, Data("maker interface Id here".utf8).base64EncodedString())
        XCTAssertEqual(offerInDatabase!.amountLowerBound, "10000")
        XCTAssertEqual(offerInDatabase!.amountUpperBound, "10000")
        XCTAssertEqual(offerInDatabase!.securityDepositAmount, "1000")
        XCTAssertEqual(offerInDatabase!.serviceFeeRate, "100")
        XCTAssertEqual(offerInDatabase!.onChainDirection, "1")
        XCTAssertEqual(offerInDatabase!.protocolVersion, "1")
        XCTAssertEqual(offerInDatabase!.state, OfferState.awaitingPublicKeyAnnouncement.asString)
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerInDatabase!.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 1)
        XCTAssertEqual(settlementMethodsInDatabase![0].0, Data("{\"f\":\"USD\",\"p\":\"SWIFT\",\"m\":\"1.00\"}".utf8).base64EncodedString())
    }
    
    /**
     Ensures that `OfferService` handles [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly for offers made by the interface user.
     */
    func testHandleOfferOpenedEventForUserIsMakerOffer() {
        
        let newOfferID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let keyPairForOffer = try! keyManagerService.generateKeyPair(storeResult: true)
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsMakerOffer_handleOfferOpenedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: newOfferID.uuidString)
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        
        let p2pErrorHandler = TestP2PErrorHandler()
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            var offerIDForAnnouncement: UUID?
            var keyPairForAnnouncement: KeyPair?
            override func announcePublicKey(offerID: UUID, keyPair: KeyPair) {
                offerIDForAnnouncement = offerID
                keyPairForAnnouncement = keyPair
            }
        }
        
        let testP2PService = TestP2PService(
            errorHandler: p2pErrorHandler,
            offerService: offerService,
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        
        offerService.p2pService = testP2PService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: newOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: keyPairForOffer.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt("31337"),
            havePublicKey: true,
            isUserMaker: true,
            state: .openOfferTransactionSent
        )
        offerTruthSource.offers[newOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: newOfferID.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.address,
            interfaceId: keyPairForOffer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.address,
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: offer.direction.string,
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: OfferState.openOfferTransactionSent.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerOpenedEvent = OfferOpenedEvent(id: newOfferID, interfaceID: keyPairForOffer.interfaceId, chainID: offer.chainID)
        
        let eventHandlingExpectation = XCTestExpectation(description: "Fulfilled when event has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleOfferOpenedEvent(offerOpenedEvent)
            eventHandlingExpectation.fulfill()
        }
        
        wait(for: [eventHandlingExpectation], timeout: 30.0)
        XCTAssertFalse(errorHandler.gotError)
        XCTAssertEqual(testP2PService.offerIDForAnnouncement, newOfferID)
        XCTAssertEqual(testP2PService.keyPairForAnnouncement!.interfaceId, keyPairForOffer.interfaceId)
        
        XCTAssertEqual(OfferState.offerOpened, offer.state)
        XCTAssertEqual(OpeningOfferState.completed, offer.openingOfferState)
        XCTAssertNil(offer.openingOfferError)
        let offerInDatabase = try! databaseService.getOffer(id: offerForDatabase.id)
        XCTAssertEqual(OfferState.offerOpened.asString, offerInDatabase?.state)
        XCTAssertEqual(OpeningOfferState.completed.asString, offerInDatabase?.openingOfferState)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) events properly, both for offers made by the user of this interface and for offers that are not.
     */
    func testHandleOfferCanceledEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        let openOfferResponseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferCanceledEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened")
        ]
        var offerOpenRequest = URLRequest(url: testingServerUrlComponents.url!)
        offerOpenRequest.httpMethod = "GET"
        offerOpenRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotErrorForOpenRequest = false
        let offerOpenRequestTask = URLSession.shared.dataTask(with: offerOpenRequest) { data, response, error in
            if let error = error {
                print(error)
                gotErrorForOpenRequest = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                openOfferResponseExpectation.fulfill()
            } else {
                print(response!)
                gotErrorForOpenRequest = true
            }
        }
        offerOpenRequestTask.resume()
        wait(for: [openOfferResponseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotErrorForOpenRequest)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository<Event: Equatable>: BlockchainEventRepository<Event> {
            
            var appendedEvent: Event? = nil
            var removedEvent: Event? = nil
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when an event is removed")
            
            override func append(_ element: Event) {
                super.append(element)
                appendedEvent = element
            }
            
            override func remove(_ elementToRemove: Event) {
                super.remove(elementToRemove)
                removedEvent = elementToRemove
                eventRemovedExpectation.fulfill()
            }
            
        }
        
        let offerCanceledEventRepository = TestBlockchainEventRepository<OfferCanceledEvent>()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerCanceledEventRepository: offerCanceledEventRepository
        )
        
        // We need this TestOfferTruthSource declaration because we need to track added and removed offers
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            let offerAddedExpectation = XCTestExpectation(description: "Fulfuilled when an offer is added to the offers dictionary")
            let offerRemovedExpectation = XCTestExpectation(description: "Fulfilled when an offer is removed to the offers dictionary")
            var hasOfferBeenAdded = false
            var serviceFeeRate: BigUInt?
            
            var offers: [UUID: Offer] {
                didSet {
                    // We want to ignore initialization and offer addition and only fulfill when a new offer is actually removed
                    if offers.keys.count != 0 {
                        hasOfferBeenAdded = true
                        offerAddedExpectation.fulfill()
                    } else {
                        if hasOfferBeenAdded {
                            offerRemovedExpectation.fulfill()
                        }
                    }
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        
        wait(for: [offerTruthSource.offerAddedExpectation], timeout: 60.0)
        let openedOffer = offerTruthSource.offers[expectedOfferID]
        
        struct SecondTestingServerResponse: Decodable {
            let offerCancellationTransactionHash: String
        }
        let cancelOfferResponseExpectation = XCTestExpectation(description: "Fulfilled when testing server responds to request for offer cancellation")
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-canceled"),
            URLQueryItem(name: "commutoSwapAddress", value: testingServerResponse!.commutoSwapAddress)
        ]
        var offerCancellationRequest = URLRequest(url: testingServerUrlComponents.url!)
        offerCancellationRequest.httpMethod = "GET"
        offerCancellationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var secondTestingServerResponse: SecondTestingServerResponse? = nil
        var gotErrorForCancellationRequest = false
        let cancellationRequestTask = URLSession.shared.dataTask(with: offerCancellationRequest) { data, response, error in
            if let error = error {
                print(error)
                gotErrorForCancellationRequest = true
            } else if let data = data {
                secondTestingServerResponse = try! JSONDecoder().decode(SecondTestingServerResponse.self, from: data)
                cancelOfferResponseExpectation.fulfill()
            } else {
                print(response!)
                gotErrorForCancellationRequest = true
            }
        }
        cancellationRequestTask.resume()
        wait(for: [cancelOfferResponseExpectation], timeout: 10.0)
        XCTAssertTrue(!gotErrorForCancellationRequest)
        
        wait(for: [offerTruthSource.offerRemovedExpectation, offerCanceledEventRepository.eventRemovedExpectation], timeout: 20.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertTrue(offerTruthSource.offers.keys.count == 0)
        XCTAssertTrue(offerTruthSource.offers[expectedOfferID] == nil)
        XCTAssertFalse(openedOffer!.isCreated)
        XCTAssertEqual(OfferState.canceled, openedOffer?.state)
        XCTAssertEqual(offerCanceledEventRepository.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerCanceledEventRepository.removedEvent!.id, expectedOfferID)
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(offerInDatabase, nil)
        
        // Ensure handleOfferCanceledEvent properly handles the cancellation of offers made by the user of this interface
        blockchainService.stopListening()
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: expectedOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        offer.cancelingOfferState = .awaitingTransactionConfirmation
        offer.offerCancellationTransaction = BlockchainTransaction(transactionHash: secondTestingServerResponse!.offerCancellationTransactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .cancelOffer)
        offerTruthSource.offers[expectedOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerCanceledEventRepositoryForMonitoredTxn = TestBlockchainEventRepository<OfferCanceledEvent>()
        let offerServiceForMonitoredTxn = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerCanceledEventRepository: offerCanceledEventRepositoryForMonitoredTxn
        )
        let offerTruthSourceForMonitoredTxn = TestOfferTruthSource()
        offerTruthSourceForMonitoredTxn.offers[expectedOfferID] = offer
        offerServiceForMonitoredTxn.offerTruthSource = offerTruthSourceForMonitoredTxn
        let blockchainServiceForMonitoredTxn = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerServiceForMonitoredTxn,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        blockchainServiceForMonitoredTxn.addTransactionToMonitor(transaction: offer.offerCancellationTransaction!)
        offerServiceForMonitoredTxn.blockchainService = blockchainServiceForMonitoredTxn
        blockchainServiceForMonitoredTxn.listen()
        
        wait(for: [offerCanceledEventRepositoryForMonitoredTxn.eventRemovedExpectation], timeout: 120.0)
        XCTAssertFalse(errorHandler.gotError)
        XCTAssertTrue(offerTruthSourceForMonitoredTxn.offers.keys.isEmpty)
        XCTAssertNil(offerTruthSourceForMonitoredTxn.offers[expectedOfferID])
        XCTAssertFalse(offer.isCreated)
        XCTAssertEqual(OfferState.canceled, offer.state)
        XCTAssertEqual(CancelingOfferState.completed, offer.cancelingOfferState)
        XCTAssertNil(blockchainServiceForMonitoredTxn.getMonitoredTransaction(transactionHash: secondTestingServerResponse!.offerCancellationTransactionHash))
        XCTAssertEqual(secondTestingServerResponse!.offerCancellationTransactionHash, offer.offerCancellationTransaction!.transactionHash)
        XCTAssertEqual(offerCanceledEventRepositoryForMonitoredTxn.appendedEvent!.id, expectedOfferID)
        XCTAssertEqual(offerCanceledEventRepositoryForMonitoredTxn.removedEvent!.id, expectedOfferID)
        let offerInDatabaseForMonitoredTxn = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertEqual(offerInDatabaseForMonitoredTxn, nil)
        
    }
    
    /**
     Ensures that `OfferService` handles [Approval](https://eips.ethereum.org/EIPS/eip-20) events properly, when such events indicate the approval of a token transfer in order to take an offer..
     */
    func testHandleApprovalToTakeOfferEvent() {
        
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt("31337"),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        offer.approvingToTakeState = .awaitingTransactionConfirmation
        let approvingToTakeTransaction = BlockchainTransaction(transactionHash: "a_transaction_hash_here", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .approveTokenTransferToTakeOffer)
        offer.approvingToTakeTransaction = approvingToTakeTransaction
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offerID.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.address,
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.address,
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: offer.direction.string,
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: OfferState.openOfferTransactionSent.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let approvalEvent = ApprovalEvent(owner: EthereumAddress.zero, spender: EthereumAddress.zero, amount: BigUInt.zero, purpose: .takeOffer, transactionHash: "0xa_transaction_hash_here", chainID: offer.chainID)
        
        let eventHandlingExpectation = XCTestExpectation(description: "Fulfilled when event has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleTokenTransferApprovalEvent(approvalEvent)
            eventHandlingExpectation.fulfill()
        }
        
        wait(for: [eventHandlingExpectation], timeout: 30.0)
        XCTAssertEqual(TokenTransferApprovalState.completed, offer.approvingToTakeState)
        XCTAssertNil(offer.approvingToTakeError)
        let offerInDatabase = try! databaseService.getOffer(id: offerForDatabase.id)
        XCTAssertEqual(TokenTransferApprovalState.completed.asString, offerInDatabase?.approveToTakeState)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers neither made nor taken by the interface user.
     */
    func testHandleOfferTakenEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken")
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerOpenedEvent = OfferOpenedEvent(id: expectedOfferID, interfaceID: Data(), chainID: BigUInt("31337"))
        let offerOpenedEventHandledExpectation = XCTestExpectation(description: "Fulfilled when OfferOpenedEvent is handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleOfferOpenedEvent(offerOpenedEvent)
            offerOpenedEventHandledExpectation.fulfill()
        }
        
        wait(for: [offerOpenedEventHandledExpectation], timeout: 10.0)
        XCTAssertEqual(1, offerTruthSource.offers.keys.count)
        XCTAssertNotNil(offerTruthSource.offers[expectedOfferID])
        let offerInDatabase = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertNotNil(offerInDatabase)
        
        let offerTakenEvent = OfferTakenEvent(id: expectedOfferID, interfaceID: Data(), chainID: BigUInt("31337"))
        let offerTakenEventHandledExpectation = XCTestExpectation(description: "Fulfilled when OfferTakenEvent is handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleOfferTakenEvent(offerTakenEvent)
            offerTakenEventHandledExpectation.fulfill()
        }
        
        wait(for: [offerTakenEventHandledExpectation], timeout: 10.0)
        XCTAssertEqual(0, offerTruthSource.offers.keys.count)
        XCTAssertNil(offerTruthSource.offers[expectedOfferID])
        let offerInDatabaseAfterTaking = try! databaseService.getOffer(id: expectedOfferID.asData().base64EncodedString())
        XCTAssertNil(offerInDatabaseAfterTaking)
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers taken by the interface user.
     */
    func testHandleOfferTakenEventForUserIsTaker() {
        
        let newOfferID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to store the whole key pair persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        let makerInterfaceID = makerKeyPair.interfaceId
        // We store the maker's public key, as if we received it via the P2P network
        try! keyManagerService.storePublicKey(pubKey: try! makerKeyPair.getPublicKey())
        
        // This is the taker's (user's) key pair, so we do want to store it persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        let makerInterfaceIDString = makerInterfaceID.base64EncodedString()
        let takerInterfaceIDString = takerKeyPair.interfaceId.base64EncodedString()
        
        // Make testing server set up the proper test environment
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsTaker_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "offerID", value: newOfferID.uuidString),
            URLQueryItem(name: "makerInterfaceID", value: makerInterfaceIDString),
            URLQueryItem(name: "takerInterfaceID", value: takerInterfaceIDString)
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        // Set up node connection
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let offerTruthSource = TestOfferTruthSource()
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: newOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt("31337"),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        offer.takingOfferState = TakingOfferState.awaitingTransactionConfirmation
        offerTruthSource.offers[newOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: newOfferID.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.address,
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.address,
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: offer.direction.string,
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: OfferState.openOfferTransactionSent.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        // OfferService should call the sendTakerInformationMessage method of this class, passing a UUID equal to newOfferID to begin the process of sending taker information
        class TestSwapService: SwapNotifiable {
            let expectedSwapIDForMessage: UUID
            var chainIDForMessage: BigUInt? = nil
            init(expectedSwapIDForMessage: UUID) {
                self.expectedSwapIDForMessage = expectedSwapIDForMessage
            }
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool {
                if swapID == expectedSwapIDForMessage {
                    chainIDForMessage = chainID
                    return true
                } else {
                    return false
                }
            }
            func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws {}
            func handleNewSwap(takenOffer: Offer) throws {}
            func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) throws {}
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
            func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {}
            func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {}
            func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {}
        }
        let swapService = TestSwapService(expectedSwapIDForMessage: newOfferID)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: swapService
        )
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: swapService,
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerTakenEvent = OfferTakenEvent(id: newOfferID, interfaceID: takerKeyPair.interfaceId, chainID: BigUInt("31337"))
        let offerTakenEventHandledExpectation = XCTestExpectation(description: "Fulfilled when event has been handled")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleOfferTakenEvent(offerTakenEvent)
            offerTakenEventHandledExpectation.fulfill()
        }
        
        wait(for: [offerTakenEventHandledExpectation], timeout: 15.0)
        XCTAssertEqual(BigUInt(31337), swapService.chainIDForMessage)
        XCTAssertEqual(OfferState.taken, offer.state)
        XCTAssertEqual(TakingOfferState.completed, offer.takingOfferState)
        
        let offerInDatabase = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(OfferState.taken.asString, offerInDatabase?.state)
        XCTAssertEqual(TakingOfferState.completed.asString, offerInDatabase?.takingOfferState)
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly for offers made by the interface user.
     */
    func testHandleOfferTakenEventForUserIsMaker() {
        let offerID = UUID()
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let keyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // Make testing server set up the proper test environment
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_forUserIsMaker_handleOfferTakenEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-taken"),
            URLQueryItem(name: "offerID", value: offerID.uuidString),
            URLQueryItem(name: "interfaceID", value: keyPair.interfaceId.base64EncodedString())
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        // Set up node connection
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let offerTruthSource = TestOfferTruthSource()
        
        // We have to persistently store an offer with an ID equal to offerID and isUserMaker set to true, so that OfferService calls handleNewSwap
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: keyPair.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        // OfferService should call the handleNewSwap method of this class, passing an offer with an ID equal to offerID. We need this new TestSwapService declaration to track when handleNewSwap is called
        class TestSwapService: SwapNotifiable {
            var swapID: UUID? = nil
            var chainID: BigUInt? = nil
            func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool { return false }
            func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws {}
            func handleNewSwap(takenOffer: Offer) throws {
                self.swapID = takenOffer.id
                self.chainID = takenOffer.chainID
            }
            func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) throws {}
            func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
            func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
            func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {}
            func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {}
            func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {}
        }
        let swapService = TestSwapService()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: swapService
        )
        offerService.offerTruthSource = offerTruthSource
        
        let p2pErrorHandler = TestP2PErrorHandler()
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            override func announcePublicKey(offerID: UUID, keyPair: KeyPair) {}
        }
        let testP2PService = TestP2PService(
            errorHandler: p2pErrorHandler,
            offerService: offerService,
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        offerService.p2pService = testP2PService
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerTakenEvent = OfferTakenEvent(id: offerID, interfaceID: Data(), chainID: BigUInt(31337))
        let offerTakenEventHandledExpectation = XCTestExpectation(description: "Fulfilled when OfferTakenEvent has been handled.")
        
        DispatchQueue.global(qos: .default).async {
            try! offerService.handleOfferTakenEvent(offerTakenEvent)
            offerTakenEventHandledExpectation.fulfill()
        }
        
        wait(for: [offerTakenEventHandledExpectation], timeout: 30.0)
        XCTAssertEqual(offerID, swapService.swapID)
        XCTAssertEqual(BigUInt(31337), swapService.chainID)
        XCTAssertTrue(offer.isTaken)
        XCTAssertNil(offerTruthSource.offers[offerID])
        XCTAssertNil(try! databaseService.getOffer(id: offerID.asData().base64EncodedString()))
        XCTAssertNil(try! databaseService.getOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: String(offer.chainID)))
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferrEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) events properly for offers not made by the interface user.
     */
    func testHandleOfferEditedEventForUserIsNotMaker() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferEditedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-edited")
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferEditedEvent> {
            
            var appendedEvent: OfferEditedEvent? = nil
            var removedEvent: OfferEditedEvent? = nil
            
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when eventRemovedExpectation is called")
            
            override func append(_ element: OfferEditedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferEditedEvent) {
                removedEvent = elementToRemove
                eventRemovedExpectation.fulfill()
                super.remove(elementToRemove)
            }
            
        }
        
        let offerEditedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerEditedEventRepository: offerEditedEventRepository
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: expectedOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )!
        offerTruthSource.offers[expectedOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerEditedEvent = OfferEditedEvent(id: expectedOfferID, chainID: BigUInt(31337), transactionHash: "offer_editing_tx_hash")
        
        // handleOfferEditedEvent runs code synchronously on the main DispatchQueue, so we must call it like this to avoid deadlock
        DispatchQueue.global().async {
            try! offerService.handleOfferEditedEvent(offerEditedEvent)
        }
        
        wait(for: [offerEditedEventRepository.eventRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertEqual(expectedOfferID, offerEditedEventRepository.appendedEvent!.id)
        XCTAssertEqual(expectedOfferID, offerEditedEventRepository.removedEvent!.id)
        
        XCTAssertEqual(2, offer.settlementMethods.count)
        XCTAssertEqual("EUR", offer.settlementMethods[0].currency)
        XCTAssertEqual("0.98", offer.settlementMethods[0].price)
        XCTAssertEqual("SEPA", offer.settlementMethods[0].method)
        XCTAssertEqual("BSD", offer.settlementMethods[1].currency)
        XCTAssertEqual("1.00", offer.settlementMethods[1].price)
        XCTAssertEqual("SANDDOLLAR", offer.settlementMethods[1].method)
        
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 2)
        XCTAssertEqual(settlementMethodsInDatabase![0].0, Data("{\"f\":\"EUR\",\"p\":\"0.98\",\"m\":\"SEPA\"}".utf8).base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase![1].0, Data("{\"f\":\"BSD\",\"p\":\"1.00\",\"m\":\"SANDDOLLAR\"}".utf8).base64EncodedString())
        
    }
    
    /**
     Ensures that `OfferService` handles [OfferrEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) events properly for offers made by the interface user.
     */
    func testHandleOfferEditedEventForUserIsMaker() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let offerId: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleOfferEditedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened-edited")
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        let expectedOfferID = UUID(uuidString: testingServerResponse!.offerId)!
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        class TestBlockchainEventRepository: BlockchainEventRepository<OfferEditedEvent> {
            
            var appendedEvent: OfferEditedEvent? = nil
            var removedEvent: OfferEditedEvent? = nil
            
            let eventRemovedExpectation = XCTestExpectation(description: "Fulfilled when eventRemovedExpectation is called")
            
            override func append(_ element: OfferEditedEvent) {
                appendedEvent = element
                super.append(element)
            }
            
            override func remove(_ elementToRemove: OfferEditedEvent) {
                removedEvent = elementToRemove
                eventRemovedExpectation.fulfill()
                super.remove(elementToRemove)
            }
            
        }
        
        let offerEditedEventRepository = TestBlockchainEventRepository()
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService(),
            offerEditedEventRepository: offerEditedEventRepository
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: expectedOfferID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )!
        try! offer.updateSettlementMethods(settlementMethods: [
            SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", privateData: "some_swift_data")
        ])
        offer.editingOfferState = .awaitingTransactionConfirmation
        offer.offerEditingTransaction = BlockchainTransaction(transactionHash: "offer_editing_tx_hash", timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .editOffer)
        offerTruthSource.offers[expectedOfferID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        let serializedSettlementMethodsAndPrivateDetails = offer.settlementMethods.compactMap { settlementMethod in
            return (try! JSONEncoder().encode(settlementMethod).base64EncodedString(), settlementMethod.privateData)
        }
        try! databaseService.storeOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID, settlementMethods: serializedSettlementMethodsAndPrivateDetails)
        
        let pendingSettlementMethods = [
            SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: "some_sepa_data"),
            SettlementMethod(currency: "BSD", price: "1.00", method: "SANDDOLLAR", privateData: "some_sanddollar_data")
        ]
        offer.selectedSettlementMethods = pendingSettlementMethods
        let serializedPendingSettlementMethodsAndPrivateDetails = pendingSettlementMethods.compactMap { pendingSettlementMethod in
            return (try! JSONEncoder().encode(pendingSettlementMethod).base64EncodedString(), pendingSettlementMethod.privateData)
        }
        try! databaseService.storePendingOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID, pendingSettlementMethods: serializedPendingSettlementMethodsAndPrivateDetails)
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offerEditedEvent = OfferEditedEvent(id: expectedOfferID, chainID: BigUInt(31337), transactionHash: "offer_editing_tx_hash")
        
        // handleOfferEditedEvent runs code synchronously on the main DispatchQueue, so we must call it like this to avoid deadlock
        DispatchQueue.global().async {
            try! offerService.handleOfferEditedEvent(offerEditedEvent)
        }
        
        wait(for: [offerEditedEventRepository.eventRemovedExpectation], timeout: 60.0)
        XCTAssertTrue(!errorHandler.gotError)
        XCTAssertEqual(1, offerTruthSource.offers.keys.count)
        XCTAssertEqual(expectedOfferID, offerTruthSource.offers[expectedOfferID]!.id)
        XCTAssertEqual(expectedOfferID, offerEditedEventRepository.appendedEvent!.id)
        XCTAssertEqual(expectedOfferID, offerEditedEventRepository.removedEvent!.id)
        XCTAssertEqual(.completed, offer.editingOfferState)
        XCTAssertEqual(0, offer.selectedSettlementMethods.count)
        
        let offerInDatabase = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual("completed", offerInDatabase?.editingOfferState)
        
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertEqual(settlementMethodsInDatabase!.count, 2)
        XCTAssertEqual(settlementMethodsInDatabase![0].0, Data("{\"f\":\"EUR\",\"p\":\"0.98\",\"m\":\"SEPA\"}".utf8).base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase![0].1, "some_sepa_data")
        XCTAssertEqual(settlementMethodsInDatabase![1].0, Data("{\"f\":\"BSD\",\"p\":\"1.00\",\"m\":\"SANDDOLLAR\"}".utf8).base64EncodedString())
        XCTAssertEqual(settlementMethodsInDatabase![1].1, "some_sanddollar_data")
        
        let pendingSettlementMethodsInDatabase = try! databaseService.getPendingOfferSettlementMethods(offerID: expectedOfferID.asData().base64EncodedString(), _chainID: offerForDatabase.chainID)
        XCTAssertNil(pendingSettlementMethodsInDatabase)
    }
    
    /**
     Ensures that `OfferService` handles [Public Key Announcements](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) properly.
     */
    func testHandlePublicKeyAnnouncement() {
        
        class TestDatabaseService: DatabaseService {
            
            let offerHavePublicKeyUpdatedExpectation = XCTestExpectation(description: "Fulfilled when updateOfferHavePublicKey is called")
            
            override func updateOfferHavePublicKey(offerID: String, _chainID: String, _havePublicKey: Bool) throws {
                try super.updateOfferHavePublicKey(offerID: offerID, _chainID: _chainID, _havePublicKey: _havePublicKey)
                offerHavePublicKeyUpdatedExpectation.fulfill()
            }
        }
        
        let databaseService = try! TestDatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<PreviewableOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = PreviewableOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let keyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        let publicKey = try! keyPair.getPublicKey()
        
        let offerID = UUID()
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: publicKey.interfaceId,
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337),
            havePublicKey: false,
            isUserMaker: false,
            state: .awaitingPublicKeyAnnouncement
        )!
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let publicKeyAnnouncement = PublicKeyAnnouncement(
            offerId: offerID,
            pubKey: publicKey
        )
        
        // handlePublicKeyAnnouncement runs code synchronously on the main DispatchQueue, so we must call it like this to avoid deadlock
        DispatchQueue.global().async {
            try! offerService.handlePublicKeyAnnouncement(publicKeyAnnouncement)
        }
        
        wait(for: [databaseService.offerHavePublicKeyUpdatedExpectation], timeout: 30)
        XCTAssertTrue(offerTruthSource.offers[offerID]!.havePublicKey)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())
        XCTAssertTrue(offerInDatabase!.havePublicKey)
        XCTAssertEqual(offerInDatabase!.state, "offerOpened")
        let keyInDatabase = try! keyManagerService.getPublicKey(interfaceId: publicKey.interfaceId)
        XCTAssertEqual(keyInDatabase?.publicKey, publicKey.publicKey)
    }
    
    /**
     Ensures that `OfferService` handles [ServiceFeeRateChanged](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#servicefeeratechanged) events properly.
     */
    func testHandleServiceFeeRateChangedEvent() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_handleServiceFeeRateChangedEvent")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "ServiceFeeRateChanged")
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 40.0)
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        // We need this TestOfferTruthSource declaration in order to track setting of the service fee rate
        class TestOfferTruthSource: OfferTruthSource {
            
            init() {
                offers = [:]
            }
            
            var offers: [UUID : Offer] = [:]
            
            let serviceFeeRateSetExpectation = XCTestExpectation(description: "Fulfilled when the service fee rate is set")
            
            var serviceFeeRate: BigUInt? {
                didSet {
                    serviceFeeRateSetExpectation.fulfill()
                }
            }
            
        }
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        blockchainService.listen()
        wait(for: [offerTruthSource.serviceFeeRateSetExpectation], timeout: 60.0)
        XCTAssertFalse(errorHandler.gotError)
        XCTAssertEqual(offerTruthSource.serviceFeeRate, BigUInt(200))
        
    }
    
    /**
     Ensures that `OfferService.createApproveTokenTransferToOpenOfferTransaction`, `BlockchainService.createApproveTransferTransaction`, `OfferService.approveTokenTransferToOpenOffer`, `OfferService.createOpenOfferTransaction`, `BlockchainService.createOpenOfferTransaction`, `OfferService.openOffer`, and `BlockchainService.sendTransaction` function properly.
     */
    func testOpenOffer() {
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let stablecoinAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        let testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_openOffer")!
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 40.0)
        XCTAssertFalse(gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let openingExpectation = XCTestExpectation(description: "Fulfilled when offerService.openOffer returns")
        
        let settlementMethods = [SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", id: UUID().uuidString, privateData: String(decoding: try! JSONEncoder().encode(PrivateSWIFTData(accountHolder: "account_holder", bic: "bic", accountNumber: "account_number")), as: UTF8.self))]
        
        offerService.createApproveTokenTransferToOpenOfferTransaction(
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            stablecoinInformation: StablecoinInformation(currencyCode: "STBL", name: "Basic Stablecoin", decimal: 3),
            minimumAmount: NSNumber(floatLiteral: 100.00).decimalValue,
            maximumAmount: NSNumber(floatLiteral: 200.00).decimalValue,
            securityDepositAmount: NSNumber(floatLiteral: 20.00).decimalValue,
            direction: .sell,
            settlementMethods: settlementMethods
        ).then { transaction in
            offerService.approveTokenTransferToOpenOffer(
                chainID: BigUInt(31337),
                stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
                stablecoinInformation: StablecoinInformation(currencyCode: "STBL", name: "Basic Stablecoin", decimal: 3),
                minimumAmount: NSNumber(floatLiteral: 100.00).decimalValue,
                maximumAmount: NSNumber(floatLiteral: 200.00).decimalValue,
                securityDepositAmount: NSNumber(floatLiteral: 20.00).decimalValue,
                direction: .sell,
                settlementMethods: settlementMethods,
                approveTokenTransferToOpenOfferTransaction: transaction
            )
        }.then { () -> Promise<EthereumTransaction> in
            // Since we aren't parsing new events, we have to set the offer state manually
            offerTruthSource.offers.first!.value.state = .awaitingOpening
            return offerService.createOpenOfferTransaction(offer: offerTruthSource.offers.first!.value)
        }.then { transaction in
            offerService.openOffer(offer: offerTruthSource.offers.first!.value, offerOpeningTransaction: transaction)
        }.done {
            openingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [openingExpectation], timeout: 60.0)
        
        let offer = offerTruthSource.offers.first!.value
        XCTAssertTrue(offer.isCreated)
        XCTAssertFalse(offer.isTaken)
        #warning("TODO: check proper maker address once WalletService is implemented")
        //XCTAssertEqual(offer.maker, blockchainService.ethKeyStore.addresses!.first!)
        XCTAssertEqual(offer.stablecoin, EthereumAddress(testingServerResponse!.stablecoinAddress)!)
        XCTAssertEqual(offer.amountLowerBound, BigUInt(100_000))
        XCTAssertEqual(offer.amountUpperBound, BigUInt(200_000))
        XCTAssertEqual(offer.securityDepositAmount, BigUInt(20_000))
        XCTAssertEqual(offer.serviceFeeRate, BigUInt(100))
        XCTAssertEqual(offer.serviceFeeAmountLowerBound, BigUInt(1_000))
        XCTAssertEqual(offer.serviceFeeAmountUpperBound, BigUInt(2_000))
        XCTAssertEqual(offer.onChainDirection, BigUInt(1))
        XCTAssertEqual(offer.direction, .sell)
        XCTAssertEqual(
            offer.onChainSettlementMethods,
            settlementMethods.compactMap { settlementMethod in
                return try? JSONEncoder().encode(settlementMethod)
            }
        )
        XCTAssertEqual(offer.settlementMethods, settlementMethods)
        XCTAssertEqual(offer.protocolVersion, BigUInt.zero)
        XCTAssertTrue(offer.havePublicKey)
        
        XCTAssertNotNil(try! keyManagerService.getKeyPair(interfaceId: offer.interfaceId))
        
        let offerInDatabase = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())!
        #warning("TODO: check proper maker address once WalletService is implemented")
        let mostlyExpectedOfferInDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: true,
            isTaken: false,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(BigUInt(1)),
            protocolVersion: String(BigUInt.zero),
            chainID: String(BigUInt(31337)),
            havePublicKey: true,
            isUserMaker: true,
            state: OfferState.openOfferTransactionSent.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        XCTAssertEqual(mostlyExpectedOfferInDatabase.id, offerInDatabase.id)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.isCreated, offerInDatabase.isCreated)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.interfaceId, offerInDatabase.interfaceId)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.stablecoin, offerInDatabase.stablecoin)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.amountLowerBound, offerInDatabase.amountLowerBound)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.amountUpperBound, offerInDatabase.amountUpperBound)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.securityDepositAmount, offerInDatabase.securityDepositAmount)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.serviceFeeRate, offerInDatabase.serviceFeeRate)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.onChainDirection, offerInDatabase.onChainDirection)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.protocolVersion, offerInDatabase.protocolVersion)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.chainID, offerInDatabase.chainID)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.havePublicKey, offerInDatabase.havePublicKey)
        XCTAssertEqual(mostlyExpectedOfferInDatabase.isUserMaker, offerInDatabase.isUserMaker)
        
        let settlementMethodsInDatabase = try! databaseService.getOfferSettlementMethods(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID))
        var expectedSettlementMethodsInDatabase: [String] = []
        for settlementMethod in offer.onChainSettlementMethods {
            expectedSettlementMethodsInDatabase.append(settlementMethod.base64EncodedString())
        }
        
        for (index, element) in expectedSettlementMethodsInDatabase.enumerated() {
            XCTAssertEqual(element, settlementMethodsInDatabase![index].0)
        }
        
        let offerStructOnChain = try! blockchainService.getOffer(id: offer.id)!
        XCTAssertTrue(offerStructOnChain.isCreated)
        XCTAssertFalse(offerStructOnChain.isTaken)
        #warning("TODO: check proper maker address once WalletService is implemented")
        XCTAssertEqual(offerStructOnChain.interfaceId, offer.interfaceId)
        XCTAssertEqual(offerStructOnChain.stablecoin, offer.stablecoin)
        XCTAssertEqual(offerStructOnChain.amountLowerBound, offer.amountLowerBound)
        XCTAssertEqual(offerStructOnChain.amountUpperBound, offer.amountUpperBound)
        XCTAssertEqual(offerStructOnChain.securityDepositAmount, offer.securityDepositAmount)
        XCTAssertEqual(offerStructOnChain.serviceFeeRate, offer.serviceFeeRate)
        XCTAssertEqual(offerStructOnChain.direction, offer.onChainDirection)
        XCTAssertEqual(offerStructOnChain.settlementMethods, offer.onChainSettlementMethods)
        XCTAssertEqual(offerStructOnChain.protocolVersion, offer.protocolVersion)
        #warning("TODO: re-enable this once we get accurate chain IDs")
        //XCTAssertEqual(offerStructOnChain.chainID, offerInTruthSource.chainID)
        
    }
    
    /**
     Ensures that `OfferService.createCancelOfferTransaction`, `OfferService.cancelOffer` and `BlockchainService.sendTransaction` function properly.
     */
    func testCancelOffer() {
        
        let offerID = UUID()
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_cancelOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString)
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt(10000),
            amountUpperBound: BigUInt(10000),
            securityDepositAmount: BigUInt(1000),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337), // Hardhat blockchain ID
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerInDatabaseBeforeCancellation = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(offerForDatabase, offerInDatabaseBeforeCancellation)
        
        let cancellationExpectation = XCTestExpectation(description: "Fulfilled when offerService.cancelOffer returns")
        
        offerService.createCancelOfferTransaction(offer: offer).then { transaction in
            return offerService.cancelOffer(offer: offer, offerCancellationTransaction: transaction)
        }.done {
            cancellationExpectation.fulfill()
        }.cauterize()
        
        wait(for: [cancellationExpectation], timeout: 30.0)
        
        XCTAssertEqual(offerTruthSource.offers[offerID]?.cancelingOfferState, .awaitingTransactionConfirmation)
        XCTAssertNotNil(offerTruthSource.offers[offerID]?.offerCancellationTransaction?.transactionHash)
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())!
        XCTAssertEqual(offerInDatabase.cancelingOfferState, "awaitingTransactionConfirmation")
        XCTAssertNotNil(offerInDatabase.offerCancellationTransactionHash)
        
        let offerStruct = try! blockchainService.getOffer(id: offerID)
        XCTAssertNil(offerStruct)
        
    }
    
    /**
     Ensures that `OfferService.createEditOfferTransaction`, `OfferService.editOffer` and `BlockchainService.editOffer` function properly.
     */
    func testEditOffer() {
        
        let offerID = UUID()
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_editOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString)
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerService.offerTruthSource = offerTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 2_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337), // Hardhat blockchain ID,
            havePublicKey: true,
            isUserMaker: true,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerInDatabaseBeforeEditing = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(offerForDatabase, offerInDatabaseBeforeEditing)
        
        let editingExpectation = XCTestExpectation(description: "Fulfilled when offerService.editOffer returns")
        
        offer.editingOfferState = .validating
        offerService.createEditOfferTransaction(offer: offer, newSettlementMethods: [SettlementMethod(currency: "USD", price: "1.23", method: "a_method", privateData: "some_private_data")]).then { transaction in
            return offerService.editOffer(offer: offer, newSettlementMethods: [SettlementMethod(currency: "USD", price: "1.23", method: "a_method", privateData: "some_private_data")], offerEditingTransaction: transaction)
        }.done {
            editingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [editingExpectation], timeout: 30.0)
        
        XCTAssertEqual(.awaitingTransactionConfirmation, offer.editingOfferState)
        XCTAssertNotNil(offer.offerEditingTransaction?.transactionHash)
        let expectedSettlementMethods = [
            try! JSONEncoder().encode(SettlementMethod(currency: "USD", price: "1.23", method: "a_method"))
        ]
        let offerInDatabase = try! databaseService.getOffer(id: offerID.asData().base64EncodedString())!
        XCTAssertEqual("awaitingTransactionConfirmation", offerInDatabase.editingOfferState)
        XCTAssertNotNil(offerInDatabase.offerEditingTransactionHash)
        let offerStruct = try! blockchainService.getOffer(id: offerID)
        XCTAssertEqual(expectedSettlementMethods, offerStruct?.settlementMethods)
        let pendingSettlementMethodsInDatabase = try! databaseService.getPendingOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: String(BigUInt(31337)))
        XCTAssertEqual(1, pendingSettlementMethodsInDatabase!.count)
        XCTAssertEqual(expectedSettlementMethods[0].base64EncodedString(), pendingSettlementMethodsInDatabase?[0].0)
        XCTAssertEqual("some_private_data", pendingSettlementMethodsInDatabase?[0].1)
        
    }
    
    /**
     Ensures that `OfferService.createApproveTokenTransferToTakeOfferTransaction`, `BlockchainService.createApproveTransferTransaction`, `OfferService.approveTokenTransferToTakeOffer`, `OfferService.createTakeOfferTransaction`, `BlockchainService.createTakeOfferTransaction`, `OfferService.openOffer`, and `BlockchainService.sendTransaction` function properly.
     */
    func testTakeOffer() {
        
        let offerID = UUID()
        
        let encodedSettlementMethod = try! JSONEncoder().encode(SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA"))
        
        struct TestingServerResponse: Decodable {
            let commutoSwapAddress: String
            let stablecoinAddress: String
        }
        
        let responseExpectation = XCTestExpectation(description: "Get response from testing server")
        var testingServerUrlComponents = URLComponents(string: "http://localhost:8546/test_offerservice_takeOffer")!
        testingServerUrlComponents.queryItems = [
            URLQueryItem(name: "events", value: "offer-opened"),
            URLQueryItem(name: "offerID", value: offerID.uuidString),
            URLQueryItem(name: "settlement_method_string", value: String(bytes: encodedSettlementMethod, encoding: .utf8)),
        ]
        var request = URLRequest(url: testingServerUrlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var testingServerResponse: TestingServerResponse? = nil
        var gotError = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                gotError = true
            } else if let data = data {
                testingServerResponse = try! JSONDecoder().decode(TestingServerResponse.self, from: data)
                responseExpectation.fulfill()
            } else {
                print(response!)
                gotError = true
            }
        }
        task.resume()
        wait(for: [responseExpectation], timeout: 60.0)
        XCTAssertTrue(!gotError)
        
        let w3 = web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!)
        
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        let offerService = OfferService<TestOfferTruthSource, TestSwapTruthSource>(
            databaseService: databaseService,
            keyManagerService: keyManagerService,
            swapService: TestSwapService()
        )
        
        let offerTruthSource = TestOfferTruthSource()
        offerTruthSource.serviceFeeRate = BigUInt(1)
        offerService.offerTruthSource = offerTruthSource
        
        let swapTruthSource = TestSwapTruthSource()
        offerService.swapTruthSource = swapTruthSource
        
        let errorHandler = TestBlockchainErrorHandler()
        
        let blockchainService = BlockchainService(
            errorHandler: errorHandler,
            offerService: offerService,
            swapService: TestSwapService(),
            web3Instance: w3,
            commutoSwapAddress: EthereumAddress(testingServerResponse!.commutoSwapAddress)!
        )
        offerService.blockchainService = blockchainService
        
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: offerID,
            maker: EthereumAddress("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress(testingServerResponse!.stablecoinAddress)!,
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 2_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337), // Hardhat blockchain ID,
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        offerTruthSource.offers[offerID] = offer
        let offerForDatabase = DatabaseOffer(
            id: offer.id.asData().base64EncodedString(),
            isCreated: offer.isCreated,
            isTaken: offer.isTaken,
            maker: offer.maker.addressData.toHexString(),
            interfaceId: offer.interfaceId.base64EncodedString(),
            stablecoin: offer.stablecoin.addressData.toHexString(),
            amountLowerBound: String(offer.amountLowerBound),
            amountUpperBound: String(offer.amountUpperBound),
            securityDepositAmount: String(offer.securityDepositAmount),
            serviceFeeRate: String(offer.serviceFeeRate),
            onChainDirection: String(offer.onChainDirection),
            protocolVersion: String(offer.protocolVersion),
            chainID: String(offer.chainID),
            havePublicKey: offer.havePublicKey,
            isUserMaker: offer.isUserMaker,
            state: offer.state.asString,
            approveToOpenState: offer.approvingToOpenState.asString,
            approveToOpenTransactionHash: nil,
            approveToOpenTransactionCreationTime: nil,
            approveToOpenTransactionCreationBlockNumber: nil,
            openingOfferState: offer.openingOfferState.asString,
            openingOfferTransactionHash: nil,
            openingOfferTransactionCreationTime: nil,
            openingOfferTransactionCreationBlockNumber: nil,
            cancelingOfferState: offer.cancelingOfferState.asString,
            offerCancellationTransactionHash: nil,
            offerCancellationTransactionCreationTime: nil,
            offerCancellationTransactionCreationBlockNumber: nil,
            editingOfferState: offer.editingOfferState.asString,
            offerEditingTransactionHash: nil,
            offerEditingTransactionCreationTime: nil,
            offerEditingTransactionCreationBlockNumber: nil,
            approveToTakeState: offer.approvingToTakeState.asString,
            approveToTakeTransactionHash: nil,
            approveToTakeTransactionCreationTime: nil,
            approveToTakeTransactionCreationBlockNumber: nil,
            takingOfferState: offer.takingOfferState.asString,
            takingOfferTransactionHash: nil,
            takingOfferTransactionCreationTime: nil,
            takingOfferTransactionCreationBlockNumber: nil
        )
        try! databaseService.storeOffer(offer: offerForDatabase)
        
        let offerInDatabaseBeforeTaking = try! databaseService.getOffer(id: offer.id.asData().base64EncodedString())
        XCTAssertEqual(offerForDatabase, offerInDatabaseBeforeTaking)
        
        let takingExpectation = XCTestExpectation(description: "Fulfilled when offerService.takeOffer returns")
        
        offerService.createApproveTokenTrasferToTakeOfferTransaction(
            offerToTake: offer,
            takenSwapAmount: NSNumber(15_000).decimalValue,
            makerSettlementMethod: SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: ""),
            takerSettlementMethod: SettlementMethod(
                currency: "EUR",
                price: "0.98",
                method: "SEPA",
                privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self)
            ),
            stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo
        ).then { transaction in
            offerService.approveTokenTransferToTakeOffer(
                offerToTake: offer,
                takenSwapAmount: NSNumber(15_000).decimalValue,
                makerSettlementMethod: SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: ""),
                takerSettlementMethod: SettlementMethod(
                    currency: "EUR",
                    price: "0.98",
                    method: "SEPA",
                    privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self)
                ),
                stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo,
                approveTokenTransferToTakeOfferTransaction: transaction
            )
        }.then { () -> Promise<(EthereumTransaction, KeyPair)> in
            // Since we aren't parsing new events, we have to set the offer's approving to take manually
            offer.approvingToTakeState = .completed
            return offerService.createTakeOfferTransaction(
                offerToTake: offer,
                takenSwapAmount: NSNumber(15_000).decimalValue,
                makerSettlementMethod: SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: ""),
                takerSettlementMethod: SettlementMethod(
                    currency: "EUR",
                    price: "0.98",
                    method: "SEPA",
                    privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self)
                ),
                stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo
            )
        }.then { transaction, keyPair in
            offerService.takeOffer(
                offerToTake: offer,
                takenSwapAmount: NSNumber(15_000).decimalValue,
                makerSettlementMethod: SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA", privateData: ""),
                takerSettlementMethod: SettlementMethod(
                    currency: "EUR",
                    price: "0.98",
                    method: "SEPA",
                    privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self)
                ),
                stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo,
                takerKeyPair: keyPair,
                offerTakingTransaction: transaction
            )
        }.done {
            takingExpectation.fulfill()
        }.cauterize()
        
        wait(for: [takingExpectation], timeout: 30.0)
        
        let swapOnChain = try! blockchainService.getSwap(id: offerID)!
        XCTAssertTrue(swapOnChain.isCreated)
        
        let keyPair = try! keyManagerService.getKeyPair(interfaceId: swapOnChain.takerInterfaceID)
        XCTAssertNotNil(keyPair)
        
        // Test the Swap in swapTruthSource
        let swapInTruthSource = swapTruthSource.swaps[offerID]!
        XCTAssertTrue(swapInTruthSource.isCreated)
        XCTAssertFalse(swapInTruthSource.requiresFill)
        XCTAssertEqual(offerID, swapInTruthSource.id)
        XCTAssertEqual(EthereumAddress("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")!, swapInTruthSource.maker)
        XCTAssertEqual(Data(), swapInTruthSource.makerInterfaceID)
        #warning("TODO: check taker address once walletService is implemented")
        XCTAssertEqual(swapInTruthSource.takerInterfaceID, swapOnChain.takerInterfaceID)
        XCTAssertEqual(EthereumAddress(testingServerResponse!.stablecoinAddress)!, swapInTruthSource.stablecoin)
        XCTAssertEqual(10_000 * BigUInt(10).power(18), swapInTruthSource.amountLowerBound)
        XCTAssertEqual(20_000 * BigUInt(10).power(18), swapInTruthSource.amountUpperBound)
        XCTAssertEqual(2_000 * BigUInt(10).power(18), swapInTruthSource.securityDepositAmount)
        XCTAssertEqual(15_000 * BigUInt(10).power(18), swapInTruthSource.takenSwapAmount)
        XCTAssertEqual(150 * BigUInt(10).power(18), swapInTruthSource.serviceFeeAmount)
        XCTAssertEqual(BigUInt(100), swapInTruthSource.serviceFeeRate)
        XCTAssertEqual(BigUInt(0), swapInTruthSource.onChainDirection)
        XCTAssertEqual(.buy, swapInTruthSource.direction)
        XCTAssertEqual(try! JSONEncoder().encode(SettlementMethod(currency: "EUR", price: "0.98", method: "SEPA")), swapInTruthSource.onChainSettlementMethod)
        XCTAssertEqual("EUR", swapInTruthSource.settlementMethod.currency)
        XCTAssertEqual("0.98", swapInTruthSource.settlementMethod.price)
        XCTAssertEqual("SEPA", swapInTruthSource.settlementMethod.method)
        XCTAssertEqual(
            String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self),
            swapInTruthSource.takerPrivateSettlementMethodData
        )
        XCTAssertEqual(BigUInt(1), swapInTruthSource.protocolVersion)
        XCTAssertFalse(swapInTruthSource.isPaymentSent)
        XCTAssertFalse(swapInTruthSource.isPaymentReceived)
        XCTAssertFalse(swapInTruthSource.hasBuyerClosed)
        XCTAssertFalse(swapInTruthSource.hasSellerClosed)
        XCTAssertEqual(BigUInt(0), swapInTruthSource.onChainDisputeRaiser)
        XCTAssertEqual(BigUInt(31337), swapInTruthSource.chainID)
        XCTAssertEqual(.takeOfferTransactionSent, swapInTruthSource.state)
        
        // Test the persistently stored swap
        let swapInDatabase = try! databaseService.getSwap(id: offerID.asData().base64EncodedString())!
        #warning("TODO: check proper taker address once WalletService is implemented")
        let expectedSwapInDatabase = DatabaseSwap(
            id: swapInTruthSource.id.asData().base64EncodedString(),
            isCreated: swapInTruthSource.isCreated,
            requiresFill: swapInTruthSource.requiresFill,
            maker: swapInTruthSource.maker.addressData.toHexString(),
            makerInterfaceID: swapInTruthSource.makerInterfaceID.base64EncodedString(),
            taker: swapInTruthSource.taker.addressData.toHexString(),
            takerInterfaceID: swapInTruthSource.takerInterfaceID.base64EncodedString(),
            stablecoin: swapInTruthSource.stablecoin.addressData.toHexString(),
            amountLowerBound: String(swapInTruthSource.amountLowerBound),
            amountUpperBound: String(swapInTruthSource.amountUpperBound),
            securityDepositAmount: String(swapInTruthSource.securityDepositAmount),
            takenSwapAmount: String(swapInTruthSource.takenSwapAmount),
            serviceFeeAmount: String(swapInTruthSource.serviceFeeAmount),
            serviceFeeRate: String(swapInTruthSource.serviceFeeRate),
            onChainDirection: String(swapInTruthSource.onChainDirection),
            onChainSettlementMethod: swapInTruthSource.onChainSettlementMethod.base64EncodedString(),
            makerPrivateSettlementMethodData: nil,
            takerPrivateSettlementMethodData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "account_holder", bic: "bic", iban: "iban", address: "address")), as: UTF8.self),
            protocolVersion: String(swapInTruthSource.protocolVersion),
            isPaymentSent: swapInTruthSource.isPaymentSent,
            isPaymentReceived: swapInTruthSource.isPaymentReceived,
            hasBuyerClosed: swapInTruthSource.hasBuyerClosed,
            hasSellerClosed: swapInTruthSource.hasSellerClosed,
            onChainDisputeRaiser: String(swapInTruthSource.onChainDisputeRaiser),
            chainID: String(swapInTruthSource.chainID),
            state: swapInTruthSource.state.asString,
            role: "takerAndSeller",
            approveToFillState: swapInTruthSource.approvingToFillState.asString,
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: swapInTruthSource.fillingSwapState.asString,
            fillingSwapTransactionHash: nil,
            fillingSwapTransactionCreationTime: nil,
            fillingSwapTransactionCreationBlockNumber: nil,
            reportPaymentSentState: swapInTruthSource.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: swapInTruthSource.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: swapInTruthSource.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
        )
        XCTAssertEqual(expectedSwapInDatabase, swapInDatabase)
        
        XCTAssertEqual(.awaitingTransactionConfirmation, offer.takingOfferState)
    }
    
}
