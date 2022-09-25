//
//  MakerInformationMessage.swift
//  iosApp
//
//  Created by jimmyt on 8/25/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 This represents a Maker Information Message, as described in the [Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 */
struct MakerInformationMessage {
    /**
     The ID of the swap for which maker information is being sent.
     */
    let swapID: UUID
    /**
     The maker's settlement method details, or `nil` if no such data exists.
     */
    let settlementMethodDetails: String?
}
