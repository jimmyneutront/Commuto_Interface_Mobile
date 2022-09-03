//
//  TestP2PErrorHandler.swift
//  iosAppTests
//
//  Created by jimmyt on 9/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

@testable import iosApp

/**
 A basic `P2PErrorNotifiable` implementation for testing.
 */
class TestP2PErrorHandler : P2PErrorNotifiable {
    func handleP2PError(_ error: Error) {}
}
