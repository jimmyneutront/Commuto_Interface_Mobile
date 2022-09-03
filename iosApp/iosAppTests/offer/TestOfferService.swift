//
//  TestOfferService.swift
//  iosAppTests
//
//  Created by jimmyt on 9/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

@testable import iosApp

/**
 A basic `OfferNotifiable` implementation used to satisfy `OfferService`'s `offerService` dependency for testing non-offer-related code.
 */
class TestOfferService: OfferNotifiable {
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {}
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleOfferEditedEvent(_ event: OfferEditedEvent) {}
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {}
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) {}
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) {}
}
