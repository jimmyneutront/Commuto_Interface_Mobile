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
    let settlementMethod: SettlementMethod
    @State var privateData: PrivateData? = nil
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
    let settlementMethod: SettlementMethod
    @State var privateData: PrivateData? = nil
    @State var finishedParsingData = false
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
