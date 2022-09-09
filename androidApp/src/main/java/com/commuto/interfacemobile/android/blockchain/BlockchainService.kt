package com.commuto.interfacemobile.android.blockchain

import android.util.Log
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacemobile.android.blockchain.structs.OfferStruct
import com.commuto.interfacemobile.android.blockchain.structs.SwapStruct
import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import com.commuto.interfacemobile.android.extension.asByteArray
import com.commuto.interfacemobile.android.offer.OfferNotifiable
import com.commuto.interfacemobile.android.offer.OfferService
import com.commuto.interfacemobile.android.swap.SwapNotifiable
import kotlinx.coroutines.*
import kotlinx.coroutines.future.asDeferred
import kotlinx.coroutines.future.await
import org.web3j.contracts.eip20.generated.ERC20
import org.web3j.crypto.Credentials
import org.web3j.protocol.Web3j
import org.web3j.protocol.core.DefaultBlockParameter
import org.web3j.protocol.core.methods.response.*
import org.web3j.protocol.http.HttpService
import org.web3j.tx.ChainIdLong
import java.math.BigInteger
import java.net.ConnectException
import java.nio.ByteBuffer
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The main Blockchain Service. It is responsible for listening to the blockchain and detecting the
 * emission of events by parsing transaction receipts, and then passing relevant detected events to
 * other services as necessary.
 *
 * @constructor Creates a new [BlockchainService] instance with the specified
 * [BlockchainExceptionNotifiable], [OfferNotifiable], [Web3j] instance and CommutoSwap contract
 * address.
 *
 * @property logTag The tag passed to [Log] calls.
 * @property exceptionHandler An object to which [BlockchainService] will pass exceptions when they
 * occur.
 * @property offerService: An object to which [BlockchainService] will pass offer-related events
 * when they occur.
 * @property swapService An object to which [BlockchainService] will pass swap-related events when they occur.
 * @property web3 The [Web3j] instance that [BlockchainService] uses to interact with the
 * EVM-compatible blockchain.
 * @property creds Blockchain credentials used for signing transactions.
 * @property lastParsedBlockNum The block number of the most recently parsed block.
 * @property newestBlockNum The block number of the most recently confirmed block.
 * @property listenInterval The number of milliseconds that [BlockchainService] should wait after
 * parsing a block before it begins parsing another block.
 * @property listenJob The coroutine [Job] in which [BlockchainService] listens to the blockchain.
 * @property runLoop Boolean that indicates whether [listenLoop] should continue to execute its
 * loop.
 * @property gasProvider Provides gas price information to [commutoSwap].
 * @property txManager A [CommutoTransactionManager] for [commutoSwap]
 * @property commutoSwap A [CommutoSwap] instance that [BlockchainService] uses to parse transaction
 * receipts for CommutoSwap events and interact with the [CommutoSwap contract](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol)
 * on chain.
 */
