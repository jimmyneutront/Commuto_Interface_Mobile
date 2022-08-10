//
//  SwapCardView.swift
//  iosApp
//
//  Created by James Telzrow on 8/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 A card displaying basic information about a swap, to be shown in the main list of swaps.
 */
struct SwapCardView: View {
    
    /**
     The direction of the swap that this card represents, as a `String`.
     */
    let swapDirection: String
    
    /**
     The currency code of the swap's stablecoin.
     */
    let stablecoinCode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(swapDirection).font(.headline)
                Spacer().frame(height: 5)
                Text(stablecoinCode)
            }
            Spacer()
        }
    }
}

struct SwapCardView_Previews: PreviewProvider {
    static var previews: some View {
        SwapCardView(swapDirection: "Buy", stablecoinCode: "DAI")
    }
}
