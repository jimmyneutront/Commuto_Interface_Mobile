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
    
    init(offerService: OfferMessageNotifiable) {
        self.offerService = offerService
        let creds = MXCredentials(homeServer: "https://matrix.org", userId: "@jimmyt:matrix.org", accessToken: "")
        self.creds = creds
        self.mxClient =  MXRestClient(credentials: creds, unrecognizedCertificateHandler: nil)
    }
    
    private let offerService: OfferMessageNotifiable
    
    // Matrix credentials
    private let creds: MXCredentials
    
    // Matrix REST client
    let mxClient: MXRestClient
    
    // The token at the end of the last batch of non-empty messages (this token is that from the beginning of the Commuto Interface network test room)
    private var lastNonEmptyBatchToken = "t1-2607497254_757284974_11441483_1402797642_1423439559_3319206_507472245_4060289024_0"
    
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
                    let messagesPromise = getMessagesPromise(from: self.lastNonEmptyBatchToken, limit: 1_000_000_000_000)
                    updateLastNonEmptyBatchToken(response.value!.messages.end)
                    return messagesPromise
                }.done { [self] response in
                    parseEvents(response.value!.chunk)
                    isDoingListening = false
                }.cauterize()
            }
        }
        timer.tolerance = 0.5
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    }
    
    private func roomSyncPromise() -> Promise<MXResponse<MXRoomInitialSync>> {
        return Promise { seal in
            mxClient.intialSync(ofRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", limit: 5) { response in
                seal.fulfill(response)
            }
        }
    }
    
    // TODO: would be nice to specify "to" parameter here
    private func getMessagesPromise(from: String, limit: UInt?) -> Promise<MXResponse<MXPaginationResponse>> {
        return Promise { seal in
            mxClient.messages(forRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", from: from, direction: .forwards, limit: limit, filter: MXRoomEventFilter()) { response in
                seal.fulfill(response)
            }
        }
    }
    
    private func parseEvents(_ events: [MXEvent]) {
        let messageEvents = events.filter { event in
            return event.wireType == "m.room.message"
        }
        for event in messageEvents {
            if let pka = try? parsePublicKeyAnnouncement(messageString: event.wireContent["body"] as? String) {
                offerService.handlePublicKeyAnnouncement(pka)
            }
        }
    
    }
    
    private func parsePublicKeyAnnouncement(messageString: String?) throws -> PublicKeyAnnouncement? {
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
        guard let messageOfferIdString = payload["offerId"] as? String, let messageOfferIdData = Data(base64Encoded: messageOfferIdString), let messageOfferId = UUID.from(data: messageOfferIdData) else {
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
            return PublicKeyAnnouncement(offerId: messageOfferId, pubKey: publicKey)
        } else {
            return nil
        }
    }
    
}
