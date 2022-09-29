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
        let settlementMethod = SettlementMethod(currency: "a_currency", price: "a_price", method: "a_settlement_method", privateData: "some_private_data")
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
            settlementMethods: [settlementMethod],
            protocolVersion: BigUInt(1),
            chainID: BigUInt(31337),
            havePublicKey: true,
            isUserMaker: false,
            state: .offerOpened
        )
        let validatedData = try validateNewSwapData(
            offer: offer,
            takenSwapAmount: NSNumber(floatLiteral: 15).decimalValue,
            selectedSettlementMethod: settlementMethod,
            stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo
        )
        let expectedValidatedData = ValidatedNewSwapData(
            takenSwapAmount: 15 * BigUInt(10).power(18),
            settlementMethod: settlementMethod
        )
        XCTAssertEqual(expectedValidatedData.takenSwapAmount, validatedData.takenSwapAmount)
        XCTAssertEqual(expectedValidatedData.settlementMethod.currency, validatedData.settlementMethod.currency)
        XCTAssertEqual(expectedValidatedData.settlementMethod.price, validatedData.settlementMethod.price)
        XCTAssertEqual(expectedValidatedData.settlementMethod.method, validatedData.settlementMethod.method)
    }
}
