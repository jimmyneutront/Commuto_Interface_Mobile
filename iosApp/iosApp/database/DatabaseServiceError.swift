//
//  DatabaseServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 An `Error` thrown by `DatabaseService` functions.
 */
enum DatabaseServiceError: Error {
    #warning("TODO rename message as desc")
    /**
     Thrown when `DatabaseService` receives an unexpected result from a database query.
     
     - Parameter message: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedQueryResult(message: String)
    /**
     Thrown when `DatabaseServer` unexpectedly encounters a `nil` value, either by calling a function or attempting to use an optional property of a class or structure.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedNilError(desc: String)
}
