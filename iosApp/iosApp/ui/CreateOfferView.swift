//
//  CreateOfferView.swift
//  iosApp
//
//  Created by James Telzrow on 7/16/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt
import web3swift

/**
 Used to create new [Offer]s(https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct CreateOfferView: View {
    
    init() {
        stablecoinFormatter = NumberFormatter()
        stablecoinFormatter.numberStyle = .currency
        stablecoinFormatter.maximumFractionDigits = 3
    }
    
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    
    private var chainID = BigUInt(1)
    
    @State private var selectedDirection: OfferDirection = .buy
    
    private var stablecoins = StablecoinInformationRepository.ethereumMainnetStablecoinInfoRepo
    
    @State private var selectedStablecoin: EthereumAddress? = nil
    
    private let stablecoinFormatter: NumberFormatter
    
    @State private var minimumAmount = 0
    
    @State private var maximumAmount = 0
    
    @State private var securityDepositAmount = 0
    
    @State private var isSecurityDepositDescriptionExpanded = false
    
    @State private var isServiceFeeRateDescriptionExpanded = false
    
    private var serviceFeeRate = 100
    
    private var settlementMethods: [SettlementMethod] = SettlementMethod.sampleSettlementMethodsEmptyPrices
    
    @State private var selectedSettlementMethods: [SettlementMethod] = []
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            let currencyCode = stablecoins.getStablecoinInformation(
                chainID: chainID,
                contractAddress: selectedStablecoin ?? EthereumAddress("0x0000000000000000000000000000000000000000")!
            )?.currencyCode
            VStack {
                HStack {
                    Text("Direction:")
                        .font(.title2)
                    Spacer()
                }
                // Note that the Picker label is not rendered
                Picker(selection: $selectedDirection, label: Text("Direction")) {
                    ForEach(OfferDirection.allCases) { direction in
                        Text(direction.string)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Stablecoin:")
                        .font(.title2)
                    Spacer()
                }
                StablecoinList(
                    chainID: chainID,
                    stablecoins: stablecoins,
                    selectedStablecoin: $selectedStablecoin
                )
                HStack {
                    Text("Minimum \(currencyCode ?? "Stablecoin") Amount:")
                        .font(.title2)
                    Spacer()
                }
                StablecoinAmountField(label: "Minimum", value: $minimumAmount, formatter: stablecoinFormatter)
                HStack {
                    Text("Maximum \(currencyCode ?? "Stablecoin") Amount:")
                        .font(.title2)
                    Spacer()
                }
                StablecoinAmountField(label: "Maximum", value: $maximumAmount, formatter: stablecoinFormatter)
                // If the user sets a minimum amount greater than the maximum amount, we set the maximum amount equal to this new minimum
                    .onChange(of: minimumAmount) { newMinimumAmount in
                        if (newMinimumAmount > maximumAmount) {
                            maximumAmount = newMinimumAmount
                        }
                    }
                DisclosureGroup(
                    isExpanded: $isSecurityDepositDescriptionExpanded,
                    content: {
                        HStack {
                            Text("The Security Deposit Amount must be at least 10% of the Maximum Amount.")
                            Spacer()
                        }
                    },
                    label: {
                        HStack {
                            Text("Security Deposit \(currencyCode ?? "Stablecoin") Amount:")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                )
                .accentColor(.primary)
                StablecoinAmountField(label: "Security Deposit", value: $securityDepositAmount, formatter: stablecoinFormatter)
                // If the user sets a new maximum amount of which current security deposit amount is less than ten percent, call fixSecurityDeposit with the current maximum amount.
                    .onChange(of: maximumAmount) { newMaximumAmount in
                        if (newMaximumAmount > securityDepositAmount * 10) {
                            fixSecurityDepositAmount(maximumAmount: newMaximumAmount)
                        }
                    }
                // If the user sets a security deposit amount less than ten percent of the maximum amount, call fixSecurityDeposit with the current maximum amount.
                    .onChange(of: securityDepositAmount) { newSecurityDepositAmount in
                        if (maximumAmount > newSecurityDepositAmount * 10) {
                            fixSecurityDepositAmount(maximumAmount: maximumAmount)
                        }
                    }
            }
            .padding([.leading, .trailing])
            VStack {
                DisclosureGroup(
                    isExpanded: $isServiceFeeRateDescriptionExpanded,
                    content: {
                        HStack {
                            Text("The percentage of the actual amount of \(currencyCode ?? "stablecoin") exchanged that you will be charged as a service fee.")
                            Spacer()
                        }
                    },
                    label: {
                        HStack {
                            Text("Service Fee Rate:")
                                .font(.title2)
                            Spacer()
                        }
                    }
                )
                .accentColor(.primary)
                HStack {
                    Text(String(format:"%.2f", Double(serviceFeeRate)/100) + " %")
                        .font(.largeTitle)
                    Spacer()
                }
                HStack {
                    Text("Settlement Methods:")
                        .font(.title2)
                    Spacer()
                }
                SettlementMethodSelector(
                    settlementMethods: settlementMethods,
                    selectedSettlementMethods: $selectedSettlementMethods
                )
                Button(
                    action: {},
                    label: {
                        Text("Create Offer")
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
                .padding([.top], 10)
            }
            .padding([.leading, .trailing, .bottom])
        }
        .navigationBarTitle(Text("Create Offer"))

    }
    
    /**
     Sets the current security deposit amount equal to the smallest possible integer greater than or equal to 10 % of the current maximum swap amount, and opens the security deposit description disclosure group.
     
     - Parameter maximumAmount: The current maximum stablecoin amount.
     */
    func fixSecurityDepositAmount(maximumAmount: Int) {
        securityDepositAmount = Int(ceil(Double(maximumAmount) / 10))
        isSecurityDepositDescriptionExpanded = true
    }
    
}

