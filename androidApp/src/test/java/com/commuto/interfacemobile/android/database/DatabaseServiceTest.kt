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
            "a_chain_id",
            0L,
            0L,
            "a_state_here"
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
            "another_chain_id",
            0L,
            0L,
            "a_state_here"
        )
        // This should do nothing and not throw
        databaseService.storeOffer(anotherOfferToStore)
        // This should not throw since only one such Offer should exist in the database
        val returnedOffer = databaseService.getOffer("a_uuid")
        assertEquals(returnedOffer, offerToStore)
        databaseService.deleteOffers("a_uuid", "a_chain_id")
        val returnedOfferAfterDeletion = databaseService.getOffer("a_uuid")
        assertEquals(null, returnedOfferAfterDeletion)
    }

    @Test
    fun testUpdateOfferHavePublicKey() = runBlocking {
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
            "a_chain_id",
            0L,
            0L,
            "a_state_here"
        )
        databaseService.storeOffer(offerToStore)
        databaseService.updateOfferHavePublicKey("a_uuid", "a_chain_id", true)
        val returnedOffer = databaseService.getOffer("a_uuid")
        assertEquals(returnedOffer!!.havePublicKey, 1L)
    }

    /**
     * Ensures that code to update a persistently stored [Offer.state] property works properly.
     */
    @Test
    fun testUpdateOfferState() = runBlocking {
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
            "a_chain_id",
            0L,
            0L,
            "a_state_here"
        )
        databaseService.storeOffer(offerToStore)
        databaseService.updateOfferState("a_uuid", "a_chain_id", "a_new_state_here")
        val returnedOffer = databaseService.getOffer("a_uuid")
        assertEquals(returnedOffer!!.state, "a_new_state_here")
    }

    @Test
    fun testStoreAndGetAndDeleteSettlementMethods() = runBlocking {
        val offerId = "an_offer_id"
        val chainID = "a_chain_id"
        val differentChainID = "different_chain_id"
        val settlementMethods = listOf(
            "settlement_method_zero",
            "settlement_method_one",
            "settlement_method_two",
        )
        databaseService.storeSettlementMethods(offerId, chainID, settlementMethods)
        databaseService.storeSettlementMethods(offerId, differentChainID, settlementMethods)
        val receivedSettlementMethods = databaseService.getSettlementMethods(offerId, chainID)!!
        assertEquals(receivedSettlementMethods.size, 3)
        assertEquals(receivedSettlementMethods[0], "settlement_method_zero")
        assertEquals(receivedSettlementMethods[1], "settlement_method_one")
        assertEquals(receivedSettlementMethods[2], "settlement_method_two")
        val newSettlementMethods = listOf(
            "settlement_method_three",
            "settlement_method_four",
            "settlement_method_five",
        )
        databaseService.storeSettlementMethods(offerId, chainID, newSettlementMethods)
        val newReturnedSettlementMethods = databaseService.getSettlementMethods(offerId, chainID)!!
        assertEquals(newReturnedSettlementMethods.size, 3)
        assertEquals(newReturnedSettlementMethods[0], "settlement_method_three")
        assertEquals(newReturnedSettlementMethods[1], "settlement_method_four")
        assertEquals(newReturnedSettlementMethods[2], "settlement_method_five")
        databaseService.deleteSettlementMethods(offerId, chainID)
        val returnedSettlementMethodsAfterDeletion = databaseService.getSettlementMethods(offerId, chainID)
        assertEquals(null, returnedSettlementMethodsAfterDeletion)
        val differentSettlementMethods = databaseService.getSettlementMethods(offerId, differentChainID)!!
        assertEquals(differentSettlementMethods.size, 3)
        assertEquals(differentSettlementMethods[0], "settlement_method_zero")
        assertEquals(differentSettlementMethods[1], "settlement_method_one")
        assertEquals(differentSettlementMethods[2], "settlement_method_two")
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