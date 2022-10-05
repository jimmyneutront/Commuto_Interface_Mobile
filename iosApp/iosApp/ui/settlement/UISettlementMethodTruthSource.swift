//
//  UISettlementMethodTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 10/2/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for settlement-method-related data in an application with a graphical user interface.
 */
protocol UISettlementMethodTruthSource: ObservableObject {
    /**
     An array of the user's settlement methods.
     */
    var settlementMethods: [SettlementMethod] { get set }
    /**
     Adds a given `SettlementMethod` with corresponding `PrivateData` to the collection of the user's settlement methods.
     
     - Parameters:
        - settlementMethod: The new  `SettlementMethod` that the user wants added to their collection of settlement methods.
        - newPrivateData: Some `PrivateData` corresponding to `settlementMethod`, supplied by the user.
        - stateOfAdding: A binding wrapped around an `AddingSettlementMethodState` value, describing the current state of the settlement-method-adding process.
        - addSettlementMethodError: A binding around an optional `Error`, the wrapped value of which this will set equal to the error that occurs in the settlement-method-adding process, if any.
     */
    func addSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfAdding: Binding<AddingSettlementMethodState>,
        addSettlementMethodError: Binding<Error?>
    )
    
}