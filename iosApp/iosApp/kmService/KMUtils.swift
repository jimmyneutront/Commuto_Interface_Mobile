//
//  KMUtils.swift
//  iosApp
//
//  Created by James Telzrow on 11/26/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation

func encryptWithPublicKey(pubKey: SecKey, clearData: Data) throws -> Data? {
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
    var error: Unmanaged<CFError>?
    guard let cipherData = SecKeyCreateEncryptedData(pubKey, algorithm, clearData as CFData, &error) as Data? else {
        throw error!.takeRetainedValue() as Error
    }
    return cipherData
}

func decryptWithPrivateKey(privKey: SecKey, cipherData: Data) throws -> Data? {
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
    var error: Unmanaged<CFError>?
    guard let clearData = SecKeyCreateDecryptedData(privKey, algorithm, cipherData as CFData, &error) as Data? else {
        throw error!.takeRetainedValue() as Error
    }
    return clearData
}
