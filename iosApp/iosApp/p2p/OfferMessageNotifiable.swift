//
//  OfferMessageNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

protocol OfferMessageNotifiable {
    func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement)
}
