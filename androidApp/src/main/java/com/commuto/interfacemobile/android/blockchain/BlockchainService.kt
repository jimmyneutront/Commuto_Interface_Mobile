package com.commuto.interfacemobile.android.blockchain

import com.commuto.interfacemobile.android.CommutoSwap
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.*
import kotlinx.coroutines.future.asDeferred
import org.web3j.crypto.Credentials
import org.web3j.protocol.Web3j
import org.web3j.protocol.core.DefaultBlockParameter
import org.web3j.protocol.core.methods.response.*
import org.web3j.protocol.http.HttpService
import org.web3j.tx.ChainIdLong
import java.math.BigInteger
import javax.inject.Inject

@Module
@InstallIn(SingletonComponent::class)
class BlockchainService @Inject constructor() {

    // Blockchain credentials
    private val creds: Credentials = Credentials.create(
        "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    )

    // The number of the last parsed block
    private var lastParsedBlockNum: BigInteger = BigInteger.ZERO

    // The number of the newest block
    private var newestBlockNum: BigInteger = BigInteger.ZERO

    private fun setLastParsedBlockNumber(blockNumber: BigInteger) {
        lastParsedBlockNum = blockNumber
    }

    // The number of milliseconds that BlockchainService should wait after parsing a block
    //private val listenInterval = 3000L
    private val listenInterval = 30L

    // The coroutine job in which BlockchainService listens to the blockchain
    private var listenJob: Job = Job()

    // Web3j web3 instance
    //TODO: Inject this
    //val web3 = Web3j.build(HttpService("https://data-seed-prebsc-1-s1.binance.org:8545"))
    private val web3: Web3j = Web3j.build(HttpService("http://192.168.1.13:8545"))

    // Gas price provider
    private val gasProvider = DumbGasProvider()

    // Commuto transaction manager
    private val txManager = CommutoTransactionManager(web3, creds, ChainIdLong.NONE)

    // CommutoSwap contract address
    private val swapAddress = "0x36B22905A1211A55E0d62eF46720172e2b0f24BD"

    // Commuto Swap contract instance
    private val commutoSwap: CommutoSwap = CommutoSwap.load(
        swapAddress,
        web3,
        txManager,
        gasProvider
    )

    @OptIn(DelicateCoroutinesApi::class)
    fun listen() {
        listenJob = GlobalScope.launch {
            listenLoop()
        }
    }

    fun stopListening() {
        listenJob.cancel()
    }

    suspend fun listenLoop() {
        while (true) {
            newestBlockNum = getNewestBlockNumberAsync().await().blockNumber
            if (newestBlockNum > lastParsedBlockNum) {
                val block = getBlockAsync(lastParsedBlockNum + BigInteger.ONE).await()
                    .block
                parseBlock(block)

                setLastParsedBlockNumber(block.number)
            }
            delay(listenInterval)
        }
    }

    private fun getNewestBlockNumberAsync(): Deferred<EthBlockNumber> {
        return web3.ethBlockNumber().sendAsync().asDeferred()
    }

    private fun getBlockAsync(blockNumber: BigInteger): Deferred<EthBlock> {
        return web3.ethGetBlockByNumber(
            DefaultBlockParameter.valueOf(blockNumber),
            false
        ).sendAsync().asDeferred()
    }

    private fun getDeferredTxReceiptOptionals (
        txHashes: List<String>
    ): List<Deferred<EthGetTransactionReceipt>> {
        return txHashes.map {
            web3.ethGetTransactionReceipt(it).sendAsync().asDeferred()
        }
    }

    private suspend fun parseBlock(block: EthBlock.Block) {
        val txHashes: List<String> = block.transactions.mapNotNull {
            when (it) {
                is EthBlock.TransactionHash -> {
                    it.get()
                }
                is EthBlock.TransactionObject -> {
                    it.get().hash
                }
                else -> {
                    null
                }
            }
        }
        val deferredTxReceiptOptionals = getDeferredTxReceiptOptionals(txHashes)
        val eventResponses: MutableList<List<BaseEventResponse>> = mutableListOf()
        for (deferredReceiptOptional in deferredTxReceiptOptionals) {
            eventResponses.add(parseDeferredReceiptOptional(deferredReceiptOptional))
        }
        handleEventResponses(eventResponses)
    }

    private suspend fun parseDeferredReceiptOptional(
        deferredReceiptOptional: Deferred<EthGetTransactionReceipt>
    ): List<BaseEventResponse> = coroutineScope {
        val receiptOptional = deferredReceiptOptional.await()
        if (receiptOptional.transactionReceipt.isPresent) {
            getEventResponsesFromReceipt(receiptOptional.transactionReceipt.get())
        } else {
            emptyList()
        }
    }

    private fun getEventResponsesFromReceipt(receipt: TransactionReceipt): List<BaseEventResponse> {
        //TODO: check for more events
        return commutoSwap.getOfferOpenedEvents(receipt)
    }

    private fun handleEventResponses(
        eventResponseLists: MutableList<List<BaseEventResponse>>
    ) {
        val eventResponses = eventResponseLists.flatten()
        for (eventResponse in eventResponses) {
            if (eventResponse is CommutoSwap.OfferOpenedEventResponse) {
                TODO("Pass this event to OfferService")
            }
        }
    }

}