//
//  P2PErrorNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 A protocol that a structure or class must adopt in order to be notified of `Error`s encountered by `P2PService`.
 */
protocol P2PErrorNotifiable {
    /**
     The function called by `P2PService` in order to notify the structure or class adopting this protocol of an `Error` encountered by  `P2PService`.
     
     - Parameter error: the `Error` encountered by `P2PService` of which  the structure or class adopting this protocol is being notified, and should handle in the implementation of this function.
     */
    func handleP2PError(_ error: Error)
}
