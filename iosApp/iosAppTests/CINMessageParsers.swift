//
//  CINMessageParsers.swift
//  iosAppTests
//
//  Created by jimmyt on 2/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
@testable import iosApp
import CryptoKit

func createPublicKeyAnnouncement(keyPair: KeyPair, offerId: Data) throws -> String {
    //Create message NSDictionary
    var message = [
        "sender": keyPair.interfaceId.base64EncodedString(),
        "msgType": "pka",
        "payload": nil,
        "signature": nil,
    ]
    
    //Create Base64-encoded string of public key in PKCS#1 bytes
    let pubKeyString = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
    
    //Create Base-64 encoded string of offer idV
    let offerIdString = offerId.base64EncodedString()
    
    //Create payload NSDictionary
    let payload = [
        "pubKey": pubKeyString,
        "offerId": offerIdString,
    ]
    
    //Create payload UTF-8 bytes and their Base-64 encoded string
    let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
    let payloadString = payloadUTF8Bytes.base64EncodedString()
    
    //Set "payload" field of message
    message["payload"] = payloadString
    
    //Create signature of payload
    let payloadDataDigest = SHA256.hash(data: payloadUTF8Bytes)
    var payloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in payloadDataDigest.makeIterator() {
        payloadDataHashByteArray.append(byte)
    }
    let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
    let signature = try keyPair.sign(data: payloadDataHash)
    
    //Set "signature" field of message
    message["signature"] = signature.base64EncodedString()
    
    //Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
}

