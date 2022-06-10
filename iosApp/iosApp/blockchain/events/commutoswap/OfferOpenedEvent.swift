//
//  File.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

class OfferOpenedEvent {
    let id: UUID
    let interfaceId: Data
    init(_ result: EventParserResultProtocol) {
        id = UUID.from(data: result.decodedResult["offerID"]! as? Data)!
        interfaceId = result.decodedResult["interfaceId"]! as! Data
    }
}
