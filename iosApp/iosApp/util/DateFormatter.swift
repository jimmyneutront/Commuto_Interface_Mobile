//
//  DateFormatter.swift
//  iosApp
//
//  Created by jimmyt on 12/31/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A struct containing utility methods for formatting dates.
 */
struct DateFormatter {
    /**
     Creates a `String` representation of `Date` in the form "yyyy-MM-dd'T'HH:mm'Z'" where Z indicates that this date and time stamp is in the UTC time zone.
     */
    static func createDateString(_ date: Date) -> String {
        return ISO8601DateFormatter().string(from: date)
    }
}
