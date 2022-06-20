//
//  DBPublicKey.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

/**
 Contains the Interface ID as Base64 `String` encoded bytes and public key in PKCS#1 Base64 `String` encoded raw bytes of a `KeyPair`. This class exists only to assist in the storage and retrieval of public keys from a database, and therefore `DBPublicKey` should never be used for any cryptography operations.
 
 - Properties:
    - interfaceId: The Interfaec ID of this public Key, as Base64 `String` encoded bytes.
    - publicKey: The public key in PKCS#1 Base64 `String` encoded bytes.
 */
public class DBPublicKey: Equatable {
    
    let interfaceId: String
    let publicKey: String
    
    /**
     Creates a new `DBPublicKey`.
     
     - Parameters:
        - interfaceId: The interface ID of the public key to be created, as Base64 `String` encoded bytes.
        - publicKey: The public key to be created, as PKCS#1 Base64 `String` encoded bytes.
     */
    public init(interfaceId: String, publicKey: String) {
        self.interfaceId = interfaceId
        self.publicKey = publicKey
    }
    
    /**
     Compares two `DBPublicKey`s for equality. Two `DBPublicKey`s are defined as equal if their `interfaceId` and `publicKey` properties (which are `String`s) are equal.
     
     - Parameters:
        - lhs: The `DBKeyPair` on the left side of the equality operator.
        - rhs: The `DBKeyPair` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    public static func == (lhs: DBPublicKey, rhs: DBPublicKey) -> Bool {
        return
            lhs.interfaceId == rhs.interfaceId &&
            lhs.publicKey == rhs.publicKey
    }
}
