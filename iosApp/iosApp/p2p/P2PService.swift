//
//  P2PService.swift
//  iosApp
//
//  Created by jimmyt on 6/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import MatrixSDK
import PromiseKit

class P2PService {
    
    init() {
        let creds = MXCredentials(homeServer: "", userId: "", accessToken: "")
        self.creds = creds
        self.mxClient =  MXRestClient(credentials: creds, unrecognizedCertificateHandler: nil)
    }
    
    // Matrix credentials
    private let creds: MXCredentials
    
    // Matrix REST client
    let mxClient: MXRestClient
    
    // The thread in which P2PService listens to the peer-to-peer network
    private var listenThread: Thread?
    
    // The timer responsible for repeatedly beginning the listening process
    private var timer: Timer?
    
    // Indicates whether P2PService is currently handling new data as part of the listening process
    private var isDoingListening = false
    
    func listen() {
        listenThread = Thread { [self] in
            listenLoop()
        }
        listenThread!.start()
    }
    
    func stopListening() {
        timer?.invalidate()
        listenThread?.cancel()
    }
    
    func listenLoop() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if (!isDoingListening) {
                isDoingListening = true
                firstly {
                    roomSyncPromise()
                }.done { response in
                    self.isDoingListening = false
                }.cauterize()
            }
        }
        timer.tolerance = 0.5
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func roomSyncPromise() -> Promise<MXResponse<MXRoomInitialSync>> {
        let promise = Promise<MXResponse<MXRoomInitialSync>> { seal in
            mxClient.intialSync(ofRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", limit: 5) { response in
                seal.fulfill(response)
            }
        }
        return promise
    }
}
