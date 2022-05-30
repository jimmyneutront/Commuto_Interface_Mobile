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
    static let sampleOffers: [Offer] =
    [
        Offer(id: UUID(), direction: "Buy", price: "1.004", pair: "USD/USDT"),
        Offer(id: UUID(), direction: "Sell", price: "1.002", pair: "GBP/USDC"),
        Offer(id: UUID(), direction: "Sell", price: "0.997", pair: "PLN/LUSD"),
    ]
}
