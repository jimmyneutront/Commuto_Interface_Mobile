//
//  MatrixTests.swift
//  iosAppTests
//
//  Created by jimmyt on 1/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest
@testable import MatrixSDK

class MatrixTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testGetRoomsFromHomeserver() throws {
        let expecation = XCTestExpectation(description: "Get public rooms from homeserver")
        let homeserverUrl = URL(string: "http://matrix.org")!
        let mxRestClient = MXRestClient(homeServer: homeserverUrl, unrecognizedCertificateHandler: nil)
        let httpOperation = mxRestClient.publicRooms(onServer: nil, limit: nil) { response in
            let client = mxRestClient
            switch response {
                case .success(let rooms):

                    // rooms is an array of MXPublicRoom objects containing information like room id
                print("The public rooms are: \(rooms)")
                    expecation.fulfill()

                case .failure:
                    XCTAssert(false, "request was not successful")
            }
        }
        wait(for: [expecation], timeout: 10.0)
    }
    
    func testUsersRooms() throws {
        let setupExpectation = XCTestExpectation(description: "Setup matrix session")
        let credentials = MXCredentials(homeServer: "http://matrix.org", userId: "@jimmyt:matrix.org",
                                        accessToken: "")
        let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        let mxSession = MXSession(matrixRestClient: mxRestClient)!
        // Launch mxSession: it will first make an initial sync with the homeserver
        mxSession.start { response in
            guard response.isSuccess else { return }

            // mxSession is ready to be used
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        let roomExpectation = XCTestExpectation(description: "Get and print some events from the Python room")
        // Retrieve the room from its room id
        let room = mxSession.room(withRoomId: "!iuyQXswfjgxQMZGrfQ:matrix.org")
        // Reset the pagination start point to now
        _ = room?.liveTimeline { timeline in
            timeline?.listenToEvents { (event, direction, roomState) in
                print("Another event:")
                print("Message Type:")
                print(event.content["msgtype"])
                print("Body:")
                print(event.content["body"])
            }
            timeline?.resetPagination()
            timeline?.paginate(10, direction: .backwards, onlyFromStore: false) { _ in
                // At this point, the SDK has finished to enumerate the events to the attached listeners
                roomExpectation.fulfill()
            }
        }
        wait(for: [roomExpectation], timeout: 60.0)
    }
    
    func testSendingMessage() throws {
        let setupExpectation = XCTestExpectation(description: "Setup matrix session")
        let credentials = MXCredentials(homeServer: "http://matrix.org", userId: "@jimmyt:matrix.org",
                                        accessToken: "")
        let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        let mxSession = MXSession(matrixRestClient: mxRestClient)!
        // Launch mxSession: it will first make an initial sync with the homeserver
        mxSession.start { response in
            guard response.isSuccess else { return }

            // mxSession is ready to be used
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        
        let sendMessageExpectation = XCTestExpectation(description: "Send message to Commuto Interface Network Test Room")
        var sentMessageId: String? = nil
        mxRestClient.sendTextMessage(toRoom: "!WEuJJHaRpDvkbSveLu:matrix.org", text: "test_message") { (response) in
            if case .success(let eventId) = response {
                    // eventId is for reference
                    // If you have registered events listener like in the previous use case, you will get
                    // a notification for this event coming down from the homeserver events stream and
                    // now handled by MXSession.
                sentMessageId = eventId
                sendMessageExpectation.fulfill()
            }
        }
        wait(for: [sendMessageExpectation], timeout: 60.0)
        
        let receiveMessageExpectation = XCTestExpectation(description: "Send message to Commuto Interface Network Test Room")
        // Retrieve the room from its room id
        let room = mxSession.room(withRoomId: "!WEuJJHaRpDvkbSveLu:matrix.org")
        _ = room?.liveTimeline { timeline in
            timeline?.listenToEvents { (event, direction, roomState) in
                if event.eventId == sentMessageId {
                    receiveMessageExpectation.fulfill()
                }
            }
            timeline?.resetPagination()
            timeline?.paginate(10, direction: .backwards, onlyFromStore: false) { _ in
                // At this point, the SDK has finished to enumerate the events to the attached listeners
            }
        }
        wait(for: [receiveMessageExpectation], timeout: 60.0)
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
