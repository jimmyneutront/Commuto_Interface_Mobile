//
//  OfferTakenEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

//TODO: so similar to OfferOpenedEvent so use some abstraction
class OfferTakenEvent {
    let id: UUID
    let interfaceId: Data
    init(_ result: EventParserResultProtocol) {
        id = UUID.from(data: result.decodedResult["offerID"]! as? Data)!
        interfaceId = result.decodedResult["takerInterfaceId"]! as! Data
    }
}
