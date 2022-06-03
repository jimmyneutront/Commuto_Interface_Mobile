package com.commuto.interfacemobile.android.ui

import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.offer.OfferService
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OffersViewModel @Inject constructor(val offerService: OfferService): ViewModel()