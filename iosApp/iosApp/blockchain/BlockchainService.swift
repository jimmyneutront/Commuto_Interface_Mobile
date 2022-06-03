//
//  BlockchainService.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import PromiseKit
import web3swift

class BlockchainService {
    
    init(offerService: OfferService) {
        self.offerService = offerService
        let web3Instance = web3(provider: Web3HttpProvider(URL(string: "http://192.168.1.13:8545")!)!)
        w3 = web3Instance
        commutoSwap = CommutoSwapProvider.provideCommutoSwap(web3Instance: web3Instance)
    }
    
    private let offerService: OfferService
    
    // The number of the last parsed block
    private var lastParsedBlockNum = UInt64(0)
    
    private func setLastParsedBlockNumber(_ blockNumber: UInt64) {
        lastParsedBlockNum = blockNumber
    }
    
    // The number of the newest block
    private var newestBlockNum = UInt64()
    
    // The number of seconds that BlockchainService should wait after parsing a block
    private var listenInterval: UInt32 = 1
    
    // The thread in which BlockchainService listens to the blockchain
    private var listenThread: Thread?
    
    // Web3Swift web3 instance
    private var w3: web3
    
    // Commuto Swap contract instance
    private let commutoSwap: web3.web3contract
    
    func listen() {
        listenThread = Thread { [self] in
            listenLoop()
        }
    }
    
    func stopListening() {
        listenThread?.cancel()
    }
    
    func listenLoop() {
        while (true) {
            newestBlockNum = UInt64(try! getNewestBlockNumberPromise().wait())
            if newestBlockNum > lastParsedBlockNum {
                let blockToParseNumber = lastParsedBlockNum + UInt64(1)
                let block = try! getBlockPromise(blockToParseNumber).wait()
                parseBlock(block)
                setLastParsedBlockNumber(blockToParseNumber)
            } else {
                sleep(listenInterval)
            }

        }
    }
    
    private func getNewestBlockNumberPromise() -> Promise<BigUInt> {
        return w3.eth.getBlockNumberPromise()
    }
    
    private func getBlockPromise(_ blockNumber: UInt64) -> Promise<Block> {
        return w3.eth.getBlockByNumberPromise(blockNumber)
    }
    
    private func parseBlock(_ block: Block) {
        var events: [EventParserResultProtocol] = []
        let eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: nil)
        let eventParser = commutoSwap.createEventParser("OfferOpened", filter: eventFilter)!
        events.append(contentsOf: try! eventParser.parseBlock(block))
        handleEvents(events)
    }
    
    private func handleEvents(_ results: [EventParserResultProtocol]) {
        for result in results {
            if result.eventName == "OfferOpened" {
                offerService.handleOfferOpenedEvent(OfferOpenedEvent(result))
            }
        }
    }
    
}
