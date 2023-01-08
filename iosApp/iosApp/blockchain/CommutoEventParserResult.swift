//
//  CommutoEventParserResult.swift
//  iosApp
//
//  Created by jimmyt on 1/5/23.
//  Copyright © 2023 orgName. All rights reserved.
//

import web3swift

/**
 An implementation of web3swift's `EventParserResultProtocol`, created because web3swift's `EventParserResult` has no public constructors.
 */
struct CommutoEventParserResult: EventParserResultProtocol {
    /**
     The name of the event that this represents.
     */
    var eventName: String
    /**
     The receipt of the transaction in which this event was emitted.
     */
    var transactionReceipt: TransactionReceipt?
    /**
     The address of the contract that emitted this event.
     */
    var contractAddress: EthereumAddress
    /**
     The decoded results containing the data of this event.
     */
    var decodedResult: [String: Any]
    /**
     The event log from which `decodedResult` should have been created.
     */
    var eventLog: EventLog? = nil
}
