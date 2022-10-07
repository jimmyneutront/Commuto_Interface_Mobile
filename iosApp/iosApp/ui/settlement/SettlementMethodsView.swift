//
//  SettlementMethodsView.swift
//  iosApp
//
//  Created by jimmyt on 9/28/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Displays the list of the user's settlement methods as `SettlementMethodCardView`s in a `List`.
 */
struct SettlementMethodsView<TruthSource>: View where TruthSource: UISettlementMethodTruthSource {
    
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodViewModel: TruthSource
    
    /**
     Indicates whether we are showing the sheet for adding a settlement method.
     */
    @State private var isShowingAddSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(settlementMethodViewModel.settlementMethods) { settlementMethod in
                    NavigationLink(destination:
                                    SettlementMethodDetailView(
                                        settlementMethod: settlementMethod,
                                        settlementMethodViewModel: settlementMethodViewModel
                                    )
                    ) {
                        SettlementMethodCardView(settlementMethod: settlementMethod)
                    }
                }
            }
            .navigationTitle(Text("Settlement Methods", comment: "Appears as a title above the list of the user's settlement methods"))
            .toolbar {
                Button(action: {
                    isShowingAddSheet = true
                }) {
                    Text("Add", comment: "The label of the button to add a new settlement method")
                }
                .sheet(isPresented: $isShowingAddSheet) {
                    AddSettlementMethodView(
                        settlementMethodViewModel: settlementMethodViewModel,
                        isShowingAddSheet: $isShowingAddSheet
                    )
                }
            }
        }
    }
}

/**
 Displays a list of settlement method types that can be added, text fields for submitting private data corresponding to the settlement method that the user selects, and a button that adds the settlement method via `settlementMethodViewModel`. This should only be displayed in a sheet.
 */
