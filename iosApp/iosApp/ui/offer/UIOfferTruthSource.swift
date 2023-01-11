//
//  UIOfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 7/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data in an application with a graphical user interface.
 */
protocol UIOfferTruthSource: OfferTruthSource, ObservableObject {
    /**
     Indicates whether this is currently getting the current service fee rate.
     */
    var isGettingServiceFeeRate: Bool { get set }
    /**
     Attempts to get the current service fee rate and set `serviceFeeRate` equal to the result.
     */
    func updateServiceFeeRate()
    /**
     Indicates whether we are currently opening an offer, and if so, the point of the [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) we are currently in.
     */
    var approvingTransferToOpenOfferState: TokenTransferApprovalState { get set }
    /**
     The `Error` that occured during the offer creation process, or `nil` if no such error has occured.
     */
    var approvingTransferToOpenOfferError: Error? { get set }
    /**
     Attempts to open a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - chainID: The ID of the blockchain on which the offer will be created.
        - stablecoin: The contract address of the stablecoin for which the offer will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which the offer will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer.
        - maximumAmount: The maximum `Decimal` amount of the new offer.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer.
        - direction: The direction of the new offer.
        - settlementMethods: The settlement methods of the new offer.
     */
    @available(*, deprecated, message: "Use the new offer pipeline with improved transaction state management")
    func openOffer(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod]
    )
    
    /**
     Attempts to create an `EthereumTransaction` to approve a token transfer in order to open a new offer.
     
     - Parameters:
        - chainID: The ID of the blockchain on which the token transfer allowance will be created.
        - stablecoin: The contract address of the stablecoin for which the token transfer allowance will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which token transfer allowance will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - maximumAmount: The maximum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer, for which the token transfer allowance will be created.
        - direction: The direction of the new offer, for which the token transfer allowance will be created.
        - settlementMethods: The settlement methods of the new offer, for which the token transfer allowance will be created.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createApproveTokenTransferToOpenOfferTransaction(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod],
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to approve a token transfer in order to open an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - chainID: The ID of the blockchain on which the token transfer allowance will be created.
        - stablecoin: The contract address of the stablecoin for which the token transfer allowance will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which token transfer allowance will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - maximumAmount: The maximum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer, for which the token transfer allowance will be created.
        - direction: The direction of the new offer, for which the token transfer allowance will be created.
        - settlementMethods: The settlement methods of the new offer, for which the token transfer allowance will be created.
        - approveTokenTransferToOpenOfferTransaction: An optional `EthereumTransaction` that can create a token transfer allowance of the proper amount (determined by the values of the other arguments) of token specified by `stablecoin`.
     */
    func approveTokenTransferToOpenOffer(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod],
        approveTokenTransferToOpenOfferTransaction: EthereumTransaction?
    )
    
    /**
     Attempts to create an `EthereumTransaction` that can open `offer` (which should be made by the user of this interface) by  calling [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer).
     
     - Parameters:
        - offer: The `Offer` to be opened.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createOpenOfferTransaction(
        offer: Offer,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to open an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) made by the user of this interface.
     
     - Parameters:
        - offer: The `Offer` to be opened.
        - offerOpeningTransaction: An optional `EthereumTransaction` that can open `offer`.
     */
    func openOffer(
        offer: Offer,
        offerOpeningTransaction: EthereumTransaction?
    )
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     - Parameter offer: The `Offer` to be canceled.
     */
    @available(*, deprecated, message: "Use the new offer pipeline with improved transaction state management")
    func cancelOffer(
        _ offer: Offer
    )
    
    /**
     Attempts to create an `EthereumTransaction` to cancel `offer`, which should be made by the user of this interface.
     
     - Parameters:
        - offer: The `Offer` to be canceled.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createCancelOfferTransaction(
        offer: Offer,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     - Parameters:
        - offer: The `Offer` to be canceled.
        - offerCancellationTransaction: An optional `EthereumTransaction` that can cancel `offer`.
     */
    func cancelOffer(offer: Offer, offerCancellationTransaction: EthereumTransaction?)
    
    /**
     Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: The new `Array` of settlement methods that the maker has selected, indicating that they are willing to use them to send/receive fiat currency for this offer.
     */
    @available(*, deprecated, message: "Use the new offer pipeline with improved transaction state management")
    func editOffer(
        offer: Offer,
        newSettlementMethods: [SettlementMethod]
    )
    
    /**
     Attempts to create an `EthereumTransaction` to edit `offer` using validated `newSettlementMethods`, which should be made by the user of this interface.
     
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
    )
    
    /**
     Attempts to edit `offer` using `offerEditingTransaction`, which should have been created using the `SettlementMethod`s in `newSettlementMethods`.
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: The `SettlementMethod`s with which `offerEditingTransaction` should have been created.
        - offerEditingTransaction: An optional `EthereumTransaction` that can edit `offer` using the `SettlementMethod`s contained in `newSettlementMethods`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod], offerEditingTransaction: EthereumTransaction?)
    
    /**
     Attempts to create an `EthereumTransaction` to approve a token transfer in order to take an offer.
     
     - Parameters:
        - offer: The `Offer` to be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createApproveTokenTransferToTakeOfferTransaction(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to approve a token transfer in order to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - offer: The `Offer` to be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - approveTokenTransferToTakeOfferTransaction: An optional `EthereumTransaction` that can create a token transfer allowance of the proper amount (determined by the values of the other arguments) of the token specified by `offer`.
     */
    func approveTokenTransferToTakeOffer(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        approveTokenTransferToTakeOfferTransaction: EthereumTransaction?
    )
    
    /**
     Attempts to create an `EthereumTransaction` that can take `offer` (which should NOT be made by the user of this interface) by calling [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer).
     
     - Parameters:
        - offer: The `Offer` to be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - createdTransactionAndKeyPairHandler: An escaping closure that will accept and handle the created `EthereumTransaction` and `KeyPair`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createTakeOfferTransaction(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        createdTransactionAndKeyPairHandler: @escaping (EthereumTransaction, KeyPair) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer).
     
     - Parameters:
        - offer: The `Offer` to be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - keyPair: An optional `KeyPair`, which serves as the user's/taker's key pair and with which `offerTakingTransaction` should have been created.
        - offerTakingTransaction: An optional `EthereumTransaction` that can take `offer`.
     */
    func takeOffer(
        offer: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        keyPair: KeyPair?,
        offerTakingTransaction: EthereumTransaction?
    )
    
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
    )
    
}
