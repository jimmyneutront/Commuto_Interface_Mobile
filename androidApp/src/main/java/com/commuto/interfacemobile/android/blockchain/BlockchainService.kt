package com.commuto.interfacemobile.android.blockchain

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.*
import kotlinx.coroutines.future.await
import org.web3j.protocol.Web3j
import org.web3j.protocol.core.DefaultBlockParameter
import org.web3j.protocol.core.methods.response.EthBlock
import org.web3j.protocol.http.HttpService
import java.math.BigInteger
import javax.inject.Inject

@Module
@InstallIn(SingletonComponent::class)
class BlockchainService @Inject constructor() {

    // The number of the last parsed block
    var lastParsedBlockNum = 10000000L - 1L

    // The number of milliseconds that BlockchainService should wait after parsing a block
    private val listenInterval = 3000L

    // The coroutine job in which BlockchainService listens to the blockchain
    private var listenJob: Job = Job()

    // Web3j web3 instance
    val web3 = Web3j.build(HttpService("https://data-seed-prebsc-1-s1.binance.org:8545"))

    fun listen() {
        listenJob = GlobalScope.launch {
            while (true) {
                val block = getBlock(BigInteger.valueOf(lastParsedBlockNum + 1)).block
                parseBlock(block)

                // setLastParsedBlockNumber(block.number)
                delay(listenInterval)
            }
        }
    }

    fun stopListening() {
        listenJob.cancel()
    }

    suspend fun getBlock(blockNumber: BigInteger): EthBlock {
        return web3.ethGetBlockByNumber(
            DefaultBlockParameter.valueOf(blockNumber),
            true
        ).sendAsync().await()
    }

    fun parseBlock(block: EthBlock.Block) {
        for (tx in block.transactions) {

        }
    }

}