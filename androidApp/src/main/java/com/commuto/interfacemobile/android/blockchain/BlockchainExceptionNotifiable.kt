package com.commuto.interfacemobile.android.blockchain

import javax.inject.Singleton

@Singleton
interface BlockchainExceptionNotifiable {
    fun handleBlockchainException(exception: Exception)
}