struct AddSettlementMethodView<TruthSource>: View where TruthSource: UISettlementMethodTruthSource {
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodViewModel: TruthSource
    /**
     An enum representing the type of settlement method that the user has decided to create.
     */
    enum SettlementMethodType: CustomStringConvertible, CaseIterable, Identifiable {
        case SEPA, SWIFT
        var id: Self { self }
        var description: String {
            switch self {
            case .SEPA:
                return "SEPA"
            case .SWIFT:
                return "SWIFT"
            }
        }
    }
    /**
     Indicates whether we are showing the sheet for editing settlement method data.
     */
    @Binding var isShowingAddSheet: Bool
    /**
     The type of settlement method that the user has decided to create, or `nil` if the user has not yet decided.
     */
    @State private var selectedSettlementMethod: SettlementMethodType? = nil
    /**
     Indicates whether we are currently adding a settlement method to the collection of the user's settlement methods, and if so, what part of the settlement-method-adding process we are in.
     */
    @State private var addingSettlementMethodState: AddingSettlementMethodState = .none
    /**
     The `Error` that occured during the settlement method adding process, or `nil` if no such error has occured.
     */
    @State private var addSettlementMethodError: Error? = nil
    /**
     The text to be displayed on the button that begins the settlement method adding process.
     */
    private var buttonText: String {
        if addingSettlementMethodState == .none || addingSettlementMethodState == .error {
            return "Add"
        } else if addingSettlementMethodState == .completed {
            return "Done"
        } else {
            return "Adding..."
        }
    }
    /**
     The text to be displayed on the button in the upper trailing corner of this view, which closes the enclosing sheet without adding a settlement method when pressed.
     */
    private var cancelButtonText: String {
        if addingSettlementMethodState == .completed {
            return "Close"
        } else {
            return "Cancel"
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Add Settlement Method")
                        .font(.title)
                        .bold()
                    Spacer()
                    Button(action: { isShowingAddSheet = false }, label: { Text(cancelButtonText) })
                }
                Text("Select type:")
                    .font(.title2)
                ForEach(SettlementMethodType.allCases) { settlementMethodType in
                    Button(
                        action: {
                            selectedSettlementMethod = settlementMethodType
                        },
                        label: {
                            VStack(alignment: .center) {
                                Text(settlementMethodType.description)
                                    .bold()
                            }
                            .frame(
                                minWidth: 0,
                                maxWidth: .infinity
                            )
                            .padding(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(getColorForSettlementMethod(settlementMethodType: settlementMethodType), lineWidth: 3)
                            )
                        }
                    )
                    .accentColor(Color.primary)
                }
                if addingSettlementMethodState != .none && addingSettlementMethodState != .error {
                    Text(addingSettlementMethodState.description)
                        .font(.title2)
                } else if addingSettlementMethodState == .error {
                    Text(addSettlementMethodError?.localizedDescription ?? "An unknown error occured")
                        .foregroundColor(Color.red)
                }
                // If we have finished adding the settlement method, then the button will be labeled "Done" and should close the closing sheet when pressed.
                if selectedSettlementMethod == .SEPA {
                    EditableSEPADetailView(
                        buttonText: buttonText,
                        buttonAction: { newPrivateData in
                        if addingSettlementMethodState == .none || addingSettlementMethodState == .error {
                            let newSettlementMethod = SettlementMethod(currency: "EUR", price: "", method: "SEPA")
                            settlementMethodViewModel.addSettlementMethod(
                                settlementMethod: newSettlementMethod,
                                newPrivateData: newPrivateData,
                                stateOfAdding: $addingSettlementMethodState,
                                addSettlementMethodError: $addSettlementMethodError
                            )
                        } else if addingSettlementMethodState == .completed {
                            isShowingAddSheet = false
                        }
                    })
                } else if selectedSettlementMethod == .SWIFT {
                    EditableSWIFTDetailView(
                        buttonText: buttonText,
                        buttonAction: { newPrivateData in
                        if addingSettlementMethodState == .none || addingSettlementMethodState == .error {
                            let newSettlementMethod = SettlementMethod(currency: "USD", price: "", method: "SWIFT")
                            settlementMethodViewModel.addSettlementMethod(
                                settlementMethod: newSettlementMethod,
                                newPrivateData: newPrivateData,
                                stateOfAdding: $addingSettlementMethodState,
                                addSettlementMethodError: $addSettlementMethodError
                            )
                        } else if addingSettlementMethodState == .completed {
                            isShowingAddSheet = false
                        }
                    })
                }
            }
            .padding()
        }
    }
    
    /**
     Returns `Color.green` if `settlementMethodType` equals `selectedSettlementMethod`, and returns `Color.primary` otherwise.
     */
    private func getColorForSettlementMethod(settlementMethodType: AddSettlementMethodView.SettlementMethodType) -> Color {
        if selectedSettlementMethod == settlementMethodType {
            return Color.green
        } else {
            return Color.primary
        }
    }
    
}

/**
 A card displaying basic information about a settlement method belonging to the user, to be shown in the list of the user's settlement methods.
 */
struct SettlementMethodCardView: View {
    /**
     The `SettlementMethod` about which this card displays information.
     */
    let settlementMethod: SettlementMethod
    /**
     A struct adopting `PrivateData` containing private data for `settlementMethod`.
     */
    @State var privateData: PrivateData? = nil
    /**
     Indicates whether we have finished attempting to parse the private data associated with `settlementMethod`.
     */
    @State var finishedParsingData = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(settlementMethod.method)
                .bold()
            Text(settlementMethod.currency)
            if let privateDataString = settlementMethod.privateData {
                if let sepaData = privateData as? PrivateSEPAData {
                    Text("IBAN: \(sepaData.iban)")
                        .font(.footnote)
                } else if let swiftData = privateData as? PrivateSWIFTData {
                    Text("Account: \(swiftData.accountNumber)")
                        .font(.footnote)
                } else if finishedParsingData {
                    Text(privateDataString)
                }
            } else {
                Text("Unable to parse data")
                    .font(.footnote)
            }
        }
        .onAppear {
            createPrivateDataStruct(privateData: settlementMethod.privateData?.data(using: .utf8) ?? Data(), resultBinding: $privateData, finished: $finishedParsingData)
        }
    }
}

