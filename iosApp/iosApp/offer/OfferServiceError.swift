//
//  OfferServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/23/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 An `Error` thrown by `OfferService` functions.
 */
enum OfferServiceError: LocalizedError {
    /**
     Thrown when `OfferService` unexpectedly encounters a `nil` value, either by calling a function or attempting to use an optional property of a class or structure.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case unexpectedNilError(desc: String)
    /**
     Thrown when the chain ID of an `Offer` does not match the chain ID of an event with an ID equal to that of the offer.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case nonmatchingChainIDError(desc: String)
    /**
     Thrown when `OfferService` tries to take an offer that is not available.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case offerNotAvailableError(desc: String)
    /**
     Thrown when two pieces of data that should match do not match.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case nonmatchingDataError(desc: String)
    /**
     Thrown when `OfferService` encounters an unexpected value.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown.
     */
    case invalidValueError(desc: String)

    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String? {
        switch self {
        case .unexpectedNilError(let desc):
            return desc
        case .nonmatchingChainIDError(let desc):
            return desc
        case .offerNotAvailableError(let desc):
            return desc
        case .nonmatchingDataError(let desc):
            return desc
        case .invalidValueError(desc: let desc):
            return desc
        }
    }
}
