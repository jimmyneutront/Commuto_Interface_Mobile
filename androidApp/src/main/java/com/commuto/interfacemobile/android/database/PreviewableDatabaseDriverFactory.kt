package com.commuto.interfacemobile.android.database

import com.squareup.sqldelight.db.SqlDriver
import com.squareup.sqldelight.sqlite.driver.JdbcSqliteDriver
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides [SqlDriver]s as in-memory [JdbcSqliteDriver]s. Note that this should only be used for testing and
 * previewing; it will cause a crash when run on an Android device.
 */
@Singleton
class PreviewableDatabaseDriverFactory @Inject constructor(): DatabaseDriverFactory {
    /**
     * Creates and returns a new [JdbcSqliteDriver] connected to an in-memory database.
     * @return A new [JdbcSqliteDriver] connected to an in-memory database.
     */
    override fun createDriver(): SqlDriver {
        return JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
    }
}