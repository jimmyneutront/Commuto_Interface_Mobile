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
    
    // The number of the last parsed block
    private var lastParsedBlockNum: BigUInt = BigUInt.zero
    
    private func setLastParsedBlockNumber(_ blockNumber: BigUInt) {
        lastParsedBlockNum = blockNumber
    }
    
    // The number of the newest block
    private var newestBlockNum: BigUInt = BigUInt.zero
    
    // The number of milliseconds that BlockchainService should wait after parsing a block
    private var listenInterval: UInt32 = 30
    
    // The thread in which BlockchainService listens to the blockchain
    private var listenThread: Thread?
    
    // Web3Swift web3 instance
    private var w3 = web3(provider: Web3HttpProvider(URL(string: "http://192.168.1.13:8545")!)!)
    
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
            newestBlockNum = try! getNewestBlockNumberPromise().wait()
            if newestBlockNum > lastParsedBlockNum {
                let block = try! getBlockPromise(blockNumber: lastParsedBlockNum + BigUInt.init(integerLiteral: 1)).wait()
                parseBlock(block)
                setLastParsedBlockNumber(block.number)
            }
            sleep(listenInterval)
        }
    }
    
    private func getNewestBlockNumberPromise() -> Promise<BigUInt> {
        return w3.eth.getBlockNumberPromise()
    }
    
    private func getBlockPromise(blockNumber: BigUInt) -> Promise<Block> {
        return w3.eth.getBlockByNumberPromise(blockNumber, fullTransactions: false)
    }
    
    private func parseBlock(_ block: Block) {
        for tx in block.transactions {
            
        }
    }
    
}
