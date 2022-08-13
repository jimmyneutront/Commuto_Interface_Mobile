//
//  OfferTests.swift
//  iosAppTests
//
//  Created by jimmyt on 8/13/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift
import XCTest

@testable import iosApp

class OfferTests: XCTestCase {
    
    /**
     Ensures that `Offer.updateSettlementMethods` updates `Offer.settlementMethods` and `Offer.onChainSettlementMethods` properly.
     */
    func testUpdateSettlementMethods() {
        let settlementMethod = SettlementMethod(
            currency: "EUR",
            price: "0.98",
            method: "SEPA"
        )
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: UUID(),
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x663F3ad617193148711d28f5334eE4Ed07016602")!, // DAI on Hardhat,
            amountLowerBound: BigUInt(1),
            amountUpperBound: BigUInt(1),
            securityDepositAmount: BigUInt(1),
            serviceFeeRate: BigUInt(1),
            direction: .buy,
            settlementMethods: [settlementMethod],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(1),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        let newSettlementMethod = SettlementMethod(
            currency: "USD",
            price: "1.00",
            method: "SWIFT"
        )
        try! offer.updateSettlementMethods(settlementMethods: [newSettlementMethod])
        XCTAssertEqual(offer.settlementMethods.count, 1)
        XCTAssertEqual(offer.settlementMethods[0], newSettlementMethod)
        XCTAssertEqual(offer.onChainSettlementMethods.count, 1)
        XCTAssertEqual(offer.onChainSettlementMethods[0], try! JSONEncoder().encode(newSettlementMethod))
    }
    
    /**
     Ensures that `Offer.updateSettlementMethodsFromChain` updates `Offer.settlementMethods` and `Offer.onChainSettlementMethods` properly.
     */
    func testUpdateSettlementMethodsFromChain() {
        let settlementMethod = SettlementMethod(
            currency: "EUR",
            price: "0.98",
            method: "SEPA"
        )
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: UUID(),
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x663F3ad617193148711d28f5334eE4Ed07016602")!, // DAI on Hardhat,
            amountLowerBound: BigUInt(1),
            amountUpperBound: BigUInt(1),
            securityDepositAmount: BigUInt(1),
            serviceFeeRate: BigUInt(1),
            direction: .buy,
            settlementMethods: [settlementMethod],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(1),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        let newSettlementMethod = SettlementMethod(
            currency: "USD",
            price: "1.00",
            method: "SWIFT"
        )
        try! offer.updateSettlementMethodsFromChain(onChainSettlementMethods: [JSONEncoder().encode(newSettlementMethod)])
        XCTAssertEqual(offer.settlementMethods.count, 1)
        XCTAssertEqual(offer.settlementMethods[0].currency, newSettlementMethod.currency)
        XCTAssertEqual(offer.settlementMethods[0].price, newSettlementMethod.price)
        XCTAssertEqual(offer.settlementMethods[0].method, newSettlementMethod.method)
        XCTAssertEqual(offer.onChainSettlementMethods.count, 1)
        XCTAssertEqual(offer.onChainSettlementMethods[0], try! JSONEncoder().encode(newSettlementMethod))
    }
    
}
