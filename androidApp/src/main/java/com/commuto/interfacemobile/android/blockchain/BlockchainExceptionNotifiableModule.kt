package com.commuto.interfacemobile.android.blockchain

import com.commuto.interfacemobile.android.ui.ExceptionViewModel
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object
 * implementing [BlockchainExceptionNotifiable]
 */
@Module
@InstallIn(SingletonComponent::class)
interface BlockchainExceptionNotifiableModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [ExceptionViewModel] into objects
     * that depend on an object implementing [BlockchainExceptionNotifiable].
     *
     * @param impl The type of object that will be injected into objects that depend on an object
     * implementing [BlockchainExceptionNotifiable].
     */
    @Binds
    fun bindBlockchainExceptionNotifiable(impl: ExceptionViewModel): BlockchainExceptionNotifiable
}