//
//  OfferAmountView.swift
//  iosApp
//
//  Created by jimmyt on 8/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt

/**
 A view that displays the minimum and maximum amount stablecoin that the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)  is willing to exchange.
 */
struct OfferAmountView: View {
    /**
     The `StablecoinInformation` struct for the offer's stablecoin, or `nil` if such a struct cannot be resolved from the offer's chain ID and stablecoin address.
     */
    let stablecoinInformation: StablecoinInformation?
    
    /**
     The offer's `amountLowerBound` divided by ten raised to the power of the stablecoin's decimal count, as a string.
     */
    let minimumString: String
    /**
     The offer's `amountUpperBound` divided by ten raised to the power of the stablecoin's decimal count, as a string.
     */
    let maximumString: String
    /**
     The offer's `securityDepositAmount` divided by ten raised to the  power of the stablecoin's decimal count, as a string.
     */
    let securityDepositString: String
    
    init(stablecoinInformation: StablecoinInformation?, minimum: BigUInt, maximum: BigUInt, securityDeposit: BigUInt) {
        self.stablecoinInformation = stablecoinInformation
        let stablecoinDecimal = stablecoinInformation?.decimal ?? 1
        minimumString = String(minimum / BigUInt(10).power(stablecoinDecimal))
        maximumString = String(maximum / BigUInt(10).power(stablecoinDecimal))
        securityDepositString = String(securityDeposit / BigUInt(10).power(stablecoinDecimal))
    }
    
    var body: some View {
        let currencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        HStack {
            let headerString = (stablecoinInformation != nil) ? "Amount: " : "Amount (in token base units):"
            Text(headerString)
                .font(.title2)
            Spacer()
        }
        .padding(.bottom, 2)
        if minimumString == maximumString {
            HStack {
                Text(minimumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
            }
        } else {
            HStack {
                Text("Minimum: " + minimumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
                
            }
            HStack {
                Text("Maximum: " + maximumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
            }
        }
        HStack {
            Text("Security Deposit: " + securityDepositString + " " + currencyCode)
                .font(.title3)
            Spacer()
        }
    }
}

/**
 Displays a preview of `OfferAmountView`
 */
struct OfferAmountView_Previews: PreviewProvider {
    static var previews: some View {
        OfferAmountView(
            stablecoinInformation: nil,
            minimum: BigUInt(10_000),
            maximum: BigUInt(20_000),
            securityDeposit: BigUInt(2_000)
        )
    }
}
