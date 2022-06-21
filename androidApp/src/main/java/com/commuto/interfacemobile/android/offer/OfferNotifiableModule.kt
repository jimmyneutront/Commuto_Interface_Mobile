package com.commuto.interfacemobile.android.offer

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object
 * implementing [OfferNotifiable]
 */
@Module
@InstallIn(SingletonComponent::class)
interface OfferNotifiableModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [OfferService] into objects
     * that depend on an object implementing [OfferNotifiable].
     *
     * @param impl The type of object that will be injected into objects that depend on an object
     * implementing [OfferNotifiable].
     */
    @Binds
    fun bindOfferNotifiable(impl: OfferService): OfferNotifiable
}