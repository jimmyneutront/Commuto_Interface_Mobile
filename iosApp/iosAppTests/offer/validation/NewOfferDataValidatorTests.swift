//
//  NewOfferDataValidatorTests.swift
//  iosAppTests
//
//  Created by jimmyt on 7/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift
import XCTest

@testable import iosApp

/**
 Tests for functions in NewOfferDataValidator
 */
class NewOfferDataValidatorTests: XCTestCase {
    /**
     Ensures that `validateNewOfferData` validates offer data properly.
     */
    func testValidateNewOfferData() throws {
        let settlementMethod = SettlementMethod(currency: "a_currency", price: "a_price", method: "a_settlement_method")
        let validatedData = try! validateNewOfferData(
            chainID: BigUInt.zero,
            stablecoin: EthereumAddress("0x6B175474E89094C44Da98b954EedeAC495271d0F")!,
            stablecoinInformation: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
            minimumAmount: NSNumber(floatLiteral: 100.0).decimalValue,
            maximumAmount: NSNumber(floatLiteral: 200.0).decimalValue,
            securityDepositAmount: NSNumber(floatLiteral: 20.0).decimalValue,
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            settlementMethods: [
                settlementMethod
            ]
        )
        let expectedValidatedData = ValidatedNewOfferData(
            stablecoin: EthereumAddress("0x6B175474E89094C44Da98b954EedeAC495271d0F")!,
            stablecoinInformation: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
            minimumAmount: BigUInt("100000000000000000000"),
            maximumAmount: BigUInt("200000000000000000000"),
            securityDepositAmount: BigUInt("20000000000000000000"),
            serviceFeeRate: BigUInt("100"),
            serviceFeeAmountLowerBound: BigUInt("1000000000000000000"),
            serviceFeeAmountUpperBound: BigUInt("2000000000000000000"),
            direction: .buy,
            settlementMethods: [
                settlementMethod
            ]
        )
        XCTAssertEqual(validatedData, expectedValidatedData)
    }
    
    /**
     Ensures that `validateNewOfferData` validates offer data properly when the service fee rate is zero.
     */
    func testValidateNewOfferDataZeroServiceFee() throws {
        let settlementMethod = SettlementMethod(currency: "a_currency", price: "a_price", method: "a_settlement_method")
        let validatedData = try! validateNewOfferData(
            chainID: BigUInt.zero,
            stablecoin: EthereumAddress("0x6B175474E89094C44Da98b954EedeAC495271d0F")!,
            stablecoinInformation: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
            minimumAmount: NSNumber(floatLiteral: 100.0).decimalValue,
            maximumAmount: NSNumber(floatLiteral: 200.0).decimalValue,
            securityDepositAmount: NSNumber(floatLiteral: 20.0).decimalValue,
            serviceFeeRate: BigUInt.zero,
            direction: .buy,
            settlementMethods: [
                settlementMethod
            ]
        )
        let expectedValidatedData = ValidatedNewOfferData(
            stablecoin: EthereumAddress("0x6B175474E89094C44Da98b954EedeAC495271d0F")!,
            stablecoinInformation: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
            minimumAmount: BigUInt("100000000000000000000"),
            maximumAmount: BigUInt("200000000000000000000"),
            securityDepositAmount: BigUInt("20000000000000000000"),
            serviceFeeRate: BigUInt.zero,
            serviceFeeAmountLowerBound: BigUInt.zero,
            serviceFeeAmountUpperBound: BigUInt.zero,
            direction: .buy,
            settlementMethods: [
                settlementMethod
            ]
        )
        XCTAssertEqual(validatedData, expectedValidatedData)
    }
    
    /**
     Ensures that `stablecoinAmountToBaseUnits` converts amounts properly.
     */
    func testStablecoinAmountToBaseUnits() throws {
        // Ensure we can't convert negative values
        do {
            _ = try stablecoinAmountToBaseUnits(
                amount: NSNumber(floatLiteral: -123.456789).decimalValue,
                stablecoinInformation: StablecoinInformation(currencyCode: "a_currency_code", name: "a_name", decimal: 0)
            )
            XCTFail("The call above should have thrown a NewOfferDataValidationError")
        } catch let error as NewOfferDataValidationError {
            XCTAssertEqual(error.errorDescription, "Stablecoin amount must be positive.")
        } catch {
            throw error
        }
        // Ensure we can't convert zero values
        do {
            _ = try stablecoinAmountToBaseUnits(
                amount: NSNumber(floatLiteral: 0.0).decimalValue,
                stablecoinInformation: StablecoinInformation(currencyCode: "a_currency_code", name: "a_name", decimal: 0)
            )
            XCTFail("The call above should have thrown a NewOfferDataValidationError")
        } catch let error as NewOfferDataValidationError {
            XCTAssertEqual(error.errorDescription, "Stablecoin amount must be positive.")
        } catch {
            throw error
        }
        // Ensure we can't have more than six decimal places
        do {
            _ = try stablecoinAmountToBaseUnits(
                amount: NSNumber(floatLiteral: 1.2345678).decimalValue,
                stablecoinInformation: StablecoinInformation(currencyCode: "a_currency_code", name: "a_name", decimal: 0)
            )
            XCTFail("The call above should have thrown a NewOfferDataValidationError")
        } catch let error as NewOfferDataValidationError {
            XCTAssertEqual(error.errorDescription, "Stablecoin amount must have no more than six decimal places.")
        } catch {
            throw error
        }
        // Ensure that amounts are correctly converted with the number of decimal places in the amount value is greater than the decimal count of the stablecoin
        XCTAssertEqual(
            try! stablecoinAmountToBaseUnits(
                amount: NSNumber(floatLiteral: 1.234).decimalValue,
                stablecoinInformation: StablecoinInformation(currencyCode: "a_currency_code", name: "a_name", decimal: 2)
            ),
            BigUInt(123)
        )
        // Ensure that amounts are correctly converted with the number of decimal places in the amount value is less than the decimal count of the stablecoin
        XCTAssertEqual(
            try! stablecoinAmountToBaseUnits(
                amount: NSNumber(floatLiteral: 1.234).decimalValue,
                stablecoinInformation: StablecoinInformation(currencyCode: "a_currency_code", name: "a_name", decimal: 6)
            ),
            BigUInt(1_234_000)
        )
    }
    
}
