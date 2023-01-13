//
//  TakeOfferView.swift
//  iosApp
//
//  Created by jimmyt on 8/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import SwiftUI

/**
 Allows the user to specify a stablecoin amount, select a settlement method and take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer). This should only be used within a sheet.
 */
struct TakeOfferView<Offer_TruthSource, SettlementMethod_TruthSource>: View where Offer_TruthSource: UIOfferTruthSource, SettlementMethod_TruthSource: UISettlementMethodTruthSource {
    
    /**
     Indicates whether we are showing the sheet in which this View is displayed.
     */
    @Binding var isShowingTakeOfferSheet: Bool
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information.
     */
    let stablecoinInfoRepo = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    /**
     The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) about which this `TakeOfferView` displays information.
     */
    let offerID: UUID
    
    /**
     The `OffersViewModel` that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: Offer_TruthSource
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodTruthSource: SettlementMethod_TruthSource
    
    /**
     A `NumberFormatter` for formatting stablecoin amounts.
     */
    let stablecoinFormatter = NumberFormatter()
    
    /**
     The amount of stablecoin that the user has indicated they want to buy/sell. If the minimum and maximum amount of the offer this `View` represents are equal, this will not be used.
     */
    @State private var specifiedStablecoinAmount = 0
    
    /**
     The settlement method (created by the offer maker) by which the user has chosen to send/receive traditional currency payment, or `nil` if the user has not made such a selection.
     */
    @State private var selectedMakerSettlementMethod: SettlementMethod? = nil
    /**
     The user's/taker's settlement method corresponding to `selectedMakerSettlementMethod`, containing the user's/taker's private data which will be sent to the maker. Must have the same currency and method value as `selectedMakerSettlementMethod`.
     */
    @State private var selectedTakerSettlementMethod: SettlementMethod? = nil
    
    /**
     Indicates whether this view should allow the user to submit information and take the offer, display a gas estimate for approving a token transfer in order to take the offer, or display a gas estimate for taking the offer.
     */
    @State private var selectedTakeOfferView: SelectedTakeOfferView = .submitInformation
    
    /**
     The key pair created for use by the user/taker, if any.
     */
    @State private var createdKeyPairForTaker: KeyPair? = nil
    
    /**
     Creates the string that will be displayed in the label  of the button that takes the offer.
     */
    func createTakeOfferButtonLabel(offer: Offer) -> String {
        if offer.approvingToTakeState == .none || offer.approvingToTakeState == .error {
            return "Approve Transfer to Take Offer"
        } else if offer.approvingToTakeState == .validating || offer.approvingToTakeState == .sendingTransaction || offer.approvingToTakeState == .awaitingTransactionConfirmation {
            return "Approving Transfer"
        } else if offer.approvingToTakeState == .completed && (offer.takingOfferState == .none || offer.takingOfferState == .error) {
            return "Take Offer"
        } else if offer.takingOfferState == .completed {
            return "Offer Taken"
        } else {
            return "Taking Offer"
        }
    }
    
    /**
     Gets the color of the outline around the button that cancels the offer.
     */
    func getTakeOfferButtonOutlineColor(offer: Offer) -> Color {
        if offer.takingOfferState == .none || offer.takingOfferState == .error {
            return Color.primary
        } else {
            return Color.gray
        }
    }
    
