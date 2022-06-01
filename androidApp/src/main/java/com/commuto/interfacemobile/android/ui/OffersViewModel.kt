package com.commuto.interfacemobile.android.ui

import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.offer.OfferService
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject

@Module
@InstallIn(SingletonComponent::class)
class OffersViewModel @Inject constructor(offerService: OfferService): ViewModel() {
    val offers = mutableStateOf(offerService.offers)
}