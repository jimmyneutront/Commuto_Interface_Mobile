//
//  StablecoinAmountField.swift
//  iosApp
//
//  Created by James Telzrow on 8/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

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
 Displays a preview of `StablecoinAmountField` with an amount of 100 and an unconfigured `NumberFormatter`.
 */
struct StablecoinAmountField_Previews: PreviewProvider {
    
    @State static var stablecoinAmount = 100
    
    static var previews: some View {
        StablecoinAmountField(value: $stablecoinAmount, formatter: NumberFormatter())
    }
}
