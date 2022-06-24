//
//  OfferServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/23/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 An `Error` thrown by `OfferService` functions.
 */
enum OfferServiceError: Error {
    /**
     Thrown when `OfferService` unexpectedly encounters a `nil` value, either by calling a function or attempting to use an optional property of a class or structure.
     
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
