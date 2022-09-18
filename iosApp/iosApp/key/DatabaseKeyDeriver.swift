//
//  DatabaseKeyDeriver.swift
//  iosApp
//
//  Created by jimmyt on 9/17/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import CryptoSwift
import Foundation

/**
 Derives a 32 byte `SymmetricKey` for AES encryption/decryption from a given password `String` and salt `Data` using HKDF with SHA256.
 */
struct DatabaseKeyDeriver {
    
    /**
     The 32 byte `SymmetricKey` derived grom the given password `String` and salt `Data`.
     */
    let key: SymmetricKey
    
    /**
     Derives a 32 byte `SymmetricKey` from `password` and `salt`, and assigns the result to `key`.
     */
    init(password: String, salt: Data) throws {
        key = SymmetricKey(key: try HKDF(password: Array(password.utf8), salt: salt.bytes, keyLength: 32, variant: .sha2(.sha256)).calculate())
    }
    
}
