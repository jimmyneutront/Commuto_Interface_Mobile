//
//  TestOfferMessageNotifiable.swift
//  iosAppTests
//
//  Created by jimmyt on 8/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

@testable import iosApp

/**
 A basic `OfferMessageNotifiable` implementation used to satisfy `P2PService`'s offerService dependency for testing non-offer-related code.
 */
class TestOfferMessageNotifiable: OfferMessageNotifiable {
    /**
     Does nothing, required to adopt `OfferMessageNotifiable`. Should not be used.
     */
    func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) throws {}
}
