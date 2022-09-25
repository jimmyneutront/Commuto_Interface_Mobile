//
//  MakerInformationMessageCreator.swift
//  iosApp
//
//  Created by jimmyt on 8/25/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 Creates a Maker Information Message using the supplied taker's public key, maker's/user's key pair, swap ID and maker's settlement method details according to the  [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 
 - Parameters:
    - takerPublicKey: The `PublicKey` of the swap taker, to which the message will be sent.
    - makerKeyPair: The `KeyPair` of the maker, with which the message will be signed.
    - swapID: The ID of the swap for which the maker is sending information.
    - settlementMethodDetails: The maker's settlement method details to be used for the swap, as an optional string. If this is `nil`, the `paymentDetails` field of the payload of the resulting message will be the empty string.
 
- Returns: A JSON `String` that is the Taker Information Message.
 */
func createMakerInformationMessage(takerPublicKey: PublicKey, makerKeyPair: KeyPair, swapID: UUID, settlementMethodDetails: String?) throws -> String {
    #warning("TODO: note that we use a UUID string for the swap ID")
    // Create payload Dictionary
    let payload = [
        "msgType": "makerInfo",
        "swapId": swapID.uuidString,
        "paymentDetails": settlementMethodDetails ?? ""
    ]
    
    // Create payload UTF8-bytes
    let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
    
    // Generate a new AES-256 key and initialization vector, and encrypt the payload bytes
    let symmetricKey = try newSymmetricKey()
    let encryptedPayload = try symmetricKey.encrypt(data: payloadUTF8Bytes)
    
    // Create signature of encrypted payload
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    let payloadSignature = try makerKeyPair.sign(data: encryptedPayloadDataHash)
    
    // Encrypt symmetric key and initialization vector with taker's public key
    let encryptedKey = try takerPublicKey.encrypt(clearData: symmetricKey.keyData)
    let encryptedInitializationVector = try takerPublicKey.encrypt(clearData: encryptedPayload.initializationVectorData)
    
    // Create message Dictionary
    let message = [
        "sender": makerKeyPair.interfaceId.base64EncodedString(),
        "recipient": takerPublicKey.interfaceId.base64EncodedString(),
        "encryptedKey": encryptedKey.base64EncodedString(),
        "encryptedIV": encryptedInitializationVector.base64EncodedString(),
        "payload": encryptedPayload.encryptedData.base64EncodedString(),
        "signature": payloadSignature.base64EncodedString()
    ]
    // Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
}
