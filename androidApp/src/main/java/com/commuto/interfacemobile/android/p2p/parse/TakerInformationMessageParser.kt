package com.commuto.interfacemobile.android.p2p.parse

import com.commuto.interfacemobile.android.key.keys.KeyPair
import com.commuto.interfacemobile.android.key.keys.PublicKey
import com.commuto.interfacemobile.android.key.keys.SymmetricKey
import com.commuto.interfacemobile.android.key.keys.SymmetricallyEncryptedData
import com.commuto.interfacemobile.android.p2p.messages.TakerInformationMessage
import com.commuto.interfacemobile.android.p2p.serializable.messages.SerializableTakerInformationMessage
import com.commuto.interfacemobile.android.p2p.serializable.payloads.SerializableTakerInformationMessagePayload
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import java.security.MessageDigest
import java.util.*

/**
 * Attempts to restore a [TakerInformationMessage] from a given [String] using a supplied [KeyPair].
 *
 * @param messageString An optional [String] from which to try to restore a [TakerInformationMessage].
 * @param keyPair The [KeyPair] with which this will attempt to decrypt the message's symmetric key and initialization
 * vector.
 */
fun parseTakerInformationMessage(messageString: String?, keyPair: KeyPair): TakerInformationMessage? {
    if (messageString == null) {
        return null
    }
    // Restore message object
    val message = try {
        Json.decodeFromString<SerializableTakerInformationMessage>(messageString)
    } catch (e: Exception) {
        return null
    }
    // Setup decoder
    val decoder = Base64.getDecoder()
    // Ensure that the recipient interface ID matches that of our key pair
    try {
        if (!decoder.decode(message.recipient).contentEquals(keyPair.interfaceId)) {
            return null
        }
    } catch (exception: IllegalArgumentException) {
        return null
    }
    // Attempt to decrypt symmetric key and initialization vector
    val symmetricKey = try {
        val encryptedKey = decoder.decode(message.encryptedKey)
        val decryptedKeyBytes = keyPair.decrypt(encryptedKey)
        SymmetricKey(decryptedKeyBytes)
    } catch (e: Exception) {
        return null
    }
    val decryptedIV = try {
        val encryptedIV = decoder.decode(message.encryptedIV)
        keyPair.decrypt(encryptedIV)
    } catch (e: Exception) {
        return null
    }
    // Decrypt the payload
    val encryptedPayload = try {
        SymmetricallyEncryptedData(
            data = decoder.decode(message.payload),
            iv = decryptedIV
        )
    } catch (e: Exception) {
        return null
    }
    val decryptedPayloadBytes = try {
        symmetricKey.decrypt(encryptedPayload)
    } catch (e: Exception) {
        return null
    }
    // Restore payload object
    val payload = try {
        val payloadString = String(bytes = decryptedPayloadBytes, charset = Charsets.UTF_8)
        Json.decodeFromString<SerializableTakerInformationMessagePayload>(payloadString)
    } catch (e: Exception) {
        return null
    }
    // Ensure that the message is a taker information message
    if (payload.msgType != "takerInfo") {
        return null
    }
    // Get the taker's public key
    val publicKey = try {
        PublicKey(decoder.decode(payload.pubKey))
    } catch (e: Exception) {
        return null
    }
    // Check that the interface ID of the taker's public key matches the value in the "sender" field of the message
    try {
        if (!decoder.decode(message.sender).contentEquals(publicKey.interfaceId)) {
            return null
        }
    } catch (e: Exception) {
        return null
    }
    // Create a hash of the encrypted payload and verify the message's signature
    val encryptedPayloadDataHash = MessageDigest.getInstance("SHA-256").digest(encryptedPayload.encryptedData)
    try {
        if (!publicKey.verifySignature(encryptedPayloadDataHash, decoder.decode(message.signature))) {
            return null
        }
    } catch (e: Exception) {
        return null
    }
    // Get settlement method details
    val settlementMethodDetails = payload.paymentDetails
    val swapID = try {
        UUID.fromString(payload.swapId)
    } catch (e: Exception) {
        return null
    }
    return TakerInformationMessage(
        swapID = swapID,
        publicKey = publicKey,
        settlementMethodDetails = settlementMethodDetails,
    )
}