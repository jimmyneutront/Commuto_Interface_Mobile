//
//  P2PService.swift
//  iosApp
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation
import os
import PromiseKit
import Switrix

/**
 The main Peer-to-Peer Service. It is responsible for listening to new messages in the Commuto Interface Network Matrix room, parsing the messages, and then passing relevant messages to other services as necessary.
 */
class P2PService {
    
    /**
     Initializes a new P2PService object.
     
     - Parameters:
        - errorHandler: An object that conforms to the `P2PErrorNotifiable` protocol, to which this will pass errors when they occur.
        - offerService: An object that comforms to the `OfferMessageNotifiable` protocol, to which this will pass offer-related messages.
        - switrixClient: A `SwitrixClient` instance used to interact with a Matrix Homeserver.
     
     - Returns: A new `P2PService` instance.
     */
    init(errorHandler: P2PErrorNotifiable, offerService: OfferMessageNotifiable, switrixClient: SwitrixClient) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        self.switrixClient = switrixClient
    }
    
    /**
     P2PService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "P2PService")
    
    /**
     An object to which `P2PService` will pass errors when they occur.
     */
    private let errorHandler: P2PErrorNotifiable
    
    /**
     An object to which `P2PService` will pass offer-related messages when they occur.
     */
    private let offerService: OfferMessageNotifiable
    
    /**
     A `SwitrixClient` instance used to interact with a Matrix Homeserver.
     */
    let switrixClient: SwitrixClient
    
    /**
     The token at the end of the last batch of non-empty Matrix events that was parsed. (The value specified here is that from the beginning of the Commuto Interface Network testing room.) This should be updated every time a new batch of events is parsed.
     */
    private var lastNonEmptyBatchToken = "t1-2607497254_757284974_11441483_1402797642_1423439559_3319206_507472245_4060289024_0"
    
    /**
     Used to update `lastNonEmptyBatchToken`. Eventually, this function will store `newToken` in persistent storage.
     
     - Parameter newToken: The batch token at the end of the most recently parsed batch of Matrix events, to be set as `lastNonEmptyBatchToken`.
     */
    private func updateLastNonEmptyBatchToken(_ newToken: String) {
        lastNonEmptyBatchToken = newToken
    }
    
    /**
     The thread in which P2PService listens for and parses messages.
     */
    private var listenThread: Thread?
    
    /**
     The timer that runs in `listenThread`'s `RunLoop` and is responsible for repeatedly executing the listening process.
     */
    private var timer: Timer?
    
    /**
     Indicates whether P2PService is currently handling new data as part of the listening process.
     */
    private var isDoingListening = false
    
    /**
     Creates a new  `Thread` to run `listenLoop()`, updates `listenThread` with a reference to the new `Thread`, and starts it.
     */
    func listen() {
        logger.notice("Starting listen loop in new thread")
        listenThread = Thread { [self] in
            listenLoop()
        }
        listenThread!.start()
        logger.notice("Started listen loop in new thread")
    }
    
    /**
     Invalidates the `Timer` resposible for repeatedly starting the listening process and cancels `listenThread`.
     */
    func stopListening() {
        logger.notice("Invalidating listen loop timer and canceling listen loop thread")
        timer?.invalidate()
        listenThread?.cancel()
        logger.notice("Invalidated listen loop timer and canceled listen loop thread")
    }
    
    /**
     Creates a new `Timer` responsible for repeatedly executing the listening process once approximately every second, adds the `Timer` to the current thread's `Runloop`, and then starts said `Runloop`.
     
     Listening Process:
     
     First,  we check the`isDoingListening` flag. If `isDoingListening` is true, then the listening process is currently running, so we don't start it again. If `isDoingListening` is false, then the listening process isn't currently running, so we can safely start it.
     
     Once we have established that we can safely start the listening process, we call `syncPromise()` to get the most recent batch token from the Matrix homeserver. Then we try to get all new events since that most recent batch token, with a limit of one trillion events, by calling `getMessagesPromise()`. We update our last non-empty batch token with the `nextBatchToken` value in the response from the `syncPromise()` call, and then we parse the new events for relavent messages.
     
     Finally, once the listening process is completed, we set `isDoingListening` to `false` to indicate that the listening process is not currently running and can be started again by the `Timer`.
     
     If we encounter an error, we pass it to our `errorHandler`. Additionally, if the error indicates that we have a missing or invalid token, we call `stopListening()` to prevent the listening process from being started again, since the user must perform some action in order to resolve this issue.
     */
    func listenLoop() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if (!isDoingListening) {
                logger.notice("Beginning iteration of listen loop")
                isDoingListening = true
                firstly {
                    self.syncPromise()
                }.then { [self] response -> Promise<(SwitrixGetEventsResponse, String)> in
                    self.logger.notice("Synced with Matrix homeserver, got nextBatchToken: \(response.nextBatchToken)")
                    return getMessagesPromise(from: self.lastNonEmptyBatchToken, limit: 1_000_000_000_000).map { ($0, response.nextBatchToken)  }
                }.done { [self] response, newToken in
                    self.logger.notice("Got new messages from Matrix homeserver from lastNonEmptyBatchToken: \(self.lastNonEmptyBatchToken)")
                    try parseEvents(response.chunk)
                    self.logger.notice("Finished parsing new events from chunk of size \(response.chunk.count)")
                    updateLastNonEmptyBatchToken(newToken)
                    self.logger.notice("Updated lastNonEmptyBatchToken with new token: \(newToken)")
                }.catch { [self] error in
                    self.logger.error("Got an error during listen loop, calling error handler. Error: \(error.localizedDescription)")
                    errorHandler.handleP2PError(error)
                    if (error as NSError).domain == "NSURLErrorDomain" {
                        self.logger.error("Detected error with internet connection; stopping listen loop.")
                        // There is a problem with the internet connection, so there is no point in continuing to listen for new events.
                        stopListening()
                    } else if let switrixError = error as? SwitrixError {
                        switch switrixError {
                        case .unknownToken:
                            self.logger.error("Got unknown token error, stopping listen loop.")
                            stopListening()
                        case .missingToken:
                            self.logger.error("Got missing token error, stopping listen loop.")
                            stopListening()
                        default:
                            break
                        }
                    }
                }.finally {
                    self.isDoingListening = false
                    self.logger.info("Completed iteration of listen loop.")
                }
            }
        }
        timer.tolerance = 0.5
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    }
    
    /**
    A `Promise` wrapper around Switrix's `SwitrixSyncClient().sync()` method.
     
     - Returns: A `Promise<SwitrixSyncResponse>`, in which the `SwitrixSyncResponse` is from the Commuto Interface Network test room.
     */
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
    /**
    A `Promise` wrapper around Switrix's `SwitrixEventsClient().getEvents(...)` method. This method gets message events only from the Commuto Interface Network test room.
     
     - Parameters:
        - from: The batch token from which to start returning events.
        - limit: The maximun number of events to return. Note that this will likely be greater than the number of events actually returned, since Switrix filters out all events that are not text message events.
     
     - Returns: A  `Promise<SwitrixGetEventsResponse>`, in which the `SwitrixGetEventsResponse`, if successful, contains text message events from the Commuto Interface Network test room.
     */
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
    
    /**
    Parses an array of `SwitrixClientEvent`s, filters out all non-message events, attempts to create message objects from the content bodies of message events, if present, and then passes any created offer-related message objects to `offerService`.
     
     - Parameter events: a list of `SwitrixClientEvent`s.
     */
    private func parseEvents(_ events: [SwitrixClientEvent]) throws {
        let messageEvents = events.filter { event in
            return event.type == "m.room.message"
        }
        self.logger.notice("parseEvents: parsing \(messageEvents.count) m.room.message events")
        for event in messageEvents {
            if let pka = parsePublicKeyAnnouncement(messageString: (event.content as? SwitrixMessageEventContent)?.body) {
                self.logger.notice("parseEvents: got Public Key Announcement message in event with Matrix event ID: \(event.eventId)")
                try offerService.handlePublicKeyAnnouncement(pka)
            }
        }
    
    }
    
    /**
    Attempts to restore a PublicKeyAnnouncement from a given `String`.
     
     - Parameter messageString: A `String?` from which to try to restore a `PublicKeyAnnouncement`. If `messageString` is nil, `parsePublicKeyAnnouncement(...)` immediately returns nil.
     
     - Returns: A `PublicKeyAnnouncement?` that will be `nil` if `messageString` does not contain a valid public key announcement, and will be non-`nil` if `messageString` does contain a valid public key announcement.
     */
    private func parsePublicKeyAnnouncement(messageString: String?) -> PublicKeyAnnouncement? {
        guard messageString != nil else {
            return nil
        }
        //Restore message NSDictionary
        guard let messageData = messageString!.data(using: String.Encoding.utf8) else {
            return nil
        }
        guard let message = try? JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
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
        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? NSDictionary else {
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
        if (try? publicKey.verifySignature(signedData: payloadDataHash, signature: signature)) != nil {
            return PublicKeyAnnouncement(offerId: messageOfferId, pubKey: publicKey)
        } else {
            return nil
        }
    }
    
}
