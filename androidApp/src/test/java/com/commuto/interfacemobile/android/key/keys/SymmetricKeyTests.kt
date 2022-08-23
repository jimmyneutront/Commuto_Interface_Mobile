package com.commuto.interfacemobile.android.key.keys

import org.junit.Test
import java.nio.charset.Charset

class SymmetricKeyTests {

    @Test
    fun testSymmetricEncryption() {
        val key: SymmetricKey = newSymmetricKey()
        val charset = Charset.forName("UTF-16")
        val originalData = "test".toByteArray(charset)
        val encryptedData = key.encrypt(originalData)
        assert(originalData.contentEquals(key.decrypt(encryptedData)))
    }

}