    var body: some View {
        if let offer = offerTruthSource.offers[offerID] {
            if (!offer.isCreated && offer.cancelingOfferState == .none) {
                // If isCreated is false and cancelingOfferState is .none, then the offer has been canceled by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS canceled by the user of this interface, we do show offer info, but relabel the "Cancel Offer" button to indicate that the offer has been canceled.
                Text("This Offer has been canceled.")
            } else if (offer.isTaken && offer.takingOfferState == .none) {
                // If isTaken is true and takingOfferState is .none, then the offer has been taken by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS taken by the user of this interface, we do show offer info, but relabel the "Take Offer" button to indicate that the offer has been taken.
                Text("This Offer has been taken.")
            } else {
                switch selectedTakeOfferView {
                case .submitInformation:
                    let stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(
                        chainID: offer.chainID,
                        contractAddress: offer.stablecoin
                    )
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading) {
                            Text("Take Offer")
                                .font(.title)
                                .bold()
                            Text("You are:")
                                .font(.title2)
                            Text(createRoleDescription(offerDirection: offer.direction, stablecoinInformation: stablecoinInformation, selectedSettlementMethod: selectedMakerSettlementMethod))
                                .font(.title)
                                .bold()
                            OfferAmountView(
                                stablecoinInformation: stablecoinInformation,
                                minimum: offer.amountLowerBound,
                                maximum: offer.amountUpperBound,
                                securityDeposit: offer.securityDepositAmount
                            )
                            if offer.amountLowerBound != offer.amountUpperBound {
                                Text("Enter an Amount:")
                                StablecoinAmountField(value: $specifiedStablecoinAmount, formatter: stablecoinFormatter)
                                ServiceFeeAmountView(
                                    stablecoinInformation: stablecoinInformation,
                                    amount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                    serviceFeeRate: offer.serviceFeeRate
                                )
                            } else {
                                ServiceFeeAmountView(
                                    stablecoinInformation: stablecoinInformation,
                                    minimumString: String(offer.serviceFeeRate * offer.amountLowerBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000))),
                                    maximumString: String(offer.serviceFeeRate * offer.amountUpperBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000)))
                                )
                            }
                            Text("Select Settlement Method:")
                                .font(.title2)
                            ImmutableSettlementMethodSelector(
                                settlementMethods: offer.settlementMethods,
                                selectedSettlementMethod: $selectedMakerSettlementMethod,
                                stablecoinCurrencyCode: stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
                            )
                            if selectedMakerSettlementMethod != nil {
                                Text("Select Your Settlement Method:")
                                    .font(.title2)
                                FilterableSettlementMethodSelector(
                                    settlementMethodTruthSource: settlementMethodTruthSource,
                                    selectedMakerSettlementMethod: $selectedMakerSettlementMethod,
                                    selectedTakerSettlementMethod: $selectedTakerSettlementMethod
                                )
                            }
                            VStack {
                                if offer.approvingToTakeState == .validating || offer.approvingToTakeState == .sendingTransaction {
                                    Text("Approving \(stablecoinInformation?.currencyCode ?? "Stablecoin") Transfer in Order to Take Offer")
                                } else if offer.approvingToTakeState == .awaitingTransactionConfirmation {
                                    Text("Awaiting Confirmation of Transfer Approval")
                                } else if offer.approvingToTakeState == .error {
                                    Text(offer.approvingToTakeError?.localizedDescription ?? "An unknown error occurred while approving the token transfer")
                                        .foregroundColor(Color.red)
                                } else if offer.approvingToTakeState == .completed {
                                    if offer.takingOfferState == .validating || offer.takingOfferState == .sendingTransaction {
                                        Text("Taking Offer")
                                    } else if offer.takingOfferState == .awaitingTransactionConfirmation {
                                        Text("Awaiting Confirmation that Offer is Taken")
                                    } else if offer.takingOfferState == .error {
                                        Text(offer.takingOfferError?.localizedDescription ?? "An unknown error occurred while taking the Offer")
                                    }
                                }
                                Button(
                                    action: {
                                        if offer.approvingToTakeState == .none || offer.approvingToTakeState == .error {
                                            selectedTakeOfferView = .approveTokenTransferGasEstimate
                                        } else if offer.takingOfferState == .none || offer.takingOfferState == .error {
                                            selectedTakeOfferView = .takeOfferGasEstimate
                                        }
                                    },
                                    label: {
                                        Text(createTakeOfferButtonLabel(offer: offer))
                                            .font(.largeTitle)
                                            .bold()
                                            .padding(10)
                                            .frame(maxWidth: .infinity)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(getTakeOfferButtonOutlineColor(offer: offer), lineWidth: 3)
                                            )
                                    }
                                )
                                .accentColor(Color.primary)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        // Set up the stablecoin NumberFormatter when this view appears
                        stablecoinFormatter.maximumFractionDigits = 3
                    }
                case .approveTokenTransferGasEstimate:
                    TransactionGasDetailsView(
                        isShowingSheet: $isShowingTakeOfferSheet,
                        title: "Approve Token Transfer",
                        buttonLabel: "Approve Token Transfer",
                        buttonAction: { createdTransaction in
                            offerTruthSource.approveTokenTransferToTakeOffer(
                                offer: offer,
                                takenSwapAmount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                makerSettlementMethod: selectedMakerSettlementMethod,
                                takerSettlementMethod: selectedTakerSettlementMethod,
                                approveTokenTransferToTakeOfferTransaction: createdTransaction
                            )
                        },
                        runOnAppearance: { approveTransferTransactionBinding, transactionCreationErrorBinding in
                            if offer.approvingToTakeState == .none || offer.approvingToTakeState == .error {
                                offerTruthSource.createApproveTokenTransferToTakeOfferTransaction(
                                    offer: offer,
                                    takenSwapAmount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                    makerSettlementMethod: selectedMakerSettlementMethod,
                                    takerSettlementMethod: selectedTakerSettlementMethod,
                                    createdTransactionHandler: { createdTransaction in
                                        approveTransferTransactionBinding.wrappedValue = createdTransaction
                                    },
                                    errorHandler: { error in
                                        transactionCreationErrorBinding.wrappedValue = error
                                    }
                                )
                            }
                        }
                    )
                case .takeOfferGasEstimate:
                    TransactionGasDetailsView(
                        isShowingSheet: $isShowingTakeOfferSheet,
                        title: "Take Offer",
                        buttonLabel: "Take Offer",
                        buttonAction: { createdTransaction in
                            offerTruthSource.takeOffer(
                                offer: offer,
                                takenSwapAmount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                makerSettlementMethod: selectedMakerSettlementMethod,
                                takerSettlementMethod: selectedTakerSettlementMethod,
                                keyPair: createdKeyPairForTaker,
                                offerTakingTransaction: createdTransaction
                            )
                        },
                        runOnAppearance: { takeOfferTransactionBinding, transactionCreationErrorBinding in
                            if offer.takingOfferState == .none || offer.takingOfferState == .error {
                                offerTruthSource.createTakeOfferTransaction(
                                    offer: offer,
                                    takenSwapAmount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                    makerSettlementMethod: selectedMakerSettlementMethod,
                                    takerSettlementMethod: selectedTakerSettlementMethod,
                                    createdTransactionAndKeyPairHandler: { createdTransaction, createdKeyPair in
                                        takeOfferTransactionBinding.wrappedValue = createdTransaction
                                        $createdKeyPairForTaker.wrappedValue = createdKeyPair
                                    },
                                    errorHandler: { error in
                                        transactionCreationErrorBinding.wrappedValue = error
                                    }
                                )
                            }
                        }
                    )
                }
            }
        } else {
            Text("This Offer is not available.")
        }
    }
    
    /**
     Creates a role description string (such as "Buying USDC with USD" or "Selling DAI for EUR", or "Buying BUSD").
     
     - Parameters:
        - offerDirection: The offer's direction.
        - stablecoinInformation: An optional `StablecoinInformation` for the offer's stablecoin.
        - selectedSettlementMethod: The currently selected settlement method that the user (taker) and the maker will use to exchange traditional currency payment.
     
     - Returns: A role description `String`.
     */
    func createRoleDescription(offerDirection: OfferDirection, stablecoinInformation: StablecoinInformation?, selectedSettlementMethod: SettlementMethod?) -> String {
        var direction: String {
            switch offerDirection {
            case .buy:
                // The maker is offering to buy stablecoin, so the user of this interface (the taker) is selling stablecoin
                return "Selling"
            case .sell:
                // The maker is offering to sell stablecoin, so the user of this interface (the maker) is buying stablecoin
                return "Buying"
            }
        }
        let stablecoinCurrencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        var directionPreposition: String {
            switch offerDirection {
            case .buy:
                // The string will be "Selling ... for ..."
                return "for"
            case .sell:
                // The string will be "Buying ... with ..."
                return "with"
            }
        }
        var currencyPhrase: String {
            if let selectedSettlementMethod = selectedSettlementMethod {
                // If the user has selected a settlement method, we want to include the currency of that settlement method in the role description.
                return " \(directionPreposition) \(selectedSettlementMethod.currency)"
            } else {
                return ""
            }
        }
        return "\(direction) \(stablecoinCurrencyCode)\(currencyPhrase)"
    }
    
    /**
     Indicates what kind of information this view should display.
     
     Indicates whether this view should allow the user to submit information and take the offer, display a gas estimate for approving a token transfer in order to take the offer, or display a gas estimate for taking the offer.
     */
    enum SelectedTakeOfferView {
        /**
         Indicates that this view should allow the user to submit information and take the offer.
         */
        case submitInformation
        /**
         Indicates that this view should display a gas estimate for approving a token transfer in order to take the offer.
         */
        case approveTokenTransferGasEstimate
        /**
         Indicates that this view should display a gas estimate for taking the offer.
         */
        case takeOfferGasEstimate
    }
    
}

