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
    func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws {}
    /**
     Does nothing, required to adopt `SwapNotifiable`. Should not be used.
     */
    func handleNewSwap(swapID: UUID, chainID: BigUInt) throws {}
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
}
