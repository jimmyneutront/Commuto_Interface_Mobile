package com.commuto.interfacemobile.android.swap

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.snapshots.SnapshotStateMap
import com.commuto.interfacemobile.android.blockchain.*
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacedesktop.db.Swap as DatabaseSwap
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.database.PreviewableDatabaseDriverFactory
import com.commuto.interfacemobile.android.extension.asByteArray
import com.commuto.interfacemobile.android.key.KeyManagerService
import com.commuto.interfacemobile.android.key.keys.KeyPair
import com.commuto.interfacemobile.android.key.keys.PublicKey
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.offer.OfferDirection
import com.commuto.interfacemobile.android.offer.OfferState
import com.commuto.interfacemobile.android.offer.TestOfferService
import com.commuto.interfacemobile.android.p2p.*
import com.commuto.interfacemobile.android.p2p.messages.MakerInformationMessage
import com.commuto.interfacemobile.android.p2p.messages.TakerInformationMessage
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.okhttp.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.Serializable
import net.folivo.trixnity.clientserverapi.client.MatrixClientServerApiClient
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.web3j.protocol.http.HttpService
import java.math.BigInteger
import java.util.*

/**
 * Tests for [SwapService]
 */
class SwapServiceTests {

    @OptIn(ExperimentalCoroutinesApi::class)
    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    /**
     * Ensure [SwapService] handles failed reporting payment sent transactions properly.
     */
    @Test
    fun testHandleFailedReportPaymentSentTransaction() = runBlocking {
        val swapID = UUID.randomUUID()

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapTruthSource = TestSwapTruthSource()

        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_SENT,
            role = SwapRole.MAKER_AND_BUYER,
        )
        val reportPaymentSentTransaction = BlockchainTransaction(
            transactionHash = "a_transaction_hash_here",
            timeOfCreation = Date(),
            latestBlockNumberAtCreation = BigInteger.ZERO,
            type = BlockchainTransactionType.REPORT_PAYMENT_SENT
        )
        swap.reportPaymentSentTransaction = reportPaymentSentTransaction
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )
        swapService.setSwapTruthSource(swapTruthSource)

        swapService.handleFailedTransaction(
            reportPaymentSentTransaction,
            exception = BlockchainTransactionException(message = "tx failed")
        )

        assertEquals(ReportingPaymentSentState.EXCEPTION, swap.reportingPaymentSentState.value)
        assertNotNull(swap.reportingPaymentSentException)
        val swapInDatabase = databaseService.getSwap(id = encoder.encodeToString(swapID.asByteArray()))
        assertEquals(ReportingPaymentSentState.EXCEPTION.asString, swapInDatabase!!.reportPaymentSentState)
    }

    /**
     * Ensure [SwapService] handles failed reporting payment received transactions properly.
     */
    @Test
    fun testHandleFailedReportPaymentReceivedTransaction() = runBlocking {
        val swapID = UUID.randomUUID()

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapTruthSource = TestSwapTruthSource()

        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_RECEIVED,
            role = SwapRole.TAKER_AND_SELLER,
        )
        val reportPaymentReceivedTransaction = BlockchainTransaction(
            transactionHash = "a_transaction_hash_here",
            timeOfCreation = Date(),
            latestBlockNumberAtCreation = BigInteger.ZERO,
            type = BlockchainTransactionType.REPORT_PAYMENT_RECEIVED
        )
        swap.reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )
        swapService.setSwapTruthSource(swapTruthSource)

        swapService.handleFailedTransaction(
            reportPaymentReceivedTransaction,
            exception = BlockchainTransactionException(message = "tx failed")
        )

        assertEquals(ReportingPaymentReceivedState.EXCEPTION, swap.reportingPaymentReceivedState.value)
        assertNotNull(swap.reportingPaymentReceivedException)
        val swapInDatabase = databaseService.getSwap(id = encoder.encodeToString(swapID.asByteArray()))
        assertEquals(ReportingPaymentReceivedState.EXCEPTION.asString, swapInDatabase!!.reportPaymentReceivedState)
    }

    /**
     * Ensure [SwapService] handles failed swap closing transactions properly.
     */
    @Test
    fun testHandleFailedCloseSwapTransaction() = runBlocking {
        val swapID = UUID.randomUUID()

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapTruthSource = TestSwapTruthSource()

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = true,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST,
            role = SwapRole.TAKER_AND_BUYER,
        )
        val closeSwapTransaction = BlockchainTransaction(
            transactionHash = "a_transaction_hash_here",
            timeOfCreation = Date(),
            latestBlockNumberAtCreation = BigInteger.ZERO,
            type = BlockchainTransactionType.CLOSE_SWAP
        )
        swap.closeSwapTransaction = closeSwapTransaction
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )
        swapService.setSwapTruthSource(swapTruthSource)

        swapService.handleFailedTransaction(
            closeSwapTransaction,
            exception = BlockchainTransactionException(message = "tx failed")
        )

        assertEquals(SwapState.AWAITING_CLOSING, swap.state.value)
        assertEquals(ClosingSwapState.EXCEPTION, swap.closingSwapState.value)
        assertNotNull(swap.closingSwapException)
        val swapInDatabase = databaseService.getSwap(id = encoder.encodeToString(swapID.asByteArray()))
        assertEquals(SwapState.AWAITING_CLOSING.asString, swapInDatabase!!.state)
        assertEquals(ClosingSwapState.EXCEPTION.asString, swapInDatabase.closeSwapState)
    }

    /**
     * Ensures that [SwapService] sends taker information correctly.
     */
    @Test
    fun testSendTakerInformation() = runBlocking {
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        // Set up SwapService
        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        // The ID of the swap for which taker information will be sent
        val swapID = UUID.randomUUID()

        /*
        The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to
        store the whole key pair persistently
         */
        val makerKeyPair = keyManagerService.generateKeyPair(storeResult = false)
        // We store the maker's public key, as if we received it via the P2P network
        keyManagerService.storePublicKey(makerKeyPair.getPublicKey())
        // This is the taker's (user's) key pair, so we do want to store it persistently
        val takerKeyPair = keyManagerService.generateKeyPair(storeResult = true)

        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = makerKeyPair.interfaceId,
            taker = "",
            takerInterfaceID = takerKeyPair.interfaceId,
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_TAKER_INFORMATION,
            role = SwapRole.TAKER_AND_SELLER,
        )
        swap.takerPrivateSettlementMethodData = "some_SWIFT_data"
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val p2pExceptionHandler = TestP2PExceptionHandler()
        val mxClient = MatrixClientServerApiClient(
            baseUrl = Url("https://matrix.org"),
        ).apply { accessToken.value = System.getenv("MXKY") }
        class TestP2PService: P2PService(
            exceptionHandler = p2pExceptionHandler,
            offerService = TestOfferMessageNotifiable(),
            swapService = TestSwapMessageNotifiable(),
            mxClient = mxClient,
            keyManagerService = keyManagerService,
        ) {
            var makerPublicKey: PublicKey? = null
            var takerKeyPair: KeyPair? = null
            var swapID: UUID? = null
            var settlementMethodDetails: String? = null
            override suspend fun sendTakerInformation(
                makerPublicKey: PublicKey,
                takerKeyPair: KeyPair,
                swapID: UUID,
                settlementMethodDetails: String?
            ) {
                this.makerPublicKey = makerPublicKey
                this.takerKeyPair = takerKeyPair
                this.swapID = swapID
                this.settlementMethodDetails = settlementMethodDetails
            }
        }
        val p2pService = TestP2PService()
        swapService.setP2PService(p2pService)

        val didSendTakerInfoMessage = swapService.sendTakerInformationMessage(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337L)
        )
        assert(didSendTakerInfoMessage)

        assert(makerKeyPair.interfaceId.contentEquals(p2pService.makerPublicKey!!.interfaceId))
        assert(takerKeyPair.interfaceId.contentEquals(p2pService.takerKeyPair!!.interfaceId))
        assertEquals(swapID, p2pService.swapID!!)
        assertEquals("some_SWIFT_data", p2pService.settlementMethodDetails!!)

        assertEquals(SwapState.AWAITING_MAKER_INFORMATION, swap.state.value)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(SwapState.AWAITING_MAKER_INFORMATION.asString, swapInDatabase!!.state)

    }

    /**
     * Ensures that [SwapService] handles new swaps made by the user of the interface properly.
     */
    @Test
    fun testHandleNewSwap() = runBlocking {
        val swapID = UUID.randomUUID()
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String)
        val testingServiceUrl = "http://localhost:8546/test_swapservice_handleNewSwap"
        val testingServerClient = HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json()
            }
            install(HttpTimeout) {
                socketTimeoutMillis = 90_000
                requestTimeoutMillis = 90_000
            }
        }
        val testingServerResponse: TestingServerResponse = runBlocking {
            testingServerClient.get(testingServiceUrl) {
                url {
                    parameters.append("events", "offer-opened-taken")
                    parameters.append("offerID", swapID.toString())
                }
            }.body()
        }

        val w3 = CommutoWeb3j(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        class TestSwapTruthSource: SwapTruthSource {
            var addedSwap: Swap? = null
            override var swaps: SnapshotStateMap<UUID, Swap> = mutableStateMapOf()
            override fun addSwap(swap: Swap) {
                swaps[swap.id] = swap
                addedSwap = swap
            }
        }
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler = exceptionHandler,
            offerService = TestOfferService(),
            swapService = swapService,
            web3 = w3,
            commutoSwapAddress = testingServerResponse.commutoSwapAddress
        )
        swapService.setBlockchainService(blockchainService)

        val offer = Offer(
            isCreated = true,
            isTaken = false,
            id = swapID,
            maker = "0x0000000000000000000000000000000000000000",
            interfaceID = ByteArray(0),
            stablecoin = "0x0000000000000000000000000000000000000000",
            amountLowerBound = BigInteger.valueOf(10000L),
            amountUpperBound = BigInteger.valueOf(10000L),
            securityDepositAmount = BigInteger.valueOf(1000L),
            serviceFeeRate = BigInteger.valueOf(100L),
            direction = OfferDirection.BUY,
            settlementMethods = mutableStateListOf(
                SettlementMethod(currency = "USD", price = "1.00", method = "SWIFT", privateData = "SWIFT_private_data")
            ),
            protocolVersion = BigInteger.valueOf(1),
            chainID = BigInteger.valueOf(31337L),
            havePublicKey = true,
            isUserMaker = true,
            state = OfferState.OFFER_OPENED
        )

        swapService.handleNewSwap(takenOffer = offer)

        assertEquals(swapID, swapTruthSource.addedSwap!!.id)

    }

    /**
     * Ensure that [SwapService] handles [TakerInformationMessage]s properly.
     */
    @Test
    fun testHandleTakerInformationMessage() = runBlocking {
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        // The ID of the swap for which taker information is being received
        val swapID = UUID.randomUUID()
        // The taker's key pair. Since we are the maker, this is NOT stored persistently.
        val takerKeyPair = KeyPair()
        // The maker's key pair. Since we are the maker, this is stored persistently
        val makerKeyPair = keyManagerService.generateKeyPair(storeResult = true)

        // The taker's information that the maker must handle
        val message = TakerInformationMessage(
            swapID = swapID,
            publicKey = takerKeyPair.getPublicKey(),
            settlementMethodDetails = "taker_settlement_method_details"
        )

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        val mxClient = MatrixClientServerApiClient(
            baseUrl = Url("https://matrix.org"),
        ).apply { accessToken.value = System.getenv("MXKY") }

        // A test P2PService that will allow us to get the maker information that will be sent
        class TestP2PService: P2PService(
            exceptionHandler = TestP2PExceptionHandler(),
            offerService = TestOfferMessageNotifiable(),
            swapService = swapService,
            mxClient = mxClient,
            keyManagerService = keyManagerService,
        ) {
            var takerPublicKey: PublicKey? = null
            var makerKeyPair: KeyPair? = null
            var swapID: UUID? = null
            var settlementMethodDetails: String? = null
            override suspend fun sendMakerInformation(
                takerPublicKey: PublicKey,
                makerKeyPair: KeyPair,
                swapID: UUID,
                settlementMethodDetails: String?
            ) {
                this.takerPublicKey = takerPublicKey
                this.makerKeyPair = makerKeyPair
                this.swapID = swapID
                this.settlementMethodDetails = settlementMethodDetails
            }
        }
        val p2pService = TestP2PService()

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.setSwapTruthSource(swapTruthSource)
        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = makerKeyPair.interfaceId,
            taker = "",
            takerInterfaceID = takerKeyPair.interfaceId,
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_TAKER_INFORMATION,
            role = SwapRole.MAKER_AND_SELLER,
        )
        swap.makerPrivateSettlementMethodData = "maker_settlement_method_details"
        swapTruthSource.addSwap(swap)
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = swap.makerPrivateSettlementMethodData,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        swapService.handleTakerInformationMessage(message)

        assert(takerKeyPair.interfaceId.contentEquals(p2pService.takerPublicKey!!.interfaceId))
        assert(makerKeyPair.interfaceId.contentEquals(p2pService.makerKeyPair!!.interfaceId))
        assertEquals(swapID, p2pService.swapID!!)
        assertEquals("maker_settlement_method_details", p2pService.settlementMethodDetails)

        // Ensure that SwapService updates swap state and taker private data in swapTruthSource
        assertEquals(SwapState.AWAITING_FILLING, swap.state.value)
        assertEquals("taker_settlement_method_details", swap.takerPrivateSettlementMethodData)

        // Ensure that SwapService persistently updates swap state and taker private data
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(SwapState.AWAITING_FILLING.asString, swapInDatabase!!.state)
        assertEquals("taker_settlement_method_details", swapInDatabase.takerPrivateData)
    }

    /**
     * Ensure that [SwapService] handles [MakerInformationMessage]s properly.
     */
    @Test
    fun testHandleMakerInformationMessage() = runBlocking {
        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        // The ID of the swap for which maker information is being received
        val swapID = UUID.randomUUID()
        // The maker's key pair. Since we are the taker, this is NOT stored persistently.
        val makerKeyPair = KeyPair()
        keyManagerService.storePublicKey(makerKeyPair.getPublicKey())
        // The taker's key pair. Since we are the taker, this is stored persistently
        val takerKeyPair = keyManagerService.generateKeyPair(storeResult = true)

        // The maker's information that the taker must handle
        val message = MakerInformationMessage(
            swapID = swapID,
            settlementMethodDetails = "maker_settlement_method_details",
        )

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.setSwapTruthSource(swapTruthSource)
        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = makerKeyPair.interfaceId,
            taker = "",
            takerInterfaceID = takerKeyPair.interfaceId,
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_MAKER_INFORMATION,
            role = SwapRole.TAKER_AND_BUYER
        )
        swap.makerPrivateSettlementMethodData = "maker_settlement_method_details"
        swapTruthSource.addSwap(swap)
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        swapService.handleMakerInformationMessage(
            message = message,
            senderInterfaceID = makerKeyPair.interfaceId,
            recipientInterfaceID = takerKeyPair.interfaceId,
        )

        assertEquals(SwapState.AWAITING_FILLING, swap.state.value)
        assertEquals("maker_settlement_method_details", swap.makerPrivateSettlementMethodData)

        // Ensure that SwapService persistently updates swap state
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(SwapState.AWAITING_FILLING.asString, swapInDatabase!!.state)
        assertEquals("maker_settlement_method_details", swapInDatabase.makerPrivateData)
    }

    /**
     * Ensures that [SwapService.fillSwap] and [BlockchainService.fillSwapAsync] function properly.
     */
    @Test
    fun testFillSwap() = runBlocking {
        val swapID = UUID.randomUUID()

        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val stablecoinAddress: String)
        val testingServiceUrl = "http://localhost:8546/test_swapservice_fillSwap"
        val testingServerClient = HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json()
            }
            install(HttpTimeout) {
                socketTimeoutMillis = 90_000
                requestTimeoutMillis = 90_000
            }
        }
        val testingServerResponse: TestingServerResponse = runBlocking {
            testingServerClient.get(testingServiceUrl){
                url {
                    parameters.append("events", "offer-opened-taken")
                    parameters.append("swapID", swapID.toString())
                }
            }.body()
        }

        val w3 = CommutoWeb3j(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler = exceptionHandler,
            offerService = TestOfferService(),
            swapService = swapService,
            web3 = w3,
            commutoSwapAddress = testingServerResponse.commutoSwapAddress
        )
        swapService.setBlockchainService(newBlockchainService = blockchainService)

        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = testingServerResponse.stablecoinAddress,
            amountLowerBound = BigInteger.valueOf(10_000L),
            amountUpperBound = BigInteger.valueOf(10_000L),
            securityDepositAmount = BigInteger.valueOf(1_000L),
            takenSwapAmount = BigInteger.valueOf(10_000L),
            serviceFeeAmount = BigInteger.valueOf(100L),
            serviceFeeRate = BigInteger.valueOf(100L),
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                  {
                      "f": "USD",
                      "p": "1.00",
                      "m": "SWIFT"
                  }
                  """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_FILLING,
            role = SwapRole.MAKER_AND_SELLER,
        )
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        swapService.fillSwap(swapToFill = swap)

        assertEquals(SwapState.FILL_SWAP_TRANSACTION_BROADCAST, swap.state.value)
        assertFalse(swap.requiresFill)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(0L, swapInDatabase!!.requiresFill)
        assertEquals(SwapState.FILL_SWAP_TRANSACTION_BROADCAST.asString, swapInDatabase.state)

    }

    /**
     * Ensure that [SwapService] handles [SwapFilledEvent]s properly.
     */
    @Test
    fun testHandleSwapFilledEvent() = runBlocking {
        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        // The ID of the swap being filled
        val swapID = UUID.randomUUID()

        val event = SwapFilledEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337)
        )

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)
        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                  {
                      "f": "USD",
                      "p": "1.00",
                      "m": "SWIFT"
                  }
                  """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_FILLING,
            role = SwapRole.MAKER_AND_SELLER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        swapService.handleSwapFilledEvent(event = event)

        assertEquals(SwapState.AWAITING_PAYMENT_SENT, swap.state.value)
        assertFalse(swap.requiresFill)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(SwapState.AWAITING_PAYMENT_SENT.asString, swapInDatabase!!.state)
        assertEquals(0L, swapInDatabase.requiresFill)

    }

    /**
     * Ensures that [BlockchainService.createReportPaymentSentTransaction],
     * [SwapService.createReportPaymentSentTransaction], [SwapService.reportPaymentSent] and
     * [BlockchainService.sendTransaction] function properly.
     */
    @Test
    fun testReportPaymentSent() = runBlocking {

        val swapID = UUID.randomUUID()

        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val stablecoinAddress: String)
        val testingServiceUrl = "http://localhost:8546/test_swapservice_reportPaymentSent"
        val testingServerClient = HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json()
            }
            install(HttpTimeout) {
                socketTimeoutMillis = 90_000
                requestTimeoutMillis = 90_000
            }
        }
        val testingServerResponse: TestingServerResponse = runBlocking {
            testingServerClient.get(testingServiceUrl){
                url {
                    parameters.append("events", "offer-opened-taken")
                    parameters.append("swapID", swapID.toString())
                }
            }.body()
        }

        val w3 = CommutoWeb3j(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler = exceptionHandler,
            offerService = TestOfferService(),
            swapService = swapService,
            web3 = w3,
            commutoSwapAddress = testingServerResponse.commutoSwapAddress
        )
        swapService.setBlockchainService(newBlockchainService = blockchainService)

        val swap = Swap(
            isCreated = true,
            requiresFill = true,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = testingServerResponse.stablecoinAddress,
            amountLowerBound = BigInteger.valueOf(10_000L),
            amountUpperBound = BigInteger.valueOf(10_000L),
            securityDepositAmount = BigInteger.valueOf(1_000L),
            takenSwapAmount = BigInteger.valueOf(10_000L),
            serviceFeeAmount = BigInteger.valueOf(100L),
            serviceFeeRate = BigInteger.valueOf(100L),
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
                  {
                      "f": "USD",
                      "p": "1.00",
                      "m": "SWIFT"
                  }
                  """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_SENT,
            role = SwapRole.MAKER_AND_BUYER,
        )
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val reportPaymentSentTransaction = swapService.createReportPaymentSentTransaction(
            swap = swap,
        )

        swapService.reportPaymentSent(
            swap = swap,
            reportPaymentSentTransaction = reportPaymentSentTransaction
        )

        assertEquals(ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION, swap.reportingPaymentSentState.value)
        assertEquals(SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST, swap.state.value)
        assertNotNull(swap.reportPaymentSentTransaction?.transactionHash)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION.asString,
            swapInDatabase?.reportPaymentSentState)
        assertEquals(SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST.asString, swapInDatabase?.state)
        assertNotNull(swapInDatabase?.reportPaymentSentTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [PaymentSentEvent]s properly for swaps in which the user of this interface is
     * the seller.
     */
    @Test
    fun testHandlePaymentSentEventForUserIsSeller() = runBlocking {
        // The ID of the swap for which payment is being sent
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
                  {
                      "f": "USD",
                      "p": "1.00",
                      "m": "SWIFT"
                  }
                  """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_SENT,
            role = SwapRole.TAKER_AND_SELLER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The PaymentSentEvent to be handled
        val event = PaymentSentEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "reporting_payment_sent_tx_hash"
        )

        swapService.handlePaymentSentEvent(event)

        // Ensure that SwapService updates swap state and isPaymentSent in swapTruthSource
        assert(swap.isPaymentSent)
        assertEquals(SwapState.AWAITING_PAYMENT_RECEIVED, swap.state.value)
        assertEquals("0xreporting_payment_sent_tx_hash", swap.reportPaymentSentTransaction?.transactionHash)

        // Ensure that SwapService updates swap state and isPaymentSent in persistent storage
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase!!.isPaymentSent)
        assertEquals(SwapState.AWAITING_PAYMENT_RECEIVED.asString, swapInDatabase.state)
        assertEquals("0xreporting_payment_sent_tx_hash", swapInDatabase.reportPaymentSentTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [PaymentSentEvent]s properly for swaps in which the user of this interface is
     * the buyer.
     */
    @Test
    fun testHandlePaymentSentEventForUserIsBuyer() = runBlocking {
        // The ID of the swap for which payment is being sent
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
                  {
                      "f": "USD",
                      "p": "1.00",
                      "m": "SWIFT"
                  }
                  """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = false,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_FILLING,
            role = SwapRole.MAKER_AND_BUYER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The PaymentSentEvent to be handled
        val event = PaymentSentEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "reporting_payment_sent_tx_hash"
        )

        swapService.handlePaymentSentEvent(event)

        // Ensure that SwapService updates swap state and isPaymentSent in swapTruthSource
        assert(swap.isPaymentSent)
        assertEquals(SwapState.AWAITING_PAYMENT_RECEIVED, swap.state.value)
        assertEquals(ReportingPaymentSentState.COMPLETED, swap.reportingPaymentSentState.value)

        // Ensure that SwapService updates swap state and isPaymentSent in persistent storage
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase!!.isPaymentSent)
        assertEquals(SwapState.AWAITING_PAYMENT_RECEIVED.asString, swapInDatabase.state)
        assertEquals(ReportingPaymentSentState.COMPLETED.asString, swapInDatabase.reportPaymentSentState)

    }

    /**
     * Ensures that [BlockchainService.createReportPaymentReceivedTransaction],
     * [SwapService.createReportPaymentReceivedTransaction], [SwapService.reportPaymentReceived] and
     * [BlockchainService.sendTransaction] function properly.
     */
    @Test
    fun testReportPaymentReceived() = runBlocking {

        val swapID = UUID.randomUUID()

        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val stablecoinAddress: String)
        val testingServiceUrl = "http://localhost:8546/test_swapservice_reportPaymentReceived"
        val testingServerClient = HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json()
            }
            install(HttpTimeout) {
                socketTimeoutMillis = 90_000
                requestTimeoutMillis = 90_000
            }
        }
        val testingServerResponse: TestingServerResponse = runBlocking {
            testingServerClient.get(testingServiceUrl){
                url {
                    parameters.append("events", "offer-opened-taken-PaymentSent")
                    parameters.append("swapID", swapID.toString())
                }
            }.body()
        }

        val w3 = CommutoWeb3j(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler = exceptionHandler,
            offerService = TestOfferService(),
            swapService = swapService,
            web3 = w3,
            commutoSwapAddress = testingServerResponse.commutoSwapAddress
        )
        swapService.setBlockchainService(newBlockchainService = blockchainService)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = testingServerResponse.stablecoinAddress,
            amountLowerBound = BigInteger.valueOf(10_000L),
            amountUpperBound = BigInteger.valueOf(10_000L),
            securityDepositAmount = BigInteger.valueOf(1_000L),
            takenSwapAmount = BigInteger.valueOf(10_000L),
            serviceFeeAmount = BigInteger.valueOf(100L),
            serviceFeeRate = BigInteger.valueOf(100L),
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
                    {
                        "f": "USD",
                        "p": "1.00",
                        "m": "SWIFT"
                    }
                    """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_RECEIVED,
            role = SwapRole.TAKER_AND_SELLER,
        )
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val reportPaymentReceivedTransaction = swapService.createReportPaymentReceivedTransaction(
            swap = swap,
        )

        swapService.reportPaymentReceived(
            swap = swap,
            reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
        )

        assertEquals(ReportingPaymentReceivedState.AWAITING_TRANSACTION_CONFIRMATION, swap.reportingPaymentReceivedState
            .value)
        assertEquals(SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST, swap.state.value)
        assertNotNull(swap.reportPaymentReceivedTransaction?.transactionHash)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(ReportingPaymentReceivedState.AWAITING_TRANSACTION_CONFIRMATION.asString,
            swapInDatabase?.reportPaymentReceivedState)
        assertEquals(SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST.asString, swapInDatabase?.state)
        assertNotNull(swapInDatabase?.reportPaymentReceivedTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [PaymentReceivedEvent]s properly for swaps in which the user of this interface
     * is the buyer.
     */
    @Test
    fun testHandlePaymentReceivedEventForUserIsBuyer() = runBlocking {
        // The ID of the swap for which payment is being sent
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                    {
                        "f": "USD",
                        "p": "1.00",
                        "m": "SWIFT"
                    }
                    """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST,
            role = SwapRole.TAKER_AND_BUYER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The PaymentReceivedEvent to be handled
        val event = PaymentReceivedEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "reporting_payment_received_tx_hash"
        )

        swapService.handlePaymentReceivedEvent(event)

        // Ensure that SwapService updates swap state and isPaymentReceived in swapTruthSource
        assert(swap.isPaymentReceived)
        assertEquals(SwapState.AWAITING_CLOSING, swap.state.value)
        assertEquals("0xreporting_payment_received_tx_hash", swap
            .reportPaymentReceivedTransaction?.transactionHash)

        // Ensure that SwapService updates swap state and isPaymentReceived in persistent storage
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase!!.isPaymentReceived)
        assertEquals(SwapState.AWAITING_CLOSING.asString, swapInDatabase.state)
        assertEquals("0xreporting_payment_received_tx_hash", swapInDatabase
            .reportPaymentReceivedTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [PaymentReceivedEvent]s properly for swaps in which the user of this interface
     * is the seller.
     */
    @Test
    fun testHandlePaymentReceivedEventForUserIsSeller() = runBlocking {
        // The ID of the swap for which payment is being sent
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
                    {
                        "f": "USD",
                        "p": "1.00",
                        "m": "SWIFT"
                    }
                    """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = false,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_PAYMENT_RECEIVED,
            role = SwapRole.MAKER_AND_SELLER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The PaymentReceivedEvent to be handled
        val event = PaymentReceivedEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "reporting_payment_received_tx_hash"
        )

        swapService.handlePaymentReceivedEvent(event)

        // Ensure that SwapService updates swap state and isPaymentReceived in swapTruthSource
        assert(swap.isPaymentReceived)
        assertEquals(SwapState.AWAITING_CLOSING, swap.state.value)
        assertEquals(ReportingPaymentReceivedState.COMPLETED, swap.reportingPaymentReceivedState.value)

        // Ensure that SwapService updates swap state and isPaymentReceived in persistent storage
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase!!.isPaymentReceived)
        assertEquals(SwapState.AWAITING_CLOSING.asString, swapInDatabase.state)
        assertEquals(ReportingPaymentReceivedState.COMPLETED.asString, swapInDatabase.reportPaymentReceivedState)

    }

    /**
     * Ensures that [BlockchainService.createCloseSwapTransaction],  [SwapService.createCloseSwapTransaction],
     * [SwapService.closeSwap] and [BlockchainService.sendTransaction] function properly.
     */
    @Test
    fun testCloseSwap() = runBlocking {

        val swapID = UUID.randomUUID()

        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val stablecoinAddress: String)
        val testingServiceUrl = "http://localhost:8546/test_swapservice_closeSwap"
        val testingServerClient = HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json()
            }
            install(HttpTimeout) {
                socketTimeoutMillis = 90_000
                requestTimeoutMillis = 90_000
            }
        }
        val testingServerResponse: TestingServerResponse = runBlocking {
            testingServerClient.get(testingServiceUrl){
                url {
                    parameters.append("events", "offer-opened-taken-PaymentSent-Received")
                    parameters.append("swapID", swapID.toString())
                }
            }.body()
        }

        val w3 = CommutoWeb3j(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler = exceptionHandler,
            offerService = TestOfferService(),
            swapService = swapService,
            web3 = w3,
            commutoSwapAddress = testingServerResponse.commutoSwapAddress
        )
        swapService.setBlockchainService(newBlockchainService = blockchainService)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = testingServerResponse.stablecoinAddress,
            amountLowerBound = BigInteger.valueOf(10_000L),
            amountUpperBound = BigInteger.valueOf(10_000L),
            securityDepositAmount = BigInteger.valueOf(1_000L),
            takenSwapAmount = BigInteger.valueOf(10_000L),
            serviceFeeAmount = BigInteger.valueOf(100L),
            serviceFeeRate = BigInteger.valueOf(100L),
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
                    {
                        "f": "USD",
                        "p": "1.00",
                        "m": "SWIFT"
                    }
                    """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = true,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_CLOSING,
            role = SwapRole.MAKER_AND_BUYER,
        )
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 1L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 0L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        val closeSwapTransaction = swapService.createCloseSwapTransaction(
            swap = swap,
        )

        swapService.closeSwap(
            swap = swap,
            closeSwapTransaction = closeSwapTransaction
        )

        assertEquals(ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION, swap.closingSwapState.value)
        assertEquals(SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST, swap.state.value)
        assertNotNull(swap.closeSwapTransaction?.transactionHash)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION.asString, swapInDatabase?.closeSwapState)
        assertEquals(SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST.asString, swapInDatabase?.state)
        assertNotNull(swapInDatabase?.closeSwapTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [BuyerClosedEvent]s properly for swaps in which the user of this interface is
     * the buyer. (Handling when the user is the seller is trivial, and thus not tested.)
     */
    @Test
    fun testHandleBuyerClosedEvent() = runBlocking {
        // The ID of the swap that the buyer has closed
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.BUY,
            onChainSettlementMethod =
            """
             {
                 "f": "USD",
                 "p": "1.00",
                 "m": "SWIFT"
             }
             """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = true,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.AWAITING_CLOSING,
            role = SwapRole.MAKER_AND_BUYER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 0L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The BuyerClosedEvent to be handled
        val event = BuyerClosedEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "close_swap_tx_hash"
        )

        swapService.handleBuyerClosedEvent(
            event = event,
        )

        assert(swap.hasBuyerClosed)
        assertEquals(SwapState.CLOSED, swap.state.value)
        assertEquals(ClosingSwapState.COMPLETED, swap.closingSwapState.value)
        assertEquals("0xclose_swap_tx_hash", swap.closeSwapTransaction?.transactionHash)

        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase?.hasBuyerClosed)
        assertEquals(SwapState.CLOSED.asString, swapInDatabase?.state)
        assertEquals(ClosingSwapState.COMPLETED.asString, swapInDatabase?.closeSwapState)
        assertEquals("0xclose_swap_tx_hash", swapInDatabase?.closeSwapTransactionHash)

    }

    /**
     * Ensure that [SwapService] handles [SellerClosedEvent]`s properly for swaps in which the user of this interface is
     * the seller. (Handling when the user is the buyer is trivial, and thus not tested.)
     */
    @Test
    fun testHandleSellerClosedEvent() = runBlocking {
        // The ID of the swap that the seller has closed
        val swapID = UUID.randomUUID()

        // Set up DatabaseService and KeyManagerService
        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()
        val keyManagerService = KeyManagerService(databaseService)

        val swapService = SwapService(
            databaseService = databaseService,
            keyManagerService = keyManagerService,
        )

        // Create swap, add it to swapTruthSource, and save it persistently
        val swapTruthSource = TestSwapTruthSource()
        // Provide swapTruthSource to swapService
        swapService.setSwapTruthSource(swapTruthSource)

        val swap = Swap(
            isCreated = true,
            requiresFill = false,
            id = swapID,
            maker = "",
            makerInterfaceID = ByteArray(0),
            taker = "",
            takerInterfaceID = ByteArray(0),
            stablecoin = "",
            amountLowerBound = BigInteger.ZERO,
            amountUpperBound = BigInteger.ZERO,
            securityDepositAmount = BigInteger.ZERO,
            takenSwapAmount = BigInteger.ZERO,
            serviceFeeAmount = BigInteger.ZERO,
            serviceFeeRate = BigInteger.ZERO,
            direction = OfferDirection.SELL,
            onChainSettlementMethod =
            """
             {
                 "f": "USD",
                 "p": "1.00",
                 "m": "SWIFT"
             }
             """.trimIndent().encodeToByteArray(),
            protocolVersion = BigInteger.ZERO,
            isPaymentSent = true,
            isPaymentReceived = true,
            hasBuyerClosed = false,
            hasSellerClosed = false,
            onChainDisputeRaiser = BigInteger.ZERO,
            chainID = BigInteger.valueOf(31337L),
            state = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST,
            role = SwapRole.MAKER_AND_SELLER,
        )
        swapTruthSource.swaps[swapID] = swap
        val encoder = Base64.getEncoder()
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(swapID.asByteArray()),
            isCreated = 1L,
            requiresFill = 0L,
            maker = swap.maker,
            makerInterfaceID = encoder.encodeToString(swap.makerInterfaceID),
            taker = swap.taker,
            takerInterfaceID = encoder.encodeToString(swap.takerInterfaceID),
            stablecoin = swap.stablecoin,
            amountLowerBound = swap.amountLowerBound.toString(),
            amountUpperBound = swap.amountUpperBound.toString(),
            securityDepositAmount = swap.securityDepositAmount.toString(),
            takenSwapAmount = swap.takenSwapAmount.toString(),
            serviceFeeAmount = swap.serviceFeeAmount.toString(),
            serviceFeeRate = swap.serviceFeeRate.toString(),
            onChainDirection = swap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(swap.onChainSettlementMethod),
            makerPrivateData = null,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = swap.protocolVersion.toString(),
            isPaymentSent = 1L,
            isPaymentReceived = 1L,
            hasBuyerClosed = 0L,
            hasSellerClosed = 0L,
            disputeRaiser = swap.onChainDisputeRaiser.toString(),
            chainID = swap.chainID.toString(),
            state = swap.state.value.asString,
            role = swap.role.asString,
            reportPaymentSentState = swap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime =  null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = swap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime =  null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = swap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)

        // The SellerClosedEvent to be handled
        val event = SellerClosedEvent(
            swapID = swapID,
            chainID = BigInteger.valueOf(31337),
            transactionHash = "close_swap_tx_hash"
        )

        swapService.handleSellerClosedEvent(
            event = event,
        )

        // Ensure that SwapService updates swap state and hasSellerClosed in swapTruthSource
        assert(swap.hasSellerClosed)
        assertEquals(SwapState.CLOSED, swap.state.value)
        assertEquals(ClosingSwapState.COMPLETED, swap.closingSwapState.value)
        assertEquals("0xclose_swap_tx_hash", swap.closeSwapTransaction?.transactionHash)

        // Ensure that SwapService updates swap state and hasSellerClosed in persistent storage
        val swapInDatabase = databaseService.getSwap(encoder.encodeToString(swapID.asByteArray()))
        assertEquals(1L, swapInDatabase?.hasSellerClosed)
        assertEquals(SwapState.CLOSED.asString, swapInDatabase?.state)
        assertEquals(ClosingSwapState.COMPLETED.asString, swapInDatabase?.closeSwapState)
        assertEquals("0xclose_swap_tx_hash", swapInDatabase?.closeSwapTransactionHash)

    }

}