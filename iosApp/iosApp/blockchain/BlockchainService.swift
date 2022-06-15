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
    
    init(errorHandler: BlockchainErrorNotifiable, offerService: OfferNotifiable, web3Instance: web3, commutoSwapAddress: String) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        w3 = web3Instance
        commutoSwap = CommutoSwapProvider.provideCommutoSwap(web3Instance: web3Instance, commutoSwapAddress: commutoSwapAddress)
    }
    
    private let errorHandler: BlockchainErrorNotifiable
    
    private let offerService: OfferNotifiable
    
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
    
    // Boolean that controls the listen loop
    private var runLoop = true
    
    // Web3Swift web3 instance
    private var w3: web3
    
    // Commuto Swap contract instance
    private let commutoSwap: web3.web3contract
    
    func listen() {
        listenThread = Thread { [self] in
            runLoop = true
            listenLoop()
        }
        listenThread!.start()
    }
    
    func stopListening() {
        runLoop = false
        listenThread?.cancel()
    }
    
    func listenLoop() {
        while (runLoop) {
            do {
                newestBlockNum = UInt64(try getNewestBlockNumberPromise().wait())
                if newestBlockNum > lastParsedBlockNum {
                    let blockToParseNumber = lastParsedBlockNum + UInt64(1)
                    let block = try getBlockPromise(blockToParseNumber).wait()
                    try parseBlock(block)
                    setLastParsedBlockNumber(blockToParseNumber)
                } else {
                    sleep(listenInterval)
                }
            } catch {
                errorHandler.handleBlockchainError(error)
                if (error as NSError).domain == "NSURLErrorDomain" {
                    stopListening()
                } else {
                    switch error {
                    case Web3Error.connectionError:
                        stopListening()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func getNewestBlockNumberPromise() -> Promise<BigUInt> {
        return w3.eth.getBlockNumberPromise()
    }
    
    private func getBlockPromise(_ blockNumber: UInt64) -> Promise<Block> {
        return w3.eth.getBlockByNumberPromise(blockNumber)
    }
    
    private func parseBlock(_ block: Block) throws {
        var events: [EventParserResultProtocol] = []
        let eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: nil)
        guard let offerOpenedEventParser = commutoSwap.createEventParser("OfferOpened", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferOpened event parser")
        }
        guard let offerCanceledEventParser = commutoSwap.createEventParser("OfferCanceled", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferCanceled event parser")
        }
        guard let offerTakenEventParser = commutoSwap.createEventParser("OfferTaken", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferTaken event parser")
        }
        events.append(contentsOf: try offerOpenedEventParser.parseBlock(block))
        events.append(contentsOf: try offerCanceledEventParser.parseBlock(block))
        events.append(contentsOf: try offerTakenEventParser.parseBlock(block))
        try handleEvents(events)
    }
    
    private func handleEvents(_ results: [EventParserResultProtocol]) throws {
        for result in results {
            if result.eventName == "OfferOpened" {
                guard let event = OfferOpenedEvent(result) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferOpened event from EventParserResultProtocol")
                }
                offerService.handleOfferOpenedEvent(event)
            } else if result.eventName == "OfferCanceled" {
                guard let event = OfferCanceledEvent(result) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferCanceled event from EventParserResultProtocol")
                }
                offerService.handleOfferCanceledEvent(event)
            } else if result.eventName == "OfferTaken" {
                guard let event = OfferTakenEvent(result) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferTaken event from EventParserResultProtocol")
                }
                offerService.handleOfferTakenEvent(event)
            }
        }
    }
    
}
