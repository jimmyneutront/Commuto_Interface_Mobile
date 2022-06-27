package com.commuto.interfacemobile.android.database

import com.squareup.sqldelight.db.SqlDriver
import com.squareup.sqldelight.sqlite.driver.JdbcSqliteDriver

/**
 * Provides [SqlDriver]s.
 */
class DatabaseDriverFactory {
    /**
     * Creates and returns a new [JdbcSqliteDriver] connected to an in-memory database.
     * @return A new [JdbcSqliteDriver] connected to an in-memory database.
     */
    fun createDriver(): SqlDriver {
        return JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
    }
}