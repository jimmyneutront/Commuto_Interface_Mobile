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
     The function called by `OfferService` in order to announce taker information for an offer that has been taken by the user of this interface.
     
     - Parameters:
        - swapID: The ID of the swap for which the structure or class adopting this protocol should announce taker information.
        - chainID: The ID of the blockchain on which the taken offer exists.
     */
    func announceTakerInformation(swapID: UUID, chainID: BigUInt) throws
}
