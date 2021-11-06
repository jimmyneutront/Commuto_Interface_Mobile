package com.commuto.interfacemobile.dbService

import com.commuto.interfacemobile.db.DatabaseDriverFactory
import com.commuto.interfacemobile.db.KeyPair
import com.commuto.interfacemobile.db.PublicKey
import kotlin.test.*

class DBServiceTest {
    private var driver = DatabaseDriverFactory()
    private var dbService = DBService(driver)

    @BeforeTest
    fun testClearDatabase() {
        dbService.clearDatabase()
    }

    @Test
    fun testStoreAndGetKeyPair() {
        dbService.storeKeyPair("interf_id", "pub_key", "priv_key")
        val expectedKeyPair = KeyPair("interf_id", "pub_key", "priv_key")
        val keyPair: KeyPair? = dbService.getKeyPair("interf_id")
        assertEquals(keyPair!!, expectedKeyPair)
    }

    @Test
    fun testStoreAndGetPublicKey() {
        dbService.storePublicKey("interf_id", "pub_key")
        val expectedPublicKey = PublicKey("interf_id", "pub_key")
        val publicKey: PublicKey? = dbService.getPublicKey("interf_id")
        assertEquals(publicKey!!, expectedPublicKey)
    }

    @Test
    fun testDuplicateKeyPairProtection() {
        dbService.storeKeyPair("interf_id", "pub_key", "priv_key")
        try {
            dbService.storeKeyPair("interf_id", "pub_key", "priv_key")
        } catch (exception: IllegalStateException) {
            assert(exception.message!!.contains("Database query for key pair with interface id interf_id " +
                    "returned result"))
        }
    }

    @Test
    fun testDuplicatePublicKeyProtection() {
        dbService.storePublicKey("interf_id", "pub_key")
        try {
            dbService.storePublicKey("interf_id", "pub_key")
        } catch (exception: IllegalStateException) {
            assert(exception.message!!.contains("Database query for public key with interface id interf_id " +
                    "returned result"))
        }
    }
}