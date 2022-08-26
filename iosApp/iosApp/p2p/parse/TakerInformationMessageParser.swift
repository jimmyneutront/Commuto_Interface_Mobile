//
//  parseTakerInformationMessage.swift
//  iosApp
//
//  Created by jimmyt on 8/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 Attempts to restore a `TakerInformationMessage` from a given `NSDictionary` using a supplied `KeyPair`.
 
 - Parameters:
    - message: An optional `NSDictionary` from which to try to restore a `TakerInformationMessage`.
    - keyPair: The `KeyPair` with which this will attempt to decrypt the message's symmetric key and initialization vector.
 
 - Returns: An optional `TakerInformationMessage` that will be `nil` if `message` does not contain a valid Taker Information Message encrypted with the public key of `keyPair`, and will be non-`nil` if it does.
 */
func parseTakerInformationMessage(message: NSDictionary, keyPair: KeyPair) throws -> TakerInformationMessage? {
    // Ensure that the recipient interface ID matches that of our key pair
    guard let recipientInterfaceIDString = message["recipient"] as? String, let recipientInterfaceID = Data(base64Encoded: recipientInterfaceIDString) else {
        return nil
    }
    guard keyPair.interfaceId == recipientInterfaceID else {
        return nil
    }
    // Attempt to decrypt symmetric key and initialization vector
    guard let encryptedKeyString = message["encryptedKey"] as? String, let encryptedKey = Data(base64Encoded: encryptedKeyString) else {
        return nil
    }
    let decryptedKeyBytes = try keyPair.decrypt(cipherData: encryptedKey)
    let symmetricKey = SymmetricKey(key: decryptedKeyBytes)
    guard let encryptedIVString = message["encryptedIV"] as? String, let encryptedIV = Data(base64Encoded: encryptedIVString) else {
        return nil
    }
    let decryptedIV = try keyPair.decrypt(cipherData: encryptedIV)
    // Decrypt the payload
    guard let encryptedPayloadString = message["payload"] as? String, let encryptedPayloadData = Data(base64Encoded: encryptedPayloadString) else {
        return nil
    }
    let encryptedPayload = SymmetricallyEncryptedData(data: encryptedPayloadData, iv: decryptedIV)
    let decryptedPayloadData = try symmetricKey.decrypt(data: encryptedPayload)
    // Restore payload object
    guard let payload = try JSONSerialization.jsonObject(with: decryptedPayloadData) as? NSDictionary else {
        return nil
    }
    // Ensure that the message is a taker information message
    guard let messageType = payload["msgType"] as? String else {
        return nil
    }
    guard messageType == "takerInfo" else {
        return nil
    }
    // Get the taker's public key
    guard let publicKeyString = payload["pubKey"] as? String, let publicKeyBytes = Data(base64Encoded: publicKeyString) else {
        return nil
    }
    guard let publicKey = try? PublicKey(publicKeyBytes: publicKeyBytes) else {
        return nil
    }
    // Check that the interface ID of the taker's public key matches the value in the "sender" field of the message
    guard let senderInterfaceIDString = message["sender"] as? String, let senderInterfaceID = Data(base64Encoded: senderInterfaceIDString) else {
        return nil
    }
    guard senderInterfaceID == publicKey.interfaceId else {
        return nil
    }
    // Create a hash of the encrypted payload and verify the message's signature
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
        return nil
    }
    guard try publicKey.verifySignature(signedData: encryptedPayloadDataHash, signature: signature) else {
        return nil
    }
    // Get settlement method details
    guard let settlementMethodDetails = payload["paymentDetails"] as? String else {
        return nil
    }
    // Get swap ID
    guard let swapIDString = payload["swapId"] as? String, let swapID = UUID(uuidString: swapIDString) else {
        return nil
    }
    return TakerInformationMessage(swapID: swapID, publicKey: publicKey, settlementMethodDetails: settlementMethodDetails)
}
