//
//  PublicKeyAnnouncement.swift
//  iosApp
//
//  Created by jimmyt on 6/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

#warning("TODO: Make this a struct")
/**
 This represents a Public Key Announcement, as described in the [Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 */
class PublicKeyAnnouncement {
    /**
     The ID of the offer corresponding to this `PublicKeyAnnouncement`.
     */
    let offerId: UUID
    /**
     The `PublicKey` that this `PublicKeyAnnouncement` is announcing.
     */
    let publicKey: PublicKey
    /**
     Creates a new `PublicKeyAnnouncement`.
     
     - Parameters:
        - offerId: The offer ID of the public key announcement
        - pubKey: The `PublicKey` being announced 
     */
    init(offerId: UUID, pubKey: PublicKey) {
        self.offerId = offerId
        publicKey = pubKey
    }
}
