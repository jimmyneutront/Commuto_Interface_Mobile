//
//  Swap.swift
//  iosApp
//
//  Created by jimmyt on 8/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Combine
import Foundation

/**
 Represents a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
 */
class Swap: ObservableObject {
    
    /**
     The ID that uniquely identifies this swap, as a `UUID`.
     */
    let id: UUID
    
    /**
     The direction of the swap, indicating whether the maker is buying stablecoin or selling stablecoin.
     */
    let direction: OfferDirection
    
    /**
     Creates a new `Swap`.
     
     - Parameters:
        - id: The ID of this swap, as a `UUID`.
        - direction: The direction of the swap, either `buy` or `sell`.
     */
    init(
        id: UUID,
        direction: OfferDirection
    ) {
        self.id = id
        self.direction = direction
    }
}

/**
 Contains a list of sample swap IDs (as `UUID`x) and a dictionary mapping those `UUID`s to `Swap`s. Used for previewing swap-related `View`s.
 */
extension Swap {
    /**
     A list of `UUID`s used for previewing swap-related `View`s
     */
    static let sampleSwapIds = [
        UUID(),
        UUID(),
    ]
    /**
     A dictionary mapping the contents of `sampleSwapIds` to `Swap`s. Used for previewing swap-related `View`s.
     */
    static let sampleSwaps: [UUID: Swap] = [
        sampleSwapIds[0]: Swap(
            id: sampleSwapIds[0],
            direction: .buy
        ),
        sampleSwapIds[1]: Swap(
            id: sampleSwapIds[1],
            direction: .buy
        ),
    ]
}
