//
//  FoundationExtensions.swift
//  iosApp
//
//  Created by jimmyt on 8/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 Allows the creation of a `UUID` from raw bytes as `Data`. Used to create offer IDs as `UUID`s from the raw bytes retrieved from [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) calls.
 */
extension UUID {
    /**
     Attempts to create a UUID given raw bytes as `Data`.
     
     - Parameter data: The UUID as `Data?`.
     
     - Returns: A `UUID` if one could be successfully created from the given `Data?`, or `nil` otherwise.
     */
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
    
    /**
     Returns the `UUID` as `Data`.
     */
    func asData() -> Data {
        return Data(fromArray: [
            self.uuid.0,
            self.uuid.1,
            self.uuid.2,
            self.uuid.3,
            self.uuid.4,
            self.uuid.5,
            self.uuid.6,
            self.uuid.7,
            self.uuid.8,
            self.uuid.9,
            self.uuid.10,
            self.uuid.11,
            self.uuid.12,
            self.uuid.13,
            self.uuid.14,
            self.uuid.15
        ])
    }
}
