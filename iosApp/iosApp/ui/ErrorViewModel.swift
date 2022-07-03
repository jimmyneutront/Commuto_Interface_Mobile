//
//  ErrorViewModel.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Combine

/**
 The Error View Model, which is notified of and handles `Error`s encountered by `BlockchainService` and `P2PService`.
 */
class ErrorViewModel: BlockchainErrorNotifiable, P2PErrorNotifiable, ObservableObject {
    
    /**
     The function called by `BlockchainService` in order to notify of an encountered`Error`.
     
     - Parameter error: The `Error` encountered by `BlockchainService` that this function should handle.
     */
    func handleBlockchainError(_ error: Error) {
        print(error)
    }
    
    /**
     The function called by `P2PService` in order to notify of an encountered`Error`.
     
     - Parameter error: The `Error` encountered by `P2PService` that this function should handle.
     */
    func handleP2PError(_ error: Error) {
        print(error)
    }
    

}
