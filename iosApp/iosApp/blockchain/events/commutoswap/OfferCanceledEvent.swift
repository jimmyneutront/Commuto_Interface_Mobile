//
//  OfferCanceledEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

class OfferCanceledEvent {
    let id: UUID
    init?(_ result: EventParserResultProtocol) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        if resultId != nil {
            id = resultId!
        } else {
            return nil
        }
    }
}
