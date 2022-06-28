package com.commuto.interfacemobile.db

import android.content.Context
import com.commuto.interfacemobile.android.database.CommutoInterfaceDB
import com.squareup.sqldelight.android.AndroidSqliteDriver
import com.squareup.sqldelight.db.SqlDriver

actual class DatabaseDriverFactory(private val context: Context) {
    actual fun createDriver(): SqlDriver {
        return AndroidSqliteDriver(CommutoInterfaceDB.Schema, context)
    }
}