func parsePublicKeyAnnouncement(messageString: String, makerInterfaceId: Data, offerId: Data) throws -> iosApp.PublicKey? {
    //Restore message NSDictionary
    guard let messageData = messageString.data(using: String.Encoding.utf8) else {
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
    guard makerInterfaceId == senderInterfaceId else {
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
    guard messageOfferId == offerId else {
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

func createTakerInfoMessage(keyPair: KeyPair, makerPubKey: iosApp.PublicKey, swapId: Data, paymentDetails: [String : Any]) throws -> String {
    //Create message NSDictionary
    var message = [
        "sender": keyPair.interfaceId.base64EncodedString(),
        "recipient": makerPubKey.interfaceId.base64EncodedString(),
        "encryptedKey": nil,
        "encryptedIV": nil,
        "payload": nil,
        "signature": nil
    ]
    
    //Create Base64-encoded string of taker's public key in PKCS#1 bytes
    let pubKeyString = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
    
    //Create Base-64 encoded string of swap id
    let swapIdString = swapId.base64EncodedString()
    
    //Create payload NSDictionary
    var payload = [
        "msgType": "takerInfo",
        "pubKey": pubKeyString,
        "swapId": swapIdString,
        "paymentDetails": nil
    ]
    
    //Create payment details UTF-8 bytes and their Base64-encoded string
    let paymentDetailsUTF8Bytes = try JSONSerialization.data(withJSONObject: paymentDetails)
    
    //Set "paymentDetails" field of payload
    payload["paymentDetails"] = paymentDetailsUTF8Bytes.base64EncodedString()
    
    //Create payload UTF-8 bytes and their Base64-encoded string
    let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
    
    //Generate a new symmetric key and initialization vector, and encrypt the payload bytes
    let symmetricKey = try newSymmetricKey()
    let encryptedPayload = try symmetricKey.encrypt(data: payloadUTF8Bytes)
    
    //Set "payload" field of message
    message["payload"] = encryptedPayload.encryptedData.base64EncodedString()
    
    //Create signature of encrypted payload
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    let signature = try keyPair.sign(data: encryptedPayloadDataHash)
    
    //Set signature field of message
    message["signature"] = signature.base64EncodedString()
    
    //Encrypt symmetric key and initialization vector with maker's public key
    let encryptedKey = try makerPubKey.encrypt(clearData: symmetricKey.keyData)
    let encryptedIV = try makerPubKey.encrypt(clearData: encryptedPayload.initializationVectorData)
    
    //Set "encryptedKey" and "encryptedIV" fields of message
    message["encryptedKey"] = encryptedKey.base64EncodedString()
    message["encryptedIV"] = encryptedIV.base64EncodedString()
    
    //Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
    
}

func parseTakerInfoMessage(messageString: String, keyPair: KeyPair, takerInterfaceId: Data, swapId: Data) throws -> (iosApp.PublicKey, [String : Any])? {
    //Restore message NSDictionary
    guard let messageData = messageString.data(using: String.Encoding.utf8) else {
        return nil
    }
    guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
        return nil
    }
    
    //Ensure that the sender is the taker and the recipient is the maker
    guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
        return nil
    }
    guard takerInterfaceId == senderInterfaceId else {
        return nil
    }
    guard let recipientInterfaceIdString = message["recipient"] as? String, let recipientInterfaceId = Data(base64Encoded: recipientInterfaceIdString) else {
        return nil
    }
    guard keyPair.interfaceId == recipientInterfaceId else {
        return nil
    }
    
    //Decrypt symmetric key, initialization vector and encrypted payload
    guard let encryptedKeyString = message["encryptedKey"] as? String, let encryptedKey = Data(base64Encoded: encryptedKeyString) else {
        return nil
    }
    let decryptedKeyBytes = try keyPair.decrypt(cipherData: encryptedKey)
    let symmetricKey = SymmetricKey(key: decryptedKeyBytes)
    guard let encryptedPayloadString = message["payload"] as? String, let encryptedPayloadData = Data(base64Encoded: encryptedPayloadString) else {
        return nil
    }
    guard let encryptedIVString = message["encryptedIV"] as? String, let encryptedIV = Data(base64Encoded: encryptedIVString) else {
        return nil
    }
    let decryptedIV = try keyPair.decrypt(cipherData: encryptedIV)
    let encryptedPayload = SymmetricallyEncryptedData(data: encryptedPayloadData, iv: decryptedIV)
    let decryptedPayloadData = try symmetricKey.decrypt(data: encryptedPayload)
    
    //Restore payload object
    guard let payload = try JSONSerialization.jsonObject(with: decryptedPayloadData) as? NSDictionary else {
        return nil
    }
    
    //Ensure the message is a taker info message
    guard let messageType = payload["msgType"] as? String else {
        return nil
    }
    guard messageType == "takerInfo" else {
        return nil
    }
    
    //Ensure that the swap id in the takerInfo message matches the swap in qustion
    guard let messageSwapIdString = payload["swapId"] as? String, let messageSwapId = Data(base64Encoded: messageSwapIdString) else {
        return nil
    }
    guard messageSwapId == swapId else {
        return nil
    }
    
    //Re-create taker's public key
    guard let pubKeyString = payload["pubKey"] as? String, let pubKeyBytes = Data(base64Encoded: pubKeyString) else {
        return nil
    }
    guard let publicKey = try? PublicKey(publicKeyBytes: pubKeyBytes) else {
        return nil
    }
    
    //Check that interface id of taker's key matches value in "sender" field of message
    guard senderInterfaceId == publicKey.interfaceId else {
        return nil
    }
    
    //Create hash of encrypted payload
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    
    //Verify signature
    guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
        return nil
    }
    guard try publicKey.verifySignature(signedData: encryptedPayloadDataHash, signature: signature) else {
        return nil
    }
    
    //Restore payment details object
    /*
    TODO: In production, we should know the sort of payment info we are looking for, try to deserialize that type exactly, and return null if the payment info is for a different payment method
     */
    guard let paymentDetailsString = payload["paymentDetails"] as? String, let paymentDetailsData = Data(base64Encoded: paymentDetailsString) else {
        return nil
    }
    guard let paymentDetails = try JSONSerialization.jsonObject(with: paymentDetailsData) as? [String : Any] else {
        return nil
    }
    return (publicKey, paymentDetails)
}

func createMakerInfoMessage(keyPair: KeyPair, takerPubKey: iosApp.PublicKey, swapId: Data, paymentDetails: [String : Any]) throws -> String {
    //Create message NSDictionary
    var message = [
        "sender": keyPair.interfaceId.base64EncodedString(),
        "recipient": takerPubKey.interfaceId.base64EncodedString(),
        "encryptedKey": nil,
        "encryptedIV": nil,
        "payload": nil,
        "signature": nil
    ]
    
    //Create Base-64 encoded string of swap id
    let swapIdString = swapId.base64EncodedString()
    
    //Create payload NSDictionary
    var payload = [
        "msgType": "makerInfo",
        "swapId": swapIdString,
        "paymentDetails": nil
    ]
    
    //Create payment details UTF-8 bytes and their Base64-encoded string
    let paymentDetailsUTF8Bytes = try JSONSerialization.data(withJSONObject: paymentDetails)
    
    //Set "paymentDetails" field of payload
    payload["paymentDetails"] = paymentDetailsUTF8Bytes.base64EncodedString()
    
    //Create payload UTF-8 bytes and their Base64-encoded string
    let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
    
    //Generate a new symmetric key and initialization vector, and encrypt the payload bytes
    let symmetricKey = try newSymmetricKey()
    let encryptedPayload = try symmetricKey.encrypt(data: payloadUTF8Bytes)
    
    //Set "payload" field of message
    message["payload"] = encryptedPayload.encryptedData.base64EncodedString()
    
    //Create signature of encrypted payload
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    let signature = try keyPair.sign(data: encryptedPayloadDataHash)
    
    //Set "signature" field of message
    message["signature"] = signature.base64EncodedString()
    
    //Encrypt symmetric key and initialization vector with taker's public key
    let encryptedKey = try takerPubKey.encrypt(clearData: symmetricKey.keyData)
    let encryptedIV = try takerPubKey.encrypt(clearData: encryptedPayload.initializationVectorData)
    
    //Set "encryptedKey" and "encryptedIV" fields of message
    message["encryptedKey"] = encryptedKey.base64EncodedString()
    message["encryptedIV"] = encryptedIV.base64EncodedString()
    
    //Prepare and return message string
    let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    return messageString
    
}

func parseMakerInfoMessage(messageString: String, keyPair: KeyPair, makerPubKey: iosApp.PublicKey, swapId: Data) throws -> [String : Any]? {
    //Restore message NSDictionary
    guard let messageData = messageString.data(using: String.Encoding.utf8) else {
        return nil
    }
    guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
        return nil
    }
    
    //Ensure that the sender is the maker and the recipient is the taker
    guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
        return nil
    }
    guard makerPubKey.interfaceId == senderInterfaceId else {
        return nil
    }
    guard let recipientInterfaceIdString = message["recipient"] as? String, let recipientInterfaceId = Data(base64Encoded: recipientInterfaceIdString) else {
        return nil
    }
    guard keyPair.interfaceId == recipientInterfaceId else {
        return nil
    }
    
    //Restore signature
    guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
        return nil
    }
    
    //Decode encrypted payload
    guard let encryptedPayloadString = message["payload"] as? String, let encryptedPayloadData = Data(base64Encoded: encryptedPayloadString) else {
        return nil
    }
    
    //Create hash of encrypted payload
    let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayloadData)
    var encryptedPayloadDataHashByteArray = [UInt8]()
    for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
        encryptedPayloadDataHashByteArray.append(byte)
    }
    let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
    
    //Verify signature
    guard try makerPubKey.verifySignature(signedData: encryptedPayloadDataHash, signature: signature) else {
        return nil
    }
    
    //Decrypt symmetric key, initialization vector and encrypted payload
    guard let encryptedKeyString = message["encryptedKey"] as? String, let encryptedKey = Data(base64Encoded: encryptedKeyString) else {
        return nil
    }
    let decryptedKeyBytes = try keyPair.decrypt(cipherData: encryptedKey)
    let symmetricKey = SymmetricKey(key: decryptedKeyBytes)
    guard let encryptedIVString = message["encryptedIV"] as? String, let encryptedIV = Data(base64Encoded: encryptedIVString) else {
        return nil
    }
    let decryptedIV = try keyPair.decrypt(cipherData: encryptedIV)
    let encryptedPayload = SymmetricallyEncryptedData(data: encryptedPayloadData, iv: decryptedIV)
    let decryptedPayloadData = try symmetricKey.decrypt(data: encryptedPayload)
    
    //Restore payload object
    guard let payload = try JSONSerialization.jsonObject(with: decryptedPayloadData) as? NSDictionary else {
        return nil
    }
    
    //Ensure the message is a maker info message
    guard let messageType = payload["msgType"] as? String else {
        return nil
    }
    guard messageType == "makerInfo" else {
        return nil
    }
    
    //Ensure that the swap id in the makerInfo message matches the swap in question
    guard let messageSwapIdString = payload["swapId"] as? String, let messageSwapId = Data(base64Encoded: messageSwapIdString) else {
        return nil
    }
    guard messageSwapId == swapId else {
        return nil
    }
    
    //Restore payment details object
    /*
    TODO: In production, we should know the sort of payment info we are looking for, try to deserialize that type exactly, and return null if the payment info is for a different payment method
     */
    guard let paymentDetailsString = payload["paymentDetails"] as? String, let paymentDetailsData = Data(base64Encoded: paymentDetailsString) else {
        return nil
    }
    guard let paymentDetails = try JSONSerialization.jsonObject(with: paymentDetailsData) as? [String : Any] else {
        return nil
    }
    return paymentDetails
}
