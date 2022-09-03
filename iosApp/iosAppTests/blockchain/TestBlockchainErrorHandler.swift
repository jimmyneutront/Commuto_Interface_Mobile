//
//  TestBlockchainErrorHandler.swift
//  iosAppTests
//
//  Created by jimmyt on 9/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

@testable import iosApp

/**
 A basic `BlockchainErrorNotifiable` implementation for testing.
 */
class TestBlockchainErrorHandler: BlockchainErrorNotifiable {
    var gotError = false
    func handleBlockchainError(_ error: Error) {
        gotError = true
    }
}
