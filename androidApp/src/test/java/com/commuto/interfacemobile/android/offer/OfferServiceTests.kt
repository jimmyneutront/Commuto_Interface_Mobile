package com.commuto.interfacemobile.android.offer

import com.commuto.interfacedesktop.db.OfferOpenedEvent
import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import com.commuto.interfacemobile.android.blockchain.BlockchainEventRepository
import com.commuto.interfacemobile.android.blockchain.BlockchainExceptionNotifiable
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.database.DatabaseDriverFactory
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.ui.OffersViewModel
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
     * Ensure that [OfferService] handles
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

        class TestDatabaseService: DatabaseService(DatabaseDriverFactory()) {
            var storedDatabaseOfferOpenedEvent: OfferOpenedEvent? = null
            var wasDeleteOfferOpenedEventCalledCorrectly = false

            override suspend fun storeOfferOpenedEvent(id: String, interfaceId: String) {
                storedDatabaseOfferOpenedEvent = OfferOpenedEvent(id, interfaceId)
                super.storeOfferOpenedEvent(id, interfaceId)
            }

            override suspend fun deleteOfferOpenedEvents(id: String) {
                if (id == storedDatabaseOfferOpenedEvent!!.offerId) {
                    wasDeleteOfferOpenedEventCalledCorrectly = true
                }
                super.deleteOfferOpenedEvents(id)
            }
        }
        val databaseService = TestDatabaseService()
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

        val offerService = OfferService(databaseService, offerOpenedEventRepository)

        // TODO: Implement OfferTruthSource as in iOS, and then un-open OffersViewModel
        class TestOfferTruthSource: OffersViewModel(offerService) {
            val offersChannel = Channel<Offer>()
            override fun addOffer(offer: Offer) {
                super.addOffer(offer)
                runBlocking {
                    offersChannel.send(offer)
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
                assert(!exceptionHandler.gotError)
                assert(offerTruthSource.offers.size == 1)
                assert(offerTruthSource.offers[0].id == expectedOfferId)
                assert(Arrays.equals(offerOpenedEventRepository.appendedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(Arrays.equals(offerOpenedEventRepository.removedEventResponse!!.offerID,
                    expectedOfferIdByteArray))
                assert(databaseService.storedDatabaseOfferOpenedEvent!!.offerId == encoder
                    .encodeToString(expectedOfferIdByteArray))
                assert(databaseService.wasDeleteOfferOpenedEventCalledCorrectly)
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
                assertEquals(offerInDatabase.onChainPrice, encoder.encodeToString("a price here".encodeToByteArray()))
                assertEquals(offerInDatabase.protocolVersion, "1")
            }
        }
    }
}