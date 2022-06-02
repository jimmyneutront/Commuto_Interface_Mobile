package com.commuto.interfacemobile.android.blockchain

import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.math.BigInteger

class BlockchainServiceTest {
    @Test
    fun testBlockchainService() = runBlocking {
        val blockchainService = BlockchainService()
        val block = blockchainService.getBlock(BigInteger.valueOf(10000000L)).block
        print(block)
    }
}