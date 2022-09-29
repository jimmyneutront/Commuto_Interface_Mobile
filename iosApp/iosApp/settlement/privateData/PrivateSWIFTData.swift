//
//  PrivateSWIFTData.swift
//  iosApp
//
//  Created by jimmyt on 9/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Private data for a SWIFT settlement method, corresponding to a bank account that can receive SWIFT transfers.
 */
struct PrivateSWIFTData: Codable {
    /**
     The legal name of the holder of the bank account.
     */
    let accountHolder: String
    /**
     The SWIFT code or Business Identifier Code identifying the bank in which the account exists.
     */
    let bic: String
    /**
     The number of the account.
     */
    let accountNumber: String
}
