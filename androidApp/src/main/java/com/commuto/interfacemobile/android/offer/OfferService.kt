package com.commuto.interfacemobile.android.offer

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject

@Module
@InstallIn(SingletonComponent::class)
class OfferService @Inject constructor() {
    val offers = Offer.manySampleOffers
}