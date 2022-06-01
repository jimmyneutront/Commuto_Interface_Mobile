//
//  OffersViewModel.swift
//  iosApp
//
//  Created by jimmyt on 5/31/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

class OffersViewModel: ObservableObject {
    @Published var offersDict = Offer.sampleOffers
}
