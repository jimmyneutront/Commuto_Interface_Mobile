package com.commuto.interfacemobile.kmService

import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import com.commuto.interfacemobile.db.DatabaseDriverFactory
import com.commuto.interfacemobile.dbService.DBService
import com.commuto.interfacemobile.kmService.kmTypes.KeyPair
import com.commuto.interfacemobile.kmService.kmTypes.PublicKey
import java.nio.charset.Charset
import java.security.KeyPair as JavaSecKeyPair
import java.security.PrivateKey
import java.security.PublicKey as JavaSecPubKey
import kotlin.test.Test

/**
 * Prints keys in B64 String format for compatibility testing, and tests the re-creation of key objects given keys in
 * B64 String format saved on other platforms.
 */
class XPlatCryptoCompatibility {

    private var driver = DatabaseDriverFactory(ApplicationProvider.getApplicationContext())
    private var dbService = DBService(driver)
    private val kmService = KMService(dbService)

    /**
     * Prints a signature, original message and public key in Base64 format
     */
    @Test
    fun testPrintSignature() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        println("Signed Data B64:\n" + Base64.encodeToString("test".toByteArray(Charset.forName("UTF-16")), Base64.DEFAULT))
        println("Public Key B64:")
        println(Base64.encodeToString(kmService
            .pubKeyToPkcs1Bytes(keyPair.keyPair.public), Base64.DEFAULT))
        val signature = keyPair.sign("test".toByteArray(Charset.forName("UTF-16")))
        println("Signature:\n" + Base64.encodeToString(signature, Base64.DEFAULT))
    }

    /**
     * Verifies a signature using an original message and public key, all given in Base64 format
     */
    @Test
    fun testVerifySignature() {
        var signedData = Base64.decode("//50AGUAcwB0AA==", Base64.DEFAULT)
        val pubKeyB64 = "MIIBCgKCAQEAnvuNlBeukUvDiF76DoNoNuhV8llOq6R2fdECyNCC1MrDmXZlShyn2NrPq6/W0tJi3PsSNopSv6He12d7Le4I0/umKpxJxEg5iJ4zm3Xthd6EaFkwPyqa+7E0ZeFOo0wcDThdRZ/5UzQQmnBwua8xCFZrxQVLY8h/eoucQQ6MJknF6iAk4fFSic5Pa8SeIJeQBjO+dmje/+POCmlMBFmhLBVJA5QG+eI7WEa274On7bxIHeMK0zx673kfLADwBTHHS10oKDaGi5Pn2hGUf4Ksihv6yI+GDJJI0uemESi1J95e2NXXlPHqqteJKUzEAENh0QXHg97XJhhJtNV7gh/60wIDAQAB"
        var signatureB64 = "D74DCCZFlsjRifmyKmGYo7qpYyxoGOEgNJ8+f0E+lg7DEI5TLFurk1Z+bwlS8tj9M6FxNjJED6iVMiHGGJREmFYrgvIJZbl+bgurDcHL2hO2xR6GOoOoBpmAoi7UiPeC5eGN2+lK9IiNKWx3XbSsGiBW0ysuZzcPyVmDE2jK1j3ZXi26BMFvkXBCQbmrQaJ9ApxKF6hkZtT4eKBvcu0K6kNAYTRrA90af5yt0TFf2aPhp9XFMlYBF1nSjG4CBQrrXIR/qK7MC+VfUJ4tvRjF0W7pwCHjIUxczfUtx1uldY7aMnYmpcfEuKi4O/QGEMWMr/JGEgpWnKl2zCjTqNYXzw=="
        val pubKey: JavaSecPubKey = kmService
            .pubKeyFromPkcs1Bytes(Base64.decode(pubKeyB64, Base64.DEFAULT))
        val wrappedPubKey = PublicKey(pubKey)
        var signature = Base64.decode(signatureB64, Base64.DEFAULT)
        assert(wrappedPubKey.verifySignature(signedData, signature))
    }

    /**
     * Prints keys according to KMService's specification in B64 format, as well as an original
     * message string and the encrypted message, also in B64 format, for cross platform
     * compatibility testing
     */
    @Test
    fun testPrintEncryptedMessage() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        println("Public Key B64:")
        println(Base64.encodeToString(kmService
            .pubKeyToPkcs1Bytes(keyPair.keyPair.public), Base64.DEFAULT))
        println("Private Key B64:")
        println(Base64.encodeToString(kmService
            .privKeyToPkcs1Bytes(keyPair.keyPair.private), Base64.DEFAULT))
        val originalMessage = "test"
        println("Original Message:\n" + originalMessage)
        println("Encrypted Message:")
        println(Base64.encodeToString(keyPair.encrypt(originalMessage
            .toByteArray(Charset.forName("UTF-16"))), Base64.DEFAULT))
    }

    /**
     * Uses the given public and private key strings to restore a KeyPair object and decrypt the
     * given message, ensuring it matches the original message.
     */
    @Test
    fun testDecryptMessage() {
        val originalMessage = "test"
        val pubKeyB64 = "MIIBCgKCAQEA6nRs5aMeFg2TIxbhH6MMh946mZ35sP5d27J+Fm1ha1IZlz9+Z7Knw7FOJ827BhLLcaeHCSI3/opnWc1TKPD6exArNZQsJLSWXJeLfBOm/zseKJyCr9PHahhQYBD3X6HfuZYqzUV4B/BZSu5cJbcvgqTsSbnR7tlRscwW32m1l/jWixLrsmE3zBg0SWBDtZ8ouOMJJ5ZSS6MXJeQUfzyrEIhc8cABpI8MFsVL82UYPdXxGvQ86AUnNMnEDGWtGvUvYqzcWCuLNpcSkx5y9+VKdnC7zevLJbuj0fyjjBadAkMc6jNcgeaGJSsWxbtKC11CawMWPuXuckzIRsAJUYFnhQIDAQAB"
        val privKeyB64 = "MIIEogIBAAKCAQEA6nRs5aMeFg2TIxbhH6MMh946mZ35sP5d27J+Fm1ha1IZlz9+Z7Knw7FOJ827BhLLcaeHCSI3/opnWc1TKPD6exArNZQsJLSWXJeLfBOm/zseKJyCr9PHahhQYBD3X6HfuZYqzUV4B/BZSu5cJbcvgqTsSbnR7tlRscwW32m1l/jWixLrsmE3zBg0SWBDtZ8ouOMJJ5ZSS6MXJeQUfzyrEIhc8cABpI8MFsVL82UYPdXxGvQ86AUnNMnEDGWtGvUvYqzcWCuLNpcSkx5y9+VKdnC7zevLJbuj0fyjjBadAkMc6jNcgeaGJSsWxbtKC11CawMWPuXuckzIRsAJUYFnhQIDAQABAoIBAA9uB5pU/J58w2LzDHBUVEy0eFH9UVOPvgC+3mjz8bjKKlh89iugGJs6q0HX2o0zsJ4Y0CcupcA+VBRsfKKsZKkI30sd/AoTX3TrB/lBDYPCcdbq4U1DMwkdXgbLKbiVEuqoF8YyzPY6yr7xcRuN/YC2gWgjDvj45j/nsQFVjT0EeWednEDhqPlo1FWMFrH0woLOTRVRhzemlrMxsxhFxc/Tvr4kJtnmacOT9+am82Fn5eOelg+Dafms6G6z+8r/EQmaiLUeXwzQYinQWpLL5jEbVEbRz4fZhBXaz++D8uK9lzF/N1Quv31V5OtHLtBAGe17OibarP9bPwLbg2knilkCgYEA9R8cYI8E6umr2TEyCUNxfpFv1XkdyTTZNv0H/ZIRh5qUVg84r/VCUguPaIq4nbmOngskgpaiwx1kYGAmJCabHV3L20yEztLAOtltBQFoTodaz6Apkws4gyharg7dQ1Z75RqZTfdHSiKZwO0Ihu4EkTEPTdY6/+wzZnt31Kzf2O0CgYEA9Nwgfra6QHw1AN5QkfYUxHqRKuPWrJoYwupwl3g+VGW7NfbrCOS/VcezdBzIgvuz5AOIEQxkNPf61kjKS6/t+/V2XE76qGV5tQ5B0Mdgm8eViAT6IoTNl2YPFZhgJizEMJ5ybGWC2Q+8hnPOBmvh1u+pQ/mG8nWGXAF9qHVE7fkCgYBUbmjp4ZmCCQcGgumHQ1HelN3+m/9khO2lATc1YpDjMp2RnyCZi1NSy2SUT+QTgAzd51ymFpjtuDwQ7k10+k9HqD1Fxm+ghftsyePBa6CwG/NtvO9VFPJcSxQhDEGupiV63tSbhGdr48suJvde8rFkCZAJ8ZbU/FkgHbtC6GEaaQKBgB2z7kUwyVs1NgDK9x8dqNtEuwNm7A24C7TpV4soTPdT9+fN8ij8BrHTLdOyAijRe7r3KrRWunkqc8U2w0N3LflYh2kfM4zl8mOiPR2kcfWzulHruKQjVAU/nijSeSdoWsxDDEJV9g96tzXgKmfhAl5eaDwUsugKlafnjmS3BQuRAoGAZp6D6LIndvr6t4025GgepDYXjcFU/irPHi6WR3LOimJouQHIB56gWRxEVmiS4/k02GmgZIpAtEpHEHcz6svCzgI8ZKzk5+P91wqNpO8TfS1O2Nl9RO+/zBxIAnbkf6TxCbo5JhVtClWCFLIXOqzE7baQOi4aMjXk1rzOQNeu9vQ="
        val encryptedMessageB64 = "test"
        val pubKey: JavaSecPubKey = kmService
            .pubKeyFromPkcs1Bytes(Base64.decode(pubKeyB64, Base64.DEFAULT))
        val privKey: PrivateKey = kmService
            .privKeyFromPkcs1Bytes(Base64.decode(privKeyB64, Base64.DEFAULT))
        val javaSecKeyPair = JavaSecKeyPair(pubKey, privKey)
        val keyPair = KeyPair(javaSecKeyPair)
        val encryptedMessageBytes = Base64.decode(encryptedMessageB64, Base64.DEFAULT)
        val decryptedMessageBytes = keyPair.decrypt(encryptedMessageBytes)
        val decryptedMessage = String(decryptedMessageBytes, Charset.forName("UTF-16"))
        assert(originalMessage.equals(decryptedMessage))
    }

    /**
     * Prints keys according to KMService's specification in B64 format, so that they can be pasted into
     * testRestoreRSAKeysFromB64() on other platforms, to ensure that keys saved on any platform can be read on any
     * other.
     */
    @Test
    fun testGenB64RSAKeys() {
        val keyPair: KeyPair = kmService.generateKeyPair(storeResult = false)
        println("Public Key B64:")
        println(Base64.encodeToString(kmService
            .pubKeyToPkcs1Bytes(keyPair.keyPair.public), Base64.DEFAULT))
        println("Private Key B64:")
        println(Base64.encodeToString(kmService
            .privKeyToPkcs1Bytes(keyPair.keyPair.private), Base64.DEFAULT))
    }

    /**
     * Attempts to restore keys according to KMService's specification given in B64 format, to ensure that keys saved on
     * other platforms can be restored to key objects on this platform.
     */
    @Test
    fun testRestoreRSAKeysFromB64() {
        val pubKeyB64 = "MIIBCgKCAQEA6nRs5aMeFg2TIxbhH6MMh946mZ35sP5d27J+Fm1ha1IZlz9+Z7Knw7FOJ827BhLLcaeHCSI3/opnWc1TKPD6exArNZQsJLSWXJeLfBOm/zseKJyCr9PHahhQYBD3X6HfuZYqzUV4B/BZSu5cJbcvgqTsSbnR7tlRscwW32m1l/jWixLrsmE3zBg0SWBDtZ8ouOMJJ5ZSS6MXJeQUfzyrEIhc8cABpI8MFsVL82UYPdXxGvQ86AUnNMnEDGWtGvUvYqzcWCuLNpcSkx5y9+VKdnC7zevLJbuj0fyjjBadAkMc6jNcgeaGJSsWxbtKC11CawMWPuXuckzIRsAJUYFnhQIDAQAB"
        val privKeyB64 = "MIIEogIBAAKCAQEA6nRs5aMeFg2TIxbhH6MMh946mZ35sP5d27J+Fm1ha1IZlz9+Z7Knw7FOJ827BhLLcaeHCSI3/opnWc1TKPD6exArNZQsJLSWXJeLfBOm/zseKJyCr9PHahhQYBD3X6HfuZYqzUV4B/BZSu5cJbcvgqTsSbnR7tlRscwW32m1l/jWixLrsmE3zBg0SWBDtZ8ouOMJJ5ZSS6MXJeQUfzyrEIhc8cABpI8MFsVL82UYPdXxGvQ86AUnNMnEDGWtGvUvYqzcWCuLNpcSkx5y9+VKdnC7zevLJbuj0fyjjBadAkMc6jNcgeaGJSsWxbtKC11CawMWPuXuckzIRsAJUYFnhQIDAQABAoIBAA9uB5pU/J58w2LzDHBUVEy0eFH9UVOPvgC+3mjz8bjKKlh89iugGJs6q0HX2o0zsJ4Y0CcupcA+VBRsfKKsZKkI30sd/AoTX3TrB/lBDYPCcdbq4U1DMwkdXgbLKbiVEuqoF8YyzPY6yr7xcRuN/YC2gWgjDvj45j/nsQFVjT0EeWednEDhqPlo1FWMFrH0woLOTRVRhzemlrMxsxhFxc/Tvr4kJtnmacOT9+am82Fn5eOelg+Dafms6G6z+8r/EQmaiLUeXwzQYinQWpLL5jEbVEbRz4fZhBXaz++D8uK9lzF/N1Quv31V5OtHLtBAGe17OibarP9bPwLbg2knilkCgYEA9R8cYI8E6umr2TEyCUNxfpFv1XkdyTTZNv0H/ZIRh5qUVg84r/VCUguPaIq4nbmOngskgpaiwx1kYGAmJCabHV3L20yEztLAOtltBQFoTodaz6Apkws4gyharg7dQ1Z75RqZTfdHSiKZwO0Ihu4EkTEPTdY6/+wzZnt31Kzf2O0CgYEA9Nwgfra6QHw1AN5QkfYUxHqRKuPWrJoYwupwl3g+VGW7NfbrCOS/VcezdBzIgvuz5AOIEQxkNPf61kjKS6/t+/V2XE76qGV5tQ5B0Mdgm8eViAT6IoTNl2YPFZhgJizEMJ5ybGWC2Q+8hnPOBmvh1u+pQ/mG8nWGXAF9qHVE7fkCgYBUbmjp4ZmCCQcGgumHQ1HelN3+m/9khO2lATc1YpDjMp2RnyCZi1NSy2SUT+QTgAzd51ymFpjtuDwQ7k10+k9HqD1Fxm+ghftsyePBa6CwG/NtvO9VFPJcSxQhDEGupiV63tSbhGdr48suJvde8rFkCZAJ8ZbU/FkgHbtC6GEaaQKBgB2z7kUwyVs1NgDK9x8dqNtEuwNm7A24C7TpV4soTPdT9+fN8ij8BrHTLdOyAijRe7r3KrRWunkqc8U2w0N3LflYh2kfM4zl8mOiPR2kcfWzulHruKQjVAU/nijSeSdoWsxDDEJV9g96tzXgKmfhAl5eaDwUsugKlafnjmS3BQuRAoGAZp6D6LIndvr6t4025GgepDYXjcFU/irPHi6WR3LOimJouQHIB56gWRxEVmiS4/k02GmgZIpAtEpHEHcz6svCzgI8ZKzk5+P91wqNpO8TfS1O2Nl9RO+/zBxIAnbkf6TxCbo5JhVtClWCFLIXOqzE7baQOi4aMjXk1rzOQNeu9vQ="
        val pubKey: JavaSecPubKey = kmService
            .pubKeyFromPkcs1Bytes(Base64.decode(pubKeyB64, Base64.DEFAULT))
        val privKey: PrivateKey = kmService
            .privKeyFromPkcs1Bytes(Base64.decode(privKeyB64, Base64.DEFAULT))
    }
}