//
//  DBKeyPair.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

/**
 Contains the interface ID as Base64 `String` encoded bytes, public key and private key, both in PKCS#1 raw byte format encoded as Base64 `String`s, of a `KeyPair`. This class exists only to assist in the storage and retrieval of key pairs from a database, and therefore `DBKeyPair`s should never be used for any cryptography operations.
 
 - Properties:
    - interfaceId: The interface ID of this key pair, as Base64 `String` encoded bytes.
    - publicKey: The public key of this key pair, in PKCS#1 Base64 `String` encoded bytes.
    - privateKey: The private key of this key pair, in PKCS#1 Base64 `String` encoded bytes.
 */
public class DBKeyPair: Equatable {
    
    let interfaceId: String
    let publicKey: String
    let privateKey: String
    
    /**
     Creates a new `DBKeyPair`.
     
     - Parameters:
        - interfaceId: The interface ID of the key pair to be created, as Base64 `String` encoded bytes.
        - publicKey: The public key of the key pair to be created, as PKCS#1 Base64 `String` encoded bytes.
        - privateKey: The private key of the key pair to be created, as PKCS#1 Base64 `String` encoded bytes.
     */
    public init(interfaceId: String, publicKey: String, privateKey: String) {
        self.interfaceId = interfaceId
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
    
    /**
    Compares two `DBKeyPair`s for equality. Two `DBKeyPair`s are defined as equal if their `interfaceId`, `publicKey` and `privateKey` properties (which are `String`s) are equal.
     
     - Parameters:
        - lhs: The `DBKeyPair` on the left side of the equality operator.
        - rhs: The `DBKeyPair` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    public static func == (lhs: DBKeyPair, rhs: DBKeyPair) -> Bool {
        return
            lhs.interfaceId == rhs.interfaceId &&
            lhs.publicKey == rhs.publicKey &&
            lhs.privateKey == rhs.privateKey
    }
}
