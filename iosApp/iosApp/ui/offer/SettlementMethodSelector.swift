//
//  SettlementMethodSelector.swift
//  iosApp
//
//  Created by jimmyt on 8/6/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Displays a vertical list of settlement method cards, one for each of the offers settlement methods. These cards can be tapped to indicate that the user is willing to use them to send/receive payment for the offer being opened.
 */
struct SettlementMethodSelector<SettlementMethod_TruthSource>: View where SettlementMethod_TruthSource: UISettlementMethodTruthSource {
    
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodViewModel: SettlementMethod_TruthSource
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    /**
     An `Array` containing the `SettlementMethod`s  that the user has selected.
     */
    @Binding var selectedSettlementMethods: [SettlementMethod]
    
    var body: some View {
        if (settlementMethodViewModel.settlementMethods.count > 0) {
            ForEach(settlementMethodViewModel.settlementMethods) { settlementMethod in
                SettlementMethodCard(
                    settlementMethod: settlementMethod,
                    stablecoinCurrencyCode: stablecoinCurrencyCode,
                    selectedSettlementMethods: $selectedSettlementMethods
                )
            }
        } else {
            Text("You haven't added any settlement methods.")
        }
    }
    
}

/**
 Displays a card containing settlement method information. The "Price" button on the card can be tapped to specify the price of the `SettlementMethod`.
 */
struct SettlementMethodCard: View {
    
    /**
     The `SettlementMethod`  that this card represents.
     */
    @State var settlementMethod: SettlementMethod
    
    /**
     A struct adopting `PrivateData` containing private data for `settlementMethod`.
     */
    @State var privateData: PrivateData? = nil
    
    /**
     Indicates whether we have finished attempting to parse the private data associated with `settlementMethod`.
     */
    @State var finishedParsingPrivateData = false
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    /**
     The `SettlementMethod`s that the user has selected.
     */
    @Binding var selectedSettlementMethods: [SettlementMethod]
    
    /**
     Indicates whether the  user has selected the `SettlementMethod` that this  card represents.
     */
    @State var isSelected = false
    
    /**
     Indicates whether the user is currently editing this `SettlementMethod`'s price.
     */
    @State var isEditingPrice = false
    
    /**
     The price that the user has specified for this `SettlementMethod`, as a `Double`.
     */
    @State var priceValue: Double = 0.0
    
    /**
     The price that the user has specified for this `SettlementMethod`, as a `Decimal`.
     */
    @State var priceValueAsDecimal: Decimal = NSNumber(floatLiteral: 0.0).decimalValue
    
    var body: some View {
        let color: Color = {
            if isSelected == true {
                return Color.green
            } else {
                return Color.primary
            }
        }()
        HStack {
            VStack(alignment: .leading) {
                Text(buildCurrencyDescription())
                    .bold()
                    .foregroundColor(color)
                    .padding(1)
                Button {
                    isEditingPrice = !isEditingPrice
                } label: {
                    Text(buildPriceDescription())
                        .bold()
                        .padding(1)
                }
                .accentColor(Color.primary)
                if isEditingPrice {
                    SettlementMethodPriceField(value: $priceValue, formatter: createPriceFormatter())
                        .onChange(of: priceValue) { newPriceValue in
                            priceValueAsDecimal = NSNumber(floatLiteral: newPriceValue).decimalValue
                            settlementMethod.price = String(describing: priceValue)
                            // If this settlement method is selected, we update its price value in the selected settlement methods list.
                            if let index = selectedSettlementMethods.firstIndex(where: {
                                selectedSettlementMethod in
                                    settlementMethod.id == selectedSettlementMethod.id
                            }) {
                                selectedSettlementMethods[index] = settlementMethod
                            }
                        }
                }
                SettlementMethodPrivateDetailView(settlementMethod: settlementMethod)
            }
            Spacer()
            Toggle("Use Settlement Method", isOn: $isSelected)
                .labelsHidden()
                .onChange(of: isSelected) { newIsSelectedValue in
                    if (!newIsSelectedValue) {
                        selectedSettlementMethods.removeAll { settlementMethodToCheck in
                            return settlementMethodToCheck.method == settlementMethod.method && settlementMethodToCheck.currency == settlementMethod.currency
                        }
                    } else {
                        if selectedSettlementMethods.firstIndex(where: { selectedSettlementMethod in
                            settlementMethod.id == selectedSettlementMethod.id
                        }) == nil {
                            // We should only add the settlement method that this card represents if it is not currently in selectedSettlementMethods
                            selectedSettlementMethods.append(settlementMethod)
                        }
                    }
                }
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
        .accentColor(.primary)
        .onAppear {
            // If the settlement method that this card represents is already in selectedSettlementMethods, then isSelected should be true
            if let index = selectedSettlementMethods.firstIndex(where: { selectedSettlementMethod in
                settlementMethod.id == selectedSettlementMethod.id
            }) {
                isSelected = true
                // If settlementMethod already has a price, we attempt to restore it
                if let priceValueFromString = Double(selectedSettlementMethods[index].price) {
                    priceValue = priceValueFromString
                    settlementMethod.price = selectedSettlementMethods[index].price
                }
            }
            // Attempt to deserialize the private data of the settlement method
            createPrivateDataStruct(privateData: settlementMethod.privateData?.data(using: .utf8) ?? Data(), resultBinding: $privateData, finished: $finishedParsingPrivateData)
        }
    }
    
    /**
     Builds a human readable string describing the currency and transfer method, such as "EUR via SEPA" or "USD via SWIFT".
     */
    func buildCurrencyDescription() -> String {
        return settlementMethod.currency + " via " + settlementMethod.method
    }
    
    /**
     Builds a human readable string describing the price specified for this settlement method, such as "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC", or "Price: Tap to specify" of this settlement method's price is empty.
     */
    func buildPriceDescription() -> String {
        if settlementMethod.price == "" {
            return "Price: Tap to specify"
        } else {
            return "Price: " + settlementMethod.price + " " + settlementMethod.currency + "/" + stablecoinCurrencyCode
        }
    }
    
    /**
     Returns a NumberFormatter with up to six decimal places of precision for formatting prices.
     */
    func createPriceFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 6
        return formatter
    }
    
}

/**
 A custom `TextField` for specifying settlement method prices.
 */
struct SettlementMethodPriceField: View {
    
    /**
     The current price value.
     */
    @Binding var value: Double
    
    /**
     The `NumberFormatter` used for formatting `value`.
     */
    let formatter: NumberFormatter
    
    var body: some View {
        HStack {
            TextField("0.00", value: $value, formatter: formatter)
                .font(.largeTitle)
                .keyboardType(.numbersAndPunctuation)
                .padding(6)
            Spacer()
        }
    }
    
}

struct SettlementMethodSelector_Previews: PreviewProvider {
    
    static let settlementMethods: [SettlementMethod] = SettlementMethod.sampleSettlementMethodsEmptyPrices
    
    @State static var selectedSettlementMethods: [SettlementMethod] = []
    
    static var previews: some View {
        SettlementMethodSelector(
            settlementMethodViewModel: PreviewableSettlementMethodTruthSource(),
            stablecoinCurrencyCode: "Stablecoin",
            selectedSettlementMethods: $selectedSettlementMethods
        )
    }
}
