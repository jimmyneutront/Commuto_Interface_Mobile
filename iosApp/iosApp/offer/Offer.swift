//
//  Offer.swift
//  iosApp
//
//  Created by jimmyt on 5/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 Represents an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct Offer {
    /**
     The ID that uniquely identifies the offer, as a `UUID`.
     */
    var id: UUID
    /**
     The direction of the offer, indicating whether the maker is offering to buy stablecoin or sell stablecoin.
     */
    var direction: String
    /**
     The price at which the maker is offering to buy/sell stablecoin, as the cost in FIAT per one STBL.
     */
    var price: String
    /**
     A string of the form "FIAT/STBL", where FIAT is the abbreviation of the fiat currency being exchanged, and STBL is the ticker symbol of the stablecoin being exchanged.
     */
    var pair: String
}

/**
 Contains a list of sample offer IDs (as `UUID`s) and a dictionary mapping those `UUID`s to `Offer`s. Used for previewing offer-related `View`s.
 */
extension Offer {
    /**
     A list of `UUID`s used for previewing offer-related `View`s
     */
    static let sampleOfferIds = [
        UUID(),
        UUID(),
        UUID()
    ]
    /**
     A dictionary mapping the contents of `sampleOfferIds` to `Offer`s. Used for previewing offer-related `View`s.
     */
    static let sampleOffers: [UUID: Offer] = [
        sampleOfferIds[0]: Offer(id: sampleOfferIds[0], direction: "Buy", price: "1.004", pair: "USD/USDT"),
        sampleOfferIds[1]: Offer(id: sampleOfferIds[1], direction: "Buy", price: "1.004", pair: "USD/USDT"),
        sampleOfferIds[2]: Offer(id: sampleOfferIds[2], direction: "Buy", price: "1.004", pair: "USD/USDT"),
    ]
}

/**
 Allows the creation of a `UUID` from raw bytes as `Data`. Used to create offer IDs as `UUID`s from the raw bytes retrieved from [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) calls.
 */
extension UUID {
    /**
     Attempts to create a UUID given raw bytes as `Data`.
     
     - Parameter data: The UUID as `Data?`.
     
     - Returns: A `UUID` if one could be successfully created from the given `Data?`, or `nil` otherwise.
     */
    static func from(data: Data?) -> UUID? {
        guard data?.count == MemoryLayout<uuid_t>.size else {
            return nil
        }
        return data?.withUnsafeBytes{
            guard let baseAddress = $0.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }
            return NSUUID(uuidBytes: baseAddress) as UUID
        }
    }
}
