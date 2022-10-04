//
//  SettlementMethodServiceError.swift
//  iosApp
//
//  Created by jimmyt on 10/2/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A `LocalizedError` thrown by `SettlementMethodService` functions.
 */
enum SettlementMethodServiceError: LocalizedError {
    /**
     Thrown when a `SettlementMethodService` function receives `nil` from a call that should return a non-`nil` result.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedNilError(desc: String)
    /**
     Thrown when a `SettlementMethodService` function is not able to serialize private data associated with a settlement method.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case privateDataSerializationError(desc: String)
    
    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String? {
        switch self {
        case .unexpectedNilError(let desc):
            return desc
        case .privateDataSerializationError(let desc):
            return desc
        }
    }
    
}
