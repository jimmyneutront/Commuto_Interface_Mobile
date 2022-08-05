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
import web3swift

/**
 The Offers View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class OffersViewModel: UIOfferTruthSource {
    
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
     Indicates whether we are currently opening an offer, and if so, the point of the [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) we are currently in.
     */
    @Published var openingOfferState = OpeningOfferState.none
    
    /**
     The `Error` that occured during the offer creation process, or `nil` if no such error has occured.
     */
    var openingOfferError: Error? = nil
    
    /**
     Sets `openingOfferState` on the main DispatchQueue.
     
     - Parameter state: The new value to which `openingOfferState` will be set.
     */
    func setOpeningOfferState(state: OpeningOfferState) {
        DispatchQueue.main.async {
            self.openingOfferState = state
        }
    }
    
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
    
    /**
     Attempts to open a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     First, this validates the data for the new offer using `validateNewOfferData`, and then passes the validated data to `offerService.openOffer`. This also passes several closures to `offerService.openOffer`, which will call `setOpeningOfferState` with the current state of the offer opening process.
     
     - Parameters:
        - chainID: The ID of the blockchain on which the offer will be created.
        - stablecoin: The contract address of the stablecoin for which the offer will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which the offer will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer.
        - maximumAmount: The maximum `Decimal` amount of the new offer.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer.
        - direction: The direction of the new offer.
        - settlementMethods: The settlement methods of the new offer.
     
     - Throws: A `NewOfferDataValidationError` if this is unable to get the current service fee rate. Note that this offer aren't thrown, but is instead passed to  `seal.reject`.
     */
    func openOffer(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod]
    ) {
        Promise<ValidatedNewOfferData> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("openOffer: validating new offer data")
                setOpeningOfferState(state: .validating)
                guard let serviceFeeRateForOffer = serviceFeeRate else {
                    seal.reject(NewOfferDataValidationError(desc: "Unable to determine service fee rate"))
                    return
                }
                do {
                    let validatedOfferData = try validateNewOfferData(
                        chainID: chainID,
                        stablecoin: stablecoin,
                        stablecoinInformation: stablecoinInformation,
                        minimumAmount: minimumAmount,
                        maximumAmount: maximumAmount,
                        securityDepositAmount: securityDepositAmount,
                        serviceFeeRate: serviceFeeRateForOffer,
                        direction: direction,
                        settlementMethods: settlementMethods
                    )
                    seal.fulfill(validatedOfferData)
                } catch {
                    seal.reject(error)
                }
            }
        }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] validatedNewOfferData -> Promise<Void> in
            logger.notice("openOffer: opening new offer with validated data")
            setOpeningOfferState(state: .creating)
            return offerService.openOffer(
                offerData: validatedNewOfferData,
                afterObjectCreation: { self.setOpeningOfferState(state: .storing) },
                afterPersistentStorage: { self.setOpeningOfferState(state: .approving) },
                afterTransferApproval: { self.setOpeningOfferState(state: .opening) }
            )
        }.done { [self] _ in
            logger.notice("openOffer: successfully opened offer")
            setOpeningOfferState(state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("openOffer: got error during openOffer call. Error: \(error.localizedDescription)")
            openingOfferError = error
            setOpeningOfferState(state: .error)
        }
    }
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     This passes the offer ID to `offerService.cancelOffer`.
     
     - Parameter offer: The `Offer` to be canceled.
     */
    func cancelOffer(_ offer: Offer) {
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("cancelOffer: canceling offer \(offer.id.uuidString)")
                offerService.cancelOffer(offerID: offer.id, chainID: offer.chainID).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
            self.logger.notice("cancelOffer: successfully canceled offer \(offer.id.uuidString)")
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
            self.logger.error("cancelOffer: got error during cancelOffer call")
        }
    }
    
}
