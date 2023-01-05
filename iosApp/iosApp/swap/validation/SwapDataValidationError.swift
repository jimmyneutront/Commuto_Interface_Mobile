//
//  SwapDataValidationError.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

import Foundation

/**
 A `LocalizedError` thrown if a problem is encountered while validating data for a swap.
 */
struct SwapDataValidationError: LocalizedError {
    
    /**
     Initializes a new `SwapDataValidationError`.
     
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
