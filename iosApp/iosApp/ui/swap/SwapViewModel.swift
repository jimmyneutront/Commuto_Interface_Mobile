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
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to fill.
     */
    func fillSwap(
        swap: Swap
    ) {
        setFillingSwapState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("fillSwap: filling \(swap.id.uuidString)")
                swapService.fillSwap(
                    swapToFill: swap,
                    afterPossibilityCheck: { self.setFillingSwapState(swap: swap, state: .approving) },
                    afterTransferApproval: { self.setFillingSwapState(swap: swap, state: .filling) }
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
     Attempts to report that a buyer has sent fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the buyer in `swap`.
     
     - Parameter swap: The `Swap` for which to report sending payment.
     */
    func reportPaymentSent(
        swap: Swap
    ) {
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
        }
    }
    
    /**
     Attempts to report that a seller has received fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the seller in `swap`.
     
     - Parameter swap: The `Swap` for which to report receiving payment.
     */
    func reportPaymentReceived(
        swap: Swap
    ) {
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
        }
    }
    
}
