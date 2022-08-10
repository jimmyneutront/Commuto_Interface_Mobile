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
struct SwapsView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(Swap.sampleSwaps.map { $0.1 }, id: \.id) { swap in
                    NavigationLink(destination: Text(swap.id.uuidString)) {
                        SwapCardView(
                            swapDirection: swap.direction.string,
                            stablecoinCode: "STBL"
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
        SwapsView()
    }
}