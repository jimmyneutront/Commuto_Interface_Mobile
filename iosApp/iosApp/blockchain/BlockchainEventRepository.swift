//
//  OfferEventRepository.swift
//  iosApp
//
//  Created by jimmyt on 6/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 A wrapper around an array of blockchain events.
 
 - Properties:
    - events: The `Array` of events that this class wraps.
 */
class BlockchainEventRepository<EventType: Equatable> {
    /**
     The `Array` of events that this class wraps.
     */
    private var events: Array<EventType> = []
    
    /**
     Appends a new `EventType` to the `Array` that this class wraps.
     
     - Parameter element: The `EventType` to be appended.
     */
    func append(_ element: EventType) {
        events.append(element)
    }
    
    /**
     Removes all elements equal to the passed element from `events`.
     
     - Parameter elementToRemove: An `EventType` that will be compared to each element in `events`. If an element is equal to `elementToRemove`, then that element will be removed from `events`.
     */
    func remove(_ elementToRemove: EventType) {
        for (index, element) in events.enumerated() {
            if elementToRemove == element {
                events.remove(at: index)
            }
        }
    }
}