/**
 Displays all information, including private information, about a given `SettlementMethod`.
 */
struct SettlementMethodDetailView<TruthSource>: View where TruthSource: UISettlementMethodTruthSource {
    /**
     The `SettlementMethod` about which this displays information.
     */
    let settlementMethod: SettlementMethod
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodViewModel: TruthSource
    /**
     A struct adopting `PrivateData` containing private data for `settlementMethod`..
     */
    @State private var privateData: PrivateData? = nil
    /**
     Indicates whether we have finished attempting to parse the private data associated with `settlementMethod`.
     */
    @State private var finishedParsingData = false
    /**
     Indicates whether we are showing the sheet for editing settlement method data.
     */
    @State private var isShowingEditSheet = false
    /**
     The title to be displayed in the upper leading corner of the view.
     */
    var navigationTitle: String {
        if settlementMethod.method == "SEPA" {
            return "SEPA Transfer"
        } else if settlementMethod.method == "SWIFT" {
            return "SWIFT Transfer"
        } else {
            return settlementMethod.method
        }
    }
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                Text("Currency:")
                    .font(.title2)
                Text(settlementMethod.currency)
                    .font(.title)
                    .bold()
                if let privateData = privateData {
                    if let sepaData = privateData as? PrivateSEPAData {
                        SEPADetailView(sepaData: sepaData)
                    } else if let swiftData = privateData as? PrivateSWIFTData {
                        SWIFTDetailView(swiftData: swiftData)
                    } else {
                        Text("Unknown Settlement Method Type")
                    }
                } else if finishedParsingData {
                    Text("Unable to parse data")
                        .font(.title)
                        .bold()
                }
                Button(
                    action: {
                        isShowingEditSheet = true
                    },
                    label: {
                        Text("Edit")
                            .font(.largeTitle)
                            .bold()
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary, lineWidth: 3)
                            )
                    }
                )
                .accentColor(Color.primary)
                .sheet(isPresented: $isShowingEditSheet) {
                    EditSettlementMethodView(
                        settlementMethodViewModel: settlementMethodViewModel,
                        settlementMethod: settlementMethod,
                        privateData: $privateData,
                        isShowingEditSheet: $isShowingEditSheet
                    )
                }
                Button(
                    action: {
                        settlementMethodViewModel.settlementMethods.removeAll(where: { possibleSettlementMethod in
                            return possibleSettlementMethod.id == settlementMethod.id
                        })
                    },
                    label: {
                        Text("Delete")
                            .font(.largeTitle)
                            .bold()
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 3)
                            )
                    }
                )
                .accentColor(Color.red)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .padding([.leading, .trailing])
        }
        .navigationTitle(Text(navigationTitle))
        .onAppear {
            createPrivateDataStruct(privateData: settlementMethod.privateData?.data(using: .utf8) ?? Data(), resultBinding: $privateData, finished: $finishedParsingData)
        }
    }
}

/**
 Displays a view allowing the user to edit the private data of `settlementMethod`, or displays an error message if the details cannot be edited. This should only be presented in a sheet.
 */
