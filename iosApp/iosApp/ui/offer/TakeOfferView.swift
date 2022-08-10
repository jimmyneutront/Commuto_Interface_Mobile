//
//  TakeOfferView.swift
//  iosApp
//
//  Created by jimmyt on 8/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Allows the user to specify a stablecoin amount, select a settlement method and take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct TakeOfferView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Take Offer")
                .font(.title)
                .bold()
            Spacer()
            Button(
                action: {},
                label: {
                    Text("Take Offer")
                        .font(.largeTitle)
                        .bold()
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary, lineWidth: 3)
                        )
                }
            )
            .accentColor(Color.primary)
        }
        .padding()
    }
}

struct TakeOfferView_Previews: PreviewProvider {
    static var previews: some View {
        TakeOfferView()
    }
}
