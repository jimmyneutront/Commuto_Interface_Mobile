//
//  SQLite.swiftExtensions.swift
//  iosApp
//
//  Created by jimmyt on 8/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SQLite

/**
 Make `QueryError` adopt `LocalizedError`.
 */
extension QueryError: LocalizedError {
    public var errorDescription: String? {
        return self.description
    }
}

extension Result: LocalizedError {
    public var errorDescription: String? {
        return self.description
    }
}