struct EditSettlementMethodView<TruthSource>: View where TruthSource: UISettlementMethodTruthSource {
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodViewModel: TruthSource
    /**
     The `SettlementMethod`, the private data of which this helps to edit.
     */
    let settlementMethod: SettlementMethod
    /**
     A binding to an optional `PrivateData` struct for `settlementMethod`.
     */
    @Binding var privateData: PrivateData?
    /**
     Indicates whether we are showing the sheet containing this `View`.
     */
    @Binding var isShowingEditSheet: Bool
    /**
     Indicates whether we are currently editing the settlement method, and if so, what part of the settlement-method-editing process we are in.
     */
    @State private var editingSettlementMethodState: EditingSettlementMethodState = .none
    /**
     The `Error` that occured during the settlement method adding process, or `nil` if no such error has occured.
     */
    @State private var editSettlementMethodError: Error? = nil
    /**
     The text to be displayed on the button that begins the settlement method editing process.
     */
    private var buttonText: String {
        if editingSettlementMethodState == .none || editingSettlementMethodState == .error {
            return "Edit"
        } else if editingSettlementMethodState == .completed {
            return "Done"
        } else {
            return "Editing..."
        }
    }
    /**
     The text to be displayed on the button in the upper trailing corner of this view, which closes the enclosing sheet without editing the settlement method when pressed.
     */
    private var cancelButtonText: String {
        if editingSettlementMethodState == .completed {
            return "Close"
        } else {
            return "Cancel"
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Edit \(settlementMethod.method) Details")
                        .font(.title)
                        .bold()
                    Spacer()
                    Button(action: { isShowingEditSheet = false }, label: { Text(cancelButtonText) })
                }
                
                if editingSettlementMethodState != .none && editingSettlementMethodState != .error {
                    Text(editingSettlementMethodState.description)
                        .font(.title2)
                } else if editingSettlementMethodState == .error {
                    Text(editSettlementMethodError?.localizedDescription ?? "An unknown error occured")
                        .foregroundColor(Color.red)
                }
                
                if settlementMethod.method == "SEPA" {
                    EditableSEPADetailView(buttonText: buttonText, buttonAction: { newPrivateData in
                        if editingSettlementMethodState == .none || editingSettlementMethodState == .error {
                            settlementMethodViewModel.editSettlementMethod(
                                settlementMethod: settlementMethod,
                                newPrivateData: newPrivateData,
                                stateOfEditing: $editingSettlementMethodState,
                                editSettlementMethodError: $editSettlementMethodError,
                                privateDataBinding: $privateData
                            )
                        } else if editingSettlementMethodState == .completed {
                            isShowingEditSheet = false
                        }
                    })
                } else if settlementMethod.method == "SWIFT" {
                    EditableSWIFTDetailView(buttonText: buttonText, buttonAction: { newPrivateData in
                        
                        if editingSettlementMethodState == .none || editingSettlementMethodState == .error {
                            settlementMethodViewModel.editSettlementMethod(
                                settlementMethod: settlementMethod,
                                newPrivateData: newPrivateData,
                                stateOfEditing: $editingSettlementMethodState,
                                editSettlementMethodError: $editSettlementMethodError,
                                privateDataBinding: $privateData
                            )
                        } else if editingSettlementMethodState == .completed {
                            isShowingEditSheet = false
                        }
                    })
                } else {
                    Text("Unable to edit details")
                }
            }
            .padding()
        }
    }
}

/**
 Allows the user to supply private SEPA data. When the user presses the "Done" button, a new `PrivateSEPAData` struct is created from the data they have supplied, and is passed to `buttonAction`.
 */
struct EditableSEPADetailView: View {
    /**
     The label of the button that lies below the input text fields.
     */
    let buttonText: String
    /**
     The action that the button should perform when clicked, which receives a new struct adopting `PrivateData` made from the data supplied by the user.
     */
    let buttonAction: (PrivateData) -> Void
    /**
     The value the user has supplied for the "Account Holder" field.
     */
    @State private var accountHolder: String = ""
    /**
     The value the user has supplied for the Bank Identification Code field.
     */
    @State private var bic: String = ""
    /**
     The value the user has supplied for the International Bank Account Number field.
     */
    @State private var iban: String = ""
    /**
     The value the user has supplied for the Address field.
     */
    @State private var address: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Holder:")
                .font(.title2)
            TextField(
                "",
                text: $accountHolder
            )
            .disableAutocorrection(true)
            Text("BIC:")
                .font(.title2)
            TextField(
                "",
                text: $bic
            )
            .disableAutocorrection(true)
            Text("IBAN:")
                .font(.title2)
            TextField(
                "",
                text: $iban
            )
            .disableAutocorrection(true)
            Text("Address:")
                .font(.title2)
            TextField(
                "",
                text: $address
            )
            .disableAutocorrection(true)
            Button(
                action: {
                    buttonAction(PrivateSEPAData(accountHolder: accountHolder, bic: bic, iban: iban, address: address))
                },
                label: {
                    Text(buttonText)
                        .font(.largeTitle)
                        .bold()
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary, lineWidth: 3)
                        )
                }
            )
            .accentColor(Color.primary)
        }
        .textFieldStyle(.roundedBorder)
    }
}

