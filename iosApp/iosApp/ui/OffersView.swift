//
//  OffersView.swift
//  iosApp
//
//  Created by jimmyt on 5/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

struct OffersView: View {
    let offers: [Offer]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(offers, id: \.id) { offer in
                    NavigationLink(destination: Text(offer.pair)) {
                        OfferCardView(offer: offer)
                    }
                }
            }
            .navigationTitle("Offers")
            .toolbar {
                HStack {
                    Button(action: {}) {
                        Text("Create")
                    }
                    Button(action: {}) {
                        Text("Filter")
                    }
                }
            }
        }
    }
}

struct OffersView_Previews: PreviewProvider {
    static var previews: some View {
        OffersView(offers: Offer.sampleOffers)
    }
}
