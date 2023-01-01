//
//  TransactionGasDetailsView.swift
//  iosApp
//
//  Created by jimmyt on 12/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import web3swift

/**
 Displays gas information about `transaction` if it is not `nil`, or displays the localized description of `transactionCreationError` if it is not `nil`. When this `View` appears, it executes `onRunAppearance`, passing `transaction` and `transactionCreationError`. `runOnAppearance` should be a closure that creates a transaction and sets the result equal to the wrapped value of `transaction`, or sets the wrapped value of `transactionCreationError` to any error that occurs during the transaction creation process. If `transaction` is not `nil`, the user can press the main button in this view which will call `buttonLabel`, passing `transaction`. This should only be presented inside a sheet.
 */
struct TransactionGasDetailsView: View {
    
    /**
     A binding that controls whether the sheet containing this `View` is presented.
     */
    @Binding var isShowingSheet: Bool
    
    /**
     The title that will be displayed at the top right of this sheet.
     */
    let title: String
    
    /**
     The label that will be displayed on the main button at the bottom of this sheet.
     */
    let buttonLabel: String
    
    /**
     A closure accepting an optional `EthereumTransaction` that will be executed when the main button is pressed.
     */
    let buttonAction: (EthereumTransaction?) -> Void
    
    /**
     A closure accepting an optional `EthereumTransaction` and an optional `Error` wrapped in `Binding`s, which should create a transaction for which details will be displayed.
     */
    let runOnAppearance: (Binding<EthereumTransaction?>, Binding<Error?>) -> Void
    
    /**
     The created `EthereumTransaction` about which this displays details (and which will be passed to `buttonAction`) or `nil` if no such transaction is available.
     */
    @State var transaction: EthereumTransaction? = nil
    
    /**
     The `Error` that occurred in `runOnAppearance`, or `nil` if no such error has occurred.
     */
    @State var transactionCreationError: Error? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                HStack() {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Button(
                        action: {
                            isShowingSheet = false
                        },
                        label: {
                            Text("Close")
                        }
                    )
                    .accentColor(Color.primary)
                }
                if let transaction = transaction {
                    if let gasLimit = transaction.parameters.gasLimit, let maxFeePerGas = transaction.parameters.maxFeePerGas {
                        Text("Estimated Gas:")
                            .font(.title2)
                        Text(String(gasLimit))
                            .font(.title)
                            .bold()
                        Text("Max Fee Per Gas (Wei):")
                            .font(.title2)
                        Text(String(maxFeePerGas))
                            .font(.title)
                            .bold()
                        Text("Estimated Total Cost (Wei):")
                            .font(.title2)
                        Text(String(gasLimit * maxFeePerGas))
                            .font(.title)
                            .bold()
                        if let transactionCreationError = transactionCreationError {
                            Text(transactionCreationError.localizedDescription)
                                .foregroundColor(Color.red)
                        }
                        Button(
                            action: {
                                // Close the sheet in which this view is presented as soon as the user presses this button.
                                buttonAction(transaction)
                                isShowingSheet = false
                            },
                            label: {
                                Text(buttonLabel)
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
                    } else {
                        Text("Unable to estimate gas and gas fee.")
                        if let transactionCreationError = transactionCreationError {
                            Text(transactionCreationError.localizedDescription)
                                .foregroundColor(Color.red)
                        }
                    }
                } else if let transactionCreationError = transactionCreationError {
                    Text(transactionCreationError.localizedDescription).foregroundColor(Color.red)
                } else {
                    Text("Creating transaction...")
                }
            }
            .padding()
            .onAppear {
                runOnAppearance($transaction, $transactionCreationError)
            }
        }
    }
}

/**
 Displays a preview of `TransactionGasDetailsView`
 */
struct TransactionGasDetailsView_Previews: PreviewProvider {
    @State static var isShowingSheet = false
    static var previews: some View {
        TransactionGasDetailsView(isShowingSheet: $isShowingSheet, title: "Cancel Offer", buttonLabel: "Cancel Offer", buttonAction: {_ in }, runOnAppearance: {_,_ in })
    }
}
