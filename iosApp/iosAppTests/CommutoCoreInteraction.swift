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
@testable import MatrixSDK
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
    
    func testJSONUtils() throws {
        //Prepare this interface's payment method details JSON string
        let ownPaymentDetailsDict: [[String : Any]] = [
            [
                "USD-SWIFT" : [
                    "Beneficiary": "Bob Roberts",
                    "Account": "293649254057",
                    "BIC": "BOBROB38"
                ]
            ]
        ]
        let ownPaymentDetails = String(decoding: try JSONSerialization.data(withJSONObject: ownPaymentDetailsDict), as: UTF8.self)
        print(ownPaymentDetails)
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
    
    func testSwapProcess() throws {
        //Specify swap direction and participant roles
        let direction = SwapDirection.buy
        let role = ParticipantRole.maker
        
        //Restore Hardhat account #1
        let password_one = "web3swift"
        let key_one = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" // Some private key
        let formattedKey_one = key_one.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataKey_one = Data.fromHex(formattedKey_one)!
        let keystore_one = try! EthereumKeystoreV3(privateKey: dataKey_one, password: password_one)!
        let keyData_one = try! JSONEncoder().encode(keystore_one.keystoreParams)
        let address_one = keystore_one.addresses!.first!.address
        
        //Establish connection to Ethereum node
        let endpoint = "http://192.168.0.195:8545"
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
        
        //Setup DBService and KMService
        let dbService: DBService = DBService()
        let kmService: KMService = KMService(dbService: dbService)
        try dbService.connectToDb()
        try dbService.createTables()
        
        //Create key pair
        let keyPair = try kmService.generateKeyPair()
        
        //Setup mxSession
        let setupExpectation = XCTestExpectation(description: "Setup matrix session")
        let credentials = MXCredentials(homeServer: "http://matrix.org", userId: "@jimmyt:matrix.org",
                                        accessToken: "")
        let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        let mxSession = MXSession(matrixRestClient: mxRestClient)!
        //Launch mxSession: it will first make an initial sync with the homeserver
        mxSession.start { response in
            guard response.isSuccess else { return }

            // mxSession is ready to be used
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        
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
        
        //Prepare this interface's payment method details JSON string
        let ownPaymentDetailsDict: [String : Any] = [
            "paymentDetails": [
                "USD-SWIFT" : [
                    "Beneficiary": "Bob Roberts",
                    "Account": "293649254057",
                    "BIC": "BOBROB38"
                ]
            ]
        ]
        let ownPaymentDetails = try JSONSerialization.data(withJSONObject: ownPaymentDetailsDict)
        
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
            
            //Prepare swap Offer
            let offerIdUUID = UUID().uuid
            offerIdArray = Data(fromArray: [offerIdUUID.0, offerIdUUID.1, offerIdUUID.2, offerIdUUID.3, offerIdUUID.4, offerIdUUID.5, offerIdUUID.6, offerIdUUID.7, offerIdUUID.8, offerIdUUID.9, offerIdUUID.10, offerIdUUID.11, offerIdUUID.12, offerIdUUID.13, offerIdUUID.14, offerIdUUID.15])
            var offer = [
                true, //isCreated
                false, //isTaken,
                walletAddress, //maker
                [UInt8](keyPair.interfaceId), //interfaceId
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
            
            //Open swap Offer
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
            
            //TODO: Prepare public key announcement message (this one doesn't work)
            var error: Unmanaged<CFError>?
            guard let pubKeyBytes = SecKeyCopyExternalRepresentation(keyPair.publicKey, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            var publicKeyAnnouncementDict: [String: Any] = [
                "sender": keyPair.interfaceId.base64EncodedString(),
                "msgType":"pka",
                "payload": [
                    "pubKey": (pubKeyBytes as NSData).base64EncodedString(),
                    "offerId": offerIdArray!.base64EncodedString()
                ],
                "signature": ""
            ]
            var payloadData = try JSONSerialization.data(withJSONObject: publicKeyAnnouncementDict["payload"])
            var payloadDataDigest = SHA256.hash(data: payloadData)
            var payloadDataHashByteArray = [UInt8]()
            for byte: UInt8 in payloadDataDigest.makeIterator() {
                payloadDataHashByteArray.append(byte)
            }
            var payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
            publicKeyAnnouncementDict["signature"] = try! keyPair.sign(data: payloadDataHash).base64EncodedString()
            let publicKeyAnnouncement = String(decoding: try JSONSerialization.data(withJSONObject: publicKeyAnnouncementDict), as: UTF8.self)
            
            //Send PKA message to CIN Matrix Room
            let sendPKAExpectation = XCTestExpectation(description: "Send PKA to Commuto Interface Network Test Room")
            mxRestClient.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: publicKeyAnnouncement) { (response) in
                if case .success(let eventId) = response {
                    sendPKAExpectation.fulfill()
                }
            }
            wait(for: [sendPKAExpectation], timeout: 60.0)
            
            //Wait for offer to be taken
            var isOfferTaken = false
            //Find events that specify our offer as the one taken, don't worry about interface Id for now
            eventFilter = EventFilter(fromBlock: nil, toBlock: nil, addresses: nil, parameterFilters: [[offerIdArray!],])
            eventParser = commutoSwapContract.createEventParser("OfferTaken", filter: eventFilter)
            var takerInterfaceId: Data? = nil
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
                            takerInterfaceId = eventParserResults![0].decodedResult["takerInterfaceId"] as! Data
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
            
            //TODO: Listen to CIN Matrix Room for taker's TakerInfo message, and handle it
            
            //TODO: Save taker's public key locally
            
            //TODO Prepare maker info message (this doesn't work)
            //TODO: Encrypt encryptedKey and encryptedIV with maker's public key
            let makerInfoMessageKey = try! newSymmetricKey()
            let symetricallyEncryptedPayload = try! makerInfoMessageKey.encrypt(data: ownPaymentDetails)
            payloadDataDigest = SHA256.hash(data: symetricallyEncryptedPayload.encryptedData)
            payloadDataHashByteArray = [UInt8]()
            for byte: UInt8 in payloadDataDigest.makeIterator() {
                payloadDataHashByteArray.append(byte)
            }
            payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
            var makerInfoMessageDict: [String: Any] = [
                "sender": keyPair.interfaceId.base64EncodedString(),
                "recipient": takerInterfaceId?.base64EncodedString(),
                "encryptedKey": "",
                "encryptedIV": "",
                "payload": symetricallyEncryptedPayload.encryptedData.base64EncodedString(),
                "signature": try! keyPair.sign(data: payloadDataHash).base64EncodedString()
            ]
            let makerInfoMessage = String(decoding: try JSONSerialization.data(withJSONObject: makerInfoMessageDict), as: UTF8.self)
            
            //Send maker info message to CIN Matrix Room
            let sendMakerInfoExpectation = XCTestExpectation(description: "Send maker info to Commuto Interface Network Test Room")
            mxRestClient.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: makerInfoMessage) { (response) in
                if case .success(let eventId) = response {
                    sendMakerInfoExpectation.fulfill()
                }
            }
            wait(for: [sendMakerInfoExpectation], timeout: 60.0)
            
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
            
            //TODO: Listen for maker's PKA message in CIN Matrix room and handle it
            
            //TODO: Save maker's public key locally
            
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
                [UInt8](keyPair.interfaceId), //takerInterfaceId
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
            
            //Prepare taker info message
            //TODO: Encrypt encryptedKey and encryptedIV with taker's public key
            var error: Unmanaged<CFError>?
            guard let pubKeyBytes = SecKeyCopyExternalRepresentation(keyPair.publicKey, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            let takerInfoMessageKey = try! newSymmetricKey()
            let takerInfoPayloadDict: [String: Any] = [
                "msgType": "takerInfo",
                "pubKey": (pubKeyBytes as NSData).base64EncodedString(),
                "swapId": offerIdArray!.base64EncodedString(),
                "paymentDetails": ownPaymentDetailsDict["paymentDetails"]
            ]
            let takerInfoPayload = try JSONSerialization.data(withJSONObject: takerInfoPayloadDict)
            let symetricallyEncryptedPayload = try! takerInfoMessageKey.encrypt(data: takerInfoPayload)
            var payloadDataDigest = SHA256.hash(data: symetricallyEncryptedPayload.encryptedData)
            var payloadDataHashByteArray = [UInt8]()
            for byte: UInt8 in payloadDataDigest.makeIterator() {
                payloadDataHashByteArray.append(byte)
            }
            var payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
            var takerInfoMessageDict: [String: Any] = [
                "sender": keyPair.interfaceId.base64EncodedString(),
                "recipient": offerData[3].base64EncodedString(),
                "encryptedKey": "",
                "encryptedIV": "",
                "payload": symetricallyEncryptedPayload.encryptedData.base64EncodedString(),
                "signature": try! keyPair.sign(data: payloadDataHash).base64EncodedString()
            ]
            let takerInfoMessage = String(decoding: try JSONSerialization.data(withJSONObject: takerInfoMessageDict), as: UTF8.self)
            
            //Send taker info message to CIN Matrix room
            let sendTakerInfoExpectation = XCTestExpectation(description: "Send taker info to Commuto Interface Network Test Room")
            mxRestClient.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: takerInfoMessage) { (response) in
                if case .success(let eventId) = response {
                    sendTakerInfoExpectation.fulfill()
                }
            }
            wait(for: [sendTakerInfoExpectation], timeout: 60.0)
            
            //TODO: Listen to CIN for maker's info message
            
            //TODO: Store maker's payment information locally
            
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
    
    func createPublicKeyAnnouncement(keyPair: KeyPair, offerId: Data) throws -> String {
        //Create message NSDictionary
        var message = [
            "sender": keyPair.interfaceId.base64EncodedString(),
            "msgType": "pka",
            "payload": nil,
            "signature": nil,
        ]
        
        //Create Base64-encoded string of public key in PKCS#1 bytes
        let pubKeyString = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
        
        //Create Base-64 encoded string of offer idV
        let offerIdString = offerId.base64EncodedString()
        
        //Create payload NSDictionary
        let payload = [
            "pubKey": pubKeyString,
            "offerId": offerIdString,
        ]
        
        //Create payload UTF-8 bytes and their Base-64 encoded string
        let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
        let payloadString = payloadUTF8Bytes.base64EncodedString()
        
        //Set "payload" field of message
        message["payload"] = payloadString
        
        //Create signature of payload
        let payloadDataDigest = SHA256.hash(data: payloadUTF8Bytes)
        var payloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in payloadDataDigest.makeIterator() {
            payloadDataHashByteArray.append(byte)
        }
        let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
        let signature = try keyPair.sign(data: payloadDataHash)
        
        //Set "signature" field of message
        message["signature"] = signature.base64EncodedString()
        
        //Prepare and return message string
        let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
        return messageString
    }
    
    func parsePublicKeyAnnouncement(messageString: String, makerInterfaceId: Data, offerId: Data) throws -> iosApp.PublicKey? {
        //Restore message NSDictionary
        guard let messageData = messageString.data(using: String.Encoding.utf8) else {
            return nil
        }
        guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the message is a Public Key Announcement message
        guard let messageType = message["msgType"] as? String else {
            return nil
        }
        guard messageType == "pka" else {
            return nil
        }
        
        //Ensure that the sender is the maker
        guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
            return nil
        }
        guard makerInterfaceId == senderInterfaceId else {
            return nil
        }
        
        //Restore payload NSDictionary
        guard let payloadString = message["payload"] as? String, let payloadData = Data(base64Encoded: payloadString) else {
            return nil
        }
        guard let payload = try JSONSerialization.jsonObject(with: payloadData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the offer id in the PKA matches the offer in question
        guard let messageOfferIdString = payload["offerId"] as? String, let messageOfferId = Data(base64Encoded: messageOfferIdString) else {
            return nil
        }
        guard messageOfferId == offerId else {
            return nil
        }
        
        //Re-create maker's public key
        guard let pubKeyString = payload["pubKey"] as? String, let pubKeyBytes = Data(base64Encoded: pubKeyString) else {
            return nil
        }
        guard let publicKey = try? PublicKey(publicKeyBytes: pubKeyBytes) else {
            return nil
        }
        
        //Check that interface id of maker's key matches value in "sender" field of message
        guard senderInterfaceId == publicKey.interfaceId else {
            return nil
        }
        
        //Create hash of payload
        let payloadDataDigest = SHA256.hash(data: payloadData)
        var payloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in payloadDataDigest.makeIterator() {
            payloadDataHashByteArray.append(byte)
        }
        let payloadDataHash = Data(bytes: payloadDataHashByteArray, count: payloadDataHashByteArray.count)
        
        //Verify signature
        guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
            return nil
        }
        if try publicKey.verifySignature(signedData: payloadDataHash, signature: signature) {
            return publicKey
        } else {
            return nil
        }
    }
    
    func testPKAParsing() throws {
        //Restore the maker's public key
        let pubKey = "MIIBCgKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQAB"
        let privKey = "MIIEogIBAAKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQABAoIBACWe/ZLfS4DG144x0lUNedhUPsuvXzl5NAj8DBXtcQ6TkZ51VN8TgsHrQ2WKwkKdVnZAzPnkEMxy/0oj5xG8tBL43RM/tXFUsUHJhpe3G9Xb7JprG/3T2aEZP/Sviy16QvvFWJWtZHq1knOIy3Fy/lGTJM/ymVciJpc0TGGtccDyeQDBxaoQrr1r4Q9q5CMED/kEXq5KNLmzbfB1WInQZJ7wQhtyyAJiXJxKIeR3hVGR1dfBJGSbIIgYA5sYv8HPnXrorU7XEgDWLkILjSNgCvaGOgC5B4sgTB1pmwPQ173ee3gbn+PCai6saU9lciXeCteQp9YRBBWfwl+DDy5oGsUCgYEA0TB+kXbUgFyatxI46LLYRFGYTHgOPZz6Reu2ZKRaVNWC75NHyFTQdLSxvYLnQTnKGmjLapCTUwapiEAB50tLSko/uVcf4bG44EhCfL4S8hmfS3uCczokhhBjR/tZxnamXb/T1Wn2X06QsPSYQQmZB7EoQ6G0u/K792YgGn/qh+cCgYEAweUWInTK5nIAGyA/k0v0BNOefNTvfgV25wfR6nvXM3SJamHUTuO8wZntekD/epd4EewTP57rEb9kCzwdQnMkAaT1ejr7pQE4RFAZcL86o2C998QS0k25fw5xUhRiOIxSMqK7RLkAlRsThel+6BzHQ+jHxB06te3yyIjxnqP576UCgYA7tvAqbhVzHvw7TkRYiNUbi39CNPM7u1fmJcdHK3NtzBU4dn6DPVLUPdCPHJMPF4QNzeRjYynrBXfXoQ3qDKBNcKyIJ8q+DpGL1JTGLywRWCcU0QkIA4zxiDQPFD0oXi5XjK7XuQvPYQoEuY3M4wSAIZ4w0DRbgosNsGVxqxoz+QKBgClYh3LLguTHFHy0ULpBLQTGd3pZEcTGt4cmZL3isI4ZYKAdwl8cMwj5oOk76P6kRAdWVvhvE+NR86xtojOkR95N5catwzF5ZB01E2e2b3OdUoT9+6F6z35nfwSoshUq3vBLQTGzXYtuHaillNk8IcW6YrbQIM/gsK/Qe+1/O/G9AoGAYJhKegiRuasxY7ig1viAdYmhnCbtKhOa6qsq4cvI4avDL+Qfcgq6E8V5xgUsPsl2QUGz4DkBDw+E0D1Z4uT60y2TTTPbK7xmDs7KZy6Tvb+UKQNYlxL++DKbjFvxz6VJg17btqid8sP+LMhT3oqfRSakyGS74Bn3NBpLUeonYkQ="
        let pubKeyBytes = Data(base64Encoded: pubKey)!
        let privKeyBytes = Data(base64Encoded: privKey)!
        let keyPair = try KeyPair(publicKeyBytes: pubKeyBytes, privateKeyBytes: privKeyBytes)
        
        //Restore offer id
        let offerId = Data(base64Encoded: "9tGMGTr0SbuySqE0QOsAMQ==")!
        
        //Create Public Key Announcement message string
        let swiftPkaMessageString = try! createPublicKeyAnnouncement(keyPair: keyPair, offerId: offerId)
        
        //A Public Key Announcement message string generated by JVM code
        let jvmPkaMessageString = #"{"sender":"gXE4i2ZrzX+QK5AdNalVTpU1tJoIA9sEMca6uRfiRSE=","msgType":"pka","payload":"eyJwdWJLZXkiOiJNSUlCQ2dLQ0FRRUFubkRCNHpWMmxsRXd3TEh3N2M5MzRlVjd0NjlPbTUyZHBMY3VjdFh0T3RqR3NhS3lPQVY5NmVnbXhYNitDK01wdEZTVDN5WDR3TzZxSzMvTlN1T0hXQlhJSGtoUUdaRWRUSE9uNEhFOWhIZHcyYXhKMEY5R1FLWmVUOHQ4a3crNTgrbitubGJRVWFGSFV3NWl5cGwzV2lJMUs3RW40WFYyZWdmWEdrOXVqRWxNcVhaTy9lRnVuM2VBTSthc1QxZzdvL2syeXNPcFk1WCtzcWVzTHNKMGd6YUdINGpmRFZ1V2lmUzVZaGRnRktrQmkxaTNVMXRmUGRjM3NONTN1TkNQRWh4amp1T3VZSDVJM1dJOVZ6anBKZXpZb1Nsd3pJNGhZTk9qWTBjV3paTTlrcWVVdDkzS3pUcHZYNEZlUWlnVDlVTzIwY3MyM001TmJJVzRxN2xBNHdJREFRQUIiLCJvZmZlcklkIjoiOXRHTUdUcjBTYnV5U3FFMFFPc0FNUT09In0=","signature":"ZdIOEtAJGnyKjx468ddxdGGcxchfbuPYq25fSkZda33EZm/vapHaht3oQci/pOSiPnPCN08MTFsxodwRJFdxr1900lHPIyLuRT0KoDJMwhOseC+tcyB3FCUvpmNUYqWfMasAtBGqsYnbWOVXn6Fct8DYe9T394LbcfnO0YHvL0x2wmjiCC/viJMgeGr+/v8FGpmxqtfuTH0oJ5VTpNrLMSrCMMYpHlaPDPpSVDQrRpeqibm+ir+KXVbzgrga1LJimUEqk5UoGzFZGIROatutvLerV2nWiwf3RCb6Nfop7ZTAHyIDkA+zOoKd00XhjUpvG2/5AJhMr4nINVK8DWwKbA=="}"#
        
        //Attempt to parse Public Key Announcement message string generated by Swift code
        let restoredSwiftPublicKey = try! parsePublicKeyAnnouncement(messageString: swiftPkaMessageString, makerInterfaceId: keyPair.interfaceId as Data, offerId: offerId)
        
        //Attempt to parse Public Key Announcement message string generated by JVM code
        let restoredJvmPublicKey = try! parsePublicKeyAnnouncement(messageString: jvmPkaMessageString, makerInterfaceId: keyPair.interfaceId as Data, offerId: offerId)
        
        //Check that original and restored interface ids (and thus keys) are identical
        XCTAssert(keyPair.interfaceId == restoredSwiftPublicKey!.interfaceId)
        XCTAssert(keyPair.interfaceId == restoredJvmPublicKey!.interfaceId)
        
    }
    
    func createTakerInfoMessage(keyPair: KeyPair, makerPubKey: iosApp.PublicKey, swapId: Data, paymentDetails: [String : Any]) throws -> String {
        //Create message NSDictionary
        var message = [
            "sender": keyPair.interfaceId.base64EncodedString(),
            "recipient": makerPubKey.interfaceId.base64EncodedString(),
            "encryptedKey": nil,
            "encryptedIV": nil,
            "payload": nil,
            "signature": nil
        ]
        
        //Create Base64-encoded string of taker's public key in PKCS#1 bytes
        let pubKeyString = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
        
        //Create Base-64 encoded string of swap id
        let swapIdString = swapId.base64EncodedString()
        
        //Create payload NSDictionary
        var payload = [
            "msgType": "takerInfo",
            "pubKey": pubKeyString,
            "swapId": swapIdString,
            "paymentDetails": nil
        ]
        
        //Create payment details UTF-8 bytes and their Base64-encoded string
        let paymentDetailsUTF8Bytes = try JSONSerialization.data(withJSONObject: paymentDetails)
        
        //Set "paymentDetails" field of payload
        payload["paymentDetails"] = paymentDetailsUTF8Bytes.base64EncodedString()
        
        //Create payload UTF-8 bytes and their Base64-encoded string
        let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
        
        //Generate a new symmetric key and initialization vector, and encrypt the payload bytes
        let symmetricKey = try newSymmetricKey()
        let encryptedPayload = try symmetricKey.encrypt(data: payloadUTF8Bytes)
        
        //Set "payload" field of message
        message["payload"] = encryptedPayload.encryptedData.base64EncodedString()
        
        //Create signature of encrypted payload
        let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
        var encryptedPayloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
            encryptedPayloadDataHashByteArray.append(byte)
        }
        let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
        let signature = try keyPair.sign(data: encryptedPayloadDataHash)
        
        //Set signature field of message
        message["signature"] = signature.base64EncodedString()
        
        //Encrypt symmetric key and initialization vector with maker's public key
        let encryptedKey = try makerPubKey.encrypt(clearData: symmetricKey.keyData)
        let encryptedIV = try makerPubKey.encrypt(clearData: encryptedPayload.initializationVectorData)
        
        //Set "encryptedKey" and "encryptedIV" fields of message
        message["encryptedKey"] = encryptedKey.base64EncodedString()
        message["encryptedIV"] = encryptedIV.base64EncodedString()
        
        //Prepare and return message string
        let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
        return messageString
        
    }
    
    func parseTakerInfoMessage(messageString: String, keyPair: KeyPair, takerInterfaceId: Data, swapId: Data) throws -> (iosApp.PublicKey, [String : Any])? {
        //Restore message NSDictionary
        guard let messageData = messageString.data(using: String.Encoding.utf8) else {
            return nil
        }
        guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the sender is the taker and the recipient is the maker
        guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
            return nil
        }
        guard takerInterfaceId == senderInterfaceId else {
            return nil
        }
        guard let recipientInterfaceIdString = message["recipient"] as? String, let recipientInterfaceId = Data(base64Encoded: recipientInterfaceIdString) else {
            return nil
        }
        guard keyPair.interfaceId == recipientInterfaceId else {
            return nil
        }
        
        //Decrypt symmetric key, initialization vector and encrypted payload
        guard let encryptedKeyString = message["encryptedKey"] as? String, let encryptedKey = Data(base64Encoded: encryptedKeyString) else {
            return nil
        }
        let decryptedKeyBytes = try keyPair.decrypt(cipherData: encryptedKey)
        let symmetricKey = SymmetricKey(key: decryptedKeyBytes)
        guard let encryptedPayloadString = message["payload"] as? String, let encryptedPayloadData = Data(base64Encoded: encryptedPayloadString) else {
            return nil
        }
        guard let encryptedIVString = message["encryptedIV"] as? String, let encryptedIV = Data(base64Encoded: encryptedIVString) else {
            return nil
        }
        let decryptedIV = try keyPair.decrypt(cipherData: encryptedIV)
        let encryptedPayload = SymmetricallyEncryptedData(data: encryptedPayloadData, iv: decryptedIV)
        let decryptedPayloadData = try symmetricKey.decrypt(data: encryptedPayload)
        
        //Restore payload object
        guard let payload = try JSONSerialization.jsonObject(with: decryptedPayloadData) as? NSDictionary else {
            return nil
        }
        
        //Ensure the message is a taker info message
        guard let messageType = payload["msgType"] as? String else {
            return nil
        }
        guard messageType == "takerInfo" else {
            return nil
        }
        
        //Ensure that the swap id in the takerInfo message matches the swap in qustion
        guard let messageSwapIdString = payload["swapId"] as? String, let messageSwapId = Data(base64Encoded: messageSwapIdString) else {
            return nil
        }
        guard messageSwapId == swapId else {
            return nil
        }
        
        //Re-create taker's public key
        guard let pubKeyString = payload["pubKey"] as? String, let pubKeyBytes = Data(base64Encoded: pubKeyString) else {
            return nil
        }
        guard let publicKey = try? PublicKey(publicKeyBytes: pubKeyBytes) else {
            return nil
        }
        
        //Check that interface id of taker's key matches value in "sender" field of message
        guard senderInterfaceId == publicKey.interfaceId else {
            return nil
        }
        
        //Create hash of encrypted payload
        let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
        var encryptedPayloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
            encryptedPayloadDataHashByteArray.append(byte)
        }
        let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
        
        //Verify signature
        guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
            return nil
        }
        guard try publicKey.verifySignature(signedData: encryptedPayloadDataHash, signature: signature) else {
            return nil
        }
        
        //Restore payment details object
        /*
        TODO: In production, we should know the sort of payment info we are looking for, try to deserialize that type exactly, and return null if the payment info is for a different payment method
         */
        guard let paymentDetailsString = payload["paymentDetails"] as? String, let paymentDetailsData = Data(base64Encoded: paymentDetailsString) else {
            return nil
        }
        guard let paymentDetails = try JSONSerialization.jsonObject(with: paymentDetailsData) as? [String : Any] else {
            return nil
        }
        return (publicKey, paymentDetails)
    }
    
    func testTakerInfoParsing() throws {
        //Restore the maker's public and private key
        let makerPubKeyB64 = "MIIBCgKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQAB"
        let makerPrivKeyB64 = "MIIEogIBAAKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQABAoIBACWe/ZLfS4DG144x0lUNedhUPsuvXzl5NAj8DBXtcQ6TkZ51VN8TgsHrQ2WKwkKdVnZAzPnkEMxy/0oj5xG8tBL43RM/tXFUsUHJhpe3G9Xb7JprG/3T2aEZP/Sviy16QvvFWJWtZHq1knOIy3Fy/lGTJM/ymVciJpc0TGGtccDyeQDBxaoQrr1r4Q9q5CMED/kEXq5KNLmzbfB1WInQZJ7wQhtyyAJiXJxKIeR3hVGR1dfBJGSbIIgYA5sYv8HPnXrorU7XEgDWLkILjSNgCvaGOgC5B4sgTB1pmwPQ173ee3gbn+PCai6saU9lciXeCteQp9YRBBWfwl+DDy5oGsUCgYEA0TB+kXbUgFyatxI46LLYRFGYTHgOPZz6Reu2ZKRaVNWC75NHyFTQdLSxvYLnQTnKGmjLapCTUwapiEAB50tLSko/uVcf4bG44EhCfL4S8hmfS3uCczokhhBjR/tZxnamXb/T1Wn2X06QsPSYQQmZB7EoQ6G0u/K792YgGn/qh+cCgYEAweUWInTK5nIAGyA/k0v0BNOefNTvfgV25wfR6nvXM3SJamHUTuO8wZntekD/epd4EewTP57rEb9kCzwdQnMkAaT1ejr7pQE4RFAZcL86o2C998QS0k25fw5xUhRiOIxSMqK7RLkAlRsThel+6BzHQ+jHxB06te3yyIjxnqP576UCgYA7tvAqbhVzHvw7TkRYiNUbi39CNPM7u1fmJcdHK3NtzBU4dn6DPVLUPdCPHJMPF4QNzeRjYynrBXfXoQ3qDKBNcKyIJ8q+DpGL1JTGLywRWCcU0QkIA4zxiDQPFD0oXi5XjK7XuQvPYQoEuY3M4wSAIZ4w0DRbgosNsGVxqxoz+QKBgClYh3LLguTHFHy0ULpBLQTGd3pZEcTGt4cmZL3isI4ZYKAdwl8cMwj5oOk76P6kRAdWVvhvE+NR86xtojOkR95N5catwzF5ZB01E2e2b3OdUoT9+6F6z35nfwSoshUq3vBLQTGzXYtuHaillNk8IcW6YrbQIM/gsK/Qe+1/O/G9AoGAYJhKegiRuasxY7ig1viAdYmhnCbtKhOa6qsq4cvI4avDL+Qfcgq6E8V5xgUsPsl2QUGz4DkBDw+E0D1Z4uT60y2TTTPbK7xmDs7KZy6Tvb+UKQNYlxL++DKbjFvxz6VJg17btqid8sP+LMhT3oqfRSakyGS74Bn3NBpLUeonYkQ="
        let makerPubKeyBytes = Data(base64Encoded: makerPubKeyB64)!
        let makerPrivKeyBytes = Data(base64Encoded: makerPrivKeyB64)!
        let makerKeyPair = try KeyPair(publicKeyBytes: makerPubKeyBytes, privateKeyBytes: makerPrivKeyBytes)
        let makerPublicKey = try PublicKey(publicKeyBytes: makerPubKeyBytes)
        
        //Restore the takers's public and private key
        let takerPubKeyB64 = "MIIBCgKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQAB"
        let takerPrivKeyB64 = "MIIEowIBAAKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQABAoIBADez/Kue3qkNILMbxrSzmdFEIaVPeP6xYUN3xi7ny2F9UQGH8smyTq4Y7D+mru/hF2ihhi2tWu/87w458QS/i8qYy3G/OeQABH03oCEauC6bodXvT9aSJg89cNZL3qcxHbZLAOkfUoWW/EBDyw5yDXVttHF6Dh491JKfoOELTamWD4KxIScR/Nf6ih6UqB/SwmLz1X5+fZpW4iGZXIRsPzOzDtDmoSGajNXoi0Ln2x9DkUeXpx9r7TTT9DBT0jTLbCUiB3LYU4I/VR6upm0bDUKKRi9VTkQjOAV5rD3qdoraPVRCSzjUVqCwL7jqfunXsG/hhRccD+Di5pXaCuPeOsECgYEA3p4LLVHDzLhF269oUcvflMoBUVKo9UNHL/wmyujdV+RwFi5J2sxVLgKHsdKHCy7FdrDmxax7Mrgh57KS3+zfdDhs98w181JLwgFxzEAxIP2PnHd4P3NEbxCxnxhILW4fEotUVzJWjjhEHXe5QhOW2z2yIZIOEqBzFfRx33kWrbMCgYEAzaUrDMaTkIkOoVI7BbNS7n5CBWL/DaPOID1UiL4eHWngeoOwaeI+CB0cxSrxngykue0xM3aI3KVFaeIYSdn7DZAxWAS3U143VApgLxgLyxZBtVX18HYiTZQx/PiTczMH6kFA5z0L7iNlf0uQrQQJgDzM6QY0kKasufoss+Baj9ECgYA1BjvvTXxvtKyfCQa2BPN6QytRLXklAiNgoJS03AZsuvKfteLNhMH9NYkQp+6WkUtjW/t7tfuaNxWMVJJ7V7ZZvl7mHvPywvVcfm+WkOuiygJ86E/x/Qid08Ia/POkLoikKB+srUbElU5UHoI35OaXzfgx2tITSbhf0FuXOQZX1QKBgAj7A4xFR8ByG89ztdwj3qVHoj51+klwM9o4k259Tvdd3k27XoLhPHBCRTVfELokNzVfZFyo+oUYOpXLJ+BhwpLvDxiW7CKZ5LSo11Z3KFywFiKDJIBhyFG2/Q/dEyNewSO7wcfXZKP7q70JYcIMgRW2kgRDHxyKCtT8VeNtEsdhAoGBAJHzNruW/ZS31o0rvQxHu8tBcd8osTsPNZBhuHs60mbPFRHwBaU8JSofl4XjR8B7K9vjYtxVYMEsIX6NqNf1JMXGDva/cTCHXyPuiCnuUMbHkK0YpsFxQABwYA+sOSlujwJwMNPu4ylzHL1HDyv9m4x74/NM20zDFW6MB/zD6G0c"
        let takerPubKeyBytes = Data(base64Encoded: takerPubKeyB64)!
        let takerPrivKeyBytes = Data(base64Encoded: takerPrivKeyB64)!
        let takerKeyPair = try KeyPair(publicKeyBytes: takerPubKeyBytes, privateKeyBytes: takerPrivKeyBytes)
        let takerPublicKey = try PublicKey(publicKeyBytes: takerPubKeyBytes)
        
        //Restore swap id
        let swapId = Data(base64Encoded: "9tGMGTr0SbuySqE0QOsAMQ==")!
        
        //Create payment details
        let paymentDetails = [
            "name": "USD-SWIFT",
            "beneficiary": "Take Ker",
            "account": "2039482",
            "bic": "TAK3940"
        ]
        
        //Create taker info message string
        let swiftTakerInfoMessageString = try! createTakerInfoMessage(keyPair: takerKeyPair, makerPubKey: makerPublicKey, swapId: swapId, paymentDetails: paymentDetails)
        
        //A taker info message string generated by JVM code
        let jvmTakerInfoMessageString = #"{"sender":"HpIWD/7nBJ3VP+yQ2WYfh2lq5/uCLAkbkNIJ3FFJ2oc=","recipient":"gXE4i2ZrzX+QK5AdNalVTpU1tJoIA9sEMca6uRfiRSE=","encryptedKey":"YKav0mnW7vUGRgniGcwS5yXNKvNNZeh1s0GDVtZ/KLUmS0pZycrRn+4iwmsF4SYN1BOJkOB0ujqqAFW88kUX0+09CjHg+YDshZk3wUWVfM9Agu3qtyuF9TdOydVMaOi62nxSbMyPAUtA8suDtw2N9T38W92DwAYZOKoT9jBeDP6a9o20+Sifp3U/uCAjesje/lMLh9+67apfzGFgzRblwl2Mod/PI1nE/x0aDkMtaFO74BGHhEgM7hm1fjdqhDyBBCDa5QQmdysLUKsk9JZVyGcFlIISQZvbaydqYRKu3zG0+KQ0/ezNUMDFwemHkd4wyrrtT0GeYuJXoNMiC14VvQ==","encryptedIV":"K2pOgo9MObLjytbn74SjILyvTvVHGnaRCJncUBYGCoiqlYTOD2DMocPbxIbgDGMAw/p3ONidOMIASGqltOP+3/2+04WsXB4xprRTlHYmP8NFY0Hxaq5W1+/qU+VdVEAtqrSUyCJYI+eXr0ovYb1RU5mKF0jinKXmXMcWofXWxTeZUnMDyzUin0mrjBH0oBfRWfNmAH1AkdXfvspzq3mQsRrjFfERX8uH2e/02JQQQCzp+q8Fw2tU7eRxG42cZRNaXYMvo3EBXmdLBbX3z6B7MIjylMpn82G70IVex1gF/qgFL+kyhvAaj3iO9zhEP85CO4yh5JNDpv4qUG02L1hxfQ==","payload":"SdoUQeUdp1xC7sgg82OFD52V6tfMQ8Qlh/23YvT7Fd4+C2rhB4ePyvND+9EoTbnGZbUNFagqIK+XmrPAdAI0R+j6ZgFNVggsEHX6hfqWw/KQV7VGzOwHnA1XteyYyNREgt/UuDWYaE7BMPJCTSL0fVqhl9qcd7I+Hk10bTu+vIBOTabDhlWybmX5/zmulGoiOhoOD9xw7IGGpWe0dLpF99aEaAWo64YahhxA1bjimwUgzmCWrIS2HeTX+z4rl4XrhdOOfhDomTiFk0Q5ioiWmgyiPosX+AmJv5VX8ieM9VUvGOfNjW/lQjvk9025vb+zeEBtkJwBxbIXFX0612rxj8iFyYGdR1JiClhTN+V/90T0wLj3nUpORZA6c2O71KEVRuzAC8Rjmsbl5rynqggxi3FGT73NnB5npKM/Ycba7S0Jt9doEeRgpV77j8KSSsZ4ciV7P4GlGj/bTTuCedmFJJcvhh1MqmAxL8wOOLSclzXbNUP0Xi9zjpgZxQzGk1aTc+zwc4RKsRgMwxdel3GjI9ascRbu5aMR6Jc7sZrY1jyAdHVUaMotw5ynsoLcQz/PpvXwzc8DOtEKBofm62kgXuxZJDRpuggE3YRSQ4nA3jqUYFPrUbyg/qXXvn5Zx6+mUi1kBIpSgwKI9J/l8AK0TkEC02mAEwgh4YmtuO26LJ1JSLJIx/rA2dX8QxPwBnA47Ael8oUsIt51bA5Kk+dM+CFVIzudDwSvxNpa0HoePuolgdMOkrp2F0QttMaw4gmDJdfOURg3cZ1sWAGmvuISD/nvSKk3Vedt3fI4TtuA7fgThbMWi1FFenoQnasLsZY4/UI9hjnykssnz+EI7mVo/vuV6rU15jtHoCE9xkFVppc=","signature":"hHtRgIHQwFHDfKnjlWmvMRTz/Nuxls6rC4FARnAfiNH6ELHKjBe2bxpjlkS3RAwxICTtf/dmdQOxpxIZo1byylGEqLz7s2OWF0dh3ZtqTu2YG/9LDWfeW4FVQVgH+MFvBqqjUN9ej84n1SknoowY/8dDSNyOmn58dQJR82h9EgzqCtTJ5UUwwjYlm36NsZhLYcYif4KKmNHJ6FEIVGPExy29ivvPb0OSfFkMqqAcB/HMt3rf/cG+DhsX/uC8ipp19qIZE8qxplENaUDwo3c5dHkBCZlurT9VwtuLa+Dsmub9VAT+iu8zg28QpNlXCxYand+i5uhiYYRAWA0hnaKVDQ=="}"#
        
        //Attempt to parse taker info message string generated by Swift code
        let swiftParsingResults = try! parseTakerInfoMessage(messageString: swiftTakerInfoMessageString, keyPair: makerKeyPair, takerInterfaceId: takerPublicKey.interfaceId, swapId: swapId)
        
        //Attempt to parse taker info message string generated by JVM code
        let jvmParsingResults = try! parseTakerInfoMessage(messageString: jvmTakerInfoMessageString, keyPair: makerKeyPair, takerInterfaceId: takerPublicKey.interfaceId, swapId: swapId)
        
        //Check that original and restored interface ids (and thus keys) are identical
        XCTAssert(takerKeyPair.interfaceId == swiftParsingResults!.0.interfaceId)
        XCTAssert(takerKeyPair.interfaceId == jvmParsingResults!.0.interfaceId)
        
        //Check that original and restored payment details are identical
        let swiftRestoredPD = swiftParsingResults!.1
        let jvmRestoredPD = jvmParsingResults!.1
        XCTAssert(swiftRestoredPD["name"] as! String == "USD-SWIFT" && swiftRestoredPD["beneficiary"] as! String == "Take Ker" && swiftRestoredPD["account"] as! String == "2039482" && swiftRestoredPD["bic"] as! String == "TAK3940")
        XCTAssert(jvmRestoredPD["name"] as! String == "USD-SWIFT" && jvmRestoredPD["beneficiary"] as! String == "Take Ker" && jvmRestoredPD["account"] as! String == "2039482" && jvmRestoredPD["bic"] as! String == "TAK3940")
    }
    
    func createMakerInfoMessage(keyPair: KeyPair, takerPubKey: iosApp.PublicKey, swapId: Data, paymentDetails: [String : Any]) throws -> String {
        //Create message NSDictionary
        var message = [
            "sender": keyPair.interfaceId.base64EncodedString(),
            "recipient": takerPubKey.interfaceId.base64EncodedString(),
            "encryptedKey": nil,
            "encryptedIV": nil,
            "payload": nil,
            "signature": nil
        ]
        
        //Create Base-64 encoded string of swap id
        let swapIdString = swapId.base64EncodedString()
        
        //Create payload NSDictionary
        var payload = [
            "msgType": "makerInfo",
            "swapId": swapIdString,
            "paymentDetails": nil
        ]
        
        //Create payment details UTF-8 bytes and their Base64-encoded string
        let paymentDetailsUTF8Bytes = try JSONSerialization.data(withJSONObject: paymentDetails)
        
        //Set "paymentDetails" field of payload
        payload["paymentDetails"] = paymentDetailsUTF8Bytes.base64EncodedString()
        
        //Create payload UTF-8 bytes and their Base64-encoded string
        let payloadUTF8Bytes = try JSONSerialization.data(withJSONObject: payload)
        
        //Generate a new symmetric key and initialization vector, and encrypt the payload bytes
        let symmetricKey = try newSymmetricKey()
        let encryptedPayload = try symmetricKey.encrypt(data: payloadUTF8Bytes)
        
        //Set "payload" field of message
        message["payload"] = encryptedPayload.encryptedData.base64EncodedString()
        
        //Create signature of encrypted payload
        let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayload.encryptedData)
        var encryptedPayloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
            encryptedPayloadDataHashByteArray.append(byte)
        }
        let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
        let signature = try keyPair.sign(data: encryptedPayloadDataHash)
        
        //Set "signature" field of message
        message["signature"] = signature.base64EncodedString()
        
        //Encrypt symmetric key and initialization vector with taker's public key
        let encryptedKey = try takerPubKey.encrypt(clearData: symmetricKey.keyData)
        let encryptedIV = try takerPubKey.encrypt(clearData: encryptedPayload.initializationVectorData)
        
        //Set "encryptedKey" and "encryptedIV" fields of message
        message["encryptedKey"] = encryptedKey.base64EncodedString()
        message["encryptedIV"] = encryptedIV.base64EncodedString()
        
        //Prepare and return message string
        let messageString = String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
        return messageString
        
    }
    
    func parseMakerInfoMessage(messageString: String, keyPair: KeyPair, makerPubKey: iosApp.PublicKey, swapId: Data) throws -> [String : Any]? {
        //Restore message NSDictionary
        guard let messageData = messageString.data(using: String.Encoding.utf8) else {
            return nil
        }
        guard let message = try JSONSerialization.jsonObject(with: messageData) as? NSDictionary else {
            return nil
        }
        
        //Ensure that the sender is the maker and the recipient is the taker
        guard let senderInterfaceIdString = message["sender"] as? String, let senderInterfaceId = Data(base64Encoded: senderInterfaceIdString) else {
            return nil
        }
        guard makerPubKey.interfaceId == senderInterfaceId else {
            return nil
        }
        guard let recipientInterfaceIdString = message["recipient"] as? String, let recipientInterfaceId = Data(base64Encoded: recipientInterfaceIdString) else {
            return nil
        }
        guard keyPair.interfaceId == recipientInterfaceId else {
            return nil
        }
        
        //Restore signature
        guard let signatureString = message["signature"] as? String, let signature = Data(base64Encoded: signatureString) else {
            return nil
        }
        
        //Decode encrypted payload
        guard let encryptedPayloadString = message["payload"] as? String, let encryptedPayloadData = Data(base64Encoded: encryptedPayloadString) else {
            return nil
        }
        
        //Create hash of encrypted payload
        let encryptedPayloadDataDigest = SHA256.hash(data: encryptedPayloadData)
        var encryptedPayloadDataHashByteArray = [UInt8]()
        for byte: UInt8 in encryptedPayloadDataDigest.makeIterator() {
            encryptedPayloadDataHashByteArray.append(byte)
        }
        let encryptedPayloadDataHash = Data(bytes: encryptedPayloadDataHashByteArray, count: encryptedPayloadDataHashByteArray.count)
        
        //Verify signature
        guard try makerPubKey.verifySignature(signedData: encryptedPayloadDataHash, signature: signature) else {
            return nil
        }
        
        //Decrypt symmetric key, initialization vector and encrypted payload
        guard let encryptedKeyString = message["encryptedKey"] as? String, let encryptedKey = Data(base64Encoded: encryptedKeyString) else {
            return nil
        }
        let decryptedKeyBytes = try keyPair.decrypt(cipherData: encryptedKey)
        let symmetricKey = SymmetricKey(key: decryptedKeyBytes)
        guard let encryptedIVString = message["encryptedIV"] as? String, let encryptedIV = Data(base64Encoded: encryptedIVString) else {
            return nil
        }
        let decryptedIV = try keyPair.decrypt(cipherData: encryptedIV)
        let encryptedPayload = SymmetricallyEncryptedData(data: encryptedPayloadData, iv: decryptedIV)
        let decryptedPayloadData = try symmetricKey.decrypt(data: encryptedPayload)
        
        //Restore payload object
        guard let payload = try JSONSerialization.jsonObject(with: decryptedPayloadData) as? NSDictionary else {
            return nil
        }
        
        //Ensure the message is a maker info message
        guard let messageType = payload["msgType"] as? String else {
            return nil
        }
        guard messageType == "makerInfo" else {
            return nil
        }
        
        //Ensure that the swap id in the makerInfo message matches the swap in question
        guard let messageSwapIdString = payload["swapId"] as? String, let messageSwapId = Data(base64Encoded: messageSwapIdString) else {
            return nil
        }
        guard messageSwapId == swapId else {
            return nil
        }
        
        //Restore payment details object
        /*
        TODO: In production, we should know the sort of payment info we are looking for, try to deserialize that type exactly, and return null if the payment info is for a different payment method
         */
        guard let paymentDetailsString = payload["paymentDetails"] as? String, let paymentDetailsData = Data(base64Encoded: paymentDetailsString) else {
            return nil
        }
        guard let paymentDetails = try JSONSerialization.jsonObject(with: paymentDetailsData) as? [String : Any] else {
            return nil
        }
        return paymentDetails
    }
    
    func testMakerInfoParsing() throws {
        //Restore the maker's public and private key
        let makerPubKeyB64 = "MIIBCgKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQAB"
        let makerPrivKeyB64 = "MIIEogIBAAKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQABAoIBACWe/ZLfS4DG144x0lUNedhUPsuvXzl5NAj8DBXtcQ6TkZ51VN8TgsHrQ2WKwkKdVnZAzPnkEMxy/0oj5xG8tBL43RM/tXFUsUHJhpe3G9Xb7JprG/3T2aEZP/Sviy16QvvFWJWtZHq1knOIy3Fy/lGTJM/ymVciJpc0TGGtccDyeQDBxaoQrr1r4Q9q5CMED/kEXq5KNLmzbfB1WInQZJ7wQhtyyAJiXJxKIeR3hVGR1dfBJGSbIIgYA5sYv8HPnXrorU7XEgDWLkILjSNgCvaGOgC5B4sgTB1pmwPQ173ee3gbn+PCai6saU9lciXeCteQp9YRBBWfwl+DDy5oGsUCgYEA0TB+kXbUgFyatxI46LLYRFGYTHgOPZz6Reu2ZKRaVNWC75NHyFTQdLSxvYLnQTnKGmjLapCTUwapiEAB50tLSko/uVcf4bG44EhCfL4S8hmfS3uCczokhhBjR/tZxnamXb/T1Wn2X06QsPSYQQmZB7EoQ6G0u/K792YgGn/qh+cCgYEAweUWInTK5nIAGyA/k0v0BNOefNTvfgV25wfR6nvXM3SJamHUTuO8wZntekD/epd4EewTP57rEb9kCzwdQnMkAaT1ejr7pQE4RFAZcL86o2C998QS0k25fw5xUhRiOIxSMqK7RLkAlRsThel+6BzHQ+jHxB06te3yyIjxnqP576UCgYA7tvAqbhVzHvw7TkRYiNUbi39CNPM7u1fmJcdHK3NtzBU4dn6DPVLUPdCPHJMPF4QNzeRjYynrBXfXoQ3qDKBNcKyIJ8q+DpGL1JTGLywRWCcU0QkIA4zxiDQPFD0oXi5XjK7XuQvPYQoEuY3M4wSAIZ4w0DRbgosNsGVxqxoz+QKBgClYh3LLguTHFHy0ULpBLQTGd3pZEcTGt4cmZL3isI4ZYKAdwl8cMwj5oOk76P6kRAdWVvhvE+NR86xtojOkR95N5catwzF5ZB01E2e2b3OdUoT9+6F6z35nfwSoshUq3vBLQTGzXYtuHaillNk8IcW6YrbQIM/gsK/Qe+1/O/G9AoGAYJhKegiRuasxY7ig1viAdYmhnCbtKhOa6qsq4cvI4avDL+Qfcgq6E8V5xgUsPsl2QUGz4DkBDw+E0D1Z4uT60y2TTTPbK7xmDs7KZy6Tvb+UKQNYlxL++DKbjFvxz6VJg17btqid8sP+LMhT3oqfRSakyGS74Bn3NBpLUeonYkQ="
        let makerPubKeyBytes = Data(base64Encoded: makerPubKeyB64)!
        let makerPrivKeyBytes = Data(base64Encoded: makerPrivKeyB64)!
        let makerKeyPair = try KeyPair(publicKeyBytes: makerPubKeyBytes, privateKeyBytes: makerPrivKeyBytes)
        let makerPublicKey = try PublicKey(publicKeyBytes: makerPubKeyBytes)
        
        //Restore the takers's public and private key
        let takerPubKeyB64 = "MIIBCgKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQAB"
        let takerPrivKeyB64 = "MIIEowIBAAKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQABAoIBADez/Kue3qkNILMbxrSzmdFEIaVPeP6xYUN3xi7ny2F9UQGH8smyTq4Y7D+mru/hF2ihhi2tWu/87w458QS/i8qYy3G/OeQABH03oCEauC6bodXvT9aSJg89cNZL3qcxHbZLAOkfUoWW/EBDyw5yDXVttHF6Dh491JKfoOELTamWD4KxIScR/Nf6ih6UqB/SwmLz1X5+fZpW4iGZXIRsPzOzDtDmoSGajNXoi0Ln2x9DkUeXpx9r7TTT9DBT0jTLbCUiB3LYU4I/VR6upm0bDUKKRi9VTkQjOAV5rD3qdoraPVRCSzjUVqCwL7jqfunXsG/hhRccD+Di5pXaCuPeOsECgYEA3p4LLVHDzLhF269oUcvflMoBUVKo9UNHL/wmyujdV+RwFi5J2sxVLgKHsdKHCy7FdrDmxax7Mrgh57KS3+zfdDhs98w181JLwgFxzEAxIP2PnHd4P3NEbxCxnxhILW4fEotUVzJWjjhEHXe5QhOW2z2yIZIOEqBzFfRx33kWrbMCgYEAzaUrDMaTkIkOoVI7BbNS7n5CBWL/DaPOID1UiL4eHWngeoOwaeI+CB0cxSrxngykue0xM3aI3KVFaeIYSdn7DZAxWAS3U143VApgLxgLyxZBtVX18HYiTZQx/PiTczMH6kFA5z0L7iNlf0uQrQQJgDzM6QY0kKasufoss+Baj9ECgYA1BjvvTXxvtKyfCQa2BPN6QytRLXklAiNgoJS03AZsuvKfteLNhMH9NYkQp+6WkUtjW/t7tfuaNxWMVJJ7V7ZZvl7mHvPywvVcfm+WkOuiygJ86E/x/Qid08Ia/POkLoikKB+srUbElU5UHoI35OaXzfgx2tITSbhf0FuXOQZX1QKBgAj7A4xFR8ByG89ztdwj3qVHoj51+klwM9o4k259Tvdd3k27XoLhPHBCRTVfELokNzVfZFyo+oUYOpXLJ+BhwpLvDxiW7CKZ5LSo11Z3KFywFiKDJIBhyFG2/Q/dEyNewSO7wcfXZKP7q70JYcIMgRW2kgRDHxyKCtT8VeNtEsdhAoGBAJHzNruW/ZS31o0rvQxHu8tBcd8osTsPNZBhuHs60mbPFRHwBaU8JSofl4XjR8B7K9vjYtxVYMEsIX6NqNf1JMXGDva/cTCHXyPuiCnuUMbHkK0YpsFxQABwYA+sOSlujwJwMNPu4ylzHL1HDyv9m4x74/NM20zDFW6MB/zD6G0c"
        let takerPubKeyBytes = Data(base64Encoded: takerPubKeyB64)!
        let takerPrivKeyBytes = Data(base64Encoded: takerPrivKeyB64)!
        let takerKeyPair = try KeyPair(publicKeyBytes: takerPubKeyBytes, privateKeyBytes: takerPrivKeyBytes)
        let takerPublicKey = try PublicKey(publicKeyBytes: takerPubKeyBytes)
        
        //Restore swap id
        let swapId = Data(base64Encoded: "9tGMGTr0SbuySqE0QOsAMQ==")!
        
        //Create payment details
        let paymentDetails = [
            "name": "USD-SWIFT",
            "beneficiary": "Make Ker",
            "account": "2039482",
            "bic": "MAK3940"
        ]
        
        //Create maker info message string
        let swiftMakerInfoMessageString = try! createMakerInfoMessage(keyPair: makerKeyPair, takerPubKey: takerPublicKey, swapId: swapId, paymentDetails: paymentDetails)
        print(swiftMakerInfoMessageString)
        
        //A maker info message string generated by JVM code
        let jvmMakerInfoMessageString = #"{"sender":"gXE4i2ZrzX+QK5AdNalVTpU1tJoIA9sEMca6uRfiRSE=","recipient":"HpIWD/7nBJ3VP+yQ2WYfh2lq5/uCLAkbkNIJ3FFJ2oc=","encryptedKey":"mnNL1n06QkPSotloyrSiUeRLJjAuKxZnLzorw/zG9211mG/kJl11OZd6Y+lP39zM4EGGeArTWB1Yl2kTGuOGrw6HBFH0VfWUCFLKD7A6Ado7bFUdlr5VSUkFork+YaY1pgkmlQFIYJ2B0nCk2vzNj1uBLn/UtP2X9WMIPHOuLpTJk1abp8uY7U6v54EcFReWNWWV1Hk6xofFH/E2VM7fscuuglPAzPW1EY6oWQ/xJvmrhujdokDVRzh9veEnKGyDHXIfjyj/c+F3lEs4ja282MHkOQQUR83edq6wxhUWoe69zGSlAtv9CCv6Q46jX1a7wbDkL1elMyX5ZpWOe/an+w==","encryptedIV":"b+RRR9UPERMFqkzflTV5gD1THt3g20neQuD+6sRfZTHswhUzOlYghJ0JQY5ghZWqoYXv9wtT/JXt4dU43n+1cpXmg+fnwS5oO+znExMT6TRACZf+7czXooGGb/LJj85yWK6Rk3cYrDjl0OirGbji2/lPe/1PAYPxntWpE6z3x2MQg5S5FuN1szIPCOpkuLsdrZgIH9Y3btEL8TFprGjR1ALEcfMe93oQByYHmy2Cuc65Os4jVhDS3sj6sz/M6qtMo61//lYUITohdhpz5vhlp8LTumxgmMl+e9f09CCcTWPefCJordEmPQrT3eAN2Aza6kmO/biZJtrwxKSloKBCvA==","payload":"UrTgL1qBtD11q/zFjr3IAJFJXHhcjj191/1LAz8l4FHZ+Hzd4hLAazg0YPh+4FLCb0t5yUVM8G3uz0qOtVBMcSB/VBb5aGXkiRGifvmbdSJGT6Y2dQoETGJnNqLo1EfFjW4tXGcNVZ588LPSpo6pAZ/39zipcnmYv8VIjbz1PZbsnbI97L8FcQ6mgvaEiNz32QHQfGULgBA1wcGzyDRd4B6rmADJpD7s4mqL5Pg5MoHTt/ea0qhdYfCUUtY74XULbPJbpOyI3PyLWSLcb3H2j7yR1/QsOCoB+RLGXOjnhfWK4S4HQN6gmF1+DYIIsJsJP8fCidhSrUpeyROS8EnAhNlDZ5jSgKqVfK85b29/od6zsbLlQr7ptpU/BOYJ3oKJ","signature":"nG6K9w06FJlOZSmih3Bs1AekEL8HLCZBUclhPyGX93kmLBW1ewYUkhNJrNGvv3Gvd1En2gV1oSHn6WHruFDXxHBD2BMxMo4P5+WOprAnU00ZIJcOeg51ixppeZ3UeSDzG5gAMU7NQrEgGg5BvDNzXy5KS2Xs4JCqpADesD+9WzyKUpcjLa40GTc6coiR9HUPUdNuHQOdjVUZhlOmvnnlt+2hGdEaChQCBT5RpZ5zAAPycQsiuNzsPJItN2n1Ihw10oOcy19wUzprs9XqPRrGpXT3aNGIbmE8DLylNWOoUlcPgWD+GQWOwaTarhnL1GYeF1305DghDIGUa8szpQpNRQ=="}"#
        
        //Attempt to parse maker info message string generated by Swift code
        let swiftRestoredPaymentDetails = try! parseMakerInfoMessage(messageString: swiftMakerInfoMessageString, keyPair: takerKeyPair, makerPubKey: makerPublicKey, swapId: swapId)
        
        //Attempt to parse maker info message string generated by JVM code
        let jvmRestoredPaymentDetails = try! parseMakerInfoMessage(messageString: jvmMakerInfoMessageString, keyPair: takerKeyPair, makerPubKey: makerPublicKey, swapId: swapId)
        
        //Check that original and restored payment details are identical
        let swiftRPD = swiftRestoredPaymentDetails!
        let jvmRPD = jvmRestoredPaymentDetails!
        XCTAssert(swiftRPD["name"] as! String == "USD-SWIFT" && swiftRPD["beneficiary"] as! String == "Make Ker" && swiftRPD["account"] as! String == "2039482" && swiftRPD["bic"] as! String == "MAK3940")
        XCTAssert(jvmRPD["name"] as! String == "USD-SWIFT" && jvmRPD["beneficiary"] as! String == "Make Ker" && jvmRPD["account"] as! String == "2039482" && jvmRPD["bic"] as! String == "MAK3940")
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
