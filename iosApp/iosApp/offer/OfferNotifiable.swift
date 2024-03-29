//
//  OfferNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 A protocol that a structure or class must adopt in order to be notified of offer-related blockchain events and transaction failures by `BlockchainService`.
 */
protocol OfferNotifiable {
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol that a monitored offer-related `BlockchainTransaction` has failed (either has been confirmed and failed, or has been dropped.)
     
     - Parameters:
        - transaction: The `BlockchainTransaction` wrapping the on-chain transaction that has failed.
        - error: A `BlockchainTransactionError` describing why the on-chain transaction has failed.
     */
    func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `ApprovalEvent`.
     
     - Parameter event: The `ApprovalEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of  this function.
     */
    func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `OfferOpenedEvent`.
     
     - Parameter event: The `OfferOpenedEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of  this function.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `OfferEditedEvent`.
     
     - Parameter event: The `OfferEditedEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of  this function.
     */
    func handleOfferEditedEvent(_ event: OfferEditedEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `OfferCanceledEvent`.
     
     - Parameter event: The `OfferCanceledEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of  this function.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `OfferTakenEvent`.
     
     - Parameter event: The `OfferTakenEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of  this function.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `ServiceFeeRateChangedEvent`.
     
     - Parameter event: The `ServiceFeeRateChangedEvent` of which the structure or class adopting this protocol is being notified and should handle in the implementation of this function.
     */
    func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) throws
    
}
