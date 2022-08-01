package com.commuto.interfacemobile.android.database

import android.content.Context
import com.squareup.sqldelight.android.AndroidSqliteDriver
import com.squareup.sqldelight.db.SqlDriver
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides [SqlDriver]s for running on Android devices.
 * @property context The [Context] object of the Android application.
 */
@Singleton
class AndroidDatabaseDriverFactory @Inject constructor(@ApplicationContext val context: Context):
    DatabaseDriverFactory {
    /**
     * Creates and returns a new [AndroidSqliteDriver].
     * @return A new [AndroidSqliteDriver].
     */
    override fun createDriver(): SqlDriver {
        // Name database to create an actual database file
        return AndroidSqliteDriver(CommutoInterfaceDB.Schema, context, null)
    }
}