/**
 Displays all of the user's settlement methods in the given truth source that have the same currency and method properties as the given maker settlement method.
 */
struct FilterableSettlementMethodSelector<TruthSource>: View where TruthSource: UISettlementMethodTruthSource {
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodTruthSource: TruthSource
    
    /**
     All settlement methods belonging to the user with method and currency properties equal to that of `selectedMakerSettlementMethod`, or none if `selectedMakerSettlementMethod` is `nil`.
     */
    var matchingSettlementMethods: [SettlementMethod] {
        settlementMethodTruthSource.settlementMethods.filter { settlementMethod in
            if let selectedMakerSettlementMethod = selectedMakerSettlementMethod {
                return settlementMethod.method == selectedMakerSettlementMethod.method && settlementMethod.currency == selectedMakerSettlementMethod.currency
            } else {
                return false
            }
        }
    }
    
    /**
     The currently selected `SettlementMethod` belonging to the maker, or `nil` if no `SettlementMethod` is currently selected.
     */
    @Binding var selectedMakerSettlementMethod: SettlementMethod?
    /**
     The currently selected `SettlementMethod` belonging to the taker, which must have method and currency values equal to those of `selectedMakerSettlementMethod`.
     */
    @Binding var selectedTakerSettlementMethod: SettlementMethod?
    
