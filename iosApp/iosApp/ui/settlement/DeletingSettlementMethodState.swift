//
//  DeletingSettlementMethodState.swift
//  iosApp
//
//  Created by jimmyt on 10/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently deleting a settlement method belonging to the user. If we are, this indicates what part of the settlement-method-deleting process we are currently in.
 */
enum DeletingSettlementMethodState {
    /**
     Indicates that we are not currently deleting a settlement method.
     */
    case none
    /**
     Indicates that we are currently deleting a settlement method.
     */
    case deleting
    /**
     Indicates that the settlement-method-deleting process finished successfully.
     */
    case completed
    /**
     Indicates that we encountered an error while deleting the settlement method.
     */
    case error
    
    var description: String {
        switch self {
        case .none: // Note This should not be used
            return "Press Delete to delete the settlement method"
        case .deleting:
            return "Deleting settlement method..."
        case .completed:
            return "Settlement method deleted."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
    
}
