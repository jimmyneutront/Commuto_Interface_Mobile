//
//  DBPublicKey.swift
//  iosApp
//
//  Created by James Telzrow on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation

public class DBPublicKey: Equatable {
    
    let interfaceId: String
    let publicKey: String
    
    public init(interfaceId: String, publicKey: String) {
        self.interfaceId = interfaceId
        self.publicKey = publicKey
    }
    
    public static func == (lhs: DBPublicKey, rhs: DBPublicKey) -> Bool {
        return
            lhs.interfaceId == rhs.interfaceId &&
            lhs.publicKey == rhs.publicKey
    }
}
