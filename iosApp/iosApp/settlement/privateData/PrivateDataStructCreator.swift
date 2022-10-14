//
//  PrivateDataStructCreator.swift
//  iosApp
//
//  Created by jimmyt on 10/13/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 Attempts to create some `PrivateData` struct by deserializing `privateData` as JSON, returning the result, or `nil` if `privateData` cannot be deserialized into a struct adopting `PrivateData`.
 
 - Parameter privateData: The `Data` from which this attempts to create a struct adopting `PrivateData`.
 
 - Returns A struct adopting `PrivateData` derived by deserializing `privateData`, or `nil` if deserialization fails.
 */
func createPrivateDataStruct(privateData: Data) -> PrivateData? {
    if let privateData = try? JSONDecoder().decode(PrivateSEPAData.self, from: privateData) {
        return privateData
    } else if let privateData = try? JSONDecoder().decode(PrivateSWIFTData.self, from: privateData) {
        return privateData
    } else {
        return nil
    }
}
