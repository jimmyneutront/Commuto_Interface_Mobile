//
//  SettlementMethodViewModel.swift
//  iosApp
//
//  Created by jimmyt on 10/2/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import PromiseKit
import SwiftUI

/**
 The Settlement Method View Mode, the single source of truth for all settlement-method-related data. It is observed by settlement-method related views, which include those for adding/editing/deleting the user's settlement methods, as well as those for creating/editing/taking offers.
 */
class SettlementMethodViewModel: UISettlementMethodTruthSource {
    
    /**
     Initializes a new `SettlementMethodViewModel`.
     
     - Parameter settlementMethodService: A `SettlementMethodService` that performs validating, adding, editing, removing operations for the user's settlement methods.
     */
    init(settlementMethodService: SettlementMethodService<SettlementMethodViewModel>) {
        self.settlementMethodService = settlementMethodService
    }
    /**
     `SettlementMethodViewModel`'s `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "SettlementMethodViewModel")
    /**
     An  array containing all of the user's `SettlementMethod`s, each with corresponding private data.
     */
    @Published var settlementMethods: [SettlementMethod] = SettlementMethod.sampleSettlementMethodsEmptyPrices
    /**
     A `SettlementMethodService` responsible for performing validating, adding, editing, and removing operations on the user's settlement methods, both in persistent storage and in `settlementMethods`.
     */
    let settlementMethodService: SettlementMethodService<SettlementMethodViewModel>
    
    /**
     Sets the wrapped value of `stateToSet` equal to `state` on the main `DispatchQueue`.
     */
    private func setAddingSettlementMethodState(state: AddingSettlementMethodState, stateToSet: Binding<AddingSettlementMethodState>) {
        DispatchQueue.main.async {
            stateToSet.wrappedValue = state
        }
    }
    /**
     Sets the wrapped value of `stateToSet` equal to `state` on the main `DispatchQueue`.
     */
    private func setEditingSettlementMethodState(state: EditingSettlementMethodState, stateToSet: Binding<EditingSettlementMethodState>) {
        DispatchQueue.main.async {
            stateToSet.wrappedValue = state
        }
    }
    
    /**
     Adds a given `SettlementMethod` with corresponding `PrivateData` to the collection of the user's settlement methods, by passing them to `SettlementMethodService.addSettlementMethod`. This also passes several closures to `SettlementMethodService.addSettlementMethod` which will call `setAddingSettlementMethodState` with the current state of the settlement-method-adding process.
     
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
    ) {
        setAddingSettlementMethodState(state: .serializing, stateToSet: stateOfAdding)
        settlementMethodService.addSettlementMethod(
            settlementMethod: settlementMethod,
            newPrivateData: newPrivateData,
            afterSerialization: {
                self.setAddingSettlementMethodState(state: .storing, stateToSet: stateOfAdding)
            },
            afterPersistentStorage: {
                self.setAddingSettlementMethodState(state: .adding, stateToSet: stateOfAdding)
            }
        ).done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("addSettlementMethod: added settlement method \(settlementMethod.id)")
            setAddingSettlementMethodState(state: .completed, stateToSet: stateOfAdding)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("addSettlementMethod: got error during addSettlementMethod call for \(settlementMethod.id). Error: \(error.localizedDescription)")
            addSettlementMethodError.wrappedValue = error
            setAddingSettlementMethodState(state: .error, stateToSet: stateOfAdding)
        }
    }
    
    /**
     Edits a given `SettlementMethod`, replacing its current private data with the supplied `PrivateData` in the collection of the user's settlement methods, via a call to `SettlementMethodService.editSettlementMethod`. This also passes several closures to `SettlementMethodService.editSettlementMethod` which will call `setEditingSettlementMethodState` with the current state of the settlement-method-editing process.
     
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
    ) {
        setEditingSettlementMethodState(state: .serializing, stateToSet: stateOfEditing)
        settlementMethodService.editSettlementMethod(
            settlementMethod: settlementMethod,
            newPrivateData: newPrivateData,
            afterSerialization: {
                self.setEditingSettlementMethodState(state: .storing, stateToSet: stateOfEditing)
            },
            afterPersistentStorage: {
                self.setEditingSettlementMethodState(state: .editing, stateToSet: stateOfEditing)
            }
        ).get(on: DispatchQueue.main) { _ in
            privateDataBinding.wrappedValue = newPrivateData
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("editSettlementMethod: edited settlement method \(settlementMethod.id)")
            setEditingSettlementMethodState(state: .completed, stateToSet: stateOfEditing)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("editSettlementMethod: got error during editSettlementMethod call for \(settlementMethod.id). Error: \(error.localizedDescription)")
            editSettlementMethodError.wrappedValue = error
            setEditingSettlementMethodState(state: .error, stateToSet: stateOfEditing)
        }
    }
    
}
