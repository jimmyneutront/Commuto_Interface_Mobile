package com.commuto.interfacemobile.android.blockchain

import kotlinx.coroutines.runBlocking
import org.junit.Test

class BlockchainServiceTest {
    @Test
    fun testBlockchainService() = runBlocking {
        val blockchainService = BlockchainService()
        blockchainService.listenLoop()
    }
}