package com.commuto.interfacemobile.android.database

import com.commuto.interfacedesktop.db.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class DatabaseServiceTest {
    private var driver = PreviewableDatabaseDriverFactory()
    private var databaseService = DatabaseService(driver)

    @Before
    fun testCreateTables() {
        databaseService.createTables()
    }

    @Test
    fun testStoreAndGetAndDeleteOffer() = runBlocking {
        val offerToStore = Offer(
            "a_uuid",
            1L,
            0L,
            "maker_address",
            "interface_id",
            "stablecoin_address",
            "lower_bound_amount",
            "upper_bound_amount",
            "security_deposit_amount",
            "service_fee_rate",
            "direction",
            "some_version",
        )
        databaseService.storeOffer(offerToStore)
        val anotherOfferToStore = Offer(
            "a_uuid",
            1L,
            0L,
            "another_maker_address",
            "another_interface_id",
            "another_stablecoin_address",
            "another_lower_bound_amount",
            "another_upper_bound_amount",
            "another_security_deposit_amount",
            "another_service_fee_rate",
            "opposite_direction",
            "some_other_version",
        )
        // This should do nothing and not throw
        databaseService.storeOffer(anotherOfferToStore)
        // This should not throw since only one such Offer should exist in the database
        val returnedOffer = databaseService.getOffer("a_uuid")
        assertEquals(returnedOffer, offerToStore)
        databaseService.deleteOffers("a_uuid")
        val returnedOfferAfterDeletion = databaseService.getOffer("a_uuid")
        assertEquals(null, returnedOfferAfterDeletion)
    }

    @Test
    fun testStoreAndGetAndDeleteSettlementMethods() = runBlocking {
        val offerId = "an_offer_id"
        val settlementMethods = listOf(
            "settlement_method_zero",
            "settlement_method_one",
            "settlement_method_two",
        )
        databaseService.storeSettlementMethods(offerId, settlementMethods)
        val receivedSettlementMethods = databaseService.getSettlementMethods(offerId)!!
        assertEquals(receivedSettlementMethods.size, 3)
        assertEquals(receivedSettlementMethods[0], "settlement_method_zero")
        assertEquals(receivedSettlementMethods[1], "settlement_method_one")
        assertEquals(receivedSettlementMethods[2], "settlement_method_two")
        val newSettlementMethods = listOf(
            "settlement_method_three",
            "settlement_method_four",
            "settlement_method_five",
        )
        databaseService.storeSettlementMethods(offerId, newSettlementMethods)
        val newReturnedSettlementMethods = databaseService.getSettlementMethods(offerId)!!
        assertEquals(newReturnedSettlementMethods.size, 3)
        assertEquals(newReturnedSettlementMethods[0], "settlement_method_three")
        assertEquals(newReturnedSettlementMethods[1], "settlement_method_four")
        assertEquals(newReturnedSettlementMethods[2], "settlement_method_five")
        databaseService.deleteSettlementMethods(offerId)
        val returnedSettlementMethodsAfterDeletion = databaseService.getSettlementMethods(offerId)
        assertEquals(null, returnedSettlementMethodsAfterDeletion)
    }

    @Test
    fun testStoreAndGetKeyPair() = runBlocking {
        databaseService.storeKeyPair("interf_id", "pub_key", "priv_key")
        val expectedKeyPair = KeyPair("interf_id", "pub_key", "priv_key")
        val keyPair: KeyPair? = databaseService.getKeyPair("interf_id")
        assertEquals(keyPair!!, expectedKeyPair)
    }

    @Test
    fun testStoreAndGetPublicKey() = runBlocking {
        databaseService.storePublicKey("interf_id", "pub_key")
        val expectedPublicKey = PublicKey("interf_id", "pub_key")
        val publicKey: PublicKey? = databaseService.getPublicKey("interf_id")
        assertEquals(publicKey!!, expectedPublicKey)
    }

    @Test
    fun testDuplicateKeyPairProtection(): Unit = runBlocking {
        databaseService.storeKeyPair("interf_id", "pub_key", "priv_key")
        // This should do nothing and not throw
        databaseService.storeKeyPair("interf_id", "another_pub_key", "another_priv_key")
        // This should not throw, since only one such key pair should exist in the database
        val keyPair = databaseService.getKeyPair("interf_id")
        assertEquals(keyPair!!.publicKey, "pub_key")
        assertEquals(keyPair.privateKey, "priv_key")
    }

    @Test
    fun testDuplicatePublicKeyProtection() = runBlocking {
        databaseService.storePublicKey("interf_id", "pub_key")
        // This should do nothing and not throw
        databaseService.storePublicKey("interf_id", "another_pub_key")
        // This should not throw, since only one such key pair should exist in the database
        val pubKey = databaseService.getPublicKey("interf_id")
        assertEquals(pubKey!!.publicKey, "pub_key")
    }

}