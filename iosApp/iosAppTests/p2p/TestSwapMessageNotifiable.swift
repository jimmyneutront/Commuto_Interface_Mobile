//
//  TestSwapMessageNotifiable.swift
//  iosAppTests
//
//  Created by jimmyt on 8/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
@testable import iosApp

/**
 A basic `SwapMessageNotifiable` implementation used to satisfy `P2PService`'s swapService dependency for testing non-swap-related code.
 */
class TestSwapMessageNotifiable: SwapMessageNotifiable {
    /**
     Does nothing, required to adopt `SwapMessageNotifiable`. Should not be used.
     */
    func handleTakerInformationMessage(_ message: TakerInformationMessage) {}
    /**
     Does nothing, required to adopt `SwapMessageNotifiable`. Should not be used.
     */
    func handleMakerInformationMessage(_ message: MakerInformationMessage, senderInterfaceID: Data, recipientInterfaceID: Data) throws {}
}
