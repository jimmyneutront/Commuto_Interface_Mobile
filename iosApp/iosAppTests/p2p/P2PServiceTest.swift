//
//  P2PServiceTest.swift
//  iosAppTests
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import XCTest

@testable import iosApp
@testable import PromiseKit
@testable import MatrixSDK
@testable import Switrix

/**
 Tests for `P2PService`.
 */
class P2PServiceTest: XCTestCase {
    
    /**
     Matrix credentials for tests that have not yet been migrated to Switrix
     */
    var creds: MXCredentials?
    /**
     Matrix client for tests that have not yet been migrated to Switrix
     */
    var mxClient: MXRestClient?
    
    /**
     Creates credentials and a Matrix client for tests that have not yet been migrated to Switrix
     */
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let creds = MXCredentials(homeServer: "https://matrix.org", userId: "@jimmyt:matrix.org", accessToken: ProcessInfo.processInfo.environment["MXKY"])
        self.creds = creds
        self.mxClient = MXRestClient(credentials: creds)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /**
     Runs the listen loop in the current thread. This doesn't actually test anything, but we have to prefix the name with "test" otherwise Xcode won't run it.
     */
    func test_runListenLoop() {
        let unfulfillableExpectation = XCTestExpectation(description: "Test the listen loop")
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        p2pService.listenLoop()
        wait(for: [unfulfillableExpectation], timeout: 10.0)
    }
    
    /**
     Runs `P2PService`'s `listen()` function. This doesn't actually test anything, but we have to prefix the name with "test" otherwise Xcode won't run it.
     */
    func test_runListen() {
        let unfulfillableExpectation = XCTestExpectation(description: "Test the listen loop")
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        p2pService.listen()
        wait(for: [unfulfillableExpectation], timeout: 60.0)
    }
    