@Singleton
class BlockchainService (private val exceptionHandler: BlockchainExceptionNotifiable,
                         private val offerService: OfferNotifiable,
                         private val swapService: SwapNotifiable,
                         private val web3: Web3j,
                         commutoSwapAddress: String) {

    @Inject constructor(
        errorHandler: BlockchainExceptionNotifiable,
        offerService: OfferNotifiable,
        swapService: SwapNotifiable
    ):
            this(errorHandler,
                offerService,
                swapService,
                Web3j.build(HttpService(System.getenv("BLOCKCHAIN_NODE"))),
                "0x687F36336FCAB8747be1D41366A416b41E7E1a96"
            )

    init {
        (offerService as? OfferService)?.setBlockchainService(this)
    }

    private val logTag = "BlockchainService"

    private val creds: Credentials = Credentials.create(
        "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    )

    private var lastParsedBlockNum: BigInteger = BigInteger.ZERO

    private var newestBlockNum: BigInteger = BigInteger.ZERO

    // TODO: rename this as updateLastParsedBlockNumber
    /**
     * Updates [lastParsedBlockNum]. Eventually, this function will store [blockNumber] in
     * persistent storage.
     *
     * @param blockNumber The block number of the block that has been most recently parsed by
     * [BlockchainService], to be set as [lastParsedBlockNum].
     */
    private fun setLastParsedBlockNumber(blockNumber: BigInteger) {
        lastParsedBlockNum = blockNumber
    }

    private val listenInterval = 30L

    private var listenJob: Job = Job()

    private var runLoop = true

    private val gasProvider = DumbGasProvider()

    private val txManager = CommutoTransactionManager(web3, creds, ChainIdLong.NONE)

    private val commutoSwap: CommutoSwap = CommutoSwap.load(
        commutoSwapAddress,
        web3,
        txManager,
        gasProvider
    )

    /**
     * Returns the contract address of [commutoSwap].
     */
    fun getCommutoSwapAddress(): String {
        return commutoSwap.contractAddress
    }

    /**
     * Launches a new coroutine [Job] in [GlobalScope], the global coroutine scope, runs
     * [listenLoop] in this new [Job], and stores a reference to it in [listenJob].
     */
    @OptIn(DelicateCoroutinesApi::class)
    fun listen() {
        Log.i(logTag, "Starting listen loop in global coroutine scope")
        listenJob = GlobalScope.launch {
            runLoop = true
            listenLoop()
        }
        Log.i(logTag, "Starting listen loop in global coroutine scope")
    }

    /**
     * Sets [runLoop] to false to prevent the listen loop from being executed again and cancels
     * [listenJob].
     */
    fun stopListening() {
        Log.i(logTag, "Stopping listen loop and canceling listen job")
        runLoop = false
        listenJob.cancel()
        Log.i(logTag, "Stopped listen loop and canceled listen job")
    }

    /**
     * Executes the listening process in the current coroutine context as long as [runLoop] is true.
     *
     * Listening Process:
     *
     * First, we get the block number of the most recently confirmed block, and update
     * [newestBlockNum] with this value. Then we compare this to the number of the most recently
     * parsed block. If the newest block number is greater than that of the most recently parsed
     * block, then there exists at least one new block that we must parse. If the newest block
     * number is not greater than the last parsed block number, then we don't have a new block to
     * parse, and we delay the coroutine in which we are running by [listenInterval] milliseconds.
     *
     * If we do have at least one new block to parse, we get the block with a block number one
     * greater than that of the last parsed block. Then we parse this new block, and then set the
     * last parsed block number as the block number of this newly parsed block.
     *
     * If we encounter an [Exception], we pass it to [exceptionHandler]. Additionally, if the
     * exception is a [ConnectException], indicating that we are having problems communicating with
     * the network node, then we stop listening.
     */
    suspend fun listenLoop() {
        while (runLoop) {
            try {
                Log.i(logTag, "Beginning iteration of listen loop, last parsed block number: $lastParsedBlockNum")
                newestBlockNum = getNewestBlockNumberAsync().await().blockNumber
                if (newestBlockNum > lastParsedBlockNum) {
                    Log.i(logTag, "Newest block number $newestBlockNum > last parsed block number " +
                            "$lastParsedBlockNum")
                    val block = getBlockAsync(lastParsedBlockNum + BigInteger.ONE)
                        .await().block
                    Log.i(logTag, "Got block ${block.number}")
                    parseBlock(block)
                    Log.i(logTag, "Parsed block ${block.number}")
                    setLastParsedBlockNumber(block.number)
                    Log.i(logTag, "Updated last parsed block number as ${block.number}")
                } else {
                    Log.i(logTag, "Newest block number $newestBlockNum <= last parsed block number " +
                            "$lastParsedBlockNum, delaying for $listenInterval ms")
                    delay(listenInterval)
                }
            } catch (e: Exception) {
                Log.e(logTag, "Got an exception during listen loop, calling exception handler", e)
                exceptionHandler.handleBlockchainException(e)
                if (e is ConnectException) {
                    Log.e(logTag, "Caught ConnectionException, stopping listening loop", e)
                    stopListening()
                }
            }
            Log.i(logTag, "Completed iteration of listen loop")
        }
    }

    /**
     * A [Deferred] wrapper around Web3j's [Web3j.ethBlockNumber] method.
     *
     * @return A [Deferred] with an [EthBlockNumber] result.
     */
    private fun getNewestBlockNumberAsync(): Deferred<EthBlockNumber> {
        return web3.ethBlockNumber().sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around Web3j's [Web3j.ethGetBlockByNumber] method.
     *
     * Note: Blocks returned by this function do not contain complete transactions, they contain
     * transaction hashes instead.
     *
     * @param blockNumber The block number of the block to be returned.
     *
     * @return A [Deferred] with an [EthBlock] result.
     */
    private fun getBlockAsync(blockNumber: BigInteger): Deferred<EthBlock> {
        return web3.ethGetBlockByNumber(
            DefaultBlockParameter.valueOf(blockNumber),
            false
        ).sendAsync().asDeferred()
    }

    /**
     * Gets full transaction receipts for transactions with the specified hashes.
     *
     * @param txHashes A list of transaction hashes (as [String]s) for which to get full
     * transaction receipts (as [EthGetTransactionReceipt]s).
     *
     * @return A [List] of [Deferred]s with [EthGetTransactionReceipt] results.
     */
    private fun getDeferredTxReceiptOptionals (
        txHashes: List<String>
    ): List<Deferred<EthGetTransactionReceipt>> {
        return txHashes.map {
            web3.ethGetTransactionReceipt(it).sendAsync().asDeferred()
        }
    }

    /**
     * Uses the [CommutoSwap.getOffer] method and [Web3j.ethChainId] to get the current chain ID and all on-chain data
     * about the offer with the specified ID, and creates and returns an [OfferStruct] with the results.
     *
     * @param id The ID of the offer to return.
     *
     * @return An [OfferStruct] containing all on-chain data of the offer with the specified ID, or null if no such
     * offer exists.
     */
    suspend fun getOffer(id: UUID): OfferStruct? {
        val offerIdByteBuffer = ByteBuffer.wrap(ByteArray(16))
        offerIdByteBuffer.putLong(id.mostSignificantBits)
        offerIdByteBuffer.putLong(id.leastSignificantBits)
        val offer = commutoSwap.getOffer(offerIdByteBuffer.array()).sendAsync().asDeferred()
        val chainID = web3.ethChainId().sendAsync().asDeferred()
        return OfferStruct.createFromGetOfferResponse(offer.await(), chainID.await().chainId)
    }

    /**
     * A [Deferred] wrapper around [CommutoSwap.serviceFeeRate] method.
     *
     * @return A [Deferred] with a [BigInteger] result.
     */
    fun getServiceFeeRateAsync(): Deferred<BigInteger> {
        return commutoSwap.serviceFeeRate.sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [ERC20](https://eips.ethereum.org/EIPS/eip-20) `approve` function.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun approveTokenTransferAsync(
        tokenAddress: String,
        destinationAddress: String,
        amount: BigInteger
    ): Deferred<TransactionReceipt> {
        val tokenContract = ERC20.load(
            tokenAddress,
            web3,
            txManager,
            gasProvider
        )
        return tokenContract.approve(destinationAddress, amount).sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.openOffer] method.
     *
     * @param id The ID of the new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be
     * opened.
     * @param offerStruct The [OfferStruct] containing the data of the new
     * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be opened.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun openOfferAsync(id: UUID, offerStruct: OfferStruct): Deferred<TransactionReceipt> {
        val iDByteBuffer = ByteBuffer.wrap(ByteArray(16))
        iDByteBuffer.putLong(id.mostSignificantBits)
        iDByteBuffer.putLong(id.leastSignificantBits)
        val iDByteArray = iDByteBuffer.array()
        return commutoSwap.openOffer(iDByteArray, offerStruct.toCommutoSwapOffer()).sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.cancelOffer] method.
     *
     * @param id The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be
     * canceled.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun cancelOfferAsync(id: UUID): Deferred<TransactionReceipt> {
        val iDByteBuffer = ByteBuffer.wrap(ByteArray(16))
        iDByteBuffer.putLong(id.mostSignificantBits)
        iDByteBuffer.putLong(id.leastSignificantBits)
        val iDByteArray = iDByteBuffer.array()
        return commutoSwap.cancelOffer(iDByteArray).sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.editOffer] method.
     *
     * @param offerID The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be
     * edited.
     * @param offerStruct The [OfferStruct] from which the [CommutoSwap.Offer] to be passed to
     * [editOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer) will be derived.
     */
    fun editOfferAsync(offerID: UUID, offerStruct: OfferStruct): Deferred<TransactionReceipt> {
        val iDByteBuffer = ByteBuffer.wrap(ByteArray(16))
        iDByteBuffer.putLong(offerID.mostSignificantBits)
        iDByteBuffer.putLong(offerID.leastSignificantBits)
        val iDByteArray = iDByteBuffer.array()

        val offer = CommutoSwap.Offer(
            offerStruct.isCreated,
            offerStruct.isTaken,
            offerStruct.maker,
            offerStruct.interfaceID,
            offerStruct.stablecoin,
            offerStruct.amountLowerBound,
            offerStruct.amountUpperBound,
            offerStruct.securityDepositAmount,
            offerStruct.serviceFeeRate,
            offerStruct.direction,
            offerStruct.settlementMethods,
            offerStruct.protocolVersion,
        )

        return commutoSwap.editOffer(
            iDByteArray,
            offer
        ).sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.takeOffer] method.
     *
     * @param id The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be taken.
     * @param swapStruct The [SwapStruct] containing data necessary to take the offer.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun takeOfferAsync(id: UUID, swapStruct: SwapStruct): Deferred<TransactionReceipt> {
        return commutoSwap.takeOffer(id.asByteArray(), swapStruct.toCommutoSwapSwap()).sendAsync().asDeferred()
    }

    /**
     * Uses the [CommutoSwap.getSwap] method and [Web3j.ethChainId] to get the current chain ID and all on-chain data
     * about the swap with the specified ID, and creates and returns an [SwapStruct] with the results.
     *
     * @param id The ID of the swap to return.
     *
     * @return A [SwapStruct] containing all on-chain data of the swap with the specified ID, or null if no such swap
     * exists.
     */
    suspend fun getSwap(id: UUID): SwapStruct? {
        val swap = commutoSwap.getSwap(id.asByteArray()).sendAsync().asDeferred()
        val chainID = web3.ethChainId().sendAsync().asDeferred()
        return SwapStruct.createFromGetSwapResponse(swap.await(), chainID.await().chainId)
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.fillSwap] method.
     *
     * @param id The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to be filled.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun fillSwapAsync(id: UUID): Deferred<TransactionReceipt> {
        return commutoSwap.fillSwap(id.asByteArray()).sendAsync().asDeferred()
    }

    /**
     * A [Deferred] wrapper around the [CommutoSwap.reportPaymentSent] method.
     *
     * @param id The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which to
     * report sending payment.
     *
     * @return A [Deferred] with a [TransactionReceipt] result.
     */
    fun reportPaymentSentAsync(id: UUID): Deferred<TransactionReceipt> {
        return commutoSwap.reportPaymentSent(id.asByteArray()).sendAsync().asDeferred()
    }

    /**
     * Parses the given [EthBlock.Block] in search of
     * [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol)
     * events, creates a list of all such events that it finds, and then calls
     * [handleEventResponses], passing said list of events. (Specifically, the events are
     * [BaseEventResponse]s)
     *
     * @param block The [EthBlock.Block] to be parsed.
     */
    private suspend fun parseBlock(block: EthBlock.Block) {
        val chainID = web3.ethChainId().sendAsync().await().chainId
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
        handleEventResponses(eventResponses, chainID)
    }

    /**
     * Awaits the given [Deferred] and gets event responses from the resulting
     * [EthGetTransactionReceipt].
     *
     * @param deferredReceiptOptional A [Deferred] with a [EthGetTransactionReceipt] result.
     *
     * @return A [List] of [BaseEventResponse]s present in the [EthGetTransactionReceipt] of
     * [deferredReceiptOptional].
     */
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

    /**
     * Parses a given [TransactionReceipt] in search of
     * [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol)
     * events, and returns any such events that are found.
     *
     * @param receipt The [TransactionReceipt] to parse.
     *
     * @return A [List] of [BaseEventResponse]s, which are CommutoSwap events.
     */
    private fun getEventResponsesFromReceipt(receipt: TransactionReceipt): List<BaseEventResponse> {
        val eventResponses: MutableList<List<BaseEventResponse>> = mutableListOf()
        if (receipt.to.equals(commutoSwap.contractAddress, ignoreCase = true)) {
            eventResponses.add(commutoSwap.getOfferOpenedEvents(receipt))
            eventResponses.add(commutoSwap.getOfferEditedEvents(receipt))
            eventResponses.add(commutoSwap.getOfferCanceledEvents(receipt))
            eventResponses.add(commutoSwap.getOfferTakenEvents(receipt))
            eventResponses.add(commutoSwap.getServiceFeeRateChangedEvents(receipt))
            eventResponses.add(commutoSwap.getSwapFilledEvents(receipt))
        }
        return eventResponses.flatten()
    }

    /**
     * Flattens and then iterates through [eventResponseLists] in search of relevant
     * [BaseEventResponse]s, and creates event objects and passes them to the proper service.
     *
     * @param eventResponseLists A [MutableList] of [List]s of [BaseEventResponse]s, which are
     * relevant events about which other services must be notified.
     */
    private suspend fun handleEventResponses(
        eventResponseLists: MutableList<List<BaseEventResponse>>,
        chainID: BigInteger
    ) {
        val eventResponses = eventResponseLists.flatten()
        Log.i(logTag, "handleEventResponses: handling ${eventResponses.size} events")
        for (eventResponse in eventResponses) {
            when (eventResponse) {
                is CommutoSwap.OfferOpenedEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling OfferOpenedEvent")
                    offerService.handleOfferOpenedEvent(OfferOpenedEvent.fromEventResponse(eventResponse, chainID))
                }
                is CommutoSwap.OfferEditedEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling OfferEditedEvent")
                    offerService.handleOfferEditedEvent(OfferEditedEvent.fromEventResponse(eventResponse, chainID))
                }
                is CommutoSwap.OfferCanceledEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling OfferCanceledEvent")
                    offerService.handleOfferCanceledEvent(OfferCanceledEvent.fromEventResponse(eventResponse, chainID))
                }
                is CommutoSwap.OfferTakenEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling OfferTakenEvent")
                    offerService.handleOfferTakenEvent(OfferTakenEvent.fromEventResponse(eventResponse, chainID))
                }
                is CommutoSwap.ServiceFeeRateChangedEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling ServiceFeeRateChangedEvent")
                    offerService.handleServiceFeeRateChangedEvent(
                        ServiceFeeRateChangedEvent.fromEventResponse(eventResponse)
                    )
                }
                is CommutoSwap.SwapFilledEventResponse -> {
                    Log.i(logTag, "handleEventResponses: handling SwapFilledEventResponse")
                    swapService.handleSwapFilledEvent(
                        SwapFilledEvent.fromEventResponse(eventResponse, chainID)
                    )
                }
            }
        }
    }

}