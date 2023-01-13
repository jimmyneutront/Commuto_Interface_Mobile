//
//  TestSwapService.swift
//  iosAppTests
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
@testable import iosApp

/**
 A basic `SwapNotifiable` implementation used to satisfy `OfferService`'s `swapService` dependency for testing non-swap-related code.
 */
class TestSwapService: SwapNotifiable {
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool { return false }
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleNewSwap(takenOffer: Offer) throws {}
    /**
     Does nothing, required to adopt `OfferNotifiable`. Should not be used.
     */
    func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {}
}
