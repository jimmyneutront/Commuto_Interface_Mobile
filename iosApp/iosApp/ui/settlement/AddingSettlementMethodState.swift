//
//  AddingSettlementMethodState.swift
//  iosApp
//
//  Created by jimmyt on 10/2/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently adding a new settlement method to the user's collection of settlement methods. If we are, this indicates what part of the settlement-method-adding process we are currently in.
 */
enum AddingSettlementMethodState {
    /**
     Indicates that we are not currently adding a settlement method.
     */
    case none
    /**
     Indicates that we are currently attempting to serialize the private data corresponding to the settlement method.
     */
    case serializing
    /**
     Indicates that we are securely storing the settlement method and its private data in persistent storage.
     */
    case storing
    /**
     Indicates that we are adding the new `SettlementMethod` to the array of `SettlementMethod`s in the settlement method truth source.
     */
    case adding
    /**
     Indicates that the settlement-method-adding process finished successfully.
     */
    case completed
    /**
     Indicates that we encountered an error while adding the settlement method.
     */
    case error
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used
            return "Press Add to add a settlement method"
        case .serializing:
            return "Serializing settlement method data..."
        case .storing:
            return "Securely storing settlement method..."
        case .adding:
            return "Adding settlement method..."
        case .completed:
            return "Settlement method added."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
    
}
