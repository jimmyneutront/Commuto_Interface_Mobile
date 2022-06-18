//
//  P2PService.swift
//  iosApp
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation
import PromiseKit
import Switrix

class P2PService {
    
    init(errorHandler: P2PErrorNotifiable, offerService: OfferMessageNotifiable, switrixClient: SwitrixClient) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        self.switrixClient = switrixClient
    }
    
    private let errorHandler: P2PErrorNotifiable
    
    private let offerService: OfferMessageNotifiable
    
    // Switrix client
    let switrixClient: SwitrixClient
    
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
                    self.syncPromise()
                }.then { [self] response -> Promise<SwitrixGetEventsResponse> in
                    let messagesPromise = getMessagesPromise(from: self.lastNonEmptyBatchToken, limit: 1_000_000_000_000)
                    let token = response.nextBatchToken
                    updateLastNonEmptyBatchToken(token)
                    return messagesPromise
                }.done { [self] response in
                    parseEvents(response.chunk)
                }.catch { [self] error in
                    // TODO: Stop listening for connection errors once bug is fixed
                    errorHandler.handleP2PError(error)
                    if let switrixError = error as? SwitrixError {
                        switch switrixError {
                        case .unknownToken:
                            stopListening()
                        case .missingToken:
                            stopListening()
                        default:
                            break
                        }
                    }
                }.finally {
                    self.isDoingListening = false
                }
            }
        }
        timer.tolerance = 0.5
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    }
    
    private func syncPromise() -> Promise<SwitrixSyncResponse> {
        return Promise { seal in
            switrixClient.sync.sync { response in
                switch response {
                case .success(let switrixSyncResponse):
                    seal.fulfill(switrixSyncResponse)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
    
    #warning("TODO: would be nice to specify to parameter here")
    private func getMessagesPromise(from: String, limit: Int) -> Promise<SwitrixGetEventsResponse> {
        return Promise { seal in
            switrixClient.events.getEvents(roomId: "!WEuJJHaRpDvkbSveLu:matrix.org", from: from, direction: .forwards, limit: limit) { response in
                switch response {
                case .success(let switrixGetEventsResponse):
                    seal.fulfill(switrixGetEventsResponse)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
    
    private func parseEvents(_ events: [SwitrixClientEvent]) {
        let messageEvents = events.filter { event in
            return event.type == "m.room.message"
        }
        for event in messageEvents {
            if let pka = try? parsePublicKeyAnnouncement(messageString: (event.content as? SwitrixMessageEventContent)?.body) {
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
