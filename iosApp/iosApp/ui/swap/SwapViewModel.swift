//
//  SwapViewModel.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import PromiseKit
import web3swift

/**
 The Swap View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class SwapViewModel: UISwapTruthSource {
    
    /**
     Initializes a new `SwapViewModel`.
     */
    init(swapService: SwapService) {
        self.swapService = swapService
        swaps = Swap.sampleSwaps
    }
    
    /**
     SwapViewModel's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "SwapViewModel")
    
    /**
     The `SwapService` used for completing the swap process for `Swap`s in `swaps`.
     */
    let swapService: SwapService
    
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swaps`s, which is the single source of truth for all swap-related data.
     */
    var swaps: [UUID : Swap] = [:]
    
    /**
     Sets the `fillingSwapState` property of `swap` to `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` of which to set the `fillingSwapState`.
        - state: The value to which `swap`'s `fillingSwapState` will be set.
     */
    private func setFillingSwapState(swap: Swap, state: FillingSwapState) {
        DispatchQueue.main.async {
            swap.fillingSwapState = state
        }
    }
    
    /**
     Sets the `reportingPaymentSentState` property of `swap` to `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` of which to set the `reportingPaymentSentState`.
        - state: The value to which `swap`'s `reportingPaymentSentState` will be set.
     */
    private func setReportingPaymentSentState(swap: Swap, state: ReportingPaymentSentState) {
        DispatchQueue.main.async {
            swap.reportingPaymentSentState = state
        }
    }
    
    /**
     Sets the `reportingPaymentReceivedState` property of `swap` to `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` of which to set the `reportingPaymentReceivedState`.
        - state: The value to which `swap`'s `reportingPaymentReceivedState` will be set.
     */
    private func setReportingPaymentReceivedState(swap: Swap, state: ReportingPaymentReceivedState) {
        DispatchQueue.main.async {
            swap.reportingPaymentReceivedState = state
        }
    }
    
    /**
     Sets the `closingSwapState` property of `swap` to `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` of which to set the `closingSwapState`.
        - state: The value to which `swap`'s `closingSwapState` will be set.
     */
    private func setClosingSwapState(swap: Swap, state: ClosingSwapState) {
        DispatchQueue.main.async {
            swap.closingSwapState = state
        }
    }
    
    /**
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to fill.
     */
    @available(*, deprecated, message: "Use new transaction pipeline")
    func fillSwap(
        swap: Swap
    ) {
        //setFillingSwapState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("fillSwap: filling \(swap.id.uuidString)")
                swapService.fillSwap(
                    swapToFill: swap,
                    afterPossibilityCheck: { /*self.setFillingSwapState(swap: swap, state: .approving)*/ },
                    afterTransferApproval: { /*self.setFillingSwapState(swap: swap, state: .filling)*/ }
                ).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("fillSwap: successfully filled \(swap.id.uuidString)")
            setFillingSwapState(swap: swap, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("fillSwap: got error during fillSwap call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.fillingSwapError = error
            setFillingSwapState(swap: swap, state: .error)
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` to approve a token transfer in order to fill a swap.
     
     This passes `swap` to `SwapService.createFillSwapTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`,
     
     - Parameter swap: The `Swap` to be filled.
     */
    func createApproveTokenTransferToFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createApproveTokenTransferToTakeOfferTransaction: creating for \(swap.id.uuidString)")
                swapService.createFillSwapTransaction(swap: swap).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to approve a token transfer in order to fill a swap.
     
     This clears `swap`'s `Swap.approvingToFillError` property and sets its `Swap.approvingToFillState` to `TokenTransferApprovalState.validating`, and then passes all data to `swapService`'s `SwapService.approveTokenTransferToFillSwap` function. When this function returns, this sets `swap`'s `SwapService.approvingToFillState` to `TokenTransferApprovalState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - swap: The `Swap` to be filled.
        - approveTokenTransferToFillSwapTransaction: An optional `EthereumTransaction` that can create a token transfer allowance of the taken swap amount of the token specified by `swap`.
     */
    func approveTokenTransferToFillSwap(
        swap: Swap,
        approveTokenTransferToFillSwapTransaction: EthereumTransaction?
    ) {
        swap.approvingToFillError = nil
        swap.approvingToFillState = .validating
        logger.notice("approveTokenTransferToFillSwap: approving for \(swap.id.uuidString)")
        swapService.approveTokenTransferToFillSwap(
            swapToFill: swap,
            approveTokenTransferToFillSwapTransaction: approveTokenTransferToFillSwapTransaction
        ).done(on: DispatchQueue.main) { _ in
            self.logger.notice("approveTokenTransferToFillSwap: successfully approved transfer for \(swap.id.uuidString)")
            swap.approvingToFillState = .awaitingTransactionConfirmation
        }.catch(on: DispatchQueue.main) { error in
            self.logger.notice("approveTokenTransferToFillSwap: got error during call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.approvingToFillError = error
            swap.approvingToFillState = .error
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that can fill `swap` (which should be a maker-as-seller swap made by the user of this interface) by calling [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap).
     
     This passes `swap` to `swapService`'s `SwapService.createFillSwapTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - swap: The `Swap` to be filled.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createFillSwapTransaction: creating for \(swap.id.uuidString)")
                swapService.createFillSwapTransaction(swap: swap).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     This clears the swap-filling-related `Error` of `swap` and sets `swap`'s `Swap.fillingSwapState` to `FillingSwapState.validating`, and then passes all data to `swapService`'s `SwapService.fillSwap` function.
     
     - Parameters:
        - swap: The `Swap` to be filled.
        - swapFillingTransaction: An optional `EthereumTransaction` can fill `swap`.
     */
    func fillSwap(
        swap: Swap,
        swapFillingTransaction: EthereumTransaction?
    ) {
        swap.fillingSwapError = nil
        swap.fillingSwapState = .validating
        logger.notice("fillSwap: filling \(swap.id.uuidString)")
        swapService.fillSwap(
            swap: swap,
            swapFillingTransaction: swapFillingTransaction
        ).done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
            self.logger.notice("fillSwap: successfully sent transaction for \(swap.id.uuidString)")
        }.catch(on: DispatchQueue.main) { error in
            self.logger.error("fillSwap: got error during call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.fillingSwapError = error
            swap.fillingSwapState = .error
        }
    }
    
    /**
     Attempts to report that a buyer has sent fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the buyer in `swap`.
     
     - Parameter swap: The `Swap` for which to report sending payment.
     */
    @available(*, deprecated, message: "Use new transaction pipeline")
    func reportPaymentSent(
        swap: Swap
    ) {
        /*
        setReportingPaymentSentState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("reportPaymentSent: reporting for \(swap.id.uuidString)")
                swapService.reportPaymentSent(
                    swap: swap,
                    afterPossibilityCheck: { self.setReportingPaymentSentState(swap: swap, state: .reporting) }
                ).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("reportPaymentSent: successfully reported for \(swap.id.uuidString)")
            setReportingPaymentSentState(swap: swap, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("reportPaymentSent: got error during reportPaymentSent call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.reportingPaymentSentError = error
            setReportingPaymentSentState(swap: swap, state: .error)
        }*/
    }
    
    /**
     Attempts to create an `EthereumTransaction` to call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`, for which the user of this interface should be the buyer.
     
     This passes `swap` to `SwapService.createReportPaymentSentTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createReportPaymentSentTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createReportPaymentSentTransaction: creating for \(swap.id.uuidString)")
                swapService.createReportPaymentSentTransaction(swap: swap).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the buyer.
     
     This clears the reporting-payment-sent-related `Error` of `swap` and sets `swap`'s `Swap.reportingPaymentSentState` to `ReportingPaymentSentState.validating`, and then passes all data to `swapService`'s `SwapService.reportPaymentSent` function.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
        - reportPaymentSentTransaction: An optional `EthereumTransaction` that will call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`.
     */
    func reportPaymentSent(
        swap: Swap,
        reportPaymentSentTransaction: EthereumTransaction?
    ) {
        swap.reportingPaymentSentError = nil
        swap.reportingPaymentSentState = .validating
        DispatchQueue.global(qos: .userInitiated).sync {
            logger.notice("reportPaymentSent: reporting for \(swap.id.uuidString)")
        }
        swapService.reportPaymentSent(swap: swap, reportPaymentSentTransaction: reportPaymentSentTransaction)
            .done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("reportPaymentSent: successfully broadcast transaction for \(swap.id.uuidString)")
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("reportPaymentSent: got error during reportPaymentSent call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
                DispatchQueue.main.sync {
                    swap.reportingPaymentSentError = error
                    swap.reportingPaymentSentState = .error
                }
            }
    }
    
    /**
     Attempts to report that a seller has received fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the seller in `swap`.
     
     - Parameter swap: The `Swap` for which to report receiving payment.
     */
    @available(*, deprecated, message: "Use new transaction pipeline")
    func reportPaymentReceived(
        swap: Swap
    ) {
        /*
        setReportingPaymentReceivedState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("reportPaymentReceived: reporting for \(swap.id.uuidString)")
                swapService.reportPaymentReceived(
                    swap: swap,
                    afterPossibilityCheck: { self.setReportingPaymentReceivedState(swap: swap, state: .reporting) }
                ).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("reportPaymentReceived: successfully reported for \(swap.id.uuidString)")
            setReportingPaymentReceivedState(swap: swap, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("reportPaymentReceived: got error during reportPaymentReceived call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.reportingPaymentReceivedError = error
            setReportingPaymentReceivedState(swap: swap, state: .error)
        }*/
    }
    
    /**
     Attempts to create an `EthereumTransaction` to call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`, for which the user of this interface should be the seller.
     
     This passes `swap` to `SwapService.createReportPaymentReceivedTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createReportPaymentReceivedTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createReportPaymentReceivedTransaction: creating for \(swap.id.uuidString)")
                swapService.createReportPaymentReceivedTransaction(swap: swap).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the seller.
     
     This clears the reporting-payment-received-related `Error` of `swap` and sets `swap`'s `Swap.reportingPaymentReceivedState` to `ReportingPaymentReceivedState.validating`, and then passes all data to `swapService`'s `SwapService.reportPaymentReceived` function.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
        - reportPaymentReceivedTransaction: An optional `EthereumTransaction` that will call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`.
     */
    func reportPaymentReceived(
        swap: Swap,
        reportPaymentReceivedTransaction: EthereumTransaction?
    ) {
        swap.reportingPaymentReceivedError = nil
        swap.reportingPaymentReceivedState = .validating
        DispatchQueue.global(qos: .userInitiated).sync {
            logger.notice("reportPaymentReceived: reporting for \(swap.id.uuidString)")
        }
        swapService.reportPaymentReceived(swap: swap, reportPaymentReceivedTransaction: reportPaymentReceivedTransaction)
            .done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("reportPaymentReceived: successfully broadcast transaction for \(swap.id.uuidString)")
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("reportPaymentReceived: got error during reportPaymentReceived call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
                DispatchQueue.main.sync {
                    swap.reportingPaymentReceivedError = error
                    swap.reportingPaymentReceivedState = .error
                }
            }
    }
    
    /**
     Attempts to close a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to close.
     */
    @available(*, deprecated, message: "Use new transaction pipeline")
    func closeSwap(
        swap: Swap
    ) {
        /*
        setClosingSwapState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("closeSwap: closing \(swap.id.uuidString)")
                swapService.closeSwap(
                    swap: swap,
                    afterPossibilityCheck: { /*self.setReportingPaymentReceivedState(swap: swap, state: .reporting)*/ }
                ).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("closeSwap: successfully closed \(swap.id.uuidString)")
            setClosingSwapState(swap: swap, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("closeSwap: got error during closeSwap call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.closingSwapError = error
            setClosingSwapState(swap: swap, state: .error)
        }*/
    }
    
    /**
     Attempts to create an `EthereumTransaction` to call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for `swap`, for which the user of this interface should be the seller.
     
     This passes `swap` to `SwapService.createCloseSwapTransaction` and then passes the resulting transaction to `createdTransactionHandler` or error to `errorHandler`.
     
     - Parameters:
        - swap: The `Swap` for which [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
        - createdTransactionHandler: An escaping closure that will accept and handle the created `EthereumTransaction`.
        - errorHandler: An escaping closure that will accept and handle any error that occurs during the transaction creation process.
     */
    func createCloseSwapTransaction(
        swap: Swap,
        createdTransactionHandler: @escaping (EthereumTransaction) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        Promise<EthereumTransaction> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createCloseSwapTransaction: creating for \(swap.id.uuidString)")
                swapService.createCloseSwapTransaction(swap: swap).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.main) { createdTransaction in
            createdTransactionHandler(createdTransaction)
        }.catch(on: DispatchQueue.main) { error in
            errorHandler(error)
        }
    }
    
    /**
     Attempts to call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the seller.
     
     This clears the swap-closing`Error` of `swap` and sets `swap`'s `Swap.closingSwapState` to `ClosingSwapState.validating`, and then passes all data to `swapService`'s `SwapService.closeSwap` function.
     
     - Parameters:
        - swap: The `Swap` for which [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
        - closeSwapTransaction: An optional `EthereumTransaction` that will call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for `swap`.
     */
    func closeSwap(
        swap: Swap,
        closeSwapTransaction: EthereumTransaction?
    ) {
        swap.closingSwapError = nil
        swap.closingSwapState = .validating
        DispatchQueue.global(qos: .userInitiated).sync {
            logger.notice("closeSwap: reporting for \(swap.id.uuidString)")
        }
        swapService.closeSwap(swap: swap, closeSwapTransaction: closeSwapTransaction)
            .done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("closeSwap: successfully broadcast transaction for \(swap.id.uuidString)")
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("closeSwap: got error during closeSwap call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
                DispatchQueue.main.sync {
                    swap.closingSwapError = error
                    swap.closingSwapState = .error
                }
            }
    }
    
}
