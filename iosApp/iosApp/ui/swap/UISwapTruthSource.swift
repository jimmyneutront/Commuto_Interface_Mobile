//
//  UISwapTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data in an application with a graphical user interface.
 */
protocol UISwapTruthSource: SwapTruthSource, ObservableObject {
    
    /**
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to fill.
     */
    func fillSwap(swap: Swap)
    
    /**
     Attempts to report that a buyer has sent fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the buyer in `swap`.
     
     - Parameter swap: The `Swap` to fill.
     */
    @available(*, deprecated, message: "Use the new offer pipeline with improved transaction state management")
    func reportPaymentSent(swap: Swap)
    
    /**
     Attempts to create an `EthereumTransaction` to call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`, for which the user of this interface should be the buyer.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createReportPaymentSentTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the buyer.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
        - reportPaymentSentTransaction: An optional `EthereumTransaction` that will call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`.
     */
    func reportPaymentSent(
        swap: Swap,
        reportPaymentSentTransaction: EthereumTransaction?
    )
    
    /**
     Attempts to report that a seller has received fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the seller in `swap`.
     
     - Parameter swap: The `Swap` to fill.
     */
    @available(*, deprecated, message: "Use the new transaction pipeline with improved transaction state management")
    func reportPaymentReceived(swap: Swap)
    
    /**
     Attempts to create an `EthereumTransaction` to call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`, for which the user of this interface should be the seller.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createReportPaymentReceivedTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
    
    /**
     Attempts to call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the buyer.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
        - reportPaymentSentTransaction: An optional `EthereumTransaction` that will call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`.
     */
    func reportPaymentReceived(
        swap: Swap,
        reportPaymentReceivedTransaction: EthereumTransaction?
    )
    
    /**
     Attempts to close a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to close.
     */
    func closeSwap(swap: Swap)
}
