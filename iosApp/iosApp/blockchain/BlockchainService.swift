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
        - errorHandler: An object that adopts the `BlockchainErrorNotifiable` protocol, to which this will pass errors when they occur.
        - offerService: An object that adopts the `OfferNotifiable` protocol, to which this will pass offer-related events.
        - swapService: An object that adopts the `SwapNotifiable` protocol, to which this will pass swap-related events.
        - web3Instance: A web3swift `web3` instance that this will use to interact with the EVM-compatible blockchain.
        - commutoSwapAddress: The `EthereumAddress` of the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol)
     
     - Returns: A new `BlockchainService` instance.
     */
    init(errorHandler: BlockchainErrorNotifiable, offerService: OfferNotifiable, swapService: SwapNotifiable, web3Instance: web3, commutoSwapAddress: EthereumAddress) {
        self.errorHandler = errorHandler
        self.offerService = offerService
        self.swapService = swapService
        w3 = web3Instance
        self.commutoSwapAddress = commutoSwapAddress
        commutoSwap = CommutoSwapProvider.provideCommutoSwap(web3Instance: web3Instance, commutoSwapAddress: commutoSwapAddress)
        commutoSwapEthereumContract = CommutoSwapProvider.provideCommutoSwapEthereumContract(commutoSwapAddress: commutoSwapAddress)!
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
     An object to which `BlockchainService` will pass swap-related events when they occur.
     */
    private let swapService: SwapNotifiable
    
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
    private(set) var newestBlockNum = UInt64()
    
    /**
     A dictionary mapping transaction hashes to corresponding `BlockchainTransaction`s created by this interface that `BlockchainService` will monitor for confirmation, transaction dropping, transaction failure and transaction success.
     */
    private var transactionsToMonitor: [String: BlockchainTransaction] = [:]
    
    /**
     Maps the `BlockchainTransaction.transactionHash` property of `transaction` to `transaction` itself in `transactionsToMonitor`.
     
     - Parameter transaction: The `BlockchainTransaction` to be added to `transactionsToMonitor`.
     */
    func addTransactionToMonitor(transaction: BlockchainTransaction) {
        transactionsToMonitor[transaction.transactionHash] = transaction
    }
    
    func getMonitoredTransaction(transactionHash: String) -> BlockchainTransaction? {
        return transactionsToMonitor[transactionHash]
    }
    
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
     The blockchain address of the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract.
     */
    let commutoSwapAddress: EthereumAddress
    
    /**
     The web3swift `web3.contract` instance of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) that `BlockchainService` uses to parse transaction receipts for CommutoSwap events and interact with the CommutoSwap contract on chain.
     */
    private let commutoSwap: web3.web3contract
    
    /**
     An `EthereumContract` identical to that wrapped by `commutoSwap`. We need this because the `EthereumContract` wrapped by `commutoSwap` has the internal protection level, and we must call some of this struct's methods in the transaction creation pipeline.
     */
    private let commutoSwapEthereumContract: EthereumContract
    
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
     Stores `transaction` in `transactionsToMonitor`, and then sends the wrapped  `EthereumTransaction` to the blockchain node via a call to [eth_sendRawTransaction](https://ethereum.github.io/execution-apis/api-documentation/). If this call fails, then `transaction` is immediately removed from `transactionsToMonitor`.
     
     - Parameter transaction: The `BlockchainTransaction` to be monitored, wrapping an `EthereumTransaction` to be sent to the node as a raw transaction.
     
     - Returns: A `Promise` wrapped around a `TransactionSendingResult` decoded from the node's response.
     
     - Throws: A `BlockchainServiceError.unexpectedNilError` if the `BlockchainTransaction.transaction` property of `transaction` is `nil`. Because this function returns a `Promise`, error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func sendTransaction(_ transaction: BlockchainTransaction) -> Promise<TransactionSendingResult> {
        return Promise<TransactionSendingResult> { seal in
            guard let wrappedTransaction = transaction.transaction else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Wrapped transaction was nil for \(transaction.transactionHash)"))
                return
            }
            transactionsToMonitor[transaction.transactionHash] = transaction
            w3.eth.sendRawTransactionPromise(wrappedTransaction).done(on: DispatchQueue.global(qos: .userInitiated)) { transactionSendingResult in
                seal.fulfill(transactionSendingResult)
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.transactionsToMonitor[transaction.transactionHash] = nil
                seal.reject(error)
            }
        }
    }
    
    /**
     Nearly identical to `EthereumContract`'s `method` method, except this passes `type` to any `EthereumParameters` struct that it creates.
     
     - Parameters:
        - method: The name of the contract method to call.
        - parameters: The parameters that will be passed to the method specified by `method`.
        - extraData: Extra data that will be included in the transaction.
        - type: The type of the transaction to create.
        - contract: The contract containing the method that this transaction will call.
     
     - Returns: An optional `EthereumTransaction` of the specified `type` that calls the `method` method of `contract`, with the specified `parameters` and `extraData`.
     */
    func method(method: String = "fallback", parameters: [AnyObject], extraData: Data, type: TransactionType?, contract: EthereumContract) -> EthereumTransaction? {
        guard let to = contract.address else { return nil }
        if (method == "fallback") {
            let params = EthereumParameters(type: type, gasLimit: BigUInt(0), gasPrice: BigUInt(0))
            let transaction = EthereumTransaction(to: to, value: BigUInt(0), data: extraData, parameters: params)
            
            return transaction
        }
        let foundMethod = contract.methods.filter { (key, value) -> Bool in
            return key == method
        }
        guard foundMethod.count == 1 else { return nil }
        let abiMethod = foundMethod[method]
        guard let encodedData = abiMethod?.encodeParameters(parameters) else { return nil }
        let params = EthereumParameters(type: type, gasLimit: BigUInt(0), gasPrice: BigUInt(0))
        let transaction = EthereumTransaction(to: to, value: BigUInt(0), data: encodedData, parameters: params)
        return transaction
    }
    
    /**
     Nearly identical to `web3.web3contract`'s `write` method, except this passes the type in `transactionOptions` to the custom `method` implementation defined above.
     
     - Parameters:
        - method: The name of the contract method to call.
        - parameters: The parameters that will be passed to the method specified by `method`.
        - extraData: Extra data that will be included in the transaction.
        - transactionOptions: Options with which the transaction will be created.
        - contract: The contract containing the method that this transaction will call.
  
     - Returns: An optional `WriteTransaction` with the specified `transactionOptions` that calls the `method` method of `contract`, with the specified `parameters` and `extraData`.
     */
    func createWriteTransaction(method: String = "fallback", parameters: [AnyObject], extraData: Data, transactionOptions: TransactionOptions, contract: EthereumContract) -> WriteTransaction? {
        let mergedOptions = contract.transactionOptions?.merge(transactionOptions)
        guard var tx = self.method(method: method, parameters: parameters, extraData: extraData, type: transactionOptions.type, contract: contract) else { return nil }
        tx.chainID = self.w3.provider.network?.chainID
        let writeTX = WriteTransaction.init(transaction: tx, web3: self.w3, contract: contract, method: method, transactionOptions: mergedOptions)
        return writeTX
    }
    
    /**
     Signs the given transaction with the user's key.
     
     - Parameter transaction: The `EthereumTransaction` to be signed.
     */
    func signTransaction(_ transaction: inout EthereumTransaction) throws {
        guard let address = ethKeyStore.getAddress() else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Unexpectedly got nil while getting address to sign transaction")
        }
        try Web3Signer.signTX(transaction: &transaction, keystore: ethKeyStore, account: address, password: ethPassword)
    }
    
    /**
     A `Promise` wrapper around the [ERC20](https://eips.ethereum.org/EIPS/eip-20) `approve` function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
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
     A `Promise` wrapper around CommutoSwap's [cancelOffer]() function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameters:
        - offerID: The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be canceled.
     
     - Returns: An empty `Promise` that will be fulfilled when the offer is opened.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func cancelOffer(offerID: UUID) -> Promise<Void> {
        return Promise { seal in
            let method = "cancelOffer"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [offerID.asData()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating cancelOffer write transaction"))
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
     Creates and returns (wrapped in a `Promise`) an EIP1559 `EthereumTransaction` from the users account to call CommutoSwaps [cancelOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#cancel-offer) function, with estimated gas limit, max priority fee per gas, max fee per gas, and with a nonce determined from all currently known transactions, including those that are still pending.
     
     - Parameters:
        - offerID: The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be canceled.
        - chainID: The blockchain ID on which the offer to be canceled exists.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` as described above, that will cancel the offer specified by `offerID` on the chain specified by `chainID`.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if the user's address is nil, or if we get nil while creating the transaction. Since this function returns a `Promise`, these errors will not be thrown but rather passed to the seal rejection call.
     */
    func createCancelOfferTransaction(offerID: UUID, chainID: BigUInt) -> Promise<EthereumTransaction> {
        return Promise { seal in
            var options = TransactionOptions()
            options.type = .eip1559
            guard let address = ethKeyStore.getAddress() else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Unexpectedly got nil while getting user's address while creating cancelOffer transaction for \(offerID.uuidString)"))
                return
            }
            options.from = address
            options.maxPriorityFeePerGas = .automatic
            options.maxFeePerGas = .automatic
            options.nonce = .pending
            
            let writeTransaction = self.createWriteTransaction(method: "cancelOffer", parameters: [offerID.asData()] as [AnyObject], extraData: Data(), transactionOptions: options, contract: commutoSwapEthereumContract)
            guard let writeTransaction = writeTransaction else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Unexpectedly got nil while creating cancelOffer transaction for \(offerID.uuidString)"))
                return
            }
            var writeTransactionParameters = writeTransaction.transaction.parameters
            writeTransactionParameters.maxFeePerGas = Web3.Utils.parseToBigUInt("100.0", units: .eth)
            writeTransaction.transaction.parameters = writeTransactionParameters
            let ethereumTransaction = try writeTransaction.assemble()
            seal.fulfill(ethereumTransaction)
        }
    }
    
    /**
     A `Promise` wrapper around CommutoSwap's [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameters:
        - offerID: The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to be taken.
        - swapStruct: The SwapStruct containing the data of the new [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to be opened.
     
     - Returns: An empty `Promise` that will be fulfilled when the swap is taken.
     
     - Throws `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func takeOffer(offerID: UUID, swapStruct: SwapStruct) -> Promise<Void> {
        return Promise { seal in
            let method = "takeOffer"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [offerID.asData(), swapStruct.toSwapDataArray()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating takeOffer write transaction"))
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
     A `Promise` wrapper around CommutoSwap's [editOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameters:
        - offerID: The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) to be edited.
        - offerStruct: The `OfferStruct` to be passed to [editOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer).
     
     - Returns: An empty `Promise` that will be fulfilled when the offer is opened.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func editOffer(offerID: UUID, offerStruct: OfferStruct) -> Promise<Void> {
        return Promise { seal in
            let method = "editOffer"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [offerID.asData(), offerStruct.toOfferDataArray()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating editOffer write transaction"))
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
     A `Promise` wrapper around CommutoSwap's [getSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-swap) function, via web3swift.
     
     - Parameter id: The id of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to get from the blockchain.
     
     - Returns: The `SwapStruct` corresponding to `id`, or `nil` if no swap with an id equal to `id` exists.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if the chain ID is `nil`, if `nil` is returned during read transaction creation, or if `nil` is returned while getting swap data from the read transaction response.
     */
    func getSwap(id: UUID) throws -> SwapStruct? {
        let method = "getSwap"
        guard let chainID = w3.provider.network?.chainID else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil chain ID during getSwap call for \(id.uuidString)")
        }
        guard let readTransaction = commutoSwap.read(
            method,
            parameters: [id.asData()] as [AnyObject],
            transactionOptions: .defaultOptions
        ) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating getSwap read transaction for \(id.uuidString)")
        }
        let swapOnChain = try readTransaction.call()
        guard let swapData = swapOnChain["0"] as? [AnyObject] else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while getting offer data from getSwap read transaction response \(id.uuidString)")
        }
        return try SwapStruct.createFromGetSwapResponse(response: swapData, chainID: chainID)
    }
    
    /**
     A `Promise` wrapper around CommutoSwap's [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameter id: The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to be filled.
     
     - Returns: An empty `Promise` that will be fulfilled when the swap is opened.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func fillSwap(id: UUID) -> Promise<Void> {
        return Promise { seal in
            let method = "fillSwap"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [id.asData()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating fillSwap write transaction"))
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
     A `Promise` wrapper around CommutoSwap's [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#reportPaymentSent) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameter id: The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which to report sending payment.
     
     - Returns: An empty `Promise` that will be fulfilled when payment sending is successfully reported.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func reportPaymentSent(id: UUID) -> Promise<Void> {
        return Promise { seal in
            let method = "reportPaymentSent"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [id.asData()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating reportPaymentSent write transaction"))
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
     A `Promise` wrapper around CommutoSwap's [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameter id: The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which to report sending payment.
     
     - Returns: An empty `Promise` that will be fulfilled when receipt of payment is successfully reported.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func reportPaymentReceived(id: UUID) -> Promise<Void> {
        return Promise { seal in
            let method = "reportPaymentReceived"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [id.asData()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating reportPaymentSent write transaction"))
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
     A `Promise` wrapper around CommutoSwap's [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) function, via web3swift. Note that this temporarily uses a manual gas limit of 30,000,000 and a manual gas price of 30,000,000, and uses BlockchainService's temporary key store.
     
     - Parameter id: The ID of the [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) to close.
     
     - Returns: An empty `Promise` that will be fulfilled when the swap is successfully closed.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if `nil` is returned during write transaction creation.
     */
    func closeSwap(id: UUID) -> Promise<Void> {
        return Promise { seal in
            let method = "closeSwap"
            guard let writeTransaction = commutoSwap.write(
                method,
                parameters: [id.asData()] as [AnyObject],
                transactionOptions: .defaultOptions
            ) else {
                seal.reject(BlockchainServiceError.unexpectedNilError(desc: "Found nil while creating closeSwap write transaction"))
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
    
    #warning("TODO: Remove hacky TransactionReceipt EthereumBloomFilter decoding fix")
    /**
     Gets the current chain ID, and iterates through all transactions in `block`  in search of [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) events. If the hash of a transaction is present in `monitoredTransactions`, then we get the transaction. If it has failed, we notifiy the proper failure handler. If it has not failed, then we parse it for events and add the resulting events to a list that will contain all events emitted in this block. In either case, we then remove the transaction hash from `monitoredTransactions`. If the hash of a transaction is not present in `monitoredTransactions`, then we parse it for events and add the resulting events to the list that will contain all events emitted in this block. Then then calls `BlockchainService`'s `handleEvents(...)` function, passing said list of events and the current chain ID. (Specifically, the events are web3swift `EventParserResultProtocols`.)
     
     Currently, this requires a hacky web3swift fix in order to work. In [this commit](https://github.com/web3swift-team/web3swift/commit/aa076ba96bbfcac98b8821029d67d76bce67065f#), a bug was introduced that skips the decoding of log bloom filters when decoding a response from the [eth_getTransactionHash]() endpoint. This bug causes all returned `TransactionReceipt` objects to have nil `logBloom` properties, meaning that event decoding is completely broken. The hacky fix is re-adding log bloom decoding code to the `TransactionReceipt` constructor.
     
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
        guard let swapFilledEventParser = commutoSwap.createEventParser("SwapFilled", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping SwapFilled event parser")
        }
        guard let paymentSentEventParser = commutoSwap.createEventParser("PaymentSent", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping PaymentSent event parser")
        }
        guard let paymentReceivedEventParser = commutoSwap.createEventParser("PaymentReceived", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping PaymentReceived event parser")
        }
        guard let buyerClosedEventParser = commutoSwap.createEventParser("BuyerClosed", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping BuyerClosed event parser")
        }
        guard let sellerClosedEventParser = commutoSwap.createEventParser("SellerClosed", filter: eventFilter) else {
            throw BlockchainServiceError.unexpectedNilError(desc: "Found nil while unwrapping SellerClosed event parser")
        }
        for transactionIndex in block.transactions.indices {
            // Get the hash of this particular transaction in the block
            let transaction = block.transactions[transactionIndex]
            var optionalTransactionHash: Data? = nil
            switch transaction {
            case .hash(let data):
                optionalTransactionHash = data
            case .transaction(let ethereumTransaction):
                // This case should never occur, because this function should never be passed a block containing full transactions.
                optionalTransactionHash = ethereumTransaction.hash
            case .null:
                ()
            }
            guard let transactionHash = optionalTransactionHash else {
                logger.warning("parseBlock: got nil transaction hash for tx \(transactionIndex) in \(block.hash.toHexString())")
                continue
            }
            var transactionHashString = transactionHash.toHexString().lowercased()
            if !transactionHashString.hasPrefix("0x") {
                transactionHashString = "0x" + transactionHashString
            }
            if let monitoredTransaction = transactionsToMonitor[transactionHashString] {
                logger.notice("parseBlock: tx \(transactionHashString) is monitored, getting receipt")
                // This transaction is one we are monitoring, so we get the entire transaction (since we currently just have the hash)
                let fullTransaction = try w3.eth.getTransactionReceipt(transactionHash)
                if fullTransaction.status == .failed {
                    logger.warning("parseBlock: monitored tx \(transactionHashString) failed, calling failure handler")
                    switch monitoredTransaction.type {
                    case .cancelOffer:
                        try offerService.handleFailedTransaction(monitoredTransaction, error: BlockchainTransactionError.init(errorDescription: "Transaction \(transactionHashString) is confirmed, but failed for unknown reason."))
                    }
                } else {
                    logger.notice("parseBlock: parsing monitored tx \(transactionHashString) for events")
                    // The tranaction has not failed, so we parse it for the proper event
                    switch monitoredTransaction.type {
                    case .cancelOffer:
                        events.append(contentsOf: try offerCanceledEventParser.parseTransactionByHash(transactionHash))
                    }
                }
                logger.notice("parseBlock: removing \(transactionHashString) from transactionsToMonitor")
                // Remove monitored transaction now that it has been handled
                transactionsToMonitor[transactionHashString] = nil
            } else {
                logger.notice("parseBlock: tx \(transactionHashString) is not monitored, parsing for events")
                // We are not monitoring this transaction, so we parse it for all possible events.
                events.append(contentsOf: try offerOpenedEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try offerEditedEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try offerCanceledEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try offerTakenEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try serviceFeeRateChangedParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try swapFilledEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try paymentSentEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try paymentReceivedEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try buyerClosedEventParser.parseTransactionByHash(transactionHash))
                events.append(contentsOf: try sellerClosedEventParser.parseTransactionByHash(transactionHash))
            }
        }
        try handleEvents(events, chainID: chainID)
    }
    
    #warning("TODO: The logger.info calls here should be logger.notice")
    #warning("TODO: include transaction hash string in Event structs")
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
            } else if result.eventName == "SwapFilled" {
                guard let event = SwapFilledEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating SwapFilled event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling SwapFilled event")
                try swapService.handleSwapFilledEvent(event)
            } else if result.eventName == "PaymentSent" {
                guard let event = PaymentSentEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating PaymentSent event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling PaymentSent event")
                try swapService.handlePaymentSentEvent(event)
            } else if result.eventName == "PaymentReceived" {
                guard let event = PaymentReceivedEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating PaymentReceived event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling PaymentReceived event")
                try swapService.handlePaymentReceivedEvent(event)
            } else if result.eventName == "BuyerClosed" {
                guard let event = BuyerClosedEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating BuyerClosed event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling BuyerClosed event")
                try swapService.handleBuyerClosedEvent(event)
            } else if result.eventName == "SellerClosed" {
                guard let event = SellerClosedEvent(result, chainID: chainID) else {
                    throw BlockchainServiceError.unexpectedNilError(desc: "Got nil while creating SellerClosed event from EventParserResultProtocol")
                }
                logger.info("handleEvents: handling SellerClosed event")
                try swapService.handleSellerClosedEvent(event)
            }
        }
    }
    
}
