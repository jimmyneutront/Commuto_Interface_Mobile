//
//  BlockchainServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 An `Error` thrown by `BlockchainService` functions.
 */
enum BlockchainServiceError: Error {
    /**
    Thrown when a `BlockchainService` function receives `nil` from a call that should return a non-`nil` result.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedNilError(desc: String)
    
    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String {
        switch self {
        case .unexpectedNilError(let desc):
            return desc
        }
    }
}
