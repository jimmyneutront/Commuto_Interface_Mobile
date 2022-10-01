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
struct SettlementMethodsView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(SettlementMethod.sampleSettlementMethodsEmptyPrices) { settlementMethod in
                    NavigationLink(destination: SettlementMethodDetailView(settlementMethod: settlementMethod)) {
                        SettlementMethodCardView(settlementMethod: settlementMethod)
                    }
                }
            }
            .navigationTitle(Text("Settlement Methods", comment: "Appears as a title above the list of the user's settlement methods"))
            .toolbar {
                Button(action: {}) {
                    Text("Add", comment: "The label of the button to add a new settlement method")
                }
            }
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
struct SettlementMethodDetailView: View {
    /**
     The `SettlementMethod` about which this displays information.
     */
    let settlementMethod: SettlementMethod
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
                    EditSettlementMethodView(settlementMethod: settlementMethod, privateData: $privateData,isShowingEditSheet: $isShowingEditSheet)
                }
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
struct EditSettlementMethodView: View {
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
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Edit \(settlementMethod.method) Details")
                        .font(.title)
                        .bold()
                    Spacer()
                    Button(action: { isShowingEditSheet = false }, label: { Text("Cancel") })
                }
                if settlementMethod.method == "SEPA" {
                    EditableSEPADetailView(privateData: $privateData, isShowingEditSheet: $isShowingEditSheet)
                } else if settlementMethod.method == "SWIFT" {
                    EditableSWIFTDetailView(privateData: $privateData, isShowingEditSheet: $isShowingEditSheet)
                } else {
                    Text("Unable to edit details")
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding()
        }
    }
}

/**
 Allows the user to supply private SEPA data. When the user presses the "Done" button, a new `PrivateSEPAData` struct is created from the data they have supplied, and is set equal to `privateData`. This should only be presented in a sheet.
 */
struct EditableSEPADetailView: View {
    /**
     A binding to an optional `PrivateData` struct, which this will set with the `PrivateSEPAData` struct it creates when the user presses "Done".
     */
    @Binding var privateData: PrivateData?
    /**
     Indicates whether we are showing the sheet containing this `View`.
     */
    @Binding var isShowingEditSheet: Bool
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
                privateData = PrivateSEPAData(accountHolder: accountHolder, bic: bic, iban: iban, address: address)
                isShowingEditSheet = false
            },
            label: {
                Text("Done")
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
}

/**
 Allows the user to supply private SWIFT data. When the user presses the "Done" button, a new `PrivateSWIFTData` struct is created from the data they have supplied, and is set equal to `privateData`. This should only be presented in a sheet.
 */
struct EditableSWIFTDetailView: View {
    /**
     A binding to an optional `PrivateData` struct, which this will set with the `PrivateSEPAData` struct it creates when the user presses "Done".
     */
    @Binding var privateData: PrivateData?
    /**
     Indicates whether we are showing the sheet containing this `View`.
     */
    @Binding var isShowingEditSheet: Bool
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
                privateData = PrivateSWIFTData(accountHolder: accountHolder, bic: bic, accountNumber: accountNumber)
                isShowingEditSheet = false
            },
            label: {
                Text("Done")
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
        SettlementMethodsView()
    }
}