    var body: some View {
        if !matchingSettlementMethods.isEmpty {
            ForEach(matchingSettlementMethods) { settlementMethod in
                
                let color: Color = {
                    if selectedTakerSettlementMethod?.id == settlementMethod.id {
                        return Color.green
                    } else {
                        return Color.primary
                    }
                }()
                
                Button(action: { selectedTakerSettlementMethod = settlementMethod }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(buildCurrencyDescription(settlementMethod: settlementMethod))
                                .bold()
                                .padding(1)
                            SettlementMethodPrivateDetailView(settlementMethod: settlementMethod)
                        }
                        Spacer()
                    }
                    .padding(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color, lineWidth: 1)
                    )
                }
                .accentColor(color)
            }
        } else {
            Text("You have no settlement methods compatible with this offer.")
                .font(.title2)
        }
    }
    
}

/**
 Displays a vertical list of `ImmutableSettlementMethodCard`s, one for each of this offer's settlement methods. Only one `ImmutableSettlementMethodCard` can be selected at a time. When such a card is selected, `selectedSettlementMethod` is set equal to the `SettlementMethod` that card represents.
 */
struct ImmutableSettlementMethodSelector: View {
    
    /**
     The `Offer`'s `SettlementMethod`s.
     */
    let settlementMethods: [SettlementMethod]
    
    /**
     The currently selected `SettlementMethod`, or `nil` if no `SettlementMethod` is currently selected.
     */
    @Binding var selectedSettlementMethod: SettlementMethod?
    
    /**
     The currency code of the Offer's stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        if settlementMethods.count > 0 {
            ForEach(settlementMethods) { settlementMethod in
                
                // If the settlement method that this card represents is the selected settlement method, this card should be colored green.
                let color: Color = {
                    if selectedSettlementMethod?.currency == settlementMethod.currency && selectedSettlementMethod?.price == settlementMethod.price && selectedSettlementMethod?.method == settlementMethod.method {
                        return Color.green
                    } else {
                        return Color.primary
                    }
                }()
                
                Button(action: { selectedSettlementMethod = settlementMethod }) {
                    ImmutableSettlementMethodCard(
                        settlementMethod: settlementMethod,
                        color: color,
                        stablecoinCurrencyCode: stablecoinCurrencyCode
                    )
                }
                .accentColor(color)
            }
        } else {
            Text("No Settlement Methods Found")
        }
    }
}

/**
 Displays a card containing settlement method information that cannot be edited.
 */
struct ImmutableSettlementMethodCard: View {
    
    /**
     The `SettlementMethod` that this card represents.
     */
    var settlementMethod: SettlementMethod
    
    /**
     The color of the stroke surrounding this card and the text within it.
     */
    var color: Color
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(buildCurrencyDescription(settlementMethod: settlementMethod))
                    .foregroundColor(color)
                    .bold()
                    .padding(1)
                Text(buildPriceDescription())
                    .foregroundColor(color)
                    .bold()
                    .padding(1)
            }
            Spacer()
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
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
    
}

/**
 Builds a human readable string describing the currency and transfer method of a settlement method, such as "EUR via SEPA" or "USD via SWIFT".
 */
func buildCurrencyDescription(settlementMethod: SettlementMethod) -> String {
    return settlementMethod.currency + " via " + settlementMethod.method
}

/**
 Displays a preview of `TakeOfferView`
 */
struct TakeOfferView_Previews: PreviewProvider {
    
    @State static var isShowingSheet = true
    
    static var previews: some View {
        TakeOfferView(
            isShowingTakeOfferSheet: $isShowingSheet,
            offerID: Offer.sampleOfferIds[2],
            offerTruthSource: PreviewableOfferTruthSource(),
            settlementMethodTruthSource: PreviewableSettlementMethodTruthSource()
        )
    }
}
