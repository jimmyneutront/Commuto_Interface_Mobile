//
//  StablecoinResolver.swift
//  iosApp
//
//  Created by jimmyt on 7/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 A structure that provides currency code and name information about a stablecoin, given its contract address and chain ID.
 */
struct StablecoinInformationRepository {
    
    /**
     Nested dictionaries containing stablecoin information. The inner dictionary maps `EthereumAddress`es of stablecoin smart contracts to `StablecoinInformation` structs containing information about the stablecoin corresponding to their `EthereumAddress` key. The outer dictionary maps blockchain IDs to `[EthereumAddress:StablecoinInformation]`s, containingch information about all the supported stablecoin contracts on the blockchain with the specified ID.
     */
    let stablecoinInformation: [BigUInt:[EthereumAddress:StablecoinInformation]]
    
    /**
     Returns a `StablecoinInformation` for the stablecoin at the specified `contractAddress` on the blockchain with the specified `chainID`, or `nil` if no such `StablecoinInformation` is found.
     
     - Parameters:
        - chainID: The ID of the blockchain on which the stablecoin for which to get information exists.
        - contractAddress: The contract address of the stablecoin for which to get information.
     
     - Returns: A `StablecoinInformation` for the stablecoin with the specified `chainID` and `contractAddress`, or `nil` if no such `StablecoinInformation` is found.
     */
    func getStablecoinInformation(chainID: BigUInt, contractAddress: EthereumAddress?) -> StablecoinInformation? {
        if contractAddress != nil {
            return stablecoinInformation[chainID]?[contractAddress ?? EthereumAddress("0x0000000000000000000000000000000000000000")!]
        } else {
            return nil
        }
        
    }
    
}

/**
 A structure containing information about a specific stablecoin.
 */
struct StablecoinInformation: Equatable {
    /**
     The stablecoin's currency code, such as "DAI" or "LUSD".
     */
    let currencyCode: String
    /**
     The stablecoin's name, such as "Liquity USD" or "USD Coin".
     */
    let name: String
    /**
     The number of token base units that make up one token unit. For example, DAI has a decimal value of 18, so one US Dollar = 10^18 DAI token base units. So when we display a DAI value to the user, we display the number of DAI token base units divided by 10^18.
     */
    let decimal: Int
}

extension StablecoinInformationRepository {
    /**
     A sample `StablecoinInformationRepository` for testing purposes, which contains `StablecoinInformation` structs for several stablecoin contracts on the Ethereum Mainnet.
     */
    static let ethereumMainnetStablecoinInfoRepo = StablecoinInformationRepository(
        stablecoinInformation: [
            // Ethereum Mainnet blockchain ID
            BigUInt(1): [
                EthereumAddress("0x6B175474E89094C44Da98b954EedeAC495271d0F")!: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
                EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!: StablecoinInformation(currencyCode: "USDC", name: "USD Coin", decimal: 6),
                EthereumAddress("0x4Fabb145d64652a948d72533023f6E7A623C7C53")!: StablecoinInformation(currencyCode: "BUSD", name: "Binance USD", decimal: 18),
                EthereumAddress("0xdAC17F958D2ee523a2206206994597C13D831ec7")!: StablecoinInformation(currencyCode: "USDT", name: "USD Tether", decimal: 6),
            ]
        ]
    )
    
    /**
     A simple `StablecoinInformationRepository` for testing purposes, which contains `StablecoinInformation` structs for several stablecoin contracts on a hardhat test networks set up by [CommuttoSwapTest.py](https://github.com/jimmyneutront/commuto-protocol/blob/main/tests/CommutoSwapTest.py).
     */
    static let hardhatStablecoinInfoRepo = StablecoinInformationRepository(
        stablecoinInformation: [
            // Hardhat blockchain ID
            BigUInt(31337): [
                EthereumAddress("0x663F3ad617193148711d28f5334eE4Ed07016602")!: StablecoinInformation(currencyCode: "DAI", name: "Dai", decimal: 18),
                EthereumAddress("0x2E983A1Ba5e8b38AAAeC4B440B9dDcFBf72E15d1")!: StablecoinInformation(currencyCode: "USDC", name: "USD Coin", decimal: 6),
                EthereumAddress("0x8438Ad1C834623CfF278AB6829a248E37C2D7E3f")!: StablecoinInformation(currencyCode: "BUSD", name: "Binance USD", decimal: 18),
                EthereumAddress("0xBC9129Dc0487fc2E169941C75aABC539f208fb01")!: StablecoinInformation(currencyCode: "USDT", name: "USD Tether", decimal: 6),
            ]
        ]
    )
}
