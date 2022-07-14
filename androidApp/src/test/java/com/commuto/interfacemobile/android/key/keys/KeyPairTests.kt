package com.commuto.interfacemobile.android.key.keys

import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.database.PreviewableDatabaseDriverFactory
import com.commuto.interfacemobile.android.key.KeyManagerService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.nio.charset.Charset

class KeyPairTests {

    private var driver = PreviewableDatabaseDriverFactory()
    private var databaseService = DatabaseService(driver)
    private val keyManagerService = KeyManagerService(databaseService)

    @Before
    fun testCreateTables() {
        databaseService.createTables()
    }

    @Test
    fun testSignatureUtils() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair(storeResult = false)
        val charset = Charset.forName("UTF-16")
        val signature = keyPair.sign("test".toByteArray(charset))
        assert(keyPair.verifySignature("test".toByteArray(charset), signature))
    }

    @Test
    fun testAsymmetricEncryptionWithKeyPair() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair(storeResult = false)
        val charset = Charset.forName("UTF-16")
        val originalString = "test"
        val originalMessage = originalString.toByteArray(charset)
        val encryptedMessage = keyPair.encrypt(originalMessage)
        val decryptedMessage = keyPair.decrypt(encryptedMessage)
        val restoredString = String(decryptedMessage, charset)
        assertEquals(originalString, restoredString)
    }

    @Test
    fun testPubKeyPkcs1Operations() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair(storeResult = false)
        val pubKeyPkcs1Bytes: ByteArray = keyPair.pubKeyToPkcs1Bytes()
        val restoredPubKey = PublicKey(pubKeyPkcs1Bytes)
        assertEquals(keyPair.keyPair.public, restoredPubKey.publicKey)
    }

    @Test
    fun testPrivKeyPkcs1Operations() = runBlocking {
        val keyPair: KeyPair = keyManagerService.generateKeyPair(storeResult = false)
        val pubKeyPkcs1Bytes: ByteArray = keyPair.pubKeyToPkcs1Bytes()
        val privKeyPkcs1Bytes: ByteArray = keyPair.privKeyToPkcs1Bytes()
        val restoredKeyPair = KeyPair(pubKeyPkcs1Bytes, privKeyPkcs1Bytes)
        assertEquals(keyPair.keyPair.private, restoredKeyPair.keyPair.private)
    }

}