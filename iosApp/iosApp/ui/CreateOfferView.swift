//
//  CreateOfferView.swift
//  iosApp
//
//  Created by jimmyt on 7/16/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt
import web3swift

/**
 The screen for creating a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct CreateOfferView<TruthSource>: View where TruthSource: UIOfferTruthSource {
    
    init(offerTruthSource: TruthSource) {
        self.offerTruthSource = offerTruthSource
        stablecoinFormatter = NumberFormatter()
        stablecoinFormatter.numberStyle = .currency
        stablecoinFormatter.maximumFractionDigits = 3
    }
    
    /**
     An object adopting the `OfferTruthSource` protocol that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: TruthSource
    
    /**
     The ID of the blockchain on which the new offer will be created.
     */
    private var chainID = BigUInt(31337)
    
    /**
     A `StablecoinInformationRepository` for all supported stablecoins on the blockchain specified by `chainID`
     */
    private var stablecoins = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    /**
     The direction of the new offer, or null if the user has not specified a direction.
     */
    @State private var selectedDirection: OfferDirection = .buy
    
    /**
     The contract address of the stablecoin that the user is offering to swap, or null if the user has not specified a stablecoin.
     */
    @State private var selectedStablecoin: EthereumAddress? = nil
    
    /**
     A `NumberFormatter` for formatting stablecoin amounts.
     */
    private let stablecoinFormatter: NumberFormatter
    
    /**
     The minimum stablecoin amount that the user will offer to swap.
     */
    @State private var minimumAmount = 0
    
    /**
     The maximum stablecoin amount that the user will offer to swap.
     */
    @State private var maximumAmount = 0
    
    /**
     The specified security  deposit amount.
     */
    @State private var securityDepositAmount = 0
    
    /**
     Indicates whether the security deposit description disclosure group is expanded.
     */
    @State private var isSecurityDepositDescriptionExpanded = false
    
    /**
     Indicates whether the service fee rate description disclosure group is expanded.
     */
    @State private var isServiceFeeRateDescriptionExpanded = false
    
    /**
     An `Array` of `SettlementMethod`s from which the user can choose.
     */
    private var settlementMethods: [SettlementMethod] = SettlementMethod.sampleSettlementMethodsEmptyPrices
    
    /**
     The `SettlementMethod`s that the user has selected.
     */
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
                StablecoinAmountField(value: $minimumAmount, formatter: stablecoinFormatter)
                HStack {
                    Text("Maximum \(currencyCode ?? "Stablecoin") Amount:")
                        .font(.title2)
                    Spacer()
                }
                StablecoinAmountField(value: $maximumAmount, formatter: stablecoinFormatter)
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
                StablecoinAmountField(value: $securityDepositAmount, formatter: stablecoinFormatter)
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
                    if offerTruthSource.isGettingServiceFeeRate {
                        Text("Getting Service Fee Rate...")
                        Spacer()
                    } else {
                        if offerTruthSource.serviceFeeRate != nil {
                            Text(String(format:"%.2f", Double(offerTruthSource.serviceFeeRate!)/100) + " %")
                                .font(.largeTitle)
                            Spacer()
                        } else {
                            Text("Could not get service fee rate.")
                            Spacer()
                            Button(
                                action: {
                                    offerTruthSource.updateServiceFeeRate()
                                },
                                label: {
                                    Text("Retry")
                                        .font(.title2)
                                        .bold()
                                        .padding(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10).stroke(Color.primary, lineWidth: 3)
                                        )
                                }
                            )
                            .accentColor(Color.primary)
                        }
                    }
                }
                if let serviceFeeRate = offerTruthSource.serviceFeeRate {
                    ServiceFeeAmountView(
                        stablecoinInformation: stablecoins.getStablecoinInformation(
                            chainID: chainID,
                            contractAddress: selectedStablecoin ?? EthereumAddress("0x0000000000000000000000000000000000000000")!
                        ),
                        minimumAmount: NSNumber(floatLiteral: Double(minimumAmount)).decimalValue,
                        maximumAmount: NSNumber(floatLiteral: Double(maximumAmount)).decimalValue,
                        serviceFeeRate: serviceFeeRate
                    )
                    .padding(.bottom, 10.0)
                }
                HStack {
                    Text("Settlement Methods:")
                        .font(.title2)
                    Spacer()
                }
                SettlementMethodSelector(
                    settlementMethods: settlementMethods,
                    stablecoinCurrencyCode: currencyCode ?? "Stablecoin",
                    selectedSettlementMethods: $selectedSettlementMethods
                )
                /*
                 We don't want to display a description of the offer opening process state if an offer isn't being opened. We also don't want to do this if we encounter an error; we should display the actual error message instead.
                 */
                if (offerTruthSource.openingOfferState != .none && offerTruthSource.openingOfferState != .error) {
                    HStack {
                        Text(offerTruthSource.openingOfferState.description)
                            .font(.title2)
                        Spacer()
                    }
                }
                if (offerTruthSource.openingOfferState == .error) {
                    HStack {
                        Text(offerTruthSource.openingOfferError?.localizedDescription ?? "An unknown error occured")
                            .foregroundColor(Color.red)
                        Spacer()
                    }
                }
                if offerTruthSource.openingOfferState == .none || offerTruthSource.openingOfferState == .error {
                    Button(
                        action: {
                            // Don't let the user create a new offer if one is currently being created, or if the user has just created one
                            if offerTruthSource.openingOfferState == .none || offerTruthSource.openingOfferState == .error {
                                offerTruthSource.openOffer(
                                    chainID: chainID,
                                    stablecoin: selectedStablecoin,
                                    stablecoinInformation: stablecoins.getStablecoinInformation(chainID: chainID, contractAddress: selectedStablecoin),
                                    minimumAmount: Decimal(minimumAmount),
                                    maximumAmount: Decimal(maximumAmount),
                                    securityDepositAmount: Decimal(securityDepositAmount),
                                    direction: selectedDirection,
                                    settlementMethods: selectedSettlementMethods
                                )
                            }
                        },
                        label: {
                            Text("Open Offer")
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
                } else if offerTruthSource.openingOfferState == .completed {
                    Text("Offer Opened")
                        .font(.largeTitle)
                        .bold()
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                } else {
                    Text("Opening Offer")
                        .font(.largeTitle)
                        .bold()
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
            }
            .padding([.leading, .trailing, .bottom])
        }
        .navigationBarTitle(Text("Open Offer"))

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
    
    /**
     The blockchain ID of the stablecoins to be displayed.
     */
    let chainID: BigUInt
    
    /**
     A `StablecoinInformationRepository` from which this will obtain stablecoin information.
     */
    let stablecoins: StablecoinInformationRepository
    
    /**
     The contract address of the currently selected stablecoin, or `nil` if the user has not selected a stablecoin.
     */
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
    
    /**
     The currency code of the stablecoin this card represents.
     */
    let stablecoinCode: String
    
    /**
     The color of the rounded rectangle stroke around this card.
     */
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
    
    /**
     The specified stablecoin amount.
     */
    @Binding var value: Int
    
    /**
     A `NumberFormatter` used for formatting the stablecoin amount.
     */
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
 Displays a vertical list of settlement method cards one for each settlement method that the offer has created. These cards can be tapped to indicate that the user is willing to use them to send/receive payment for the offer being created.
 */
struct SettlementMethodSelector: View {
    
    /**
     An `Array` of `SettlementMethod`s to be displayed.
     */
    let settlementMethods: [SettlementMethod]
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    /**
     An `Array` containing the `SettlementMethod`s  that the user has selected.
     */
    @Binding var selectedSettlementMethods: [SettlementMethod]
    
    var body: some View {
        ForEach(settlementMethods) { settlementMethod in
            SettlementMethodCard(
                settlementMethod: settlementMethod,
                stablecoinCurrencyCode: stablecoinCurrencyCode,
                selectedSettlementMethods: $selectedSettlementMethods
            )
        }
    }
    
}

/**
 Displays a card containing settlement method information. The "Price" button on the card can be tapped to specify the price of the
 */
struct SettlementMethodCard: View {
    
    /**
     The `SettlementMethod`  that this card represents.
     */
    @State var settlementMethod: SettlementMethod
    
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
                        selectedSettlementMethods.append(settlementMethod)
                    }
                }
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
        .accentColor(.primary)
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

/**
 Displays a preview of `CreateOfferView`
 */
struct CreateOfferView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CreateOfferView<PreviewableOfferTruthSource>(
                offerTruthSource: PreviewableOfferTruthSource()
            )
        }
    }
}
