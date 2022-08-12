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
     Indicates whether we are currently opening an offer, and if so, the point of the [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) we are currently in.
     */
    var openingOfferState: OpeningOfferState = .none

    /**
     The `Error` that occured during the offer creation process, or `nil` if no such error has occured.
     */
    var openingOfferError: Error?
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createOffer(chainID: BigUInt, stablecoin: EthereumAddress?, stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, securityDepositAmount: Decimal, direction: OfferDirection, settlementMethods: [SettlementMethod]) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func openOffer(chainID: BigUInt, stablecoin: EthereumAddress?, stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, securityDepositAmount: Decimal, direction: OfferDirection, settlementMethods: [SettlementMethod]) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func cancelOffer(_ offer: Offer) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod]) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func takeOffer(offer: Offer, takenSwapAmount: Decimal, settlementMethod: SettlementMethod?) {}
    
}
