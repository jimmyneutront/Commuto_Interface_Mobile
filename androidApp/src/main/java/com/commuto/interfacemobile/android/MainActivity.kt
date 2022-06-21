package com.commuto.interfacemobile.android

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import androidx.activity.compose.setContent
import com.commuto.interfacemobile.android.ui.OffersComposable
import com.commuto.interfacemobile.android.ui.OffersViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * The main Activity and entry point into the application.
 *
 * @property offersViewModel The [OffersViewModel] that acts as a single source of truth for all
 * offer-related data.
 */
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject
    lateinit var offersViewModel: OffersViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            OffersComposable(offersViewModel)
        }
    }
}
