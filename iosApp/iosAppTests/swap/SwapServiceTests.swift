//
//  SwapServiceTests.swift
//  iosAppTests
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Switrix
import XCTest

@testable import iosApp

class SwapServiceTests: XCTestCase {
    /**
     Ensures that `SwapService` announces taker information correctly..
     */
    func testAnnounceTakerInformation() {
        
        // Set up DatabaseService and KeyManagerService
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // Set up SwapService
        let swapService = SwapService(
            databaseService: databaseService,
            keyManagerService: keyManagerService
        )
        
        // The ID of the swap for which taker information will be announced
        let swapID = UUID()
        
        // The public key of this key pair will be the maker's public key (NOT the user's/taker's), so we do NOT want to store the whole key pair persistently
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        // We store the maker's public key, as if we received it via the P2P network
        try! keyManagerService.storePublicKey(pubKey: try! makerKeyPair.getPublicKey())
        // This is the taker's (user's) key pair, so we do want to store it persistently
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        
        // We must persistently store a swap with an ID equal to swapID and the maker and taker interface IDs from the keys created above, otherwise SwapService won't be able to get the keys necessary to make the taker info announcement
        let swapForDatabase = DatabaseSwap(
            id: swapID.asData().base64EncodedString(),
            isCreated: true,
            requiresFill: false,
            maker: "",
            makerInterfaceID: makerKeyPair.interfaceId.base64EncodedString(),
            taker: "",
            takerInterfaceID: takerKeyPair.interfaceId.base64EncodedString(),
            stablecoin: "",
            amountLowerBound: "",
            amountUpperBound: "",
            securityDepositAmount: "",
            takenSwapAmount: "",
            serviceFeeAmount: "",
            serviceFeeRate: "",
            onChainDirection: "",
            onChainSettlementMethod: "",
            protocolVersion: "",
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: "",
            chainID: "31337",
            state: ""
        )
        try! databaseService.storeSwap(swap: swapForDatabase)
        
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        
        class TestP2PService: P2PService {
            var makerPublicKey: PublicKey? = nil
            var takerKeyPair: KeyPair? = nil
            var swapID: UUID? = nil
            var paymentDetails: String? = nil
            override func announceTakerInformation(makerPublicKey: PublicKey, takerKeyPair: KeyPair, swapID: UUID, paymentDetails: String) throws {
                self.makerPublicKey = makerPublicKey
                self.takerKeyPair = takerKeyPair
                self.swapID = swapID
                self.paymentDetails = paymentDetails
            }
        }
        let p2pService = TestP2PService(errorHandler: TestP2PErrorHandler(), offerService: TestOfferService(), switrixClient: switrixClient)
        swapService.p2pService = p2pService
        swapService.swapTruthSource = TestSwapTruthSource()
        
        try! swapService.announceTakerInformation(swapID: swapID, chainID: BigUInt(31337))
        
        XCTAssertEqual(p2pService.makerPublicKey!.interfaceId, makerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.takerKeyPair!.interfaceId, takerKeyPair.interfaceId)
        XCTAssertEqual(p2pService.swapID, swapID)
        #warning("TODO: update this once SettlementMethodService is added")
        XCTAssertEqual(p2pService.paymentDetails, "TEMPORARY")
        
        let swapInDatabase = try! databaseService.getSwap(id: swapID.asData().base64EncodedString())
        XCTAssertEqual(swapInDatabase!.state, "awaitingMakerInfo")
        
    }
}
