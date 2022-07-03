package com.commuto.interfacemobile.android.database

import com.squareup.sqldelight.db.SqlDriver
import javax.inject.Singleton


/**
 * An interface that a class must implement in order to provide [SqlDriver]s
 */
@Singleton
interface DatabaseDriverFactory {
    /**
     * The method by which this class provides [SqlDriver]s.
     */
    fun createDriver(): SqlDriver
}