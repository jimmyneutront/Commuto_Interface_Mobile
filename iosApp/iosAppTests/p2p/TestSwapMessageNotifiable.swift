//
//  TestSwapMessageNotifiable.swift
//  iosAppTests
//
//  Created by jimmyt on 8/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

@testable import iosApp

/**
 A basic `SwapMessageNotifiable` implementation used to satisfy `P2PService`'s swapService dependency for testing non-swap-related code.
 */
class TestSwapMessageNotifiable: SwapMessageNotifiable {
    /**
     Does nothing, required to adopt `SwapMessageNotifiable`. Should not be used.
     */
    func handleTakerInformationMessage(_ message: TakerInformationMessage) {}
}
