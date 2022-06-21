package com.commuto.interfacemobile.android

import android.app.Application
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

/**
 * The main Commuto Interface [Application].
 *
 * @property blockchainService The app's [BlockchainService].
 */
@HiltAndroidApp
class CommutoApplication: Application() {

    @Inject
    lateinit var blockchainService: BlockchainService

    override fun onCreate() {
        super.onCreate()
        // Start listening to the blockchain
        blockchainService.listen()
    }
}