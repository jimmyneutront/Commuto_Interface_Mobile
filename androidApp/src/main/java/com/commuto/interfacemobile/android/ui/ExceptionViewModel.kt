package com.commuto.interfacemobile.android.ui

import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.blockchain.BlockchainExceptionNotifiable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ExceptionViewModel @Inject constructor(): ViewModel(), BlockchainExceptionNotifiable {
    override fun handleBlockchainException(exception: Exception) {
        throw exception
    }
}