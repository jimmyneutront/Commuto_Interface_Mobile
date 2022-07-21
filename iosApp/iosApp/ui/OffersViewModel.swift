//
//  OffersViewModel.swift
//  iosApp
//
//  Created by jimmyt on 5/31/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import os
import PromiseKit

/**
 The Offers View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class OffersViewModel: OfferTruthSource {
    
    /**
     Initializes a new `OffersViewModel`.
     
     - Parameter offerService: An `OfferService` that adds and removes `Offer`s from this class's `offers` dictionary as offers are created, canceled and taken.
     */
    init(offerService: OfferService<OffersViewModel>) {
        self.offerService = offerService
        offers = Offer.sampleOffers
    }
    
    /**
     OfferersViewModel's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "OffersViewModel")
    
    /**
     The `OfferService` responsible for adding and removing `Offer`s from this class's `offers` dictionary as offers are created, canceled and taken.
     */
    let offerService: OfferService<OffersViewModel>
    
    /**
     The current service fee rate, or `nil` if the current service fee rate is not known.
     */
    @Published var serviceFeeRate: BigUInt?
    
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    @Published var offers: [UUID: Offer]
    
    /**
     Indicates whether this is currently getting the current service fee rate.
     */
    @Published var isGettingServiceFeeRate: Bool = false
    
    /**
     Gets the current service fee rate via `offerService` on  the global DispatchQueue and sets `serviceFeeRate` equal to the result on the main DispatchQueue.
     */
    func updateServiceFeeRate() {
        isGettingServiceFeeRate = true
        Promise<BigUInt> { seal in
            DispatchQueue.global(qos: .userInitiated).async {
                self.logger.notice("getServiceFeeRate: getting service fee rate")
                self.offerService.getServiceFeeRate().pipe(to: seal.resolve)
            }
        }.done { serviceFeeRate in
            self.serviceFeeRate = serviceFeeRate
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
            self.logger.error("getServiceFeeRate: got error during getServiceFeeRate call. Error: \(error.localizedDescription)")
        }.finally {
            after(seconds: 0.7).done { self.isGettingServiceFeeRate = false }
        }
    }
    
}
