package com.commuto.interfacemobile.android

import android.app.Application
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.database.DatabaseService
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
    @Inject
    lateinit var databaseService: DatabaseService

    override fun onCreate() {
        super.onCreate()
        // TODO: ONLY do this when using an in memory database, NOT when using a production database!
        databaseService.createTables()
        // Start listening to the blockchain
        blockchainService.listen()
    }
}