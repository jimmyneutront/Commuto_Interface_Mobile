package com.commuto.interfacemobile.android.key

import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.database.PreviewableDatabaseDriverFactory
import com.commuto.interfacemobile.android.key.keys.KeyPair
import com.commuto.interfacemobile.android.key.keys.PublicKey
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class KeyManagerServiceTests {

    private var driver = PreviewableDatabaseDriverFactory()
    private var databaseService = DatabaseService(driver)
    private val keyManagerService = KeyManagerService(databaseService)

    @Before
    fun testCreateTables() {
        databaseService.createTables()
    }

    @Test
    fun testGenerateAndRetrieveKeyPair() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair()
        val retrievedKeyPair: KeyPair? = keyManagerService.getKeyPair(keyPair.interfaceId)
        assert(keyPair.interfaceId.contentEquals(retrievedKeyPair!!.interfaceId))
        assertEquals(keyPair.keyPair.public, retrievedKeyPair.keyPair.public)
        assertEquals(keyPair.keyPair.private, retrievedKeyPair.keyPair.private)
    }

    @Test
    fun testStoreAndRetrievePubKey() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair(storeResult = false)
        val publicKey = PublicKey(keyPair.keyPair.public)
        keyManagerService.storePublicKey(publicKey)
        val retrievedPublicKey: PublicKey? = keyManagerService.getPublicKey(publicKey.interfaceId)
        assert(publicKey.interfaceId.contentEquals(retrievedPublicKey!!.interfaceId))
        assertEquals(publicKey.publicKey, retrievedPublicKey.publicKey)
    }

}