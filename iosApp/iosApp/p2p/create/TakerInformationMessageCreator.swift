//
//  TakerInformationMessageCreator.swift
//  iosApp
//
//  Created by jimmyt on 8/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 Creates a Taker Information Message using the supplied maker's public key, taker's/user's key pair, swap ID and taker's settlement method details according to the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 
 - Parameters:
    - makerPublicKey: The `PublicKey` of the swap maker, to which the message will be sent.
    - takerKeyPair: The `KeyPair` of the taker, with which the message will be signed.
    - swapID: The ID of the swap for which the taker is sending information.
    - settlementMethodDetails: The taker's settlement method details to be used for the swap.
 
 - Returns: A JSON `String` that is the Taker Information Message.
 */
func createTakerInformationMessage(makerPublicKey: PublicKey, takerKeyPair: KeyPair, swapID: UUID, settlementMethodDetails: String) throws -> String {
    // Create Base64-encoded string of the taker's (user's) public key in PKCS#1 bytes
    let makerPublicKeyString = try takerKeyPair.pubKeyToPkcs1Bytes().base64EncodedString()
    
    #warning("TODO: note that we use a UUID string for the swap ID")
    // Create payload Dictionary
    let payload = [
        "msgType": "takerInfo",
        "pubKey": makerPublicKeyString,
        "swapId": swapID.uuidString,
        "paymentDetails": settlementMethodDetails
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
    let payloadSignature = try takerKeyPair.sign(data: encryptedPayloadDataHash)
    
    // Encrypt symmetric key and initialization vector with maker's public key
    let encryptedKey = try makerPublicKey.encrypt(clearData: symmetricKey.keyData)
    let encryptedInitializationVector = try makerPublicKey.encrypt(clearData: encryptedPayload.initializationVectorData)
    
    // Create message Dictionary
    let message = [
        "sender": takerKeyPair.interfaceId.base64EncodedString(),
        "recipient": makerPublicKey.interfaceId.base64EncodedString(),
        "encryptedKey": encryptedKey.base64EncodedString(),
        "encryptedIV": encryptedInitializationVector.base64EncodedString(),
        "payload": encryptedPayload.encryptedData.base64EncodedString(),
        "signature": payloadSignature.base64EncodedString()
    ]
    // Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
}
