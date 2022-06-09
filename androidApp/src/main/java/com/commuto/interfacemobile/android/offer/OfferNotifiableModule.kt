package com.commuto.interfacemobile.android.offer

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
interface OfferNotifiableModule {
    @Binds
    fun bindOfferNotifiable(impl: OfferService): OfferNotifiable
}