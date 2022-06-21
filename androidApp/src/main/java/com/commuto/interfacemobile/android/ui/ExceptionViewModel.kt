package com.commuto.interfacemobile.android.ui

import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.blockchain.BlockchainExceptionNotifiable
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The Exception View Model, used to display a visual notification to the user when unexpected
 * exceptions occur.
 */
@Singleton
class ExceptionViewModel @Inject constructor(): ViewModel(), BlockchainExceptionNotifiable {
    /**
     * The method called by [BlockchainService] in order to notify of an [Exception] encountered
     * by [BlockchainService].
     *
     * @param exception The [Exception] encountered by [BlockchainService] about which this method
     * should notify the user.
     */
    override fun handleBlockchainException(exception: Exception) {
        throw exception
    }
}