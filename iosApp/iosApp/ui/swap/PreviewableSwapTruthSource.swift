//
//  PreviewableSwapTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 A `UISwapTruthSource` implementation used for previewing user interfaces.
 */
class PreviewableSwapTruthSource: UISwapTruthSource {
    /**
     Initializes a new `PreviewableSwapTruthSource` with sample swaps.
     */
    init() {
        swaps = Swap.sampleSwaps
    }
    
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swap`s, which is the single source of truth for all swap-related data.
     */
    @Published var swaps: [UUID : Swap]
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func fillSwap(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func createApproveTokenTransferToFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func approveTokenTransferToFillSwap(
        swap: Swap,
        approveTokenTransferToFillSwapTransaction: EthereumTransaction?
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func createFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func fillSwap(
        swap: Swap,
        swapFillingTransaction: EthereumTransaction?
    ) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentSent(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func createReportPaymentSentTransaction(swap: Swap, createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void ) {}

    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentSent(swap: Swap, reportPaymentSentTransaction: EthereumTransaction?) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentReceived(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func createReportPaymentReceivedTransaction(swap: Swap, createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void ) {}

    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentReceived(swap: Swap, reportPaymentReceivedTransaction: EthereumTransaction?) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func closeSwap(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func createCloseSwapTransaction(swap: Swap, createdTransactionHandler: @escaping (EthereumTransaction) -> Void, errorHandler: @escaping (Error) -> Void ) {}

    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func closeSwap(swap: Swap, closeSwapTransaction: EthereumTransaction?) {}
    
}
