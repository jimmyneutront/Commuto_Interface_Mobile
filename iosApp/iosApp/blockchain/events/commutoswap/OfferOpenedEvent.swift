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

extension UUID {
    static func from(data: Data?) -> UUID? {
        guard data?.count == MemoryLayout<uuid_t>.size else {
            return nil
        }
        return data?.withUnsafeBytes{
            guard let baseAddress = $0.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }
            return NSUUID(uuidBytes: baseAddress) as UUID
        }
    }
}
