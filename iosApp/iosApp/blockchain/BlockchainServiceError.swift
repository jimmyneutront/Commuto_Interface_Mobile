//
//  BlockchainServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

enum BlockchainServiceError: Error {
    case unexpectedNilError(desc: String)
    public var errorDescription: String {
        switch self {
        case .unexpectedNilError(let desc):
            return desc
        }
    }
}
