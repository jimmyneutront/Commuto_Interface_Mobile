//
//  SettlementMethodService.swift
//  iosApp
//
//  Created by jimmyt on 10/2/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import PromiseKit

/**
 The main Settlement Method Service. It is responsible for validating, adding, editing, and removing the user's settlement methods and their corresponding private data, both in persistent storage and in a `UISettlementMethodTruthSource`.
 */
class SettlementMethodService<_SettlementMethodTruthSource> where _SettlementMethodTruthSource: UISettlementMethodTruthSource {
    
    /**
     Initializes a new `SettlementMethodService` object.
     
     - Parameter databaseService: The `DatabaseService` that this ``
     */
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }
    
    /**
     `SettlementMethodService`'s `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "SettlementMethodService")
    
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    var settlementMethodTruthSource: _SettlementMethodTruthSource? = nil
    
    /**
     The `DatabaseService` that this uses for persistent storage.
     */
    let databaseService: DatabaseService
    
    /**
     Attempts to add a `SettlementMethod` with corresponding `PrivateData` the list of the user's settlement methods.
     
     On the global `DispatchQueue`, this ensures that the supplied private data corresponds to the type of settlement method that the user is adding. Then this serializes the supplied `PrivateData` accordingly, and associates it with the supplied `SettlementMethod`. Then this securely stores the new `SettlementMethod` and associated serialized private data in persistent storage, via `databaseService`. Finally, on the main `DispatchQueue`, this appends the new `SettlementMethod` to the array of settlement methods in `settlementMethodTruthSource`.
     
     - Parameters:
        - settlementMethod: The `SettlementMethod` to be added.
        - newPrivateData: The `PrivateData` for the new settlement method.
        - afterSerialization: A closure that will be executed after `newPrivateData` has been serialized.
        - afterPersistentStorage: A closure that will be executed after `settlementMethod` is saved in persistent storage.
     
     - Returns: An empty promise that will be fulfilled when the settlement-method-adding process is complete.
    
     - Throws: A `SettlementMethodServiceError.privateDataSerializationError` if `newPrivateData` cannot be cast as a type of private data corresponding to the type specified in `settlementMethod`, or if serialization fails, or a `SettlementMethodServiceError.unexpectedNilError` if `settlementMethodTruthSource` is `nil`.
     */
    func addSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        afterSerialization: (() -> Void)? = nil,
        afterPersistentStorage: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<SettlementMethod> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    self.logger.notice("addSettlementMethod: adding \(settlementMethod.id)")
                    do {
                        var settlementMethod = settlementMethod
                        
                        if settlementMethod.method == "SEPA" {
                            guard let privateSEPAData = newPrivateData as? PrivateSEPAData else {
                                throw SettlementMethodServiceError.privateDataSerializationError(desc: "Unable to serialize SEPA data")
                            }
                            settlementMethod.privateData = String(decoding: try JSONEncoder().encode(privateSEPAData), as: UTF8.self)
                        } else if settlementMethod.method == "SWIFT" {
                            guard let privateSWIFTData = newPrivateData as? PrivateSWIFTData else {
                                throw SettlementMethodServiceError.privateDataSerializationError(desc: "Unable to serialize SWIFT data")
                            }
                            settlementMethod.privateData = String(decoding: try JSONEncoder().encode(privateSWIFTData), as: UTF8.self)
                        } else {
                            throw SettlementMethodServiceError.privateDataSerializationError(desc: "Did not recognize settlement method")
                        }
                        if let afterSerialization = afterSerialization {
                            afterSerialization()
                        }
                        seal.fulfill(settlementMethod)
                    } catch {
                        logger.notice("addSettlementMethod: got error while adding \(settlementMethod.id): \(error.localizedDescription)")
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] newSettlementMethod in
                logger.notice("addSettlementMethod: persistently storing settlement method \(settlementMethod.id)")
                try databaseService.storeUserSettlementMethod(id: newSettlementMethod.id, settlementMethod: String(decoding: JSONEncoder().encode(newSettlementMethod), as: UTF8.self), privateData: newSettlementMethod.privateData)
                if let afterPersistentStorage = afterPersistentStorage {
                    afterPersistentStorage()
                }
            }.done(on: DispatchQueue.main) { [self] newSettlementMethod in
                logger.notice("addSettlementMethod: adding \(newSettlementMethod.id) to settlementMethodTruthSource")
                guard let settlementMethodTruthSource = settlementMethodTruthSource else {
                    throw SettlementMethodServiceError.unexpectedNilError(desc: "settlementMethodTruthSource was nil during addSettlementMethod call")
                }
                settlementMethodTruthSource.settlementMethods.append(newSettlementMethod)
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.notice("addSettlementMethod: encountered error: \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    
}
