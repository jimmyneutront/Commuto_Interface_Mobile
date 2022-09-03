package com.commuto.interfacemobile.android.blockchain

/**
 * A basic [BlockchainExceptionNotifiable] implementation for testing.
 */
class TestBlockchainExceptionHandler: BlockchainExceptionNotifiable {
    var gotError = false
    override fun handleBlockchainException(exception: Exception) {
        gotError = true
    }
}