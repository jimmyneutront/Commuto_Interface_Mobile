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

class P2PServiceTest: XCTestCase {
    
    var creds: MXCredentials?
    var mxClient: MXRestClient?
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let creds = MXCredentials(homeServer: "https://matrix.org", userId: "@jimmyt:matrix.org", accessToken: "")
        self.creds = creds
        self.mxClient = MXRestClient(credentials: creds)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testP2PServiceExpectation() {
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(errorHandler: TestP2PErrorHandler(), offerService: TestOfferService(), mxClient: self.mxClient!, switrixClient: switrixClient)
        let syncExpectation = XCTestExpectation(description: "Sync with Matrix homeserver")
        p2pService.mxClient.sync(fromToken: nil, serverTimeout: 60000, clientTimeout: 60000, setPresence: nil) { response in
            print(response)
            syncExpectation.fulfill()
        }
        wait(for: [syncExpectation], timeout: 60.0)
    }
    
    func testRoomInitialSync() {
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(errorHandler: TestP2PErrorHandler(), offerService: TestOfferService(), mxClient: self.mxClient!, switrixClient: switrixClient)
        let roomSyncExpectation = XCTestExpectation(description: "Sync with Matrix homeserver")
        p2pService.mxClient.intialSync(ofRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", limit: 5) { response in
            print(response)
        }
        wait(for: [roomSyncExpectation], timeout: 60.0)
    }
    
    /*
     This doesn't actually test anything, but we have to prefix the name with "test" otherwise Xcode won't run it
     */
    func test_runListenLoop() {
        let unfulfillableExpectation = XCTestExpectation(description: "Test the listen loop")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(errorHandler: TestP2PErrorHandler(), offerService: TestOfferService(), mxClient: self.mxClient!, switrixClient: switrixClient)
        p2pService.listenLoop()
        wait(for: [unfulfillableExpectation], timeout: 10.0)
    }
    
    func test_runListen() {
        let unfulfillableExpectation = XCTestExpectation(description: "Test the listen loop")
        class TestP2PErrorHandler : P2PErrorNotifiable {
            func handleP2PError(_ error: Error) {}
        }
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(errorHandler: TestP2PErrorHandler(), offerService: TestOfferService(), mxClient: self.mxClient!, switrixClient: switrixClient)
        p2pService.listen()
        wait(for: [unfulfillableExpectation], timeout: 60.0)
    }
    
    func testListen() {
        
        let dbService: DBService = DBService()
        let kmService: KMService = KMService(dbService: dbService)
        let keyPair = try! kmService.generateKeyPair(storeResult: false)
        var error: Unmanaged<CFError>?
        let pubKeyBytes = SecKeyCopyExternalRepresentation(keyPair.publicKey, &error)!
        
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
        
        let expectedPKA = PublicKeyAnnouncement(offerId: offerId, pubKey: try! PublicKey(publicKey: keyPair.publicKey))
        let offerService = TestOfferService(expectedPKA: expectedPKA)
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!)
        let p2pService = P2PService(errorHandler: TestP2PErrorHandler(), offerService: offerService, mxClient: self.mxClient!, switrixClient: switrixClient)
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
        p2pService.mxClient.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: publicKeyAnnouncementString) { (response) in
            if case .success(_) = response {
                sendMsgExpectation.fulfill()
            }
        }
        wait(for: [sendMsgExpectation], timeout: 60.0)
        wait(for: [offerService.pkaExpectation], timeout: 120.0)
    }
    
    func testListenErrorHandling() {
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
        class TestOfferService : OfferMessageNotifiable {
            func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) {}
        }

        // For some reason, uncommenting the following line causes a EXC_BAD_ACCESS error
        // self.creds!.accessToken = "not-a-real-token"
        let switrixClient = SwitrixClient(homeserver: "https://matrix.org", token: "not_a_real_token")
        let p2pService = P2PService(errorHandler: errorHandler, offerService: TestOfferService(), mxClient: self.mxClient!, switrixClient: switrixClient)
        p2pService.listen()
        wait(for: [errorExpectation], timeout: 60.0)
        XCTAssertTrue((try! errorHandler.errorPromise!.wait() as! SwitrixError).errorCode == "M_UNKNOWN_TOKEN")
    }
}
