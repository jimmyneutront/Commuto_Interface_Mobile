//
//  OfferCardView.swift
//  iosApp
//
//  Created by jimmyt on 5/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 A card displaying basic information about an offer, to be shown in the main list of open offers.
 */
struct OfferCardView: View {
    
    /**
     The direction of the offer that this card represents, as a `String`.
     */
    let offerDirection: String
    
    /**
     The currency code of the offer's stablecoin.
     */
    let stablecoinCode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(offerDirection).font(.headline)
                Spacer().frame(height: 5)
                Text(stablecoinCode)
            }
            Spacer()
        }
    }
}

/**
 Displays a preview of `OfferCardView` with a sample `Offer`.
 */
struct OfferCardView_Previews: PreviewProvider {
    static var previews: some View {
        OfferCardView(offerDirection: "Buy", stablecoinCode: "DAI")
            .previewLayout(.fixed(width: 400, height: 60))
    }
}
