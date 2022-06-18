//
//  PublicKeyAnnouncement.swift
//  iosApp
//
//  Created by jimmyt on 6/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
/**
 This represents a Public Key Announcement, as specified in the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/d26697ab78a5b00bd9578bbea1f40796cda6f0b3/commuto-interface-specification.txt#L50).
 
 - Properties:
    - offerId: The ID of the offer corresponding to this `PublicKeyAnnouncement`.
    - pubKey: The `PublicKey` that this `PublicKeyAnnouncement` is announcing
 */
#warning("Make this a struct")
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
