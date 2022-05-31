package com.commuto.interfacemobile.android

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.compose.material.Text
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.ui.OffersComposable

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            OffersComposable(offers = Offer.sampleOffers)
        }
    }
}
