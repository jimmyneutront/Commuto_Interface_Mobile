package com.commuto.interfacemobile.android.p2p

import com.commuto.interfacemobile.android.p2p.messages.MakerInformationMessage
import com.commuto.interfacemobile.android.p2p.messages.TakerInformationMessage

/**
 * An interface that a class must implement in order to be notified of swap-related messages by [P2PService].
 */
interface SwapMessageNotifiable {
    /**
     * The method called by [P2PService] in order to notify the class implementing this interface of a new
     * [TakerInformationMessage].
     *
     * @param message The new [TakerInformationMessage] of which the class implementing this interface is being notified
     * and should handle in the implementation of this method.
     */
    suspend fun handleTakerInformationMessage(message: TakerInformationMessage)

    /**
     * The method called by [P2PService] in order to notify the class implementing this interface of a new
     * [MakerInformationMessage].
     *
     * @param message The new [MakerInformationMessage] of which the class implementing this interface is being notified
     * and should handle in the implementation of this method.
     * @param senderInterfaceID The interface ID of the message's sender.
     * @param recipientInterfaceID The interface ID of the message's intended recipient.
     */
    suspend fun handleMakerInformationMessage(
        message: MakerInformationMessage,
        senderInterfaceID: ByteArray,
        recipientInterfaceID: ByteArray
    )
}