package com.commuto.interfacemobile.android.p2p

import com.commuto.interfacemobile.android.offer.OfferService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object
 * implementing [OfferMessageNotifiable]
 */
@Module
@InstallIn(SingletonComponent::class)
interface OfferMessageNotifiableModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [OfferService] into objects
     * that depend on an object implementing [OfferMessageNotifiable].
     *
     * @param impl The type of object that will be injected into objects that depend on an object
     * implementing [OfferMessageNotifiable].
     */
    @Binds
    fun bindOfferNotifiable(impl: OfferService): OfferMessageNotifiable
}