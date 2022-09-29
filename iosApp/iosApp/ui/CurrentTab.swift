//
//  CurrentTab.swift
//  iosApp
//
//  Created by jimmyt on 8/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates which tab view should be displayed to the user.
 */
enum CurrentTab {
    /**
     Indicates that `OffersView` should be displayed to the user.
     */
    case offers
    /**
     Indicates that `SwapsView` should be displayed to the user.
     */
    case swaps
    /**
     Indicates that `SettlementMethodsView` should be displayed to the user.
     */
    case settlementMethods
}
