//
//  EditingSettlementMethodState.swift
//  iosApp
//
//  Created by jimmyt on 10/5/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently editing a settlement method belonging to the user. If we are, this indicates what part of the settlement-method-editing process we are currently in.
 */
enum EditingSettlementMethodState {
    /**
     Indicates that we are not currently editing a settlement method.
     */
    case none
    /**
     Indicates that we are currently attempting to serialize new private data that will replace the current private data of the settlement method.
     */
    case serializing
    /**
     Indicates that we are securely replacing the settlement method's existing private data with new private data in persistent storage.
     */
    case storing
    /**
     Indicates that we are editing the private data of the `SettlementMethod` in the settlement method truth source.
     */
    case editing
    /**
     Indicates that the settlement-method-editing process finished successfully.
     */
    case completed
    /**
     Indicates that we encountered an error while editing the settlement method.
     */
    case error
    
    /**
     A human-readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used
            return "Press Edit to edit the settlement method" 
        case .serializing:
            return "Serializing settlement method data..."
        case .storing:
            return "Securely storing settlement method data..."
        case .editing:
            return "Editing settlement method..."
        case .completed:
            return "Settlement method edited."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
    
}
