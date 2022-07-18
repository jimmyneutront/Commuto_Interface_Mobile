//
//  EthereumAddressExtensions.swift
//  iosApp
//
//  Created by jimmyt on 7/17/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import web3swift

/**
 An extension of web3swift's `EthereumAddress` to adopt the `Identifiable` protocol.
 */
extension EthereumAddress: Identifiable {
    public var id: String {
        self.address
    }
}
