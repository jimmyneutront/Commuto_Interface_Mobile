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
struct SettlementMethod: Identifiable, Decodable {
    /**
     The currency in which the maker is willing to send/receive payment.
     */
    let currency: String
    /**
     The amount of the currency specified in `currency` that the maker is willing to exchange for one stablecoin unit.
     */
    let price: String
    /**
     The method by which the currency specified in `currency` will be transferred from the stablecoin buyer to the stablecoin seller.
     */
    let method: String
    /**
     An ID that uniquely identifies this settlement method, so it can be consumed by SwiftUI's `ForEach`.
     */
    var id: String = UUID().uuidString
    
    /**
     Specifies the JSON keys for `SettlementMethod` properties as specified in the [whitepaper](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt)
     */
    enum CodingKeys: String, CodingKey {
        case currency = "f"
        case price = "p"
        case method = "m"
    }
    
}
