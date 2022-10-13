//
//  SwapView.swift
//  iosApp
//
//  Created by jimmyt on 8/27/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt

/**
 Displays information about a specific [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
 */
struct SwapView<TruthSource>: View where TruthSource: UISwapTruthSource {
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information. Defaults to `StablecoinInformationRepository.hardhatStablecoinInfoRepo` if no other value is provided.
     */
    let stablecoinInfoRepo = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    /**
     The [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) about which this `SwapView` displays information.
     */
    @ObservedObject var swap: Swap
    
    /**
     The `SwapTruthSource` that acts as a single source of truth for all swap-related data.
     */
    @ObservedObject var swapTruthSource: TruthSource
    
    /**
     The direction component of the counterparty's role, as a human readable string. (either "Buyer" if the counterparty is the buyer and the user is the seller, or "Seller" if the counterparty is the seller and the user is the buyer)
     */
    var counterPartyDirection: String {
        switch swap.role {
        case .makerAndBuyer, .takerAndBuyer:
            // We are the buyer, so the counterparty must be the seller
            return "Seller"
        case .makerAndSeller, .takerAndSeller:
            // We are the seller, so the counterparty must be the buyer
            return "Buyer"
        }
    }
    
    /**
     The settlement method of `swap`, but with the private data belonging to the user of this interface.
     */
    var settlementMethodOfUser: SettlementMethod {
        var settlementMethod = swap.settlementMethod
        switch swap.role {
        case .makerAndBuyer, .makerAndSeller:
            settlementMethod.privateData = swap.makerPrivateSettlementMethodData
        case .takerAndBuyer, .takerAndSeller:
            settlementMethod.privateData = swap.takerPrivateSettlementMethodData
        }
        return settlementMethod
    }
    
    /**
     The settlement method of `swap`, but with the private data of the counterparty, if any.
     */
    var settlementMethodOfCounterparty: SettlementMethod {
        var settlementMethod = swap.settlementMethod
        switch swap.role {
        case .makerAndBuyer, .makerAndSeller:
            // We are the maker, so the counterparty is the taker
            settlementMethod.privateData = swap.takerPrivateSettlementMethodData
        case .takerAndBuyer, .takerAndSeller:
            // We are the taker, so the counterparty is the maker
            settlementMethod.privateData = swap.makerPrivateSettlementMethodData
        }
        return settlementMethod
    }
    
