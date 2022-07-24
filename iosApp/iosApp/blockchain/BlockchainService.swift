//
//  BlockchainService.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import os
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
        - commutoSwapAddress: A `String` containing the address of the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol)
     
     - Returns: A new `BlockchainService` instance.
     */
    init(errorHandler: BlockchainErrorNotifiable, offerService: OfferNotifiable, web3Instance: web3, commutoSwapAddress: String) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        w3 = web3Instance
        commutoSwap = CommutoSwapProvider.provideCommutoSwap(web3Instance: web3Instance, commutoSwapAddress: commutoSwapAddress)
        
        #warning("TODO: we temporarily create a wallet here until WalletService is implemented.")
        let ethPassword = "web3swift"
        let ethPrivateKey = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
        let ethFormattedPrivateKey = ethPrivateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let ethPrivateKeyData = Data.fromHex(ethFormattedPrivateKey)!
        let ethKeyStore = try! EthereumKeystoreV3(privateKey: ethPrivateKeyData, password: ethPassword)!
        let ethKeyStoreManager = KeystoreManager([ethKeyStore])
        w3.addKeystoreManager(ethKeyStoreManager)
        self.ethPassword = ethPassword
        self.ethKeyStore = ethKeyStore
        
    }
    
    #warning("TODO: This is temporary, will move to WalletService when it is implemented")
    let ethPassword: String
    let ethKeyStore: EthereumKeystoreV3
    
    /**
     BlockchainService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "BlockchainService")
    
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
    
    #warning("rename this as updateLastParsedBlockNumber")
    /**
     Updates `lastParsedBlockNum`. Eventually, this function will store `blockNumber` in persistent storage.
     
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
    private let w3: web3
    
    /**
     The web3swift `web3.contract` instance of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) that `BlockchainService` uses to parse transaction receipts for CommutoSwap events and interact with the CommutoSwap contract on chain.
     */
    private let commutoSwap: web3.web3contract
    
    /**
     Creates a new `Thread` to run `listenLoop()`,  updates `listenThread` with a reference to the new `Thread`, and starts it.
     */
    func listen() {
        logger.notice("Starting listen loop in new thread")
        listenThread = Thread { [self] in
            runLoop = true
            listenLoop()
        }
        listenThread!.start()
        logger.notice("Started listen loop in new thread")
    }
    
    /**
     Sets `runLoop` from false to prevent the listen loop from being executed again and cancels `listenThread`.
     */
    func stopListening() {
        logger.notice("Stopping listen loop and canceling listen loop thread")
        runLoop = false
        listenThread?.cancel()
        logger.notice("Stopped listen loop and canceled listen loop thread")
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
                logger.notice("Beginning iteration of listen loop, last parsed block number: \(self.lastParsedBlockNum)")
                newestBlockNum = UInt64(try getNewestBlockNumberPromise().wait())
                if newestBlockNum > lastParsedBlockNum {
                    logger.notice("Newest block number \(self.newestBlockNum) > last parsed block number \(self.lastParsedBlockNum)")
                    let blockToParseNumber = lastParsedBlockNum + UInt64(1)
                    let block = try getBlockPromise(blockToParseNumber).wait()
                    logger.notice("Got block \(blockToParseNumber)")
                    try parseBlock(block)
                    logger.notice("Parsed block \(blockToParseNumber)")
                    setLastParsedBlockNumber(blockToParseNumber)
                    logger.notice("Updated last parsed block number as \(blockToParseNumber)")
                } else {
                    logger.notice("Newest block number \(self.newestBlockNum) <= last parsed block number \(self.lastParsedBlockNum), sleeping for \(self.listenInterval) sec")
                    sleep(listenInterval)
                }
            } catch {
                logger.error("Got an error during listen loop, calling error handler. Error: \(error.localizedDescription)")
                errorHandler.handleBlockchainError(error)
                if (error as NSError).domain == "NSURLErrorDomain" {
                    logger.error("Detected error with internet connection; stopping listen loop.")
                    // There is a problem with the internet connection, so there is no point in continuing to listen to the blockchain.
                    stopListening()
                } else {
                    switch error {
                    case Web3Error.connectionError:
                        logger.error("Caught Web3Error.connectionError; stopping listen loop.")
                        stopListening()
                    default:
                        break
                    }
                }
            }
            logger.notice("Completed iteration of listen loop")
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
     A `Promise` wrapper around CommutoSwap's [getOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-offer) function, via web3swift.
     
     - Parameter id: The id of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to get from the blockchain.
     
     - Returns: The `OfferStruct` corresponding to `id`, or `nil` if no offer with an id equal to `id` exists.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if the chain ID is `nil`, if `nil` is returned during read transaction creation, or if `nil` is returned while getting offer data from the read transaction response.
     */
    func getOffer(id: UUID) throws -> OfferStruct? {
        let method = "getOffer"
        guard let chainID = w3.provider.network?.chainID else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil chain ID during getOffer call")
        }
        guard let readTransaction = commutoSwap.read(
            method,
            parameters: [id.asData()] as [AnyObject],
            transactionOptions: .defaultOptions
        ) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating getOffer read transaction")
        }
        let offerOnChain = try readTransaction.call()
        guard let offerData = offerOnChain["0"] as? [AnyObject] else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while getting offer data from getOffer read transaction response")
        }
        return try OfferStruct.createFromGetOfferResponse(response: offerData, chainID: chainID)
    }
    
    /**
     A `Promise` wrapper around CommutoSwap's [getServiceFeeRate](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-service-fee-rate) function, via web3swift.
     
     - Returns: A `Promise` that will be fulfilled with the current service fee rate (which is a percentage times 100) as a `BigUInt`.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during read transaction creation or while getting data from the read transaction response. Note that because this function returns a `Promise` these errors aren't thrown, but instead they are passed to the call of `seal.reject`.
     */
    func getServiceFeeRate() -> Promise<BigUInt> {
        return Promise { seal in
            let method = "getServiceFeeRate"
            guard let readTransaction = commutoSwap.read(
                method,
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating getServiceFeeRate read transaction"))
                return
            }
            let readTransactionResponse = try readTransaction.call()
            guard let serviceFeeRate = readTransactionResponse["0"] as? BigUInt else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Got nil while getting service fee rate from getServiceFeeRate read transaction response"))
                return
            }
            seal.fulfill(serviceFeeRate)
        }
    }
    
    /**
     A `Promise` wrapper around the ERC20 (https://eips.ethereum.org/EIPS/eip-20) `approve` function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameters:
        - tokenAddress: The contract address of the stablecoin for which a transfer will be approved.
        - destinationAddress: The address to which a transfer will be approved.
        - amount: The transfer amount that will be approved.
     
     - Returns: An empty `Promise` that will be fulfilled when the token transfer is approved.
     
     - Throws `BlockchainServiceError.unexpectedNilError` if `nil` is returned during ERC20 contract creation, or if `nil` is returned during write transaction creation.
     */
    func approveTokenTransfer(tokenAddress: EthereumAddress, destinationAddress: EthereumAddress, amount: BigUInt) -> Promise<Void> {
        return Promise { seal in
            let method = "approve"
            guard let tokenContract = w3.contract(Web3.Utils.erc20ABI, at: tokenAddress, abiVersion: 2) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating token contract object"))
                return
            }
            guard let writeTransaction = tokenContract.write(
                method,
                parameters: [destinationAddress, amount] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating token transfer approval write transaction"))
                return
            }
            #warning("TODO: this is temporary, will be improved when WalletService is implemented")
            writeTransaction.transactionOptions.from = ethKeyStore.addresses!.first!
            writeTransaction.transactionOptions.gasLimit = .manual(BigUInt(30000000))
            writeTransaction.transactionOptions.gasPrice = .manual(BigUInt(30000000))
            writeTransaction.sendPromise(password: ethPassword).done { transactionSendingResult in
                seal.fulfill(())
            }.catch { error in
                seal.reject(error)
            }
        }
    }
    
    /**
     A `Promise` wrapper around CommutoSwap's [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameters:
        - offerID: The ID of the new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be opened.
        - offerStruct: The OfferStruct containing the data of the new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be opened.
     
     - Returns: An empty `Promise` that will be fulfilled when the offer is opened.
     
     - Throws `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func openOffer(offerID: UUID, offerStruct: OfferStruct) -> Promise<Void> {
        return Promise { seal in
            let method = "openOffer"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [offerID.asData(), offerStruct.toOfferDataArray()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating openOffer write transaction"))
                return
            }
            #warning("TODO: this is temporary, will be improved when WalletService is implemented")
            writeTransaction.transactionOptions.from = ethKeyStore.addresses!.first!
            writeTransaction.transactionOptions.gasLimit = .manual(BigUInt(30000000))
            writeTransaction.transactionOptions.gasPrice = .manual(BigUInt(30000000))
            writeTransaction.sendPromise(password: ethPassword).done { TransactionSendingResult in
                seal.fulfill_()
            }.catch { error in
                seal.reject(error)
            }
        }
    }
    
    /**
     Gets the current chain ID, parses the given `Block` in search of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) events, creates a list of all such events that it finds, and then calls `BlockchainService`'s `handleEvents(...)` function, passing said list of events and the currenc chain ID. (Specifically, the events are web3swift `EventParserResultProtocols`.)
     
     - Note: In order to parse a block, the `EventParserProtocol`s created in this function must query a network node for full transaction receipts.
     
     - Parameter block: The `Block` to be parsed.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if the chain ID is `nil` or `commutoSwap`'s `createEventParser(...)` function returns `nil`.
     */
    private func parseBlock(_ block: Block) throws {
        var events: [EventParserResultProtocol] = []
        let eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: nil)
        guard let chainID = w3.provider.network?.chainID else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil chain ID during parseBlock call")
        }
        guard let offerOpenedEventParser = commutoSwap.createEventParser("OfferOpened", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferOpened event parser")
        }
        guard let offerEditedEventParser = commutoSwap.createEventParser("OfferEdited", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferEdited event parser")
        }
        guard let offerCanceledEventParser = commutoSwap.createEventParser("OfferCanceled", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferCanceled event parser")
        }
        guard let offerTakenEventParser = commutoSwap.createEventParser("OfferTaken", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping OfferTaken event parser")
        }
        guard let serviceFeeRateChangedParser = commutoSwap.createEventParser("ServiceFeeRateChanged", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping ServiceFeeRateChanged event parser")
        }
        events.append(contentsOf: try offerOpenedEventParser.parseBlock(block))
        events.append(contentsOf: try offerEditedEventParser.parseBlock(block))
        events.append(contentsOf: try offerCanceledEventParser.parseBlock(block))
        events.append(contentsOf: try offerTakenEventParser.parseBlock(block))
        events.append(contentsOf: try serviceFeeRateChangedParser.parseBlock(block))
        try handleEvents(events, chainID: chainID)
    }
    
    #warning("TODO: The logger.info calls here should be logger.notice")
    /**
     Iterates through `results` in search of relevant `EventParserResultProtocol`s, attempts to create event objects from said relevant `EventParserResultProtocol`s, and passes resulting event objects to the proper service.
     
     - Parameter results: An array of `EventParserResultProtocol`s created by `parseBlock(...)`, which contain relevant events about which other services must be notified.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if we attempt to create an event from an `EventParserResultProtocol` with corresponding event names, but get nil instead.
     */
    private func handleEvents(_ results: [EventParserResultProtocol], chainID: BigUInt) throws {
        logger.info("handleEvents: handling \(results.count) events")
        for result in results {
            if result.eventName == "OfferOpened" {
                guard let event = OfferOpenedEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferOpened event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling OfferOpened event")
                try offerService.handleOfferOpenedEvent(event)
            } else if result.eventName == "OfferEdited" {
                guard let event = OfferEditedEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferEdited event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling OfferEdited event")
                try offerService.handleOfferEditedEvent(event)
            } else if result.eventName == "OfferCanceled" {
                guard let event = OfferCanceledEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferCanceled event from EventParserResultProtocol")
                }
                try offerService.handleOfferCanceledEvent(event)
                logger.info("handleEvents: handling OfferCanceled event")
            } else if result.eventName == "OfferTaken" {
                guard let event = OfferTakenEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating OfferTaken event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling OfferTaken event")
                try offerService.handleOfferTakenEvent(event)
            } else if result.eventName == "ServiceFeeRateChanged" {
                guard let event = ServiceFeeRateChangedEvent(result) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating ServiceFeeRateChanged event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling ServiceFeeRateChanged event")
                try offerService.handleServiceFeeRateChangedEvent(event)
            }
        }
    }
    
}
