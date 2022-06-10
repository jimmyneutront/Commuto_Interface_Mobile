//
//  Offer.swift
//  iosApp
//
//  Created by jimmyt on 5/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

struct Offer {
    var id: UUID
    var direction: String
    var price: String
    var pair: String
}

extension Offer {
    static let sampleOfferIds = [
        UUID(),
        UUID(),
        UUID()
    ]
    static let sampleOffers: [UUID: Offer] = [
        sampleOfferIds[0]: Offer(id: sampleOfferIds[0], direction: "Buy", price: "1.004", pair: "USD/USDT"),
        sampleOfferIds[1]: Offer(id: sampleOfferIds[1], direction: "Buy", price: "1.004", pair: "USD/USDT"),
        sampleOfferIds[2]: Offer(id: sampleOfferIds[2], direction: "Buy", price: "1.004", pair: "USD/USDT"),
    ]
}

extension UUID {
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
