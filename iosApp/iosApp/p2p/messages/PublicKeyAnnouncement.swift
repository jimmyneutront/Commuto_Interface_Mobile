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
 This represents a [Public Key Announcement](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt#L50).
 
 - Properties:
    - offerId: The ID of the offer corresponding to this `PublicKeyAnnouncement`.
    - pubKey: The `PublicKey` that this `PublicKeyAnnouncement` is announcing
 */
class PublicKeyAnnouncement {
    let offerId: UUID
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
