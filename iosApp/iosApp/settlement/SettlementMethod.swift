//
//  SettlementMethod.swift
//  iosApp
//
//  Created by jimmyt on 7/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A settlement method specified by the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) by which they are willing to send/receive payment
 */
struct SettlementMethod: Codable, Equatable, Identifiable {
    /**
     The currency in which the maker is willing to send/receive payment.
     */
    let currency: String
    /**
     The amount of the currency specified in `currency` that the maker is willing to exchange for one stablecoin unit.
     */
    var price: String
    /**
     The method by which the currency specified in `currency` will be transferred from the stablecoin buyer to the stablecoin seller.
     */
    let method: String
    /**
     An ID that uniquely identifies this settlement method, so it can be consumed by SwiftUI's `ForEach`.
     */
    var id: String = UUID().uuidString
    /**
     This `SettlementMethod` as encoded to UTF-8 bytes, or `nil` if this settlement method cannot be encoded.
     */
    var onChainData: Data? {
        try? JSONEncoder().encode(self)
    }
    /**
     The private data associated with this settlement method, such as an address or bank account number of the settlement method's owner.
     */
    var privateData: String? = nil
    
    /**
     Specifies the JSON keys for `SettlementMethod` properties as specified in the [whitepaper](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt)
     */
    enum CodingKeys: String, CodingKey {
        case currency = "f"
        case price = "p"
        case method = "m"
    }
    
}

extension SettlementMethod {
    
    static let sampleSettlementMethods: [SettlementMethod] = [
        SettlementMethod(currency: "EUR", price: "0.94", method: "SEPA", privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "Proper Name", bic: "A BIC", iban: "An IBAN", address: "An Address")), as: UTF8.self)),
        SettlementMethod(currency: "USD", price: "1.00", method: "SWIFT", privateData: String(decoding: try! JSONEncoder().encode(PrivateSWIFTData(accountHolder: "Proper Name", bic: "A BIC", accountNumber: "An Account Number")), as: UTF8.self)),
        SettlementMethod(currency: "BUSD", price: "1.00", method: "SANDDOLLAR", privateData: "Some SANDDOLLAR data"),
    ]
    
    static let sampleSettlementMethodsEmptyPrices: [SettlementMethod] = [
        SettlementMethod(currency: "EUR", price: "", method: "SEPA", privateData: String(decoding: try! JSONEncoder().encode(PrivateSEPAData(accountHolder: "Proper Name", bic: "A BIC", iban: "An IBAN", address: "An Address")), as: UTF8.self)),
        SettlementMethod(currency: "USD", price: "", method: "SWIFT", privateData: "Some SWIFT data"),
        SettlementMethod(currency: "BUSD", price: "", method: "SANDDOLLAR", privateData: "Some SANDDOLLAR data"),
    ]
    
}
