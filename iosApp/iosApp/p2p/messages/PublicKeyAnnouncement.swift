//
//  PublicKeyAnnouncement.swift
//  iosApp
//
//  Created by jimmyt on 6/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

class PublicKeyAnnouncement {
    let offerId: UUID
    let publicKey: PublicKey
    init(offerId: UUID, pubKey: PublicKey) {
        self.offerId = offerId
        publicKey = pubKey
    }
}