/**
 Allows the user to supply private SWIFT data. When the user presses the "Done" button, a new `PrivateSWIFTData` struct is created from the data they have supplied, and is passed to `buttonAction`.
 */
struct EditableSWIFTDetailView: View {
    /**
     The label of the button that lies below the input text fields.
     */
    let buttonText: String
    /**
     The action that the button should perform when clicked, which receives a new struct adopting `PrivateData` made from the data supplied by the user.
     */
    let buttonAction: (PrivateData) -> Void
    /**
     The value the user has supplied for the "Account Holder" field.
     */
    @State private var accountHolder: String = ""
    /**
     The value the user has supplied for the Bank Identification Code field.
     */
    @State private var bic: String = ""
    /**
     The value the user has supplied for the Account Number field.
     */
    @State private var accountNumber: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Holder:")
                .font(.title2)
            TextField(
                "",
                text: $accountHolder
            )
            .disableAutocorrection(true)
            Text("BIC:")
                .font(.title2)
            TextField(
                "",
                text: $bic
            )
            .disableAutocorrection(true)
            Text("Account Number:")
                .font(.title2)
            TextField(
                "",
                text: $accountNumber
            )
            .disableAutocorrection(true)
            Button(
                action: {
                    buttonAction(PrivateSWIFTData(accountHolder: accountHolder, bic: bic, accountNumber: accountNumber))
                },
                label: {
                    Text(buttonText)
                        .font(.largeTitle)
                        .bold()
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary, lineWidth: 3)
                        )
                }
            )
            .accentColor(Color.primary)
        }
        .textFieldStyle(.roundedBorder)
    }
}

/**
 Displays private SEPA account information.
 */
struct SEPADetailView: View {
    let sepaData: PrivateSEPAData
    var body: some View {
        Text("Account Holder:")
            .font(.title2)
        Text(sepaData.accountHolder)
            .font(.title)
            .bold()
        Text("BIC:")
            .font(.title2)
        Text(sepaData.bic)
            .font(.title)
            .bold()
        Text("IBAN:")
            .font(.title2)
        Text(sepaData.iban)
            .font(.title)
            .bold()
        Text("Address:")
            .font(.title2)
        Text(sepaData.address)
            .font(.title)
            .bold()
    }
}

/**
 Displays private SWIFT account information.
 */
struct SWIFTDetailView: View {
    let swiftData: PrivateSWIFTData
    var body: some View {
        Text("Account Holder:")
            .font(.title2)
        Text(swiftData.accountHolder)
            .font(.title)
            .bold()
        Text("BIC:")
            .font(.title2)
        Text(swiftData.bic)
            .font(.title)
            .bold()
        Text("Account Number:")
            .font(.title2)
        Text(swiftData.accountNumber)
            .font(.title)
            .bold()
    }
}

/**
 Attempts to create a private data structure by deserializing `privateData` as JSON, then on the main DispatchQueue, this sets the value of `resultBinding` to the result and sets the value of `finished` to `true`.
 */
func createPrivateDataStruct(privateData: Data, resultBinding: Binding<PrivateData?>, finished: Binding<Bool>) {
    var createdPrivateData: PrivateData? = nil
    DispatchQueue.global(qos: .userInteractive).async {
        if let privateData = try? JSONDecoder().decode(PrivateSEPAData.self, from: privateData) {
            createdPrivateData = privateData
        } else if let privateData = try? JSONDecoder().decode(PrivateSWIFTData.self, from: privateData) {
            createdPrivateData = privateData
        }
        DispatchQueue.main.async {
            resultBinding.wrappedValue = createdPrivateData
            finished.wrappedValue = true
        }
    }
}

struct SettlementMethodsView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementMethodsView(settlementMethodViewModel: PreviewableSettlementMethodTruthSource())
    }
}
