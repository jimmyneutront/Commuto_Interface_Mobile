package com.commuto.interfacemobile.android.blockchain

import com.commuto.interfacemobile.android.ui.ExceptionViewModel
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
interface BlockchainExceptionNotifiableModule {
    @Binds
    fun bindBlockchainExceptionNotifiable(impl: ExceptionViewModel): BlockchainExceptionNotifiable
}