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
    init(offerService: OfferService<OffersViewModel, SwapViewModel>) {
        self.offerService = offerService
        offers = Offer.sampleOffers
    }
    
    /**
     `OffersViewModel`'s `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "OffersViewModel")
    
    /**
     The `OfferService` responsible for adding and removing `Offer`s from this class's `offers` dictionary as offers are created, canceled and taken.
     */
    let offerService: OfferService<OffersViewModel, SwapViewModel>
    
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
     Sets `openingOfferState` on the main `DispatchQueue`.
     
     - Parameter state: The new value to which `openingOfferState` will be set.
     */
    private func setOpeningOfferState(state: OpeningOfferState) {
        DispatchQueue.main.async {
            self.openingOfferState = state
        }
    }
    
    #warning("TODO: Remove this once old cancelOffer method is removed")
    /**
     Sets the `cancelingOfferState` property of the `Offer` in `offers` with the specified `offerID` on the main `DispatchQueue`.
     
     - Parameters:
        - offerID: The ID of the `Offer` of which to set the `cancelingOfferState`.
        - state: The value to which the `Offer`'s `cancelingOfferState` will be set.
     */
    private func setCancelingOfferState(offerID: UUID, state: CancelingOfferState) {
        DispatchQueue.main.async {
            self.offers[offerID]?.cancelingOfferState = state
        }
    }
    
    #warning("TODO: Remove this once old editOffer method is removed")
    /**
     Sets the `editingOfferState` property of the `Offer` in `offers` with the specified `offerID` on the main `DispatchQueue`.
     
     - Parameters:
        - offerID: The ID of the `Offer` of which to set the `editingOfferState`.
        - state: The value to which the `Offer`'s `editingOfferState` will be set.
     */
    private func setEditingOfferState(offerID: UUID, state: EditingOfferState) {
        DispatchQueue.main.async {
            self.offers[offerID]?.editingOfferState = state
        }
    }
    
    /**
     Sets the `takingOfferState` property of the `Offer` in `offers` with the specified `offerID` on the main `DispatchQueue`.
     
     - Parameters:
        - offerID: The ID of the `Offer` of which to set the `takingOfferState`.
        - state: The value to which the `Offer`'s `takingOfferState` will be set.
     */
    private func setTakingOfferState(offerID: UUID, state: TakingOfferState) {
        DispatchQueue.main.async {
            self.offers[offerID]?.takingOfferState = state
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
     
     - Throws: An `OfferDataValidationError` if this is unable to get the current service fee rate. Note that this offer aren't thrown, but is instead passed to  `seal.reject`.
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
        setOpeningOfferState(state: .validating)
        Promise<ValidatedNewOfferData> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("openOffer: validating new offer data")
                guard let serviceFeeRateForOffer = serviceFeeRate else {
                    seal.reject(OfferDataValidationError(desc: "Unable to determine service fee rate"))
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
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
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
    @available(*, deprecated, message: "Use cancelOffer with new transaction pipeline")
    func cancelOffer(_ offer: Offer) {
        offer.cancelingOfferError = nil
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("cancelOffer: canceling offer \(offer.id.uuidString)")
                offerService.cancelOffer(offerID: offer.id, chainID: offer.chainID).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
            logger.notice("cancelOffer: successfully canceled offer \(offer.id.uuidString)")
            setCancelingOfferState(offerID: offer.id, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("cancelOffer: got error during cancelOffer call for \(offer.id.uuidString). Error: \(error.localizedDescription)")
            offer.cancelingOfferError = error
            setCancelingOfferState(offerID: offer.id, state: .error)
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` to cancel `offer`, which should be made by the user of this interface.
     
     This passes `offer` to `OfferService.createCancelOfferTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - offer: The `Offer` to be canceled.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createCancelOfferTransaction(
        offer: Offer,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createCancelOfferTransaction: creating for \(offer.id.uuidString)")
                offerService.createCancelOfferTransaction(offer: offer).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     This clears the offer-canceling-related `Error` of `offer` and sets `offer`'s `Offer.cancelingOfferState` to `CancelingOfferState.validating`, and then passes all data to `offerService`'s `OfferService.cancelOffer` function.
     
     - Parameters:
        - offer: The `Offer` to be canceled.
        - offerCancellationTransaction: An optional `EthereumTransaction` that can cancel `offer`.
     */
    func cancelOffer(offer: Offer, offerCancellationTransaction: EthereumTransaction?) {
        offer.cancelingOfferError = nil
        offer.cancelingOfferState = .validating
        DispatchQueue.global(qos: .userInitiated).sync {
            logger.notice("cancelOffer: canceling offer \(offer.id.uuidString)")
        }
        offerService.cancelOffer(offer: offer, offerCancellationTransaction: offerCancellationTransaction)
            .done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("cancelOffer: successfully broadcast transaction for \(offer.id.uuidString)")
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("cancelOffer: got error during cancelOffer call for \(offer.id.uuidString). Error: \(error.localizedDescription)")
                DispatchQueue.main.sync {
                    offer.cancelingOfferError = error
                    offer.cancelingOfferState = .error
                }
            }
    }
    
    /**
     Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     This validates `newSettlementMethods`, passes the offer ID and validated settlement methods to `offerService.editOffer`, and then clears `offer.selectedSettlementMethods`
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: An `Array` of `SettlementMethod`s with which the `Offer` will be edited.
     */
    func editOffer(
        offer: Offer,
        newSettlementMethods: [SettlementMethod]
    ) {
        //setEditingOfferState(offerID: offer.id, state: .editing)
        Promise<Array<SettlementMethod>> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("editOffer: editing \(offer.id.uuidString)")
                offer.editingOfferError = nil
                logger.notice("editOffer: validating edited settlement methods for \(offer.id.uuidString)")
                do {
                    let validatedSettlementMethods = try validateSettlementMethods(newSettlementMethods)
                    seal.fulfill(validatedSettlementMethods)
                } catch {
                    seal.reject(error)
                }
            }
        }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] validatedSettlementMethods -> Promise<Void> in
            logger.notice("editOffer: editing offer \(offer.id.uuidString) with validated settlement methods")
            return offerService.editOffer(offerID: offer.id, newSettlementMethods: newSettlementMethods)
        }.done(on: DispatchQueue.main) { [self] _ in
            logger.notice("editOffer: successfully edited offer \(offer.id.uuidString)")
            try offer.updateSettlementMethods(settlementMethods: newSettlementMethods)
            // We have successfully edited the offer, so we empty the selected settlement method list.
            offer.selectedSettlementMethods = []
            setEditingOfferState(offerID: offer.id, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("editOffer: got error during editOffer call for \(offer.id.uuidString). Error: \(error.localizedDescription)")
            offer.editingOfferError = error
            setEditingOfferState(offerID: offer.id, state: .error)
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` to edit `offer` using validated `newSettlementMethods`, which should be made by the user of this interface.
     
     This validates `newSettlementMethods`, passes `offer` and `newSettlementMethods` `OfferService.createEditOfferTransaction`, and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: An array of `SettlementMethod`s with which `offer` will be edited after they are validated.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createEditOfferTransaction(
        offer: Offer,
        newSettlementMethods: [SettlementMethod],
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createEditOfferTransaction: creating for \(offer.id.uuidString), validating edited settlement methods")
                do {
                    let validatedSettlementMethods = try validateSettlementMethods(newSettlementMethods)
                    offerService.createEditOfferTransaction(offer: offer, newSettlementMethods: validatedSettlementMethods).pipe(to: seal.resolve)
                } catch {
                    seal.reject(error)
                }
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to edit `offer` using `offerEditingTransaction`, which should have been created using the `SettlementMethod`s in `newSettlementMethods`.
     
     This clears any offer-editing-related `error` of `offer`, and sets `offer`'s `Offer.editingOfferState` to `EditingOfferState.validating`, and then passes all data to `offerService`'s `OfferService.editOffer` function.
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: The `SettlementMethod`s with which `offerEditingTransaction` should have been created.
        - offerEditingTransaction: An optional `EthereumTransaction` that can edit `offer` using the `SettlementMethod`s contained in `newSettlementMethods`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod], offerEditingTransaction: EthereumTransaction?) {
        offer.editingOfferError = nil
        offer.editingOfferState = .validating
        DispatchQueue.global(qos: .userInitiated).sync {
            logger.notice("editOffer: editing offer \(offer.id.uuidString)")
        }
        offerService.editOffer(offer: offer, newSettlementMethods: newSettlementMethods, offerEditingTransaction: offerEditingTransaction)
            .done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("editOffer: successfully broadcast transaction for \(offer.id.uuidString)")
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("editOffer: got error during editOffer call for \(offer.id.uuidString). Error: \(error.localizedDescription)")
                DispatchQueue.main.sync {
                    offer.editingOfferError = error
                    offer.editingOfferState = .error
                }
            }
    }
    
    /**
     Attempts to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - offer: The `Offer` to be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
     */
    func takeOffer(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?
    ) {
        setTakingOfferState(offerID: offer.id, state: .validating)
        Promise<ValidatedNewSwapData> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("takeOffer: validating new swap data for \(offer.id.uuidString)")
                do {
                    #warning("TODO: get the proper stablecoin info repo here")
                    let validatedSwapData = try validateNewSwapData(
                        offer: offer,
                        takenSwapAmount: takenSwapAmount,
                        selectedMakerSettlementMethod: makerSettlementMethod,
                        selectedTakerSettlementMethod: takerSettlementMethod,
                        stablecoinInformationRepository: StablecoinInformationRepository.hardhatStablecoinInfoRepo)
                    seal.fulfill(validatedSwapData)
                } catch {
                    seal.reject(error)
                }
            }
        }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] validatedNewSwapData -> Promise<Void> in
            logger.notice("takeOffer: taking \(offer.id.uuidString) with validated data")
            setTakingOfferState(offerID: offer.id, state: .checking)
            return offerService.takeOffer(
                offerToTake: offer,
                swapData: validatedNewSwapData,
                afterAvailabilityCheck: { self.setTakingOfferState(offerID: offer.id, state: .creating) },
                afterObjectCreation: { self.setTakingOfferState(offerID: offer.id, state: .storing) },
                afterPersistentStorage: { self.setTakingOfferState(offerID: offer.id, state: .approving) },
                afterTransferApproval: { self.setTakingOfferState(offerID: offer.id, state: .taking) }
            )
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
            logger.notice("takeOffer: successfully took offer \(offer.id.uuidString)")
            setTakingOfferState(offerID: offer.id, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("takeOffer: got error during takeOffer call for \(offer.id.uuidString). Error: \(error.localizedDescription)")
            offer.takingOfferError = error
            setTakingOfferState(offerID: offer.id, state: .error)
        }
    }
    
}
