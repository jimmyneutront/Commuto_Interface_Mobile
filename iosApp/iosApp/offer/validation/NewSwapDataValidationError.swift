//
//  NewSwapDataValidationError.swift
//  iosApp
//
//  Created by jimmyt on 8/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A `LocalizedError` thrown if a problem is encountered while validating data to take an offer.
 */
struct NewSwapDataValidationError: LocalizedError {
    
    /**
     Initializes a new `NewSwapDataValidationError`.
     
     - Parameter desc: A `String` that provides information about the context in which the error was thrown, which will be stored in the `errorDescription` property.
     */
    init(desc: String) {
        self.errorDescription = desc
    }
    
    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String?
    
}
