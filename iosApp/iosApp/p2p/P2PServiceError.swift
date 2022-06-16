//
//  P2PServiceError.swift
//  iosApp
//
//  Created by jimmyt on 6/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

enum P2PServiceError: Error {
    case matrixCallFailureWithNil(desc: String)
    // TODO: remove this, it's no longer used
    //case noResponseValue(desc: String)
    public var errorDescription: String {
        switch self {
        case .matrixCallFailureWithNil(let desc):
            return desc
        }
    }
}
