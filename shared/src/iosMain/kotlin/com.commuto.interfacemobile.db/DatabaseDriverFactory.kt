package com.commuto.interfacemobile.db

import co.touchlab.sqliter.DatabaseConfiguration
import com.squareup.sqldelight.drivers.native.NativeSqliteDriver
import com.squareup.sqldelight.db.SqlDriver
import com.squareup.sqldelight.drivers.native.wrapConnection

actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        val schema = CommutoInterfaceDB.Schema
        val config = DatabaseConfiguration(
            name = "test",
            version = schema.version,
            create = { connection ->
                wrapConnection(connection) { schema.create(it) }
            },
            upgrade = { connection, oldVersion, newVersion ->
                wrapConnection(connection) { schema.migrate(it, oldVersion, newVersion) }
            },
            inMemory = true
        )
        return NativeSqliteDriver(configuration = config)
    }
}