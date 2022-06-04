//
//  OffersView.swift
//  iosApp
//
//  Created by jimmyt on 5/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

struct OffersView: View {
    
    @ObservedObject var offersViewModel: OffersViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(offersViewModel.offers.map { $0.1 }, id: \.id) { offer in
                    NavigationLink(destination: Text("id: " + offer.id.uuidString)) {
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
        OffersView(offersViewModel: OffersViewModel(offerService: OfferService()))
    }
}
