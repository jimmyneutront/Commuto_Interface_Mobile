//
//  OfferCardView.swift
//  iosApp
//
//  Created by jimmyt on 5/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

struct OfferCardView: View {
    
    let offer: Offer
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(offer.direction).font(.headline)
                Spacer().frame(height: 5)
                Text(offer.price + " " + offer.pair)
            }
            Spacer()
        }
    }
}

struct OfferCardView_Previews: PreviewProvider {
    static var previews: some View {
        OfferCardView(offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!)
            .previewLayout(.fixed(width: 400, height: 60))
    }
}
