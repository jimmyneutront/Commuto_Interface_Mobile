package com.commuto.interfacemobile.android.ui

import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.blockchain.BlockchainExceptionNotifiable
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The Exception View Model, which is notified of and handles [Exception]s encountered by [BlockchainService] and
 * [com.commuto.interfacemobile.android.p2p.P2PService].
 */
@Singleton
class ExceptionViewModel @Inject constructor(): ViewModel(), BlockchainExceptionNotifiable {
    /**
     * The method called by [BlockchainService] in order to notify of an encountered [Exception].
     *
     * @param exception The [Exception] encountered by [BlockchainService] that this method should handle.
     */
    override fun handleBlockchainException(exception: Exception) {
        throw exception
    }
}