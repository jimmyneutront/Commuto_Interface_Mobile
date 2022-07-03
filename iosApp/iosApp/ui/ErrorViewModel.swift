//
//  ErrorViewModel.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Combine

/**
 The Error View Model, which is notified of `Error` encountered by `BlockchainService` and `P2PService`.
 */
class ErrorViewModel: BlockchainErrorNotifiable, P2PErrorNotifiable, ObservableObject {
    
    /**
     Handle an `Error` encountered by `BlockchainService`.
     
     - Parameter error: The `Error` encountered by `BlockchainService` that should be handled in this function.
     */
    func handleBlockchainError(_ error: Error) {
        print(error)
    }
    
    /**
     Handle an `Error` encountered by `P2PService`.
     
     - Parameter error: The `Error` encountered by `P2PService` that should be handled in this function.
     */
    func handleP2PError(_ error: Error) {
        print(error)
    }
    

}
