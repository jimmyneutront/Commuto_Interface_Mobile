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
    
    /**
     Edits a given `SettlementMethod`, replacing its current private data with the supplied `PrivateData` in the collection of the user's settlement methods.
     
     - Parameters:
        - settlementMethod: The user's `SettlementMethod` that they want to edit.
        - newPrivateData: Some `PrivateData`, with which the current private data of the given settlement method will be replaced.
        - stateOfEditing: A binding wrapped around an `EditingSettlementMethodState` value, describing the current state of the settlement-method-editing process.
        - editSettlementMethodError: A binding around an optional `Error`, the wrapped  value of which this will set equal to the error that occurs in the settlement-method-editing process, if any.
        - privateDataBinding: A binding around an optional `PrivateData`, with which this will update with `newPrivateData` once the settlement-method-editing process is complete.
     */
    func editSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfEditing: Binding<EditingSettlementMethodState>,
        editSettlementMethodError: Binding<Error?>,
        privateDataBinding: Binding<PrivateData?>
    )
    
    /**
     Deletes a given `SettlementMethod`.
     
     - Parameters:
        - settlementMethod: The user's `SettlementMethod` that they want to delete.
        - stateOfDeleting: A binding wrapped around a `DeletingSettlementMethodState` value, describing the current state of the settlement-method-deleting process.
        - deleteSettlementMethodError: A binding around an optional `Error`, the wrapped value of which this will set equal to the error that occurs in the settlement-method-deleting process, if any.
     */
    func deleteSettlementMethod(
        settlementMethod: SettlementMethod,
        stateOfDeleting: Binding<DeletingSettlementMethodState>,
        deleteSettlementMethodError: Binding<Error?>
    )
    
}
