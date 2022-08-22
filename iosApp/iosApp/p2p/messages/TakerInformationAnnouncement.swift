//
//  TakerInformationAnnouncement.swift
//  iosApp
//
//  Created by James Telzrow on 8/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 This represents a [Taker Information Announcement], as described in the [Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 */
struct TakerInformationAnnouncement {
    /**
     The ID of the swap for which taker information is being announced.
     */
    let swapID: UUID
    /**
     The taker's public key.
     */
    let publicKey: PublicKey
    /**
     The taker's settlement method details.
     */
    let settlementMethodDetails: String
}
