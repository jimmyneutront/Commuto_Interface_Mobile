package com.commuto.interfacemobile.android.blockchain

import com.commuto.interfacemobile.android.offer.OfferService
import kotlinx.coroutines.runBlocking
import org.junit.Test

class BlockchainServiceTest {
    @Test
    fun testBlockchainService() = runBlocking {
        val blockchainService = BlockchainService(OfferService())
        blockchainService.listenLoop()
    }
}