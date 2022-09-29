//
//  PrivateSEPAData.swift
//  iosApp
//
//  Created by jimmyt on 9/28/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Private data for a SEPA settlement method, corresponding to a bank account that can receive SEPA transfers.
 */
struct PrivateSEPAData: Codable {
    /**
     The legal name of the holder of the bank account.
     */
    let accountHolder: String
    /**
     The Business Identifier Code identifying the bank in which the account exists.
     */
    let bic: String
    /**
     The International Bank Account Number of the account.
     */
    let iban: String
    /**
     The address associated with the account.
     */
    let address: String
}
