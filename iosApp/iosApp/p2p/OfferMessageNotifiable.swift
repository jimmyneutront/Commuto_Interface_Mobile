//
//  OfferMessageNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 A protocol that a structure or class must adopt in order to receive offer-related messages from `P2PService`.
 */
protocol OfferMessageNotifiable {
    /**
     The function called by `P2PService` in order to notify the structure or class adopting this protocol of a new `PublicKeyAnnouncement`.
     
     - Parameter message: the new `PublicKeyAnnouncement` of which the structure or class adopting this protocol is being notified, and should handle in the implementation of this function.
     */
    func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement)
}
