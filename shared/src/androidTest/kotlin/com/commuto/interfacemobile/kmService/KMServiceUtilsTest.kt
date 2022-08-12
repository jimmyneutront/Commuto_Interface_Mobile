package com.commuto.interfacemobile.kmService

import androidx.test.core.app.ApplicationProvider
import com.commuto.interfacemobile.db.DatabaseDriverFactory
import com.commuto.interfacemobile.dbService.DBService
import com.commuto.interfacemobile.kmService.kmTypes.KeyPair
import com.commuto.interfacemobile.kmService.kmTypes.PublicKey
import com.commuto.interfacemobile.kmService.kmTypes.SymmetricKey
import com.commuto.interfacemobile.kmService.kmTypes.newSymmetricKey
import java.nio.charset.Charset
import java.security.PrivateKey
import java.security.PublicKey as JavaSecPublicKey
import java.util.Arrays
import kotlin.test.BeforeTest
import kotlin.test.Test

internal class KMServiceUtilsTest {

    private var driver = DatabaseDriverFactory(ApplicationProvider.getApplicationContext())
    private var dbService = DBService(driver)
    private val kmService = KMService(dbService)

    @BeforeTest
    fun testCreateTables() {
        dbService.createTables()
    }

    @Test
    fun testSymmetricEncryption() {
        val key: SymmetricKey = newSymmetricKey()
        val charset = Charset.forName("UTF-16")
        val originalData = "test".toByteArray(charset)
        val encryptedData = key.encrypt(originalData)
        assert(Arrays.equals(originalData, key.decrypt(encryptedData)))
    }

    @Test
    fun testSignatureUtils() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        val charset = Charset.forName("UTF-16")
        val signature = keyPair.sign("test".toByteArray(charset))
        assert(keyPair.verifySignature("test".toByteArray(charset), signature))
    }

    @Test
    fun testAsymmetricEncryption() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        val charset = Charset.forName("UTF-16")
        val originalString = "test"
        val originalMessage = originalString.toByteArray(charset)
        val encryptedMessage = keyPair.encrypt(originalMessage)
        val decryptedMessage = keyPair.decrypt(encryptedMessage)
        val restoredString = String(decryptedMessage, charset)
        assert(originalString.equals(restoredString))
    }

    @Test
    fun testPubKeyPkcs1Operations() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        val pubKeyPkcs1Bytes: ByteArray = keyPair.pubKeyToPkcs1Bytes()
        val restoredPubKey: JavaSecPublicKey = PublicKey(pubKeyPkcs1Bytes).publicKey
        assert(keyPair.keyPair.public.equals(restoredPubKey))
    }

    @Test
    fun testPrivKeyPkcs1Operations() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        val pubKeyPkcs1Bytes: ByteArray = keyPair.pubKeyToPkcs1Bytes()
        val privKeyPkcs1Bytes: ByteArray = keyPair.privKeyToPkcs1Bytes()
        val restoredKeyPair = KeyPair(pubKeyPkcs1Bytes, privKeyPkcs1Bytes)
        val restoredPrivKey: PrivateKey = restoredKeyPair.keyPair.private
        assert(keyPair.keyPair.private.equals(restoredPrivKey))
    }
}