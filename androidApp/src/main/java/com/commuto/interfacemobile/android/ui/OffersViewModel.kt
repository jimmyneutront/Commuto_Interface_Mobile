package com.commuto.interfacemobile.android.ui

import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.offer.OfferService
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OffersViewModel @Inject constructor(val offerService: OfferService): ViewModel() {
}