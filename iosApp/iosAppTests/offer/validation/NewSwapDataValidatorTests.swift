//
//  NewSwapDataValidatorTests.swift
//  iosAppTests
//
//  Created by jimmyt on 8/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift
import XCTest

@testable import iosApp

class NewSwapDataValidatorTests: XCTestCase {
    /**
     Ensures that `validateNewSwapData` validates swap data properly.
     */
    func testValidateNewSwapData() throws {
        let makerSettlementMethod = SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", id: UUID().uuidString, privateData: String(decoding: try! JSONEncoder().encode(PrivateSWIFTData(accountHolder: "account_holder", bic: "bic", accountNumber: "account_number")), as: UTF8.self))
        let takerSettlementMethod = SettlementMethod(currency: "USD", price: "", method: "SWIFT", id: UUID().uuidString, privateData: String(decoding: try! JSONEncoder().encode(PrivateSWIFTData(accountHolder: "account_holder", bic: "bic", accountNumber: "account_number")), as: UTF8.self))
        let offer = Offer(
            isCreated: true,
            isTaken: false,
            id: UUID(),
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceID: Data(),
            stablecoin: EthereumAddress("0x8438Ad1C834623CfF278AB6829a248E37C2D7E3f")!, // BUSD on Hardhat,
            amountLowerBound: 10 * BigUInt(10).power(18),
            amountUpperBound: 20 * BigUInt(10).power(18),
            securityDepositAmount: 2 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [makerSettlementMethod],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        let validatedData = try validateNewSwapData(
            offer: offer,
            takenSwapAmount: NSNumber(floatLiteral: 15).decimalValue,
            selectedMakerSettlementMethod: makerSettlementMethod,
            selectedTakerSettlementMethod: takerSettlementMethod,
            stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo
        )
        let expectedValidatedData = ValidatedNewSwapData(
            takenSwapAmount: 15 * BigUInt(10).power(18),
            makerSettlementMethod: makerSettlementMethod,
            takerSettlementMethod: takerSettlementMethod
        )
        XCTAssertEqual(expectedValidatedData.takenSwapAmount, validatedData.takenSwapAmount)
        
        XCTAssertEqual(expectedValidatedData.makerSettlementMethod.currency, validatedData.makerSettlementMethod.currency)
        XCTAssertEqual(expectedValidatedData.makerSettlementMethod.price, validatedData.makerSettlementMethod.price)
        XCTAssertEqual(expectedValidatedData.makerSettlementMethod.method, validatedData.makerSettlementMethod.method)
        
        XCTAssertEqual(expectedValidatedData.takerSettlementMethod.currency, validatedData.takerSettlementMethod.currency)
        XCTAssertEqual(expectedValidatedData.takerSettlementMethod.method, validatedData.takerSettlementMethod.method)
    }
}
