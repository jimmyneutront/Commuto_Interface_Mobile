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

/**
 The main Blockchain Service. It is responsible for listening to the blockchain and detecting the emission of events by parsing transaction receipts, and then passing relevant detected events to other services as necessary.
 */
class BlockchainService {
    
    /**
     Initializes a new BlockchainService object.
     
     - Parameters:
        - errorHandler: An object that conforms to the `BlockchainErrorNotifiable` protocol, to which this will pass errors when they occur.
        - offerService: An object that comforms to the `OfferMessageNotifiable` protocol, to which this will pass offer-related events.
        - web3Instance: A web3swift `web3` instance that this will use to interact with the EVM-compatible blockchain.
        - commutoSwapAddress: A `String` containing the address of the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/cca886f724d9069069330b74e7653b781860bff8/CommutoSwap.sol)
     
     - Returns: A new `BlockchainService` instance.
     */
    init(errorHandler: BlockchainErrorNotifiable, offerService: OfferNotifiable, web3Instance: web3, commutoSwapAddress: String) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        w3 = web3Instance
        commutoSwap = CommutoSwapProvider.provideCommutoSwap(web3Instance: web3Instance, commutoSwapAddress: commutoSwapAddress)
    }
    
    /**
     An object to which `BlockchainService` will pass errors when they occur.
     */
    private let errorHandler: BlockchainErrorNotifiable
    
    /**
     An object to which `BlockchainService` will pass offer-related events when they occur.
     */
    private let offerService: OfferNotifiable
    
    /**
     The block number of the most recently parsed block.
     */
    private var lastParsedBlockNum = UInt64(0)
    
    /**
     Updates `lastParsedBlockNum`. Evantually, this function will store `blockNumber` in persistent storage.
     
     - Parameter blockNumber: The block number of the block that has been most recently parsed by `BlockchainService`, to be set as `lastParsedBlockNum`.
     */
    private func setLastParsedBlockNumber(_ blockNumber: UInt64) {
        lastParsedBlockNum = blockNumber
    }
    
    /**
     The number of the most recently confirmed block.
     */
    private var newestBlockNum = UInt64()
    
    /**
     The number of seconds that `BlockchainService` should wait after parsing a block before it begins parsing another block.
     */
    private var listenInterval: UInt32 = 1
    
    // The thread in which BlockchainService listens to the blockchain
    /**
     The `Thread` in which `BlockchainService` listens for new blocks and parses the transaction receipts that they contain.
     */
    private var listenThread: Thread?
    
    /**
     Boolean that indicates whether `listenLoop()` should continue to execute its loop.
     */
    private var runLoop = true
    
    /**
     The web3swift `web3` instance that `BlockchainService` uses to interact with the EVM-compatible blockchain.
     */
    private var w3: web3
    
    // Commuto Swap contract instance
    /**
     The web3swift `web3.contract` instance of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) that `BlockchainService` uses to parse transaction receipts for CommutoSwap events and interact with the CommutoSwap contract on chain.
     */
    private let commutoSwap: web3.web3contract
    
    /**
     Creates a new `Thread` to run `listenLoop()`,  updates `listenThread` with a reference to the new `Thread`, and starts it.
     */
    func listen() {
        listenThread = Thread { [self] in
            runLoop = true
            listenLoop()
        }
        listenThread!.start()
    }
    
    /**
     Sets `runLoop` from false to prevent the listen loop from being executed again and cancels `listenThread`.
     */
    func stopListening() {
        runLoop = false
        listenThread?.cancel()
    }
    
    /**
     Executes the listening process in the current thread as long as `runLoop` is true.
     
     Listening Process:
     
     First, we get the newest block number, the number of the most recently confirmed block. Then we compare this to the number of the most recently parsed block. If the newest block number is greater than that of the most recently parsed block, then there exists at least one new block that we must parse. If the newest block number is not greater than the last parsed block number, then we don't have a new block to parse.
     
     If we do have at least one new block to parse, we get the block with a block number one greater than that of the last parsed block. Then we parse this new block, and then set the last parsed block number as the block number of this newly parsed block.
     
     If we encounter an `Error`, we pass it to our `errorHandler`. Additionally, if the domain of the `Error` (once cast as an `NSError`) is  "NSURLErrorDomain", indicating that we are having problems communicating with a network node, then we stop listening. We also stop listening if our error is a `Web3Error.connectionError`, since this also indicates we are having problems communicating with a network node.
     */
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
    
    /**
     A `Promise` wrapper around `web3swift`'s  `w3.eth.getBlockNumberPromise()` function.
     
     - Returns: A `Promise<BigUInt>`,  in which `BigUInt` is the block number of the most recently confirmed block.
     */
    private func getNewestBlockNumberPromise() -> Promise<BigUInt> {
        return w3.eth.getBlockNumberPromise()
    }
    
    /**
     A `Promise` wrapper around `web3swift`'s `w3.eth.getBlockByNumberPromise()` function.
     
     - Note: Blocks returned by this function do not contain complete transactions, they contain transaction hashes instead.
     
     - Parameter blockNumber: The block number of the block to be returned.
     
     - Returns: A `Promise<Block>`, in which `Block` is the web3swift `Block` object with the specified block number.
     */
    private func getBlockPromise(_ blockNumber: UInt64) -> Promise<Block> {
        return w3.eth.getBlockByNumberPromise(blockNumber)
    }
    
    
    /**
     Parses the given `Block` in search of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/cca886f724d9069069330b74e7653b781860bff8/CommutoSwap.sol) events, creates a list of all such events that it finds, and then calls `BlockchainService`'s `handleEvents(...)` function, passing said list of events. (Specifically, the events are web3swift `EventParserResultProtocols`.)
     
     - Note: In order to parse a block, the `EventParserProtocol`s created in this function must query a network node for full transaction receipts.
     
     - Parameter block: The `Block` to be parsed.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `commutoSwap`'s `createEventParser(...)` function returns nil.
     */
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
    
    /**
     Iterates through `results` in search of relevant `EventParserResultProtocol`s, attempts to create event objects from said relevant `EventParserResultProtocol`s, and passes resulting event objects to the proper service.
     
     - Parameter results: An array of `EventParserResultProtocol`s created by `parseBlock(...)`, which contain relevant events about which other services must be notified.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if we attempt to create an event from an `EventParserResultProtocol` with corresponding event names, but get nil instead.
     */
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
