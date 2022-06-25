//
//  DatabasePublicKey.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

/**
 Contains the Interface ID as Base64 `String` encoded bytes and public key in PKCS#1 Base64 `String` encoded raw bytes of a `KeyPair`. This class exists only to assist in the storage and retrieval of public keys from a database, and therefore `DatabasePublicKey` should never be used for any cryptography operations.
 
 - Properties:
    - interfaceId: The Interfaec ID of this public Key, as Base64 `String` encoded bytes.
    - publicKey: The public key in PKCS#1 Base64 `String` encoded bytes.
 */
public class DatabasePublicKey: Equatable {
    
    let interfaceId: String
    let publicKey: String
    
    /**
     Creates a new `DatabasePublicKey`.
     
     - Parameters:
        - interfaceId: The interface ID of the public key to be created, as Base64 `String` encoded bytes.
        - publicKey: The public key to be created, as PKCS#1 Base64 `String` encoded bytes.
     */
    public init(interfaceId: String, publicKey: String) {
        self.interfaceId = interfaceId
        self.publicKey = publicKey
    }
    
    /**
     Compares two `DatabasePublicKey`s for equality. Two `DatabasePublicKey`s are defined as equal if their `interfaceId` and `publicKey` properties (which are `String`s) are equal.
     
     - Parameters:
        - lhs: The `DatabasePublicKey` on the left side of the equality operator.
        - rhs: The `DatabasePublicKey` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    public static func == (lhs: DatabasePublicKey, rhs: DatabasePublicKey) -> Bool {
        return
            lhs.interfaceId == rhs.interfaceId &&
            lhs.publicKey == rhs.publicKey
    }
}
