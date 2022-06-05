//
//  P2PService.swift
//  iosApp
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation
import MatrixSDK
import PromiseKit

class P2PService {
    
    init() {
        let creds = MXCredentials(homeServer: "", userId: "", accessToken: "")
        self.creds = creds
        self.mxClient =  MXRestClient(credentials: creds, unrecognizedCertificateHandler: nil)
    }
    
    // Matrix credentials
    private let creds: MXCredentials
    
    // Matrix REST client
    let mxClient: MXRestClient
    
    // The token at the end of the last batch of non-empty messages
    private var lastNonEmptyBatchToken = ""
    
    private func updateLastNonEmptyBatchToken(_ newToken: String) {
        lastNonEmptyBatchToken = newToken
    }
    
    // The thread in which P2PService listens to the peer-to-peer network
    private var listenThread: Thread?
    
    // The timer responsible for repeatedly beginning the listening process
    private var timer: Timer?
    
    // Indicates whether P2PService is currently handling new data as part of the listening process
    private var isDoingListening = false
    
    func listen() {
        listenThread = Thread { [self] in
            listenLoop()
        }
        listenThread!.start()
    }
    
    func stopListening() {
        timer?.invalidate()
        listenThread?.cancel()
    }
    
    func listenLoop() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if (!isDoingListening) {
                isDoingListening = true
                firstly {
                    self.roomSyncPromise()
                }.then { [self] response -> Promise<MXResponse<MXPaginationResponse>> in
                    updateLastNonEmptyBatchToken(response.value!.messages.end)
                    return getMessagesPromise(from: self.lastNonEmptyBatchToken, limit: 1_000_000)
                }.done { [self] response in
                    parseEvents(response.value!.chunk)
                    isDoingListening = false
                }.cauterize()
            }
        }
        timer.tolerance = 0.5
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func roomSyncPromise() -> Promise<MXResponse<MXRoomInitialSync>> {
        return Promise { seal in
            mxClient.intialSync(ofRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", limit: 5) { response in
                seal.fulfill(response)
            }
        }
    }
    
    private func getMessagesPromise(from: String, limit: UInt?) -> Promise<MXResponse<MXPaginationResponse>> {
        return Promise { seal in
            mxClient.messages(forRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", from: from, direction: .backwards, limit: limit, filter: MXRoomEventFilter()) { response in
                seal.fulfill(response)
            }
        }
    }
    
    private func parseEvents(_ events: [MXEvent]) {
        let messageEvents = events.filter { event in
            return event.wireType == "m.room.message"
        }
        for event in messageEvents {
            if let publicKey = try? parsePublicKeyAnnouncement(messageString: event.wireContent["body"] as? String) {
                print(publicKey)
            }
        }
    
    }
    
    private func parsePublicKeyAnnouncement(messageString: String?) throws -> iosApp.PublicKey? {
        guard messageString != nil else {
            return nil
        }
        //Restore message NSDictionary
        guard let messageData = messageString!.data(using: String.Encoding.utf8) else {
            return nil
        }
        guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the message is a Public Key Announcement message
        guard let messageType = message["msgType"] as? String else {
            return nil
        }
        guard messageType == "pka" else {
            return nil
        }
        
        //Ensure that the sender is the maker
        guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
            return nil
        }
        
        //Restore payload NSDictionary
        guard let payloadString = message["payload"] as? String, let payloadData = Data(base64Encoded: payloadString) else {
            return nil
        }
        guard let payload = try JSONSerialization.jsonObject(with: payloadData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the offer id in the PKA matches the offer in question
        guard let messageOfferIdString = payload["offerId"] as? String, let messageOfferId = Data(base64Encoded: messageOfferIdString) else {
            return nil
        }
        
        //Re-create maker's public key
        guard let pubKeyString = payload["pubKey"] as? String, let pubKeyBytes = Data(base64Encoded: pubKeyString) else {
            return nil
        }
        guard let publicKey = try? PublicKey(publicKeyBytes: pubKeyBytes) else {
            return nil
        }
        
        //Check that interface id of maker's key matches value in "sender" field of message
        guard senderInterfaceId == publicKey.interfaceId else {
            return nil
        }
        
        //Create hash of payload
        let payloadDataDigest = SHA256.hash(data: payloadData)
        var payloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in payloadDataDigest.makeIterator() {
            payloadDataHashByteArray.append(byte)
        }
        let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
        
        //Verify signature
        guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
            return nil
        }
        if try publicKey.verifySignature(signedData: payloadDataHash, signature: signature) {
            return publicKey
        } else {
            return nil
        }
    }
    
}
