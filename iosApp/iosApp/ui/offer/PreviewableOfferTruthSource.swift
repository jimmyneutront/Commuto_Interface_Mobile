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
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    var approvingTransferToOpenOfferState: TokenTransferApprovalState = .none
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    var approvingTransferToOpenOfferError: Error?
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createApproveTokenTransferToOpenOfferTransaction(chainID: BigUInt, stablecoin: EthereumAddress?, stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, securityDepositAmount: Decimal, direction: OfferDirection, settlementMethods: [SettlementMethod], createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func approveTokenTransferToOpenOffer(chainID: BigUInt, stablecoin: EthereumAddress?, stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, securityDepositAmount: Decimal, direction: OfferDirection, settlementMethods: [SettlementMethod], approveTokenTransferToOpenOfferTransaction: EthereumTransaction?) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createOpenOfferTransaction(offer: Offer, createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func openOffer(offer: Offer, offerOpeningTransaction: EthereumTransaction?) {}
    
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
    func createCancelOfferTransaction(offer: Offer, createdTransactionHandler: (EthereumTransaction) -> Void, errorHandler: (Error) -> Void) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func cancelOffer(offer: Offer, offerCancellationTransaction: EthereumTransaction?) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createEditOfferTransaction(offer: Offer, newSettlementMethods: [SettlementMethod], createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod], offerEditingTransaction: EthereumTransaction?) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod]) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createApproveTokenTransferToTakeOfferTransaction(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func approveTokenTransferToTakeOffer(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        approveTokenTransferToTakeOfferTransaction: EthereumTransaction?
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func createTakeOfferTransaction(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        createdTransactionAndKeyPairHandler: @escaping (EthereumTransaction, KeyPair) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func takeOffer(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        keyPair: KeyPair?,
        offerTakingTransaction: EthereumTransaction?
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UIOfferTruthSource`.
     */
    func takeOffer(offer: Offer, takenSwapAmount: Decimal, makerSettlementMethod: SettlementMethod?, takerSettlementMethod: SettlementMethod?) {}
    
}
