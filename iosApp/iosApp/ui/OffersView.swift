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
            .navigationTitle(Text("Offers", comment: "Appears as a title above the list of open offers"))
            .toolbar {
                HStack {
                    Button(action: {}) {
                        Text("Create", comment: "The label of the button to create a new offer")
                    }
                    Button(action: {}) {
                        Text("Filter", comment: "The label of the button to filter the offers shown in the open offers list")
                    }
                }
            }
        }
    }
}

struct OffersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OffersView(offersViewModel: OffersViewModel(offerService: OfferService()))
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}
