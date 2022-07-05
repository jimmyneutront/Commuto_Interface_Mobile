package com.commuto.interfacemobile.android.offer

import androidx.compose.runtime.mutableStateListOf
import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import com.commuto.interfacemobile.android.blockchain.BlockchainEventRepository
import com.commuto.interfacemobile.android.blockchain.BlockchainExceptionNotifiable
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.database.DatabaseDriverFactory
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.database.PreviewableDatabaseDriverFactory
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.okhttp.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import org.web3j.protocol.Web3j
import org.web3j.protocol.http.HttpService
import java.nio.ByteBuffer
import java.util.*

/**
 * Tests for [OfferService]
 */
class OfferServiceTests {

    @OptIn(ExperimentalCoroutinesApi::class)
    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    /**
     * Ensures that [OfferService] handles
     * [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events properly.
     */
    @Test
    fun testHandleOfferOpenedEvent()  {
        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val offerId: String)

        val testingServiceUrl = "http://localhost:8546/test_offerservice_handleOfferOpenedEvent"
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
                    parameters.append("events", "offer-opened")
                }
            }.body()
        }
        val expectedOfferId = UUID.fromString(testingServerResponse.offerId)
        val expectedOfferIdByteBuffer = ByteBuffer.wrap(ByteArray(16))
        expectedOfferIdByteBuffer.putLong(expectedOfferId.mostSignificantBits)
        expectedOfferIdByteBuffer.putLong(expectedOfferId.leastSignificantBits)
        val expectedOfferIdByteArray = expectedOfferIdByteBuffer.array()

        val w3 = Web3j.build(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()

        class TestBlockchainEventRepository: BlockchainEventRepository<CommutoSwap.OfferOpenedEventResponse>() {

            var appendedEventResponse: CommutoSwap.OfferOpenedEventResponse? = null
            var removedEventResponse: CommutoSwap.OfferOpenedEventResponse? = null

            override fun append(element: CommutoSwap.OfferOpenedEventResponse) {
                appendedEventResponse = element
                super.append(element)
            }

            override fun remove(elementToRemove: CommutoSwap.OfferOpenedEventResponse) {
                removedEventResponse = elementToRemove
                super.remove(elementToRemove)
            }

        }
        val offerOpenedEventRepository = TestBlockchainEventRepository()

        val offerService = OfferService(
            databaseService,
            offerOpenedEventRepository,
            BlockchainEventRepository(),
            BlockchainEventRepository(),
            BlockchainEventRepository(),
        )

        class TestOfferTruthSource: OfferTruthSource {
            init {
                offerService.setOfferTruthSource(this)
            }
            val offersChannel = Channel<Offer>()
            override var offers = mutableStateListOf<Offer>()
            override fun addOffer(offer: Offer) {
                offers.add(offer)
                runBlocking {
                    offersChannel.send(offer)
                }
            }

            override fun removeOffer(id: UUID) {
                throw IllegalStateException("TestOfferTruthSource.removeOffer should not be called here")
            }
        }
        val offerTruthSource = TestOfferTruthSource()

        class TestBlockchainExceptionHandler: BlockchainExceptionNotifiable {
            var gotError = false
            override fun handleBlockchainException(exception: Exception) {
                gotError = true
            }
        }
        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler,
            offerService,
            w3,
            testingServerResponse.commutoSwapAddress
        )
        blockchainService.listen()
        val encoder = Base64.getEncoder()
        runBlocking {
            withTimeout(60_000) {
                offerTruthSource.offersChannel.receive()
                assertFalse(exceptionHandler.gotError)
                assert(offerTruthSource.offers.size == 1)
                assert(offerTruthSource.offers[0].id == expectedOfferId)
                assert(Arrays.equals(offerOpenedEventRepository.appendedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(Arrays.equals(offerOpenedEventRepository.removedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                val offerInDatabase = databaseService.getOffer(encoder.encodeToString(expectedOfferIdByteArray))
                assert(offerInDatabase!!.isCreated == 1L)
                assert(offerInDatabase.isTaken == 0L)
                assertEquals(offerInDatabase.interfaceId, encoder.encodeToString("maker interface Id here"
                    .encodeToByteArray()))
                assertEquals(offerInDatabase.amountLowerBound, "10000")
                assertEquals(offerInDatabase.amountUpperBound, "10000")
                assertEquals(offerInDatabase.securityDepositAmount, "1000")
                assertEquals(offerInDatabase.serviceFeeRate, "100")
                assertEquals(offerInDatabase.onChainDirection, "1")
                assertEquals(offerInDatabase.protocolVersion, "1")
                val settlementMethodsInDatabase = databaseService.getSettlementMethods(encoder
                    .encodeToString(expectedOfferIdByteArray))
                assertEquals(settlementMethodsInDatabase!!.size, 1)
                assertEquals(settlementMethodsInDatabase[0], encoder.encodeToString("USD-SWIFT|a price here"
                    .encodeToByteArray()))
            }
        }
    }

    /**
     * Ensures that [OfferService] handles
     * [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) events properly.
     */
    @Test
    fun testHandleOfferCanceledEvent() {
        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val offerId: String)

        val testingServiceUrl = "http://localhost:8546/test_offerservice_handleOfferCanceledEvent"
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
                    parameters.append("events", "offer-opened-canceled")
                }
            }.body()
        }
        val expectedOfferId = UUID.fromString(testingServerResponse.offerId)
        val expectedOfferIdByteBuffer = ByteBuffer.wrap(ByteArray(16))
        expectedOfferIdByteBuffer.putLong(expectedOfferId.mostSignificantBits)
        expectedOfferIdByteBuffer.putLong(expectedOfferId.leastSignificantBits)
        val expectedOfferIdByteArray = expectedOfferIdByteBuffer.array()

        val w3 = Web3j.build(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()

        class TestBlockchainEventRepository: BlockchainEventRepository<CommutoSwap.OfferCanceledEventResponse>() {

            var appendedEventResponse: CommutoSwap.OfferCanceledEventResponse? = null
            var removedEventResponse: CommutoSwap.OfferCanceledEventResponse? = null

            override fun append(element: CommutoSwap.OfferCanceledEventResponse) {
                appendedEventResponse = element
                super.append(element)
            }

            override fun remove(elementToRemove: CommutoSwap.OfferCanceledEventResponse) {
                removedEventResponse = elementToRemove
                super.remove(elementToRemove)
            }

        }
        val offerCanceledEventRepository = TestBlockchainEventRepository()

        val offerService = OfferService(
            databaseService,
            BlockchainEventRepository(),
            BlockchainEventRepository(),
            offerCanceledEventRepository,
            BlockchainEventRepository(),
        )

        class TestOfferTruthSource: OfferTruthSource {
            init {
                offerService.setOfferTruthSource(this)
            }
            val offersChannel = Channel<Offer>()
            override var offers = mutableStateListOf<Offer>()

            override fun addOffer(offer: Offer) {
                offers.add(offer)
            }

            override fun removeOffer(id: UUID) {
                val offerToSend = offers.first {
                    it.id == id
                }
                offers.removeIf { it.id == id }
                runBlocking {
                    offersChannel.send(offerToSend)
                }
            }
        }
        val offerTruthSource = TestOfferTruthSource()

        class TestBlockchainExceptionHandler: BlockchainExceptionNotifiable {
            var gotError = false
            override fun handleBlockchainException(exception: Exception) {
                gotError = true
            }
        }
        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler,
            offerService,
            w3,
            testingServerResponse.commutoSwapAddress
        )
        blockchainService.listen()
        val encoder = Base64.getEncoder()
        runBlocking {
            withTimeout(60_000) {
                offerTruthSource.offersChannel.receive()
                assertFalse(exceptionHandler.gotError)
                assert(offerTruthSource.offers.isEmpty())
                assert(Arrays.equals(offerCanceledEventRepository.appendedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(Arrays.equals(offerCanceledEventRepository.removedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                val offerInDatabase = databaseService.getOffer(encoder.encodeToString(expectedOfferIdByteArray))
                assertEquals(offerInDatabase, null)
            }
        }
    }

    /**
     * Ensures that [OfferService] handles
     * [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events properly.
     */
    @Test
    fun testHandleOfferTakenEvent() {
        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val offerId: String)

        val testingServiceUrl = "http://localhost:8546/test_offerservice_handleOfferTakenEvent"
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
                }
            }.body()
        }
        val expectedOfferId = UUID.fromString(testingServerResponse.offerId)
        val expectedOfferIdByteBuffer = ByteBuffer.wrap(ByteArray(16))
        expectedOfferIdByteBuffer.putLong(expectedOfferId.mostSignificantBits)
        expectedOfferIdByteBuffer.putLong(expectedOfferId.leastSignificantBits)
        val expectedOfferIdByteArray = expectedOfferIdByteBuffer.array()

        val w3 = Web3j.build(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()

        class TestBlockchainEventRepository: BlockchainEventRepository<CommutoSwap.OfferTakenEventResponse>() {

            var appendedEventResponse: CommutoSwap.OfferTakenEventResponse? = null
            var removedEventResponse: CommutoSwap.OfferTakenEventResponse? = null

            override fun append(element: CommutoSwap.OfferTakenEventResponse) {
                appendedEventResponse = element
                super.append(element)
            }

            override fun remove(elementToRemove: CommutoSwap.OfferTakenEventResponse) {
                removedEventResponse = elementToRemove
                super.remove(elementToRemove)
            }

        }
        val offerTakenEventRepository = TestBlockchainEventRepository()

        val offerService = OfferService(
            databaseService,
            BlockchainEventRepository(),
            BlockchainEventRepository(),
            BlockchainEventRepository(),
            offerTakenEventRepository
        )

        class TestOfferTruthSource: OfferTruthSource {
            init {
                offerService.setOfferTruthSource(this)
            }
            val offersChannel = Channel<Offer>()
            override var offers = mutableStateListOf<Offer>()

            override fun addOffer(offer: Offer) {
                offers.add(offer)
            }

            override fun removeOffer(id: UUID) {
                val offerToSend = offers.first {
                    it.id == id
                }
                offers.removeIf { it.id == id }
                runBlocking {
                    offersChannel.send(offerToSend)
                }
            }
        }
        val offerTruthSource = TestOfferTruthSource()

        class TestBlockchainExceptionHandler: BlockchainExceptionNotifiable {
            var gotError = false
            override fun handleBlockchainException(exception: Exception) {
                gotError = true
            }
        }
        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler,
            offerService,
            w3,
            testingServerResponse.commutoSwapAddress
        )
        blockchainService.listen()
        val encoder = Base64.getEncoder()
        runBlocking {
            withTimeout(60_000) {
                offerTruthSource.offersChannel.receive()
                assertFalse(exceptionHandler.gotError)
                assert(offerTruthSource.offers.isEmpty())
                assert(Arrays.equals(offerTakenEventRepository.appendedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(Arrays.equals(offerTakenEventRepository.removedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                val offerInDatabase = databaseService.getOffer(encoder.encodeToString(expectedOfferIdByteArray))
                assertEquals(offerInDatabase, null)
            }
        }
    }

    /**
     * Ensures that [OfferService] handles
     * [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) events properly.
     */
    @Test
    fun handleOfferEditedEvent() {
        @Serializable
        data class TestingServerResponse(val commutoSwapAddress: String, val offerId: String)

        val testingServiceUrl = "http://localhost:8546/test_offerservice_handleOfferEditedEvent"
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
                    parameters.append("events", "offer-opened-edited")
                }
            }.body()
        }
        val expectedOfferId = UUID.fromString(testingServerResponse.offerId)
        val expectedOfferIdByteBuffer = ByteBuffer.wrap(ByteArray(16))
        expectedOfferIdByteBuffer.putLong(expectedOfferId.mostSignificantBits)
        expectedOfferIdByteBuffer.putLong(expectedOfferId.leastSignificantBits)
        val expectedOfferIdByteArray = expectedOfferIdByteBuffer.array()

        val w3 = Web3j.build(HttpService(System.getenv("BLOCKCHAIN_NODE")))

        val databaseService = DatabaseService(PreviewableDatabaseDriverFactory())
        databaseService.createTables()

        class TestBlockchainEventRepository: BlockchainEventRepository<CommutoSwap.OfferEditedEventResponse>() {

            var appendedEventResponse: CommutoSwap.OfferEditedEventResponse? = null
            var removedEventResponse: CommutoSwap.OfferEditedEventResponse? = null

            override fun append(element: CommutoSwap.OfferEditedEventResponse) {
                appendedEventResponse = element
                super.append(element)
            }

            override fun remove(elementToRemove: CommutoSwap.OfferEditedEventResponse) {
                removedEventResponse = elementToRemove
                super.remove(elementToRemove)
            }

        }
        val offerEditedEventRepository = TestBlockchainEventRepository()

        val offerService = OfferService(
            databaseService,
            BlockchainEventRepository(),
            offerEditedEventRepository,
            BlockchainEventRepository(),
            BlockchainEventRepository(),
        )

        class TestOfferTruthSource: OfferTruthSource {
            init {
                offerService.setOfferTruthSource(this)
            }
            val offersChannel = Channel<Offer>()
            var offersAddedCounter = 0
            override var offers = mutableStateListOf<Offer>()
            override fun addOffer(offer: Offer) {
                offersAddedCounter++
                offers.add(offer)
                if (offersAddedCounter == 2) {
                    // We only want to send the offer with the updated price, not the first one.
                    runBlocking {
                        offersChannel.send(offer)
                    }
                }
            }

            override fun removeOffer(id: UUID) {
                offers.removeIf { it.id == id }
            }
        }
        val offerTruthSource = TestOfferTruthSource()

        class TestBlockchainExceptionHandler: BlockchainExceptionNotifiable {
            var gotError = false
            override fun handleBlockchainException(exception: Exception) {
                gotError = true
            }
        }
        val exceptionHandler = TestBlockchainExceptionHandler()

        val blockchainService = BlockchainService(
            exceptionHandler,
            offerService,
            w3,
            testingServerResponse.commutoSwapAddress
        )
        blockchainService.listen()
        val encoder = Base64.getEncoder()
        runBlocking {
            withTimeout(60_000) {
                offerTruthSource.offersChannel.receive()
                assertFalse(exceptionHandler.gotError)
                assert(offerTruthSource.offers.size == 1)
                assert(offerTruthSource.offers[0].id == expectedOfferId)
                assert(Arrays.equals(offerEditedEventRepository.appendedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(Arrays.equals(offerEditedEventRepository.removedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                val offerInDatabase = databaseService.getOffer(encoder.encodeToString(expectedOfferIdByteArray))
                assert(offerInDatabase!!.isCreated == 1L)
                assert(offerInDatabase.isTaken == 0L)
                assertEquals(offerInDatabase.interfaceId, encoder.encodeToString("maker interface Id here"
                    .encodeToByteArray()))
                assertEquals(offerInDatabase.amountLowerBound, "10000")
                assertEquals(offerInDatabase.amountUpperBound, "10000")
                assertEquals(offerInDatabase.securityDepositAmount, "1000")
                assertEquals(offerInDatabase.serviceFeeRate, "100")
                assertEquals(offerInDatabase.onChainDirection, "1")
                assertEquals(offerInDatabase.protocolVersion, "1")
                val settlementMethodsInDatabase = databaseService.getSettlementMethods(encoder
                    .encodeToString(expectedOfferIdByteArray))
                assertEquals(settlementMethodsInDatabase!!.size, 1)
                assertEquals(settlementMethodsInDatabase[0], encoder.encodeToString("EUR-SEPA|an edited price here"
                    .encodeToByteArray()))
            }
        }
    }
}