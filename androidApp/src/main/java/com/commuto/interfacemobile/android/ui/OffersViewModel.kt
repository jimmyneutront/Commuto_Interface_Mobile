package com.commuto.interfacemobile.android.ui

import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.offer.Offer
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject

@Module
@InstallIn(SingletonComponent::class)
class OffersViewModel @Inject constructor(): ViewModel() {
    val offers = mutableStateOf(Offer.manySampleOffers)
}