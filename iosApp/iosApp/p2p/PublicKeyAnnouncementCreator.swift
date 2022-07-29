//
//  PublicKeyAnnouncementCreator.swift
//  iosApp
//
//  Created by jimmyt on 7/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 Creates a Public Key Announcement for the given public key and offer ID according to the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 
 - Parameters:
    - offerID: The ID of the offer for which this `PublicKey` is being announced.
    - keyPair: The `KeyPair` containing the `PublicKey` to be announced.
 
 - Returns: A JSON `String` that is the Public Key Announcement
 */
func createPublicKeyAnnouncement(offerID: UUID, keyPair: KeyPair) throws -> String {
    // Create Base64-encoded string of public key in PKCS#1 bytes
    let publicKeyString = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
    
    // Create a Base64-encoded string of the offer ID
    let offerIDString = offerID.asData().base64EncodedString()
    
    // Create payload Dictionary
    let payload = [
        "pubKey": publicKeyString,
        "offerId": offerIDString
    ]
    
    // Create payload UTF-8 bytes and their Base64-encoded string
    let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
    let payloadString = payloadUTF8Bytes.base64EncodedString()
    
    // Create signature of payload hash
    let payloadDataDigest = SHA256.hash(data: payloadUTF8Bytes)
    var payloadDataHashArray = [UInt8]()
    for byte: UInt8 in payloadDataDigest.makeIterator() {
        payloadDataHashArray.append(byte)
    }
    let payloadDataHash = Data(bytes: payloadDataHashArray, count: payloadDataHashArray.count)
    let payloadDataSignature = try keyPair.sign(data: payloadDataHash)
    
    // Create message Dictionary
    let message = [
        "sender": keyPair.interfaceId.base64EncodedString(),
        "msgType": "pka",
        "payload": payloadString,
        "signature": payloadDataSignature.base64EncodedString()
    ]
    
    // Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
    
}
