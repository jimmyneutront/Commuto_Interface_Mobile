//
//  ServiceFeeAmountView.swift
//  iosApp
//
//  Created by jimmyt on 8/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt

/**
 A view that displays the minimum and maximum service fee for an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct ServiceFeeAmountView: View {
    
    /**
     The `StablecoinInformation` struct for the offer's stablecoin, or `nil` if no such information is available.
     */
    let stablecoinInformation: StablecoinInformation?
    
    /**
     The offer's minimum service fee.
     */
    var minimumString: String
    
    /**
     The offer's maximum service fee.
     */
    var maximumString: String
    
    /**
     Creates a `ServiceFeeAmountView` for an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - stablecoinInformation: The `StablecoinInformation` of the offer for which this `View` is being displayed, or `nil` if this information is not available.
        - minimumAmount: The offer's minimum amount, as a `Decimal` in token units.
        - maximumAmount: The offer's maximum amount, as a `Decimal` in token units.
        - serviceFeeRate: The service fee rate for the offer, as a `BigUInt`.
     */
    init(stablecoinInformation: StablecoinInformation?, minimumAmount: Decimal, maximumAmount: Decimal, serviceFeeRate: BigUInt) {
        self.stablecoinInformation = stablecoinInformation
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .currency
        
        let minimumFeeDecimal = NSNumber(floatLiteral: Double(serviceFeeRate)).decimalValue * minimumAmount / NSNumber(floatLiteral: 10000.0).decimalValue
        let maximumFeeDecimal = NSNumber(floatLiteral: Double(serviceFeeRate)).decimalValue * maximumAmount / NSNumber(floatLiteral: 10000.0).decimalValue
        
        minimumString = formatter.string(for: minimumFeeDecimal) ?? "?"
        maximumString = formatter.string(for: maximumFeeDecimal) ?? "?"
        
    }
    
    /**
     Creates a `ServiceFeeAmountView` to use when taking an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer). When taking an offer, the user must specify the amount of stablecoin to be swapped (or, if the minimum swap amount equals the maximum swap amount, there is only one possible swap amount), and thus we only want to display a single service fee to the user.
     
     - Parameters:
        - stablecoinInformation: The `StablecoinInformation` of the offer for which this `View` is being displayed, or `nil` if this information is not available.
        - amount: The amount from which the service fee will be calculated, as a `Decimal` in token units.
        - serviceFeeRate: The service fee rate for the offer, as a `BigUInt`.
     */
    init(stablecoinInformation: StablecoinInformation?, amount: Decimal, serviceFeeRate: BigUInt) {
        self.init(
            stablecoinInformation: stablecoinInformation,
            minimumAmount: amount,
            maximumAmount: amount,
            serviceFeeRate: serviceFeeRate
        )
    }
    
    /**
     Creates a `ServiceFeeAmountView` for an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     - Parameters:
        - stablecoinInformation: The `StablecoinInformation` of the offer for which this `View` is being displayed, or `nil` if this information is not available.
        - minimumString: The `String` value to be displayed as the minimum amount.
        - maximumString: The `String` value to be displayed  as the maximum amount.
     */
    init(stablecoinInformation: StablecoinInformation?, minimumString: String, maximumString: String) {
        self.stablecoinInformation = stablecoinInformation
        self.minimumString = minimumString
        self.maximumString = maximumString
    }
    
    var body: some View {
        let currencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        HStack {
            let headerString = (stablecoinInformation != nil) ? "Service Fee: " : "Service Fee (in token base units):"
            Text(headerString)
                .font(.title2)
            Spacer()
        }
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
    }
    
}

struct ServiceFeeAmountView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceFeeAmountView(stablecoinInformation: nil, minimumAmount: NSNumber(floatLiteral: 100.0).decimalValue, maximumAmount: NSNumber(floatLiteral: 200.0).decimalValue, serviceFeeRate: BigUInt(100))
    }
}
