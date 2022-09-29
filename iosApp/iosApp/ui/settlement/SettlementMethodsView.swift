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
                    SettlementMethodCardView(settlementMethod: settlementMethod)
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
    var body: some View {
        VStack(alignment: .leading) {
            Text(settlementMethod.method)
                .bold()
            Text(settlementMethod.currency)
            if let privateDataString = settlementMethod.privateData {
                if let privateData = try? JSONDecoder().decode(PrivateSEPAData.self, from: privateDataString.data(using: .utf8) ?? Data()) {
                    Text("IBAN: \(privateData.iban)")
                        .font(.footnote)
                } else if let privateData = try? JSONDecoder().decode(PrivateSWIFTData.self, from: privateDataString.data(using: .utf8) ?? Data()) {
                    Text("Account: \(privateData.accountNumber)")
                        .font(.footnote)
                } else {
                    Text(privateDataString)
                }
            } else {
                Text("Unable to parse data")
                    .font(.footnote)
            }
        }
    }
}

struct SettlementMethodsView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementMethodsView()
    }
}
