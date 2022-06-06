package com.commuto.interfacemobile.android.p2p

import android.util.Base64
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test

class P2PServiceTest {
    @Test
    fun testP2PService() = runBlocking {
        val p2pService = P2PService()
        p2pService.listenLoop()
    }
}