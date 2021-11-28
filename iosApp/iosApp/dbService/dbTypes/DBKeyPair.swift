//
//  DBKeyPair.swift
//  iosApp
//
//  Created by James Telzrow on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation

public class DBKeyPair: Equatable {
    
    let interfaceId: String
    let publicKey: String
    let privateKey: String
    
    public init(interfaceId: String, publicKey: String, privateKey: String) {
        self.interfaceId = interfaceId
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
    
    public static func == (lhs: DBKeyPair, rhs: DBKeyPair) -> Bool {
        return
            lhs.interfaceId == rhs.interfaceId &&
            lhs.publicKey == rhs.publicKey &&
            lhs.privateKey == rhs.privateKey
    }
}
