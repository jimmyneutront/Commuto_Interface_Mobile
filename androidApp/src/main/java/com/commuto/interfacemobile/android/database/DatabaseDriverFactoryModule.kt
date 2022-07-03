package com.commuto.interfacemobile.android.database

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * A Dagger [Module] that tells Dagger what to inject into objects that depend on an object implementing
 * [DatabaseDriverFactory].
 */
@Module
@InstallIn(SingletonComponent::class)
interface DatabaseDriverFactoryModule {
    /**
     * A Dagger Binding that tells Dagger to inject an instance of [AndroidDatabaseDriverFactory] into objects
     * that depend on an object implementing [DatabaseDriverFactory].
     *
     * @param impl The type of object that will be injected into objects that depend on an object implementing
     * [DatabaseDriverFactory].
     */
    @Binds
    fun bindDatabaseDriverFactory(impl: AndroidDatabaseDriverFactory): DatabaseDriverFactory
}