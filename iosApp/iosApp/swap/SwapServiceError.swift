//
//  SwapServiceError.swift
//  iosApp
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 An `Error` thrown by `SwapService` functions.
 */
enum SwapServiceError: LocalizedError {
    /**
     Thrown when `SwapService` unexpectedly encounters a `nil` value, either by calling a function or attempting to use an optional property of a class or structure.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedNilError(desc: String)
    /**
     Thrown when `SwapService` encounters an unexpected value, such as a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) struct with a raw `direction` value of 3.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case invalidValueError(desc: String)
    /**
     Thrown when `SwapService` determines that an on-chain function call cannot be executed because its transaction will revert.
     */
    case transactionWillRevertError(desc: String)
    
    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String? {
        switch self {
        case .unexpectedNilError(let desc):
            return desc
        case .invalidValueError(let desc):
            return desc
        case .transactionWillRevertError(let desc):
            return desc
        }
    }
}
