//
//  PreviewableOfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 7/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 A `UIOfferTruthSource` implementation used for previewing user interfaces.
 */
class PreviewableOfferTruthSource: UIOfferTruthSource {
    /**
     Initializes a new `PreviewableOfferTruthSource` with sample offers.
     */
    init() {
        offers = Offer.sampleOffers
    }
    
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    @Published var offers: [UUID : Offer]
    
    /**
     The current service fee rate, or `nil` if the current service fee rate is not known.
     */
    @Published var serviceFeeRate: BigUInt?
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    var isGettingServiceFeeRate: Bool = false
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func updateServiceFeeRate() {}
    
    /**
     Not used since this class is for previewing usser interfaces, but required for adoption of `UIOfferTruthSource`
     */
    func createOffer(chainID: BigUInt, stablecoin: EthereumAddress?, stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, securityDepositAmount: Decimal, direction: OfferDirection, settlementMethods: [SettlementMethod]) {}
    
}
