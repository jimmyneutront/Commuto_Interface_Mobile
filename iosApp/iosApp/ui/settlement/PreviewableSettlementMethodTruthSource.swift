//
//  PreviewableSettlementMethodTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 10/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 A `UISettlementMethodTruthSource` implementation used for previewing user interfaces
 */
class PreviewableSettlementMethodTruthSource: UISettlementMethodTruthSource {
    
    /**
     A list of containing the user's `SettlementMethods`.
     */
    var settlementMethods: [SettlementMethod] = []
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISettlementMethodTruthSource`.
     */
    func addSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfAdding: Binding<AddingSettlementMethodState>,
        addSettlementMethodError: Binding<Error?>
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISettlementMethodTruthSource`.
     */
    func editSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfEditing: Binding<EditingSettlementMethodState>,
        editSettlementMethodError: Binding<Error?>,
        privateDataBinding: Binding<PrivateData?>
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISettlementMethodTruthSource`.
     */
    func deleteSettlementMethod(
        settlementMethod: SettlementMethod,
        stateOfDeleting: Binding<DeletingSettlementMethodState>,
        deleteSettlementMethodError: Binding<Error?>
    ) {}
    
}
