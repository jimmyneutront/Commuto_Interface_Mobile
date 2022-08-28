//
//  SwapMessageNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 8/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A protocol that a structure or class must adopt in order to be notified of swap-related messages by `P2PService`
 */
protocol SwapMessageNotifiable {
    /**
     The function called by `P2PService` in order to notify the structure or class adopting this protocol of a new `TakerInformationMessage`.
     
     - Parameter message: the new `TakerInformationMessage` of which the structure or class adopting this protocol is being notified, and should handle in the implementation of this function.
     */
    func handleTakerInformationMessage(_ message: TakerInformationMessage) throws
    /**
     The function called by `P2PService` in order to notify the structure or class adopting this protocol of a new `MakerInformationMessage`.
     
     - Parameters:
        - message: the new `MakerInformationMessage` of which the structure or class adopting this protocol is being notified, and should handle in the implementation of this function.
        - senderInterfaceID: The interface ID of the message's sender.
        - recipientInterfaceID: The interface ID of the message's intended recipient.
     */
    func handleMakerInformationMessage(_ message: MakerInformationMessage, senderInterfaceID: Data, recipientInterfaceID: Data) throws
}
