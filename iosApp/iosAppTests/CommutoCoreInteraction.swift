//
//  CommutoCoreInteraction.swift
//  iosAppTests
//
//  Created by jimmyt on 12/5/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest

@testable import BigInt
@testable import iosApp
@testable import Pods_iosApp
@testable import PromiseKit
@testable import web3swift
import CryptoKit

class CommutoCoreInteraction: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testTransferEth() {
        //TODO: Check that account 2 actually ends up with 1 more eth than starts with
        //Restore Hardhat account #1
        let password_one = "web3swift"
        let key_one = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" // Some private key
        let formattedKey_one = key_one.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataKey_one = Data.fromHex(formattedKey_one)!
        let keystore_one = try! EthereumKeystoreV3(privateKey: dataKey_one, password: password_one)!
        let keyData_one = try! JSONEncoder().encode(keystore_one.keystoreParams)
        let address_one = keystore_one.addresses!.first!.address
        
        //Restore Hardhat account #2
        let password_two = "web3swift"
        let key_two = "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" // Some private key
        let formattedKey_two = key_two.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataKey_two = Data.fromHex(formattedKey_two)!
        let keystore_two = try! EthereumKeystoreV3(privateKey: dataKey_two, password: password_two)!
        let keyData_two = try! JSONEncoder().encode(keystore_two.keystoreParams)
        let address_two = keystore_two.addresses!.first!.address
        
        //Establish connection to Hardhat node
        let endpoint = "http://192.168.1.12:8545"
        let web3 = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
        let keystoreManager = KeystoreManager([keystore_one, keystore_two])
        web3.addKeystoreManager(keystoreManager)
        
        //Get initial balance of account #2
        let toAddress = EthereumAddress(address_two)!
        let initialBalance = try! web3.eth.getBalance(address: toAddress)
        
        //Transfer 1 ETH from account #1 to account #2
        let value: String = "1.0" // In Ether
        let walletAddress = EthereumAddress(address_one)!
        let contract = web3.contract(Web3.Utils.coldWalletABI, at: toAddress, abiVersion: 2)!
        let amount = Web3.Utils.parseToBigUInt(value, units: .eth)
        var options = TransactionOptions.defaultOptions
        options.value = amount
        options.from = walletAddress
        options.gasPrice = .manual(BigUInt(875000000))
        options.gasLimit = .manual(BigUInt(30000000))
        let tx = contract.write(
            "fallback",
            parameters: [AnyObject](),
            extraData: Data(),
            transactionOptions: options)!
        let password = "web3swift"
        let result = try! tx.send(password: password)
        
