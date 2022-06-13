package com.commuto.interfacemobile.android.p2p

import javax.inject.Singleton

@Singleton
interface P2PExceptionNotifiable {
    fun handleP2PException(exception: Exception)
}