/**
 Displays a vertical list of `StablecoinCard`s, one for each stablecoin with the specified chain ID in the specified `StablecoinInformationRepository`. Only one `StablecoinCard` can be selected at a time.
 */
struct StablecoinList: View {
    
    let chainID: BigUInt
    
    let stablecoins: StablecoinInformationRepository
    
    @Binding var selectedStablecoin: EthereumAddress?
    
    var body: some View {
        ForEach(Array(stablecoins.stablecoinInformation[chainID]?.keys.enumerated() ?? [:].keys.enumerated()), id: \.element) { _, stablecoinAddress in
            
            let color: Color = {
                if selectedStablecoin == stablecoinAddress {
                    return Color.green
                } else {
                    return Color.primary
                }
            }()
            
            Button(action: { selectedStablecoin = stablecoinAddress }) {
                StablecoinCard(
                    stablecoinCode: stablecoins.stablecoinInformation[chainID]?[stablecoinAddress]?.name ?? "Unknown Stablecoin",
                    strokeColor: color
                )
            }
            .accentColor(color)
        }
    }
    
}

/**
 Displays a card containing a stablecoin currency code
 */
struct StablecoinCard: View {
    
    let stablecoinCode: String
    
    let strokeColor: Color
    
    var body: some View {
        HStack {
            Spacer()
            Text(stablecoinCode)
                .bold()
            Spacer()
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

/**
 A custom `TextField` for entering stablecoin amounts.
 */
struct StablecoinAmountField: View {
    
    #warning("TODO: make sure this label parameter does nothing and then get rid of it")
    let label: String
    @Binding var value: Int
    let formatter: NumberFormatter
    
    var body: some View {
        TextField("0.00", value: $value, formatter: formatter)
            .font(.largeTitle)
            .keyboardType(.numbersAndPunctuation)
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary, lineWidth: 1)
            )
    }
    
}

/**
 Displays a vertical list of `SettlementMethodCard`s, one for each settlement method that the offer has created. These cards can be tapped to indicate that the user is willing to use them to send/receive payment for the offer being created.
 */
struct SettlementMethodSelector: View {
    
    let settlementMethods: [SettlementMethod]
    
    @Binding var selectedSettlementMethods: [SettlementMethod]
    
    var body: some View {
        ForEach(settlementMethods) { settlementMethod in
            SettlementMethodCard(
                settlementMethod: settlementMethod,
                stablecoinCurrencyCode: "STBL",
                selectedSettlementMethods: $selectedSettlementMethods
            )
        }
    }
    
}

/**
 Displays a card containing settlement method information. The "Price" button on the card can be tapped to specify the price of the
 */
struct SettlementMethodCard: View {
    
    @State var settlementMethod: SettlementMethod
    
    let stablecoinCurrencyCode: String
    
    @Binding var selectedSettlementMethods: [SettlementMethod]
    
    @State var isSelected = false
    
    @State var isEditingPrice = false
    
    @State var priceValue: Double = 0.0
    
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
                            // If this settlement is selected, we update its price value in the selected settlement methods list.
                            if let index = selectedSettlementMethods.firstIndex(where: {
                                selectedSettlementMethod in
                                    settlementMethod.id == selectedSettlementMethod.id
                            }) {
                                settlementMethod.price = String(describing: priceValue)
                                selectedSettlementMethods[index] = settlementMethod
                            }
                            
                        }
                }
            }
           Spacer()
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
        .accentColor(.primary)
        .contentShape(Rectangle())
        .onTapGesture {
            if (isSelected) {
                selectedSettlementMethods.removeAll { settlementMethodToCheck in
                    return settlementMethodToCheck.method == settlementMethod.method && settlementMethodToCheck.currency == settlementMethod.currency
                }
                isSelected = false
            } else {
                selectedSettlementMethods.append(settlementMethod)
                isSelected = true
            }
        }
    }
    
    /**
     Builds a human readable string describing the currency and transfer method, such as "EUR via SEPA" or "USD via SWIFT"
     */
    func buildCurrencyDescription() -> String {
        return settlementMethod.currency + " via " + settlementMethod.method
    }
    
    /**
     Builds a human readable string describing the price specified for this settlement method, such as "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC"
     */
    func buildPriceDescription() -> String {
        if settlementMethod.price == "" {
            return "Price: Tap to specify"
        } else {
            return "Price: " + settlementMethod.price + " " + settlementMethod.currency + "/" + stablecoinCurrencyCode
        }
    }
    
    /**
     Returns a NumberFormatter
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
    
    @Binding var value: Double
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

/**
 Displays a preview of `CreateOfferView`
 */
struct CreateOfferView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CreateOfferView()
        }
    }
}
