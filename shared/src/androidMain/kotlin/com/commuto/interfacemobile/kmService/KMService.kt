package com.commuto.interfacemobile.kmService

import com.commuto.interfacemobile.dbService.DBService
import com.commuto.interfacemobile.kmService.kmTypes.KeyPair
import com.commuto.interfacemobile.kmService.kmTypes.PublicKey
import org.bouncycastle.asn1.*
import java.security.KeyFactory
import java.security.KeyPair as JavaSecKeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey as JavaSecPublicKey
import java.security.spec.RSAPrivateKeySpec
import java.security.spec.RSAPrivateCrtKeySpec
import java.security.spec.X509EncodedKeySpec
import android.util.Base64
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo
import org.bouncycastle.asn1.pkcs.PKCSObjectIdentifiers
import org.bouncycastle.asn1.pkcs.RSAPrivateKey
import org.bouncycastle.asn1.x509.AlgorithmIdentifier
import org.bouncycastle.asn1.x509.SubjectPublicKeyInfo

/**
 * The Key Manager Service Class.
 *
 * This is responsible for generating, storing, and retrieving key pairs, and for storing and retrieving public keys.
 *
 * @property dbService the Database Service used to store and retrieve data
 */
class KMService(var dbService: DBService) {

    /**
     * Generates a new KeyPair, and optionally stores it in the database
     *
     * @param storeResult indicate whether the generated key pair should be stored in the database. This will primarily
     * be left as true, but testing code may set as false to generate a key pair for testing duplicate key protection.
     * If true, each key pair is stored in the database as Base64 encoded Strings of byte representations of the public
     * and private keys in PKCS#1 format.
     *
     * @return a new KeyPair object
     */
    fun generateKeyPair(storeResult: Boolean = true): KeyPair {
        val keyPair = KeyPair()
        if (storeResult) {
            dbService.storeKeyPair(Base64.encodeToString(keyPair.interfaceId, Base64.DEFAULT),
                Base64.encodeToString(keyPair.pubKeyToPkcs1Bytes(), Base64.DEFAULT),
                Base64.encodeToString(keyPair.privKeyToPkcs1Bytes(), Base64.DEFAULT))
        }
        return keyPair
    }

    /**
     * Retrieves the persistently stored KeyPair associated with the given interface id, or returns null if not
     * present.
     *
     * @param interfaceId the interface id of the key pair, a SHA-256 hash of the PKCS#1 byte array encoded
     * representation of its public key.
     *
     * @return KeyPair?
     * @return null if no KeyPair is found with the given interface id
     */
    fun getKeyPair(interfaceId: ByteArray): KeyPair? {
        val dbKeyPair: com.commuto.interfacemobile.db.KeyPair? = dbService
            .getKeyPair(Base64.encodeToString(interfaceId, Base64.DEFAULT))
        if (dbKeyPair != null) {
            return KeyPair(Base64.decode(dbKeyPair.publicKey, Base64.DEFAULT),
                Base64.decode(dbKeyPair.privateKey, Base64.DEFAULT))
        } else {
            return null
        }
    }

    /**
     * Persistently stores a PublicKey associated with an interface id. This will generate a PKCS#1 byte array
     * representation of the public key, encode it as a Base64 String and store it in the database.
     *
     * @param pubKey the public key to be stored
     */
    fun storePublicKey(pubKey: PublicKey) {
        val interfaceId: ByteArray = MessageDigest.getInstance("SHA-256")
            .digest(pubKey.toPkcs1Bytes())
        dbService.storePublicKey(Base64.encodeToString(interfaceId, Base64.DEFAULT),
            Base64.encodeToString(pubKey.toPkcs1Bytes(), Base64.DEFAULT))
    }

    /**
     * Retrieves the persistently stored PublicKey associated with the given interface id, or returns null if not
     * present
     *
     * @param interfaceId the interface id of the public key, a SHA-256 hash of its PKCS#1 byte array encoded
     * representation
     *
     * @return PublicKey?
     * @return null if no PublicKey is found with the given interface id
     */
    fun getPublicKey(interfaceId: ByteArray): PublicKey? {
        val dbPubKey: com.commuto.interfacemobile.db.PublicKey? = dbService
            .getPublicKey(Base64.encodeToString(interfaceId, Base64.DEFAULT))
        if (dbPubKey != null) {
            return PublicKey(Base64.decode(dbPubKey.publicKey, Base64.DEFAULT))
        } else {
            return null
        }
    }

}