    /**
     Tests `P2PService`'s `listen()` function by ensuring it detects and handles public key announcements properly.
     */
    func testListen() {
        #warning("TODO: migrate to SwitrixSDK in this test")
        let databaseService = try! DatabaseService()
        let keyManagerService: KeyManagerService = KeyManagerService(databaseService: databaseService)
        let keyPair = try! keyManagerService.generateKeyPair(storeResult: false)
        var error: Unmanaged<CFError>?
        let pubKeyBytes = try! keyPair.getPublicKey().toPkcs1Bytes()
        
        let offerId = UUID()
        let offerIdBytes = offerId.uuid
        let offerIdData = Data(fromArray: [offerIdBytes.0, offerIdBytes.1, offerIdBytes.2, offerIdBytes.3, offerIdBytes.4, offerIdBytes.5, offerIdBytes.6, offerIdBytes.7, offerIdBytes.8, offerIdBytes.9, offerIdBytes.10, offerIdBytes.11, offerIdBytes.12, offerIdBytes.13, offerIdBytes.14, offerIdBytes.15])
        
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        class TestOfferService : OfferMessageNotifiable {
            init(expectedPKA: PublicKeyAnnouncement) {
                self.expectedPKA = expectedPKA
            }
            let expectedPKA: PublicKeyAnnouncement
            let pkaExpectation = XCTestExpectation(description: "We should find our specific public key announcment while parsing peer-to-peer messages")
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {
                if message.offerId == expectedPKA.offerId && message.publicKey.interfaceId == expectedPKA.publicKey.interfaceId {
                    pkaExpectation.fulfill()
                }
            }
        }
        
        let expectedPKA = PublicKeyAnnouncement(offerId: offerId, pubKey: try! keyPair.getPublicKey())
        let offerService = TestOfferService(expectedPKA: expectedPKA)
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: offerService,
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        p2pService.listen()
        
        let publicKeyAnnouncementPayload: [String:Any] = [
            "pubKey": (pubKeyBytes as NSData).base64EncodedString(),
            "offerId": offerIdData.base64EncodedString()
        ]
        let payloadData = try! JSONSerialization.data(withJSONObject: publicKeyAnnouncementPayload)
        let encodedPayloadString = payloadData.base64EncodedString()
        
        var publicKeyAnnouncementMsg: [String:Any] = [
            "sender": keyPair.interfaceId.base64EncodedString(),
            "msgType": "pka",
            "payload": encodedPayloadString,
            "signature": ""
        ]
        let payloadDataDigest = SHA256.hash(data: payloadData)
        var payloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in payloadDataDigest.makeIterator() {
            payloadDataHashByteArray.append(byte)
        }
        let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
        publicKeyAnnouncementMsg["signature"] = try! keyPair.sign(data: payloadDataHash).base64EncodedString()
        let publicKeyAnnouncementString = String(decoding: try! JSONSerialization.data(withJSONObject: publicKeyAnnouncementMsg), as: UTF8.self)
        
        let sendMsgExpectation = XCTestExpectation(description: "Send public key announcement to Commuto Interface Network Test Room")
        mxClient!.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: publicKeyAnnouncementString) { (response) in
            if case .success(_) = response {
                sendMsgExpectation.fulfill()
            }
        }
        wait(for: [sendMsgExpectation], timeout: 60.0)
        wait(for: [offerService.pkaExpectation], timeout: 120.0)
    }
    
    /**
     Tests `P2PService`'s error handling logic by ensuring that it handles unknown token errors properly.
     */
    func testListenErrorHandling() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        class TestP2PErrorHandler: P2PErrorNotifiable {
            init(_ eE: XCTestExpectation) {
                errorExpectation = eE
            }
            var errorPromise: Promise<Error>? = nil
            let errorExpectation: XCTestExpectation
            func handleP2PError(_ error: Error) {
                errorPromise = Promise { seal in
                    seal.fulfill(error)
                }
                errorExpectation.fulfill()
            }
        }
        let errorExpectation = XCTestExpectation(description: "We expect to get an error here")
        let errorHandler = TestP2PErrorHandler(errorExpectation)
        
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        let p2pService = P2PService(
            errorHandler: errorHandler,
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        p2pService.listen()
        wait(for: [errorExpectation], timeout: 60.0)
        XCTAssertTrue((try! errorHandler.errorPromise!.wait() as! SwitrixError).errorCode == "M_UNKNOWN_TOKEN")
    }
    
    /**
     Ensure that `P2PService.announcePublicKey` makes Public Key Announcements properly.
     */
    func testAnnouncePublicKey() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        class TestP2PService: P2PService {
            var receivedMessage: String?
            override func sendMessage(_ message: String) {
                receivedMessage = message
            }
        }
        let p2pService = TestP2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        
        let keyPair = try! KeyPair()
        let offerID = UUID()
        
        try! p2pService.announcePublicKey(offerID: offerID, keyPair: keyPair)
        
        let createdPublicKeyAnnouncement = parsePublicKeyAnnouncement(messageString: p2pService.receivedMessage)
        XCTAssertEqual(keyPair.interfaceId, createdPublicKeyAnnouncement!.publicKey.interfaceId)
        XCTAssertEqual(offerID, createdPublicKeyAnnouncement!.offerId)
    }
    
    /**
     Ensure that `P2PService.sendTakerInformation` sends [Taker Information Message](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt)s properly.
     */
    func testSendTakerInformation() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        #warning("TODO: move this to its own class")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        class TestP2PService: P2PService {
            var receivedMessage: String?
            override func sendMessage(_ message: String) {
                receivedMessage = message
            }
        }
        let p2pService = TestP2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        
        // The key pair, the public key of which we use as the maker's public key
        let makerKeyPair = try! KeyPair()
        // The taker's/user's key pair
        let takerKeyPair = try! KeyPair()
        
        let swapID = UUID()
        
        // Send the information
        try! p2pService.sendTakerInformation(makerPublicKey: makerKeyPair.getPublicKey(), takerKeyPair: takerKeyPair, swapID: swapID, paymentDetails: "some_payment_details")
        let message = try! JSONSerialization.jsonObject(with: p2pService.receivedMessage!.data(using: String.Encoding.utf8)!) as! NSDictionary
        let createdTakerInformationMessage = try! parseTakerInformationMessage(message: message, keyPair: makerKeyPair)
        XCTAssertEqual(swapID, createdTakerInformationMessage!.swapID)
        XCTAssertEqual(takerKeyPair.interfaceId, createdTakerInformationMessage!.publicKey.interfaceId)
        XCTAssertEqual("some_payment_details", createdTakerInformationMessage!.settlementMethodDetails)
    }
    
    /**
     Ensure that `P2PService.parseEvents` handles `TakerInformationMessage`s properly.
     */
    func testParseTakerInformationMessage() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // Since we are the maker, we want the maker's key pair in persistent storage.
        let makerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        // Since we are the maker, we do NOT want the taker's key pair in persistent storage.
        let takerKeyPair = try! KeyPair()
        
        let swapID = UUID()
        
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        
        class TestSwapService: SwapMessageNotifiable {
            var message: TakerInformationMessage? = nil
            func handleTakerInformationMessage(_ message: TakerInformationMessage) {
                self.message = message
            }
            func handleMakerInformationMessage(_ message: MakerInformationMessage, senderInterfaceID: Data, recipientInterfaceID: Data) throws {}
        }
        let swapService = TestSwapService()
        
        let takerInformationMessageString = try! createTakerInformationMessage(makerPublicKey: makerKeyPair.getPublicKey(), takerKeyPair: takerKeyPair, swapID: swapID, settlementMethodDetails: "settlement_method_details")
        
        let takerInformationMessageEventContent = SwitrixMessageEventContent(body: takerInformationMessageString)
        
        let takerInformationMessageEvent = SwitrixClientEvent(content: takerInformationMessageEventContent, eventId: "", originServerTimestamp: 0, roomId: "", sender: "", type: "m.room.message")
        
        let p2pService = P2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: swapService,
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        try! p2pService.parseEvents([takerInformationMessageEvent])
        
        XCTAssertEqual(swapID, swapService.message!.swapID)
        XCTAssertEqual(takerKeyPair.interfaceId, swapService.message!.publicKey.interfaceId)
        XCTAssertEqual("settlement_method_details", swapService.message!.settlementMethodDetails)
        
    }
    
    /**
     Ensure that `P2PService.sendMakerInformation` sends [Maker Information Message](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt)s properly.
     */
    func testSendMakerInformation() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        #warning("TODO: move this to its own class")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        class TestP2PService: P2PService {
            var receivedMessage: String?
            override func sendMessage(_ message: String) {
                receivedMessage = message
            }
        }
        let p2pService = TestP2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: TestSwapMessageNotifiable(),
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        
        // The key pair, the public key of which we use as the taker's key pair
        let takerKeyPair = try! KeyPair()
        // The maker's/user's key pair
        let makerKeyPair = try! KeyPair()
        
        let swapID = UUID()
        
        // Send the information
        try! p2pService.sendMakerInformation(takerPublicKey: takerKeyPair.getPublicKey(), makerKeyPair: makerKeyPair, swapID: swapID, settlementMethodDetails: "some_payment_details")
        let message = try! JSONSerialization.jsonObject(with: p2pService.receivedMessage!.data(using: String.Encoding.utf8)!) as! NSDictionary
        // Parse sent information
        let createdMakerInformationMessage = try! parseMakerInformationMessage(message: message, keyPair: takerKeyPair, publicKey: makerKeyPair.getPublicKey())
        // Validate sent information
        XCTAssertEqual(swapID, createdMakerInformationMessage!.swapID)
        XCTAssertEqual("some_payment_details", createdMakerInformationMessage!.settlementMethodDetails)
        
    }
    
    /**
     Ensure that `P2PService.parseEvents` handles `MakerInformationMessage`s properly.
     */
    func testParseMakerInformationMessage() {
        let databaseService = try! DatabaseService()
        try! databaseService.createTables()
        let keyManagerService = KeyManagerService(databaseService: databaseService)
        
        // Since we are the taker, we want the taker's key pair in persistent storage
        let takerKeyPair = try! keyManagerService.generateKeyPair(storeResult: true)
        // Since we are the taker, we do NOT want the maker's key pair in persistent storage
        let makerKeyPair = try! KeyPair()
        try! keyManagerService.storePublicKey(pubKey: makerKeyPair.getPublicKey())
        
        let swapID = UUID()
        
        #warning("TODO: move this to its own class")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        
        class TestSwapService: SwapMessageNotifiable {
            var message: MakerInformationMessage? = nil
            var senderInterfaceID: Data? = nil
            var recipientInterfaceID: Data? = nil
            func handleTakerInformationMessage(_ message: TakerInformationMessage) {}
            func handleMakerInformationMessage(_ message: MakerInformationMessage, senderInterfaceID: Data, recipientInterfaceID: Data) throws {
                self.message = message
                self.senderInterfaceID = senderInterfaceID
                self.recipientInterfaceID = recipientInterfaceID
            }
        }
        let swapService = TestSwapService()
        
        let makerInformationMessageString = try! createMakerInformationMessage(takerPublicKey: takerKeyPair.getPublicKey(), makerKeyPair: makerKeyPair, swapID: swapID, settlementMethodDetails: "maker_settlement_method_details")
        
        let makerInformationMessageEventContent = SwitrixMessageEventContent(body: makerInformationMessageString)
        
        let makerInformationMessageEvent = SwitrixClientEvent(content: makerInformationMessageEventContent, eventId: "", originServerTimestamp: 0, roomId: "", sender: "", type: "m.room.message")
        
        let p2pService = P2PService(
            errorHandler: TestP2PErrorHandler(),
            offerService: TestOfferMessageNotifiable(),
            swapService: swapService,
            switrixClient: switrixClient,
            keyManagerService: keyManagerService
        )
        try! p2pService.parseEvents([makerInformationMessageEvent])
        
        XCTAssertEqual(swapID, swapService.message!.swapID)
        XCTAssertEqual("maker_settlement_method_details", swapService.message!.settlementMethodDetails)
        XCTAssertEqual(makerKeyPair.interfaceId, swapService.senderInterfaceID!)
        XCTAssertEqual(takerKeyPair.interfaceId, swapService.recipientInterfaceID)
        
    }
    
}
