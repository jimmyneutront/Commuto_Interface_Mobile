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
     
     On the global `DispatchQueue`, this validates and serializes the supplied private data via `serializePrivateSettlementMethodData`. Then this securely stores the new `SettlementMethod` and associated serialized private data in persistent storage, via `databaseService`. Finally, on the main `DispatchQueue`, this appends the new `SettlementMethod` to the array of settlement methods in `settlementMethodTruthSource`.
     
     - Parameters:
        - settlementMethod: The `SettlementMethod` to be added.
        - newPrivateData: The `PrivateData` for the new settlement method.
        - afterSerialization: A closure that will be executed after `newPrivateData` has been serialized.
        - afterPersistentStorage: A closure that will be executed after `settlementMethod` is saved in persistent storage.
     
     - Returns: An empty promise that will be fulfilled when the settlement-method-adding process is complete.
    
     - Throws: A  `SettlementMethodServiceError.unexpectedNilError` if `settlementMethodTruthSource` is `nil`.
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
                        let settlementMethod = try serializePrivateSettlementMethodData(
                            settlementMethod: settlementMethod,
                            privateData: newPrivateData
                        )
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
                logger.notice("addSettlementMethod: adding \(newSettlementMethod.id) to settlementMethodTruthSource")
            }.done(on: DispatchQueue.main) { [self] newSettlementMethod in
                guard let settlementMethodTruthSource = settlementMethodTruthSource else {
                    throw SettlementMethodServiceError.unexpectedNilError(desc: "settlementMethodTruthSource was nil during addSettlementMethod call")
                }
                settlementMethodTruthSource.settlementMethods.append(newSettlementMethod)
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.notice("addSettlementMethod: encountered error while adding \(settlementMethod.id): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to edit the private data of the given `SettlementMethod` in the list of the user's settlement methods, both in `settlementMethodTruthSource` and in persistent storage.
     
     On the global `DispatchQueue`, this validates and serializes the supplied private data via `serializePrivateSettlementMethodData`. Then this updates the private data of the settlement method in persistent storage with this newly serialized private data. Finally, on the main `DispatchQueue`, this finds the `SettlementMethod` in `settlementMethodTruthSource` with an id equal to that of `settlementMethod`, and sets its `SettlementMethod.privateData` property equal to the newly serialized data.
     
     - Parameters:
        - settlementMethod: The existing `SettlementMethod` to be edited.
        - newPrivateData: The new private data with which this will update the existing `SettlementMethod`.
        - afterSerialization: A closure that will be executed after `newPrivateData` has been serialized.
        - afterPersistentStorage: A closure that will be executed after this updates the private data of `settlementMethod` in persistent storage.
     
     - Returns: An empty promise that will be fulfilled when the settlement-method-adding process is complete.
     
     - Throws: A `SettlementMethodServiceError.unexpectedNilError` if `settlementMethodTruthSource` is `nil`.
     */
    func editSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        afterSerialization: (() -> Void)? = nil,
        afterPersistentStorage: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<SettlementMethod> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    self.logger.notice("editSettlementMethod: editing \(settlementMethod.id)")
                    do {
                        let settlementMethod = try serializePrivateSettlementMethodData(
                            settlementMethod: settlementMethod,
                            privateData: newPrivateData
                        )
                        if let afterSerialization = afterSerialization {
                            afterSerialization()
                        }
                        seal.fulfill(settlementMethod)
                    } catch {
                        logger.notice("editSettlementMethod: got error while editing \(settlementMethod.id): \(error.localizedDescription)")
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] editedSettlementMethod in
                logger.notice("editSettlementMethod: persistently storing edited private data for \(settlementMethod.id)")
                try databaseService.updateUserSettlementMethod(id: settlementMethod.id, privateData: editedSettlementMethod.privateData)
                if let afterPersistentStorage = afterPersistentStorage {
                    afterPersistentStorage()
                }
                logger.notice("editSettlementMethod: editing \(editedSettlementMethod.id) in settlementMethodTruthSource")
            }.done(on: DispatchQueue.main) { [self] newSettlementMethod in
                guard let settlementMethodTruthSource = settlementMethodTruthSource else {
                    throw SettlementMethodServiceError.unexpectedNilError(desc: "settlementMethodTruthSource was nil during editSettlementMethod call")
                }
                let indexOfEditedSettlementMethod = settlementMethodTruthSource.settlementMethods.firstIndex(where: { someSettlementMethod in
                    someSettlementMethod.id == newSettlementMethod.id
                })
                if let index = indexOfEditedSettlementMethod {
                    settlementMethodTruthSource.settlementMethods[index].privateData = newSettlementMethod.privateData
                }
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.notice("editSettlementMethod: encountered error while editing \(settlementMethod.id): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Ensures that the given `PrivateData` corresponds to the method in the given `SettlementMethod`, serializes `privateData` accordingly, sets the  `SettlementMethod.privateData` field of `settlementMethod` equal to the result, and then returns `settlementMethod`.
     
     - Parameters:
        - settlementMethod: The `SettlementMethod` for which this should serialize private data.
        - privateData: The `PrivateData` to be serialized.
     
     - Returns: `settlementMethod`, the private data property of which is `privateData` serialized to a string.
     
     - Throws: A `SettlementMethodServiceError.privateDataSerialization` error cannot be cast as the type of private data corresponding to the type specified in `settlementMethod`, or if serialization fails.
     */
    private func serializePrivateSettlementMethodData(settlementMethod: SettlementMethod, privateData: PrivateData) throws -> SettlementMethod {
        var settlementMethod = settlementMethod
        if settlementMethod.method == "SEPA" {
            guard let privateSEPAData = privateData as? PrivateSEPAData else {
                throw SettlementMethodServiceError.privateDataSerializationError(desc: "Unable to serialize SEPA data")
            }
            settlementMethod.privateData = String(decoding: try JSONEncoder().encode(privateSEPAData), as: UTF8.self)
        } else if settlementMethod.method == "SWIFT" {
            guard let privateSWIFTData = privateData as? PrivateSWIFTData else {
                throw SettlementMethodServiceError.privateDataSerializationError(desc: "Unable to serialize SWIFT data")
            }
            settlementMethod.privateData = String(decoding: try JSONEncoder().encode(privateSWIFTData), as: UTF8.self)
        } else {
            throw SettlementMethodServiceError.privateDataSerializationError(desc: "Did not recognize settlement method")
        }
        return settlementMethod
    }
    
    /**
     Attempts to delete the given `SettlementMethod` from the list of the user's settlement methods, both in `settlementMethodTruthSource` and in persistent storage.
     
     On the global `DispatchQueue`, this removes all settlement methods with IDs equal to that of `settlementMethod` (and their private data) from persistent storage. Then, on the main `DispatchQueue`, this removes all `SettlementMethod`s with IDs equal to that of `settlementMethod` from `settlementMethodTruthSource`.
     
     - Parameter settlementMethod: The existing `SettlementMethod` that this will delete.
     
     - Returns: An empty promise that will be fulfilled when the settlement-method-deleting process is complete.
     
     - Throws: A `SettlementMethodServiceError.unexpectedNilError` if `settlementMethodTruthSource` is `nil`.
     */
    func deleteSettlementMethod(
        settlementMethod: SettlementMethod
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<SettlementMethod> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("deleteSettlementMethod: removing \(settlementMethod.id) from persistent storage")
                    do {
                        try databaseService.deleteUserSettlementMethod(id: settlementMethod.id)
                        logger.notice("deleteSettlementmethod: deleting \(settlementMethod.id) from settlementMethodTruthSource")
                        seal.fulfill(settlementMethod)
                    } catch {
                        logger.notice("deleteSettlementMethod: got error while deleting \(settlementMethod.id) from persistent storage")
                        seal.reject(error)
                    }
                }
            }.done(on: DispatchQueue.main) { deletedSettlementMethod in
                guard let settlementMethodTruthSource = self.settlementMethodTruthSource else {
                    throw SettlementMethodServiceError.unexpectedNilError(desc: "settlementMethodTruthSource was nil during deleteSettlementMethod call")
                }
                settlementMethodTruthSource.settlementMethods.removeAll { someSettlementMethod in
                    someSettlementMethod.id == deletedSettlementMethod.id
                }
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.notice("deleteSettlementMethod: encountered error while deleting \(settlementMethod.id): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
}
