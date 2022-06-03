package com.commuto.interfacemobile.android.offer

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfferService @Inject constructor() {
    val offers = Offer.manySampleOffers
    private val scope = CoroutineScope(Dispatchers.Default)
}