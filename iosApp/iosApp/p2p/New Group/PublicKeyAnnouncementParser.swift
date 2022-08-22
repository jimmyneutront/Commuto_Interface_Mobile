//
//  PublicKeyAnnouncementParser.swift
//  iosApp
//
//  Created by jimmyt on 7/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
Attempts to restore a PublicKeyAnnouncement from a given `String`.
 
 - Parameter messageString: An optional`String` from which to try to restore a `PublicKeyAnnouncement`.
 
 - Returns: An optional `PublicKeyAnnouncement` that will be `nil` if `messageString` does not contain a valid public key announcement, and will be non-`nil` if `messageString` does contain a valid public key announcement.
 */
func parsePublicKeyAnnouncement(messageString: String?) -> PublicKeyAnnouncement? {
    guard messageString != nil else {
        return nil
    }
    // Restore message NSDictionary
    guard let messageData = messageString!.data(using: String.Encoding.utf8) else {
        return nil
    }
    guard let message = try? JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
        return nil
    }
    
    // Ensure that the message is a Public Key Announcement message
    guard let messageType = message["msgType"] as? String else {
        return nil
    }
    guard messageType == "pka" else {
        return nil
    }
    
    // Get the interface ID of the sender
    guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
        return nil
    }
    
    // Restore payload NSDictionary
    guard let payloadString = message["payload"] as? String, let payloadData = Data(base64Encoded: payloadString) else {
        return nil
    }
    guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? NSDictionary else {
        return nil
    }
    
    // Get the offer ID in the announcement
    guard let messageOfferIdString = payload["offerId"] as? String, let messageOfferIdData = Data(base64Encoded: messageOfferIdString), let messageOfferId = UUID.from(data: messageOfferIdData) else {
        return nil
    }
    
    // Re-create maker's public key
    guard let pubKeyString = payload["pubKey"] as? String, let pubKeyBytes = Data(base64Encoded: pubKeyString) else {
        return nil
    }
    guard let publicKey = try? PublicKey(publicKeyBytes: pubKeyBytes) else {
        return nil
    }
    
    // Check that interface id of maker's key matches value in "sender" field of message
    guard senderInterfaceId == publicKey.interfaceId else {
        return nil
    }
    
    // Create hash of payload
    let payloadDataDigest = SHA256.hash(data: payloadData)
    var payloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in payloadDataDigest.makeIterator() {
        payloadDataHashByteArray.append(byte)
    }
    let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
    
    // Verify signature
    guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
        return nil
    }
    if (try? publicKey.verifySignature(signedData: payloadDataHash, signature: signature)) != nil {
        return PublicKeyAnnouncement(offerId: messageOfferId, pubKey: publicKey)
    } else {
        return nil
    }
}