    var body: some View {
        let stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(chainID: swap.chainID, contractAddress: swap.stablecoin)
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                Text("Role:")
                    .font(.title2)
                Text(createRoleDescription(swapRole: swap.role, stablecoinInformation: stablecoinInformation))
                    .font(.title)
                    .bold()
                SwapAmountView(
                    stablecoinInformation: stablecoinInformation,
                    amount: swap.takenSwapAmount,
                    securityDeposit: swap.securityDepositAmount,
                    serviceFee: swap.serviceFeeAmount
                )
                Text("Settlement method:")
                    .font(.title2)
                SwapSettlementMethodView(
                    stablecoinInformation: stablecoinInformation,
                    settlementMethod: swap.settlementMethod,
                    swapAmount: swap.takenSwapAmount
                )
                Text("\(counterPartyDirection)'s Details:")
                    .font(.title2)
                if settlementMethodOfCounterparty.privateData != nil {
                    SettlementMethodPrivateDetailView(settlementMethod: settlementMethodOfCounterparty)
                        .padding(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(lineWidth: 3)
                        )
                } else {
                    Text("Not yet received.")
                        .padding([.top, .bottom], 3)
                }
                Text("Your Details:")
                    .font(.title2)
                SettlementMethodPrivateDetailView(settlementMethod: settlementMethodOfUser)
                    .padding(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(lineWidth: 3)
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .padding([.leading, .trailing])
            VStack(alignment: .leading) {
                Text("State:")
                    .font(.title2)
                SwapStateView(
                    swapState: swap.state,
                    userRole: swap.role,
                    settlementMethodCurrency: swap.settlementMethod.currency
                )
                ActionButton(
                    swap: swap,
                    swapTruthSource: swapTruthSource
                )
                Button(
                    action: {},
                    label: {
                        Text("Chat")
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
                .accentColor(.primary)
                Button(
                    action: {},
                    label: {
                        Text("Raise Dispute")
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
                .accentColor(.red)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .padding([.leading, .trailing, .bottom])
        }
        .navigationBarTitle(Text("Swap"))
    }
    
    /**
     Creates a role description string (such as "Buying USDC as maker" or "Selling DAI as taker") given the user's `SwapRole` and an optional `StablecoinInformation`.
     
     - Parameters:
        - role: The user's `SwapRole` for this swap.
        - stablecoinInformation: An optional `StablecoinInformation` for this swap's stablecoin. If this is `nil`, this uses the symbol "Unknown Stablecoin".
     
     - Returns: A role description.
     */
    func createRoleDescription(swapRole: SwapRole, stablecoinInformation: StablecoinInformation?) -> String {
        var direction: String {
            switch swapRole {
            case .makerAndBuyer, .takerAndBuyer:
                return "Buying"
            case .makerAndSeller, .takerAndSeller:
                return "Selling"
            }
        }
        let currencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        var role: String {
            switch swapRole {
            case .makerAndBuyer, .makerAndSeller:
                return "Maker"
            case .takerAndBuyer, .takerAndSeller:
                return "Taker"
            }
        }
        return "\(direction) \(currencyCode) as \(role)"
    }
    
}

/**
 A view that displays the amount, service fee, and security deposit for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
 */
struct SwapAmountView: View {
    /**
     An optional `StablecoinInformation` for the swap's stablecoin.
     */
    let stablecoinInformation: StablecoinInformation?
    /**
     The swap's `takenSwapAmount` divided by ten raised to the power of the stablecoin's decimal count, as a `String`.
     */
    let amountString: String
    /**
     The swap's `serviceFeeAmount` divided by ten raised to the power of the stablecoin's decimal count, as a `String`.
     */
    let serviceFeeString: String
    /**
     The swap's `securityDepositAmount` divided by ten raised to the power of the stablecoin's decimal count, as a `String`.
     */
    let securityDepositString: String
    
    /**
     Creates a new `SwapAmountView`.
     
     - Parameters:
        - stablecoinInformation: An optional `StablecoinInformation` for the swap's stablecoin. If this is `nil`, the currency code "Unknown Stablecoin" will be used, and the amounts will be displayed in token base units.
        - amount: The `Swap`'s `takenSwapAmount`.
        - securityDeposit: The `Swap`'s `securityDepositAmount`.
        - serviceFee: The `Swap`'s `serviceFeeAmount`.
     */
    init(stablecoinInformation: StablecoinInformation?, amount: BigUInt, securityDeposit: BigUInt, serviceFee: BigUInt) {
        self.stablecoinInformation = stablecoinInformation
        let stablecoinDecimal = stablecoinInformation?.decimal ?? 1
        amountString = String(amount / BigUInt(10).power(stablecoinDecimal))
        serviceFeeString = String(serviceFee / BigUInt(10).power(stablecoinDecimal))
        securityDepositString = String(securityDeposit / BigUInt(10).power(stablecoinDecimal))
    }
    
    var body: some View {
        let currencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        let amountHeader = (stablecoinInformation != nil) ? "Amount: " : "Amount (in token base units):"
        Text(amountHeader)
            .font(.title2)
        Text("\(amountString) \(currencyCode)")
            .font(.title2).bold()
        Text("Service Fee Amount:")
            .font(.title2)
        Text("\(serviceFeeString) \(currencyCode)")
            .font(.title2).bold()
        Text("Security Deposit Amount:")
            .font(.title2)
        Text("\(securityDepositString) \(currencyCode)")
            .font(.title2).bold()
    }
}

/**
 Displays a card containing information about the swap's settlement method.
 */
struct SwapSettlementMethodView: View {
    /**
     A human readable string describing the currency and transfer method, such as "EUR via SEPA"
     */
    let currencyDescription: String
    /**
     A human readable string describing the price for the settlement method, such as "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC"
     */
    let priceDescription: String
    /**
     A human readable string describing the total traditional currency cost of this swap, such as "15000 EUR" or "1000 USD".
     */
    let totalString: String
    
    /**
     Creates a new `SwapSettlementMethodView`.
     
     - Parameters:
        - stablecoinInformation: An optional `StablecoinInformation` for the swap's stablecoin. If this is `nil`, `priceDescription` will be "Unable to determine price" and `totalString` will be "Unable to calculate total".
        - settlementMethod: The swap's `SettlementMethod`.
        - swapAmount: The swap's taken swap amount.
     */
    init(stablecoinInformation: StablecoinInformation?, settlementMethod: SettlementMethod, swapAmount: BigUInt) {
        currencyDescription = "\(settlementMethod.currency) via \(settlementMethod.method)"
        if let stablecoinInformation = stablecoinInformation {
            priceDescription = "Price: \(settlementMethod.price) \(settlementMethod.currency)/\(stablecoinInformation.currencyCode)"
            let amountString = String(swapAmount / BigUInt(10).power(stablecoinInformation.decimal))
            let amountDecimal = Decimal(string: amountString)
            let priceDecimal = Decimal(string: settlementMethod.price)
            if let amountDecimal = amountDecimal, let priceDecimal = priceDecimal {
                let total = amountDecimal * priceDecimal
                totalString = "\(String(describing: total)) \(settlementMethod.currency)"
            } else {
                totalString = "Unable to calculate total"
            }
        } else {
            priceDescription = "Unable to determine price"
            totalString = "Unable to calculate total"
        }
        
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(currencyDescription)
                .padding(1)
            Text(priceDescription)
                .padding(1)
            Text("Total: \(totalString)")
                .padding(1)
        }
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary, lineWidth: 3)
        )
    }
    
}

/**
 Displays a human readable string describing the swap's current state.
 */
struct SwapStateView: View {
    
    /**
     The `state` property of the `Swap` that this view represents.
     */
    let swapState: SwapState
    /**
     The `role` property of the `Swap` that this view represents.
     */
    let userRole: SwapRole
    /**
     The currency code of this `Swap`'s settlement method.
     */
    let settlementMethodCurrency: String
    /**
     A name by which we can refer to the stablecoin buyer. If the user is the buyer, this is "you". If the user is the seller, this is "buyer".
     */
    var buyerName: String {
        switch userRole {
        case .makerAndBuyer, .takerAndBuyer:
            // The user is the buyer, so the buyer's name is "you"
            return "you"
        case .makerAndSeller, .takerAndSeller:
            // The user is the seller, so the buyer's name is "buyer"
            return "buyer"
        }
    }
    /**
     A name by which we can refer to the stablecoin seller. If the user is the buyer, this is "seller". If the user is the seller, this is "you".
     */
    var sellerName: String {
        switch userRole {
        case .makerAndBuyer, .takerAndBuyer:
            // The user is the buyer, so the seller's name is "seller"
            return "seller"
        case .makerAndSeller, .takerAndSeller:
            // The user is the seller, so the seller's name is "you"
            return "you"
        }
    }
    
    /**
     A string describing `swapState` based on the value of `userRole`.
     */
    var stateDescription: String {
        switch swapState {
        case .taking:
            return "Taking Offer..."
        case .takeOfferTransactionBroadcast:
            return "Awaiting confirmation that offer is taken"
        case .awaitingTakerInformation:
            switch userRole {
            case .makerAndBuyer, .makerAndSeller:
                // We are the maker, so we are waiting to receive settlement method information from the taker
                return "Waiting to receive details from taker"
            case .takerAndBuyer, .takerAndSeller:
                // We are the taker, so we are sending settlement method information to the maker
                return "Sending details to maker"
            }
        case .awaitingMakerInformation:
            switch userRole {
            case .makerAndBuyer, .makerAndSeller:
                // We are the maker, so we are sending settlement method information to the taker
                return "Sending details to taker"
            case .takerAndBuyer, .takerAndSeller:
                // We are the taker, so we are waiting to receive settlement method information from the maker
                return "Waiting to receive details from maker"
            }
        case .awaitingFilling:
            // The offer should only be in this state if it is a maker-as-seller offer, therefore if we are not the maker and seller, we are waiting for the maker/seller to fill the swap
            switch userRole {
            case .makerAndSeller:
                return "Waiting for you to fill swap"
            default:
                return "Waiting for maker to fill swap"
            }
        case .fillSwapTransactionBroadcast:
            return "Awaiting confirmation that swap is filled"
        case .awaitingPaymentSent:
            return "Waiting for \(buyerName) to send \(settlementMethodCurrency)"
        case .reportPaymentSentTransactionBroadcast:
            return "Awaiting confirmation of reporting that payment is sent"
        case .awaitingPaymentReceived:
            return "Waiting for \(sellerName) to receive \(settlementMethodCurrency)"
        case .reportPaymentReceivedTransactionBroadcast:
            return "Awaiting confirmation of reporting that payment is received"
        case .awaitingClosing:
            return "Waiting for you to close swap"
        case .closeSwapTransactionBroadcast:
            return "Awaiting confirmation that swap is closed"
        case .closed:
            return "Swap Closed"
        }
    }
    
    var body: some View {
        Text(stateDescription)
            .font(.title)
            .bold()
    }
}

/**
 Displays a button allowing the user to execute the current action that must be completed in order to continue the swap process, or displays nothing if the user cannot execute said action.
 
 For example, if the current state of the swap is `SwapState.awaitingPaymentSent` and the user is the buyer, then the user must confirm that they have sent payment in order for the swap process to continue. Therefore this will display a button with the label "Confirm Payment is Sent" which allows the user to do so. However, if the user is the seller, they cannot confirm payment is sent, since that is the buyer's responsibility. In that case, this would display nothing.
 */
struct ActionButton<TruthSource>: View where TruthSource: UISwapTruthSource {
    
    /**
     The `Swap` for which this `ActionButton` displays a button.
     */
    @ObservedObject var swap: Swap
    
    /**
     The `UISwapTruthSource` that acts as a single source of truth for all swap-related data.
     */
    @ObservedObject var swapTruthSource: TruthSource
    
    var body: some View {
        if (swap.state == .awaitingFilling) && swap.role == .makerAndSeller {
            // If the swap state is awaitingFilling and we are the maker and seller, then we display the "Fill Swap" button
            if swap.fillingSwapState != .none && swap.fillingSwapState != .error {
                Text(swap.fillingSwapState.description)
                    .font(.title2)
            }
            if swap.fillingSwapState == .error {
                Text(swap.fillingSwapError?.localizedDescription ?? "An unknown error occured")
                    .foregroundColor(Color.red)
            }
            actionButtonBuilder(
                action: {
                    if (swap.fillingSwapState == .none || swap.fillingSwapState == .error) {
                        swapTruthSource.fillSwap(swap: swap)
                    }
                },
                labelText: {
                    if swap.fillingSwapState == .none || swap.fillingSwapState == .error {
                        return "Fill Swap"
                    } else if swap.fillingSwapState == .completed {
                        return "Swap Filled"
                    } else {
                        return "Filling Swap"
                    }
                }()
            )
        } else if swap.state == .awaitingPaymentSent && (swap.role == .makerAndBuyer || swap.role == .takerAndBuyer) {
            // If the swap state is awaitingPaymentSent and we are the buyer, then we display the "Confirm Payment is Sent" button
            if swap.reportingPaymentSentState != .none && swap.reportingPaymentSentState != .error {
                Text(swap.reportingPaymentSentState.description)
                    .font(.title2)
            }
            if swap.reportingPaymentSentState == .error {
                Text(swap.reportingPaymentSentError?.localizedDescription ?? "An unknown error occured")
                    .foregroundColor(Color.red)
            }
            actionButtonBuilder(
                action: {
                    if (swap.reportingPaymentSentState == .none || swap.reportingPaymentSentState == .error) {
                        swapTruthSource.reportPaymentSent(swap: swap)
                    }
                },
                labelText: {
                    if swap.reportingPaymentSentState == .none || swap.reportingPaymentSentState == .error {
                        return "Report that Payment Is Sent"
                    } else if swap.reportingPaymentSentState == .completed {
                        return "Reported that Payment Is Sent"
                    } else {
                        return "Reporting that Payment Is Sent"
                    }
                }()
            )
        } else if swap.state == .awaitingPaymentReceived && (swap.role == .makerAndSeller || swap.role == .takerAndSeller) {
            // If the swap state is awaitingPaymentReceived and we are the seller, then we display the "Confirm Payment is Received" button
            if swap.reportingPaymentReceivedState != .none && swap.reportingPaymentReceivedState != .error {
                Text(swap.reportingPaymentReceivedState.description)
                    .font(.title2)
            }
            if swap.reportingPaymentReceivedState == .error {
                Text(swap.reportingPaymentReceivedError?.localizedDescription ?? "An unknown error occured")
                    .foregroundColor(Color.red)
            }
            actionButtonBuilder(
                action: {
                    if (swap.reportingPaymentReceivedState == .none || swap.reportingPaymentReceivedState == .error) {
                        swapTruthSource.reportPaymentReceived(swap: swap)
                    }
                },
                labelText: {
                    if swap.reportingPaymentReceivedState == .none || swap.reportingPaymentReceivedState == .error {
                        return "Report that Payment Is Received"
                    } else if swap.reportingPaymentSentState == .completed {
                        return "Reported that Payment Is Received"
                    } else {
                        return "Reporting that Payment Is Received"
                    }
                }()
            )
        } else if swap.state == .awaitingClosing {
            // We can now close the swap, so we display the "Close Swap" button
            if swap.closingSwapState != .none && swap.closingSwapState != .error {
                Text(swap.closingSwapState.description)
                    .font(.title2)
            }
            if swap.closingSwapState == .error {
                Text(swap.closingSwapError?.localizedDescription ?? "An unknown error occured")
                    .foregroundColor(Color.red)
            }
            actionButtonBuilder(
                action: {
                    if (swap.closingSwapState == .none || swap.closingSwapState == .error) {
                        swapTruthSource.closeSwap(swap: swap)
                    }
                },
                labelText: {
                    if swap.closingSwapState == .none || swap.closingSwapState == .error {
                        return "Close Swap"
                    } else if swap.reportingPaymentSentState == .completed {
                        return "Swap Closed"
                    } else {
                        return "Closing Swap"
                    }
                }()
            )
        }
    }
    
    /**
     Displays a button with the specified `labelText` with a primary-colored rounded rectangle overlay that performs `action` when clicked.
     
     - Parameters:
        - action: The closure to execute when the button is clicked.
        - labelText: The `String` that will be displayed as the label of this button.
     */
    @ViewBuilder
    func actionButtonBuilder(action: @escaping () -> Void, labelText: String) -> some View {
        Button(
            action: action,
            label: {
                Text(labelText)
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
        .accentColor(.primary)
    }
    
}

/**
 Displays a preview of `SwapView` with a sample `Swap`.
 */
struct SwapView_Previews: PreviewProvider {
    static var previews: some View {
        SwapView(
            swap: Swap.sampleSwaps[Swap.sampleSwapIds[0]]!,
            swapTruthSource: PreviewableSwapTruthSource()
        )
    }
}
