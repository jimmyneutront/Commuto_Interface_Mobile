//
//  BlockchainErrorNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 A protocol that a structure or class must adopt in order to be notified of `Error`s encountered by `BlockchainService`.
 */
protocol BlockchainErrorNotifiable {
    /**
     The function called by `BlockchainService` in order to notify the structure or class adopting this protocol of an `Error` encountered by  `BlockchainService`.
     
     - Parameter error: the `Error` encountered by `BlockchainService` of which the structure or class adopting this protocol is being notified and should handle in the implementation of this function.
     */
    func handleBlockchainError(_ error: Error)
}
