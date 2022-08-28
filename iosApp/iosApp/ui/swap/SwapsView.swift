//
//  SwapsView.swift
//  iosApp
//
//  Created by jimmyt on 8/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Displays the main list of offers as `SwapCardView`s in a `List` within a `NavigationView`
 */
struct SwapsView<TruthSource>: View where TruthSource: UISwapTruthSource {
    
    /**
     An object adopting the `UISwapTruthSource` protocol that acts as a single source of truth for all swap-related data.
     */
    @ObservedObject var swapTruthSource: TruthSource
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information. Defaults to `StablecoinInformationRepository.hardhatStablecoinInfoRepo` if no other value is provided.
     */
    let stablecoinInformationRepository = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    var body: some View {
        NavigationView {
            List {
                ForEach(swapTruthSource.swaps.map { $0.1 }, id: \.id) { swap in
                    NavigationLink(destination: SwapView(swap: swap)) {
                        SwapCardView(
                            swapDirection: swap.direction.string,
                            stablecoinCode: stablecoinInformationRepository.getStablecoinInformation(chainID: swap.chainID, contractAddress: swap.stablecoin)?.currencyCode ?? "Unknown Stablecoin"
                        )
                    }
                }
            }
            .navigationTitle(Text("Swaps", comment: "Appears as a title above the list of swaps"))
        }
    }
}

/**
 Displays a preview of `SwapsView`
 */
struct SwapsView_Previews: PreviewProvider {
    static var previews: some View {
        SwapsView(
            swapTruthSource: PreviewableSwapTruthSource()
        )
    }
}
