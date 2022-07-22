//
//  ServiceFeeRateChanged.swift
//  iosApp
//
//  Created by jimmyt on 7/20/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 This class represents a [ServiceFeeRateChanged](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#servicefeeratechanged) event, emitted by the CommutoSwap smart contract when the service fee rate is changed.
 */
class ServiceFeeRateChangedEvent {
    /**
     The new service fee rate, as a percentage times 100.
     */
    let newServiceFeeRate: BigUInt
    
    /**
     Creates a new `ServiceFeeRateChangedEvent` given a web3swift `EventParserResultProtocol` containing information from a [ServiceFeeRateChanged](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#servicefeeratechanged) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from a ServiceFeeRateChanged event.
     
     - Parameters:
        - result: A web3swift `EventParserResultProtocol`, from which this attempts to create a `ServiceFeeRateChanged` event.
     */
    init?(_ result: EventParserResultProtocol) {
        guard let newServiceFeeRate = result.decodedResult["newServiceFeeRate"] as? BigUInt else {
            return nil
        }
        self.newServiceFeeRate = newServiceFeeRate
    }
}
