//
//  OfferView.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

struct OfferView: View {
    
    var offer: Offer? = Offer.sampleOffers[Offer.sampleOfferIds[0]]
    
    var body: some View {
        Text("Hello, World!")
    }
}

struct OfferView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OfferView()
                
        }
    }
}
