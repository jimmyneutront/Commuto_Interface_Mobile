package com.commuto.interfacemobile.android.p2p

import com.commuto.interfacemobile.android.offer.OfferService
import com.commuto.interfacemobile.android.swap.SwapService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object implementing
 * [SwapMessageNotifiable]
 */
@Module
@InstallIn(SingletonComponent::class)
interface SwapMessageNotifiableModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [SwapService] into objects that depend on an object
     * implementing [SwapMessageNotifiable].
     *
     * @param impl The type of object that will be injected into objects that depend on an object implementing
     * [SwapMessageNotifiable].
     */
    @Binds
    fun bindSwapNotifiable(impl: SwapService): SwapMessageNotifiable
}