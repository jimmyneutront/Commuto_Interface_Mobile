//
//  SwapNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import BigInt

/**
 A protocol that a structure or class must adopt in order to be notified of swap-related events by `BlockchainService` and `OfferService`
 */
protocol SwapNotifiable {
    /**
     The function called by `OfferService` in order to send taker information for an offer that has been taken by the user of this interface.
     
     - Parameters:
        - swapID: The ID of the swap for which the structure or class adopting this protocol should send taker information.
        - chainID: The ID of the blockchain on which the taken offer exists.
     */
    func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws
    
    /**
     The function called by `OfferService` when an offer made by the user of this interface has been taken.
     
     - Parameter takenOffer: The `Offer` made by the user of this interface that has been taken and now corresponds to a swap.
     */
    func handleNewSwap(takenOffer: Offer) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `SwapFilledEvent`.
     */
    func handleSwapFilledEvent(_ event: SwapFilledEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `PaymentSentEvent`.
     */
    func handlePaymentSentEvent(_ event: PaymentSentEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `PaymentReceivedEvent`.
     */
    func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `BuyerClosedEvent`.
     */
    func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws
    
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of a `SellerClosedEvent`.
     */
    func handleSellerClosedEvent(_ event: SellerClosedEvent) throws
}
