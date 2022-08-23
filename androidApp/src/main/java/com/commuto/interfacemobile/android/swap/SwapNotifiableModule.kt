package com.commuto.interfacemobile.android.swap

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object implementing
 * [SwapNotifiable]
 */
@Module
@InstallIn(SingletonComponent::class)
interface SwapNotifiableModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [SwapService] into objects that depend on an object
     * implementing [SwapNotifiable].
     *
     * @param impl The type of object that will be injected into objects that depend on an object implementing
     * [SwapNotifiable].
     */
    @Binds
    fun bindSwapNotifiable(impl: SwapService): SwapNotifiable
}