        //Get final balance of account #2 and check for proper amount
        let finalBalance = try! web3.eth.getBalance(address: toAddress)
        XCTAssertEqual(initialBalance + amount!, finalBalance)
    }
    
    func testGenerateEthAccount() {
        let password = "web3swift"
        let bitsOfEntropy = 128
        let mnemonics = try! BIP39.generateMnemonics(bitsOfEntropy: bitsOfEntropy, language: .english)!
        let keystore = try! BIP32Keystore(
            mnemonics: mnemonics,
            password: password,
            mnemonicsPassword: "",
            language: .english
        )!
        let address = keystore.addresses!.first!.address
        print("Public Address: " + address)
        print("Password: " + password)
        print("Mnemonics: " + mnemonics)
    }
    
    //Setup swap direction and participant role enums for testSwapProcess()
    enum SwapDirection {
        case buy
        case sell
    }
    
    enum ParticipantRole {
        case maker
        case taker
    }
    
    //TODO: Use non-blocking eth function calls
    func testSwapProcess() throws {
        //Specify swap direction and participant roles
        let direction = SwapDirection.sell
        let role = ParticipantRole.taker
        
        //Restore Hardhat account #1
        let password_one = "web3swift"
        let key_one = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" // Some private key
        let formattedKey_one = key_one.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataKey_one = Data.fromHex(formattedKey_one)!
        let keystore_one = try! EthereumKeystoreV3(privateKey: dataKey_one, password: password_one)!
        let keyData_one = try! JSONEncoder().encode(keystore_one.keystoreParams)
        let address_one = keystore_one.addresses!.first!.address
        
        //Establish connection to Ethereum node
        let endpoint = "http://192.168.1.12:8545"
        var web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
        let keystoreManager = KeystoreManager([keystore_one])
        web3Instance.addKeystoreManager(keystoreManager)
        let walletAddress = EthereumAddress(address_one)!
        
        //Setup CommutoSwap contract interface
        let commutoContractAddress = EthereumAddress("0x5FC8d32690cc91D4c39d9d3abcBD16989F875707")!
        let commutoSwapABI = #"[{"inputs": [{"internalType": "address", "name": "_serviceFeePool", "type": "address"}, {"internalType": "address", "name": "_daiAddress", "type": "address"}, {"internalType": "address", "name": "_usdcAddress", "type": "address"}, {"internalType": "address", "name": "_busdAddress", "type": "address"}, {"internalType": "address", "name": "_usdtAddress", "type": "address"}], "stateMutability": "nonpayable", "type": "constructor"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "BuyerClosed", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "offerID", "type": "bytes16"}], "name": "OfferCanceled", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "offerID", "type": "bytes16"}, {"indexed": false, "internalType": "bytes", "name": "interfaceId", "type": "bytes"}], "name": "OfferOpened", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "offerID", "type": "bytes16"}, {"indexed": false, "internalType": "bytes", "name": "takerInterfaceId", "type": "bytes"}], "name": "OfferTaken", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "PaymentReceived", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "PaymentSent", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "offerID", "type": "bytes16"}], "name": "PriceChanged", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "SellerClosed", "type": "event"}, {"anonymous": false, "inputs": [{"indexed": false, "internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "SwapFilled", "type": "event"}, {"inputs": [], "name": "busdAddress", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "offerID", "type": "bytes16"}], "name": "cancelOffer", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "closeSwap", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [], "name": "daiAddress", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "offerID", "type": "bytes16"}, {"components": [{"internalType": "bool", "name": "isCreated", "type": "bool"}, {"internalType": "bool", "name": "isTaken", "type": "bool"}, {"internalType": "address", "name": "maker", "type": "address"}, {"internalType": "bytes", "name": "interfaceId", "type": "bytes"}, {"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "uint256", "name": "amountLowerBound", "type": "uint256"}, {"internalType": "uint256", "name": "amountUpperBound", "type": "uint256"}, {"internalType": "uint256", "name": "securityDepositAmount", "type": "uint256"}, {"internalType": "enum CommutoSwap.SwapDirection", "name": "direction", "type": "uint8"}, {"internalType": "bytes", "name": "price", "type": "bytes"}, {"internalType": "bytes[]", "name": "settlementMethods", "type": "bytes[]"}, {"internalType": "uint256", "name": "protocolVersion", "type": "uint256"}], "internalType": "struct CommutoSwap.Offer", "name": "editedOffer", "type": "tuple"}, {"internalType": "bool", "name": "editPrice", "type": "bool"}, {"internalType": "bool", "name": "editSettlementMethods", "type": "bool"}], "name": "editOffer", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "fillSwap", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "offerID", "type": "bytes16"}], "name": "getOffer", "outputs": [{"components": [{"internalType": "bool", "name": "isCreated", "type": "bool"}, {"internalType": "bool", "name": "isTaken", "type": "bool"}, {"internalType": "address", "name": "maker", "type": "address"}, {"internalType": "bytes", "name": "interfaceId", "type": "bytes"}, {"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "uint256", "name": "amountLowerBound", "type": "uint256"}, {"internalType": "uint256", "name": "amountUpperBound", "type": "uint256"}, {"internalType": "uint256", "name": "securityDepositAmount", "type": "uint256"}, {"internalType": "enum CommutoSwap.SwapDirection", "name": "direction", "type": "uint8"}, {"internalType": "bytes", "name": "price", "type": "bytes"}, {"internalType": "bytes[]", "name": "settlementMethods", "type": "bytes[]"}, {"internalType": "uint256", "name": "protocolVersion", "type": "uint256"}], "internalType": "struct CommutoSwap.Offer", "name": "", "type": "tuple"}], "stateMutability": "view", "type": "function"}, {"inputs": [], "name": "getSupportedSettlementMethods", "outputs": [{"internalType": "bytes[]", "name": "", "type": "bytes[]"}], "stateMutability": "view", "type": "function"}, {"inputs": [], "name": "getSupportedStablecoins", "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "getSwap", "outputs": [{"components": [{"internalType": "bool", "name": "isCreated", "type": "bool"}, {"internalType": "bool", "name": "requiresFill", "type": "bool"}, {"internalType": "address", "name": "maker", "type": "address"}, {"internalType": "bytes", "name": "makerInterfaceId", "type": "bytes"}, {"internalType": "address", "name": "taker", "type": "address"}, {"internalType": "bytes", "name": "takerInterfaceId", "type": "bytes"}, {"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "uint256", "name": "amountLowerBound", "type": "uint256"}, {"internalType": "uint256", "name": "amountUpperBound", "type": "uint256"}, {"internalType": "uint256", "name": "securityDepositAmount", "type": "uint256"}, {"internalType": "uint256", "name": "takenSwapAmount", "type": "uint256"}, {"internalType": "uint256", "name": "serviceFeeAmount", "type": "uint256"}, {"internalType": "enum CommutoSwap.SwapDirection", "name": "direction", "type": "uint8"}, {"internalType": "bytes", "name": "price", "type": "bytes"}, {"internalType": "bytes", "name": "settlementMethod", "type": "bytes"}, {"internalType": "uint256", "name": "protocolVersion", "type": "uint256"}, {"internalType": "bool", "name": "isPaymentSent", "type": "bool"}, {"internalType": "bool", "name": "isPaymentReceived", "type": "bool"}, {"internalType": "bool", "name": "hasBuyerClosed", "type": "bool"}, {"internalType": "bool", "name": "hasSellerClosed", "type": "bool"}], "internalType": "struct CommutoSwap.Swap", "name": "", "type": "tuple"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "offerID", "type": "bytes16"}, {"components": [{"internalType": "bool", "name": "isCreated", "type": "bool"}, {"internalType": "bool", "name": "isTaken", "type": "bool"}, {"internalType": "address", "name": "maker", "type": "address"}, {"internalType": "bytes", "name": "interfaceId", "type": "bytes"}, {"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "uint256", "name": "amountLowerBound", "type": "uint256"}, {"internalType": "uint256", "name": "amountUpperBound", "type": "uint256"}, {"internalType": "uint256", "name": "securityDepositAmount", "type": "uint256"}, {"internalType": "enum CommutoSwap.SwapDirection", "name": "direction", "type": "uint8"}, {"internalType": "bytes", "name": "price", "type": "bytes"}, {"internalType": "bytes[]", "name": "settlementMethods", "type": "bytes[]"}, {"internalType": "uint256", "name": "protocolVersion", "type": "uint256"}], "internalType": "struct CommutoSwap.Offer", "name": "newOffer", "type": "tuple"}], "name": "openOffer", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [], "name": "owner", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}, {"inputs": [], "name": "protocolVersion", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "reportPaymentReceived", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "swapID", "type": "bytes16"}], "name": "reportPaymentSent", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [], "name": "serviceFeePool", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}, {"inputs": [{"internalType": "bytes", "name": "settlementMethod", "type": "bytes"}, {"internalType": "bool", "name": "support", "type": "bool"}], "name": "setSettlementMethodSupport", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "bool", "name": "support", "type": "bool"}], "name": "setStablecoinSupport", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [{"internalType": "bytes16", "name": "offerID", "type": "bytes16"}, {"components": [{"internalType": "bool", "name": "isCreated", "type": "bool"}, {"internalType": "bool", "name": "requiresFill", "type": "bool"}, {"internalType": "address", "name": "maker", "type": "address"}, {"internalType": "bytes", "name": "makerInterfaceId", "type": "bytes"}, {"internalType": "address", "name": "taker", "type": "address"}, {"internalType": "bytes", "name": "takerInterfaceId", "type": "bytes"}, {"internalType": "address", "name": "stablecoin", "type": "address"}, {"internalType": "uint256", "name": "amountLowerBound", "type": "uint256"}, {"internalType": "uint256", "name": "amountUpperBound", "type": "uint256"}, {"internalType": "uint256", "name": "securityDepositAmount", "type": "uint256"}, {"internalType": "uint256", "name": "takenSwapAmount", "type": "uint256"}, {"internalType": "uint256", "name": "serviceFeeAmount", "type": "uint256"}, {"internalType": "enum CommutoSwap.SwapDirection", "name": "direction", "type": "uint8"}, {"internalType": "bytes", "name": "price", "type": "bytes"}, {"internalType": "bytes", "name": "settlementMethod", "type": "bytes"}, {"internalType": "uint256", "name": "protocolVersion", "type": "uint256"}, {"internalType": "bool", "name": "isPaymentSent", "type": "bool"}, {"internalType": "bool", "name": "isPaymentReceived", "type": "bool"}, {"internalType": "bool", "name": "hasBuyerClosed", "type": "bool"}, {"internalType": "bool", "name": "hasSellerClosed", "type": "bool"}], "internalType": "struct CommutoSwap.Swap", "name": "newSwap", "type": "tuple"}], "name": "takeOffer", "outputs": [], "stateMutability": "nonpayable", "type": "function"}, {"inputs": [], "name": "usdcAddress", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}, {"inputs": [], "name": "usdtAddress", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "stateMutability": "view", "type": "function"}]"#
        let commutoSwapContract = web3Instance.contract(commutoSwapABI, at: commutoContractAddress, abiVersion: 2)!
        
        //Don't parse any blocks earlier than that with this block number looking for events emitted by Commuto, because there won't be any
        var lastParsedBlockNumber = BigUInt(0)//try! web3Instance.eth.getBlockNumber()
        
        //Setup dummy Dai contract interface
        let dummyDaiContractAddress = EthereumAddress("0x5FbDB2315678afecb367f032d93F642f64180aa3")!
        let dummyDaiContract = web3Instance.contract(Web3.Utils.erc20ABI, at: dummyDaiContractAddress, abiVersion: 2)!
        var options = TransactionOptions.defaultOptions
        options.from = walletAddress
        let gasPrice = BigUInt(875000000)
        let gasLimit = BigUInt(30000000)
        options.gasPrice = .manual(gasPrice)
        options.gasLimit = .manual(gasLimit)
        
        //Get initial Dai Balance
        var txHash: Data? = nil
        var method = "balanceOf"
        var readTx = dummyDaiContract.read(
            method,
            parameters: [walletAddress] as [AnyObject],
            transactionOptions: options
        )!
        let initialDaiBalance = try! readTx.call()["0"] as! BigUInt
        
        var value: BigUInt = 0
        var writeTx: WriteTransaction? = nil
        var promise: Promise<TransactionSendingResult>? = nil
        var offerIdArray: Data?
        var txReceipt: TransactionReceipt?
        var eventLog: EventLog?
        var eventFilter: EventFilter?
        var eventParser: EventParserProtocol?
        var swap: [String : Any]?
        
        if role == .maker {
            //Approve transfer to open offer
            method = "approve"
            value = 11
            writeTx = dummyDaiContract.write(
                method,
                parameters: [commutoContractAddress, value] as [AnyObject],
                extraData: Data(),
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var approvalTxConfirmed = false
            while !approvalTxConfirmed {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        approvalTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
            
            //Open swap Offer
            let offerIdUUID = UUID().uuid
            offerIdArray = Data(fromArray: [offerIdUUID.0, offerIdUUID.1, offerIdUUID.2, offerIdUUID.3, offerIdUUID.4, offerIdUUID.5, offerIdUUID.6, offerIdUUID.7, offerIdUUID.8, offerIdUUID.9, offerIdUUID.10, offerIdUUID.11, offerIdUUID.12, offerIdUUID.13, offerIdUUID.14, offerIdUUID.15])
            var offer = [
                true, //isCreated
                false, //isTaken,
                walletAddress, //maker
                Array("maker's interface Id here".utf8),
                dummyDaiContractAddress, //stablecoin
                100, //amountLowerBound
                100, //amountUpperBound
                10, //securityDepositAmount
                2, //direction
                Array("a price here".utf8), //price
                [Array("USD-SWIFT".utf8)], //settlementMethods
                1, //protocolVersion
            ] as [Any]
            if direction == .sell {
                offer[8] = 1
            } else if direction == .buy {
                offer[8] = 0
            }
            method = "openOffer"
            writeTx = commutoSwapContract.write(
                method,
                parameters: [offerIdArray!, offer] as [AnyObject],
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var openOfferTxConfirmed = false
            while openOfferTxConfirmed == false {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        openOfferTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
            
            //Wait for offer to be taken
            var isOfferTaken = false
            //Find events that specify our offer as the one taken, don't worry about interface Id for now
            eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: [[offerIdArray!],])
            eventParser = commutoSwapContract.createEventParser("OfferTaken", filter: eventFilter)
            while isOfferTaken == false {
                var eventParserResults: [EventParserResultProtocol]? = []
                do {
                    if try web3Instance.eth.getBlockNumber() > lastParsedBlockNumber {
                        eventParserResults = try eventParser!.parseBlockByNumber(UInt64(lastParsedBlockNumber + 1))
                        if eventParserResults != nil && (eventParserResults?.count)! > 0 {
                            //Parse receipt and event log of tx that took offer
                            //TODO: this^
                            txReceipt = eventParserResults![0].transactionReceipt
                            eventLog = eventParserResults![0].eventLog
                            isOfferTaken = true
                        }
                        lastParsedBlockNumber += 1
                    }
                    if isOfferTaken == false {
                        sleep(UInt32(1.0))
                    }
                } catch {
                    //TODO: Only catch connection loss exceptions here
                    web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
                    web3Instance.addKeystoreManager(keystoreManager)
                }
            }
            
            //Get the newly taken swap
            method = "getSwap"
            readTx = commutoSwapContract.read(
                method,
                parameters: [offerIdArray!] as [AnyObject],
                transactionOptions: options
            )!
            swap = try! readTx.call()
            let swapData = swap!["0"] as! [AnyObject]
            
        } else if role == .taker {
            //Listen for new offers
            /*
            Note: As of now, this will try to take the first OfferOpened event that it finds, even if the offer is closed
            or there exists more than one open offer
             */
            var foundOpenOffer = false
            eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: nil)
            eventParser = commutoSwapContract.createEventParser("OfferOpened", filter: eventFilter)
            while foundOpenOffer == false {
                var eventParserResults: [EventParserResultProtocol]? = []
                do {
                    if try web3Instance.eth.getBlockNumber() > lastParsedBlockNumber {
                        eventParserResults = try eventParser!.parseBlockByNumber(UInt64(lastParsedBlockNumber + 1))
                        if eventParserResults != nil && (eventParserResults?.count)! > 0 {
                            //TODO: Parse receipt and event log of tx that opened offer
                            txReceipt = eventParserResults![0].transactionReceipt
                            eventLog = eventParserResults![0].eventLog
                            offerIdArray = eventParserResults![0].decodedResult["offerID"]! as! Data
                            foundOpenOffer = true
                        }
                        lastParsedBlockNumber += 1
                    }
                    if foundOpenOffer == false {
                        sleep(UInt32(1.0))
                    }
                } catch {
                    //TODO: Only catch connection loss exceptions here
                    web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
                    web3Instance.addKeystoreManager(keystoreManager)
                }
            }
            
            //Get new offer
            method = "getOffer"
            readTx = commutoSwapContract.read(
                method,
                parameters: [offerIdArray!] as [AnyObject],
                transactionOptions: options
            )!
            let offer: [String : Any] = try! readTx.call()
            let offerData = offer["0"] as! [AnyObject]
            
            //Create allowance to take offer
            method = "approve"
            if direction == .buy {
                value = 111
            } else if direction == .sell {
                value = 11
            }
            writeTx = dummyDaiContract.write(
                method,
                parameters: [commutoContractAddress, value] as [AnyObject],
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var approvalTxConfirmed = false
            while !approvalTxConfirmed {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        approvalTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
            
            //Create swap object and take offer
            let preparedSwap: [Any] = [
                false, //isCreated
                false, //requiresFill
                offerData[2], //maker
                offerData[3], //makerInterfaceId
                walletAddress, //taker
                Array("taker's interface Id here".utf8), //takerInterfaceId
                offerData[4], //stablecoin
                offerData[5], //amountLowerBound
                offerData[6], //amountUpperBound
                offerData[7], //securityDepositAmount
                100, //takenSwapAmount
                1, //securityDepositAmount
                offerData[8], //direction
                offerData[9], //price
                (offerData[10] as! Array)[0], //settlementMethod
                1, //protocolVersion
                false, //isPaymentSent
                false, //isPaymentReceived
                false, //hasBuyerClosed
                false //hasSellerClosed
            ]
            method = "takeOffer"
            writeTx = commutoSwapContract.write(
                method,
                parameters: [offerIdArray!, preparedSwap] as [AnyObject],
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var takeOfferTxConfirmed = false
            while !takeOfferTxConfirmed {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        takeOfferTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
            
        }
        
        if direction == .sell {
            if role == .maker {
                //Create allowance to fill newly taken swap
                method = "approve"
                value = 100
                writeTx = dummyDaiContract.write(
                    method,
                    parameters: [commutoContractAddress, value] as [AnyObject],
                    transactionOptions: options
                )!
                writeTx!.transaction.gasPrice = gasPrice
                writeTx!.transaction.gasLimit = gasLimit
                writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
                try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
                txHash = writeTx!.transaction.hash
                promise = writeTx!.sendPromise()
                var approvalTxConfirmed = false
                while !approvalTxConfirmed {
                    do {
                        if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                            approvalTxConfirmed = true
                        }
                    } catch Web3Error.nodeError(desc: let desc) {
                        if desc == "Invalid value from Ethereum node" {
                            sleep(UInt32(1.0))
                        } else {
                            throw Web3Error.nodeError(desc: desc)
                        }
                    }
                }
                
                //Fill the newly taken swap
                method = "fillSwap"
                writeTx = commutoSwapContract.write(
                    method,
                    parameters: [offerIdArray!] as [AnyObject],
                    transactionOptions: options
                )!
                writeTx!.transaction.gasPrice = gasPrice
                writeTx!.transaction.gasLimit = gasLimit
                writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
                try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
                txHash = writeTx!.transaction.hash
                promise = writeTx!.sendPromise()
                var fillSwapTxConfirmed = false
                while !fillSwapTxConfirmed {
                    do {
                        if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                            fillSwapTxConfirmed = true
                        }
                    } catch Web3Error.nodeError(desc: let desc) {
                        if desc == "Invalid value from Ethereum node" {
                            sleep(UInt32(1.0))
                        } else {
                            throw Web3Error.nodeError(desc: desc)
                        }
                    }
                }
            } else if role == .taker {
                //Start listening for SwapFilled event
                /*
                 Note: As of now, this will try to take the first SwapFilled event that it finds
                 */
                var isSwapFilled = false
                eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: [[offerIdArray!],])
                eventParser = commutoSwapContract.createEventParser("SwapFilled", filter: eventFilter)
                while isSwapFilled == false {
                    var eventParserResults: [EventParserResultProtocol]? = []
                    do {
                        if try web3Instance.eth.getBlockNumber() > lastParsedBlockNumber {
                            eventParserResults = try eventParser!.parseBlockByNumber(UInt64(lastParsedBlockNumber + 1))
                            if eventParserResults != nil && (eventParserResults?.count)! > 0 {
                                //TODO: Parse receipt and event log of tx that opened offer
                                txReceipt = eventParserResults![0].transactionReceipt
                                eventLog = eventParserResults![0].eventLog
                                isSwapFilled = true
                            }
                            lastParsedBlockNumber += 1
                        }
                        if isSwapFilled == false {
                            sleep(UInt32(1.0))
                        }
                    } catch {
                        //TODO: Only catch connection loss exceptions here
                        web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
                        web3Instance.addKeystoreManager(keystoreManager)
                    }
                }
            }
        }
        
        if (direction == .buy && role == .maker) || (direction == .sell && role == .taker) {
            //Report payment sent
            method = "reportPaymentSent"
            writeTx = commutoSwapContract.write(
                method,
                parameters: [offerIdArray!] as [AnyObject],
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var repPaySntTxConfirmed = false
            while !repPaySntTxConfirmed {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        repPaySntTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
            
            //Start listening for PaymentReceived event
            var isPaymentReceived = false
            eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: [[offerIdArray!],])
            eventParser = commutoSwapContract.createEventParser("PaymentReceived", filter: eventFilter)
            while isPaymentReceived == false {
                var eventParserResults: [EventParserResultProtocol]? = []
                do {
                    if try web3Instance.eth.getBlockNumber() > lastParsedBlockNumber {
                        eventParserResults = try eventParser!.parseBlockByNumber(UInt64(lastParsedBlockNumber + 1))
                        if eventParserResults != nil && (eventParserResults?.count)! > 0 {
                            //TODO: Parse receipt and event log of tx that reported payment received
                            txReceipt = eventParserResults![0].transactionReceipt
                            eventLog = eventParserResults![0].eventLog
                            isPaymentReceived = true
                        }
                        lastParsedBlockNumber += 1
                    }
                    if isPaymentReceived == false {
                        sleep(UInt32(1.0))
                    }
                } catch {
                    //TODO: Only catch connection loss exceptions here
                    web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
                    web3Instance.addKeystoreManager(keystoreManager)
                }
            }
        } else if (direction == .sell && role == .maker) || (direction == .buy && role == .taker) {
            //Start listening for PaymentSent event
            var isPaymentSent = false
            eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: [[offerIdArray!],])
            eventParser = commutoSwapContract.createEventParser("PaymentSent", filter: eventFilter)
            while isPaymentSent == false {
                var eventParserResults: [EventParserResultProtocol]? = []
                do {
                    if try web3Instance.eth.getBlockNumber() > lastParsedBlockNumber {
                        eventParserResults = try eventParser!.parseBlockByNumber(UInt64(lastParsedBlockNumber + 1))
                        if eventParserResults != nil && (eventParserResults?.count)! > 0 {
                            //TODO: Parse receipt and event log of tx that reported payment sent
                            txReceipt = eventParserResults![0].transactionReceipt
                            eventLog = eventParserResults![0].eventLog
                            isPaymentSent = true
                        }
                        lastParsedBlockNumber += 1
                    }
                    if isPaymentSent == false {
                        sleep(UInt32(1.0))
                    }
                } catch {
                    //TODO: Only catch connection loss exceptions here
                    web3Instance = web3(provider: Web3HttpProvider(URL(string: endpoint)!)!)
                    web3Instance.addKeystoreManager(keystoreManager)
                }
            }
            
            //Report payment received
            method = "reportPaymentReceived"
            writeTx = commutoSwapContract.write(
                method,
                parameters: [offerIdArray!] as [AnyObject],
                transactionOptions: options
            )!
            writeTx!.transaction.gasPrice = gasPrice
            writeTx!.transaction.gasLimit = gasLimit
            writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
            try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
            txHash = writeTx!.transaction.hash
            promise = writeTx!.sendPromise()
            var repPayRcvdTxConfirmed = false
            while !repPayRcvdTxConfirmed {
                do {
                    if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                        repPayRcvdTxConfirmed = true
                    }
                } catch Web3Error.nodeError(desc: let desc) {
                    if desc == "Invalid value from Ethereum node" {
                        sleep(UInt32(1.0))
                    } else {
                        throw Web3Error.nodeError(desc: desc)
                    }
                }
            }
        }
        
        //close swap
        method = "closeSwap"
        writeTx = commutoSwapContract.write(
            method,
            parameters: [offerIdArray!] as [AnyObject],
            transactionOptions: options
        )!
        writeTx!.transaction.gasPrice = gasPrice
        writeTx!.transaction.gasLimit = gasLimit
        writeTx!.transaction.nonce = try web3Instance.eth.getTransactionCount(address: walletAddress)
        try! Web3Signer.signTX(transaction: &writeTx!.transaction, keystore: keystore_one, account: walletAddress, password: password_one)
        txHash = writeTx!.transaction.hash
        promise = writeTx!.sendPromise()
        var closeSwapTxConfirmed = false
        while !closeSwapTxConfirmed {
            do {
                if try web3Instance.eth.getTransactionDetails(txHash!).blockNumber != nil {
                    closeSwapTxConfirmed = true
                }
            } catch Web3Error.nodeError(desc: let desc) {
                if desc == "Invalid value from Ethereum node" {
                    sleep(UInt32(1.0))
                } else {
                    throw Web3Error.nodeError(desc: desc)
                }
            }
        }
        
        //check that balance has changed by proper amount
        method = "balanceOf"
        readTx = dummyDaiContract.read(
            method,
            parameters: [walletAddress] as [AnyObject],
            transactionOptions: options
        )!
        let finalDaiBalance = try! readTx.call()["0"] as! BigUInt
        
        if (direction == .buy && role == .maker) || (direction == .sell && role == .taker) {
            XCTAssertEqual(initialDaiBalance + BigUInt.init(99), finalDaiBalance)
        } else if (direction == .sell && role == .maker) || (direction == .buy && role == .taker) {
            XCTAssertEqual(initialDaiBalance, finalDaiBalance + BigUInt.init(101))
        }
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
