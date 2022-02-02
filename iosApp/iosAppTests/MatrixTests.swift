//
//  MatrixTests.swift
//  iosAppTests
//
//  Created by jimmyt on 1/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import XCTest
@testable import iosApp
@testable import MatrixSDK

class MatrixTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCINMessageHandling() throws {
        let setupExpectation = XCTestExpectation(description: "Setup matrix session")
        let homeserverUrl = URL(string: "http://matrix.org")
        let credentials = MXCredentials(homeServer: "http://matrix.org", userId: "@jimmyt:matrix.org", accessToken: "")
        let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        let mxSession = MXSession(matrixRestClient: mxRestClient)!
        //Launch mxSession: it will first make an initial sync with the homserver
        mxSession.start { response in
            guard response.isSuccess else { return }
            
            //MxSession is ready to be used
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        let pkaExpectation = XCTestExpectation(description: "Get and parse public key announcement")
        let takerInfoExpectation = XCTestExpectation(description: "Get and parse taker info message")
        let makerInfoExpectation = XCTestExpectation(description: "Get and parse maker info message")
        
        //Restore the maker's public and private key and payment info
        let makerPubKeyB64 = "MIIBCgKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQAB"
        let makerPrivKeyB64 = "MIIEogIBAAKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQABAoIBACWe/ZLfS4DG144x0lUNedhUPsuvXzl5NAj8DBXtcQ6TkZ51VN8TgsHrQ2WKwkKdVnZAzPnkEMxy/0oj5xG8tBL43RM/tXFUsUHJhpe3G9Xb7JprG/3T2aEZP/Sviy16QvvFWJWtZHq1knOIy3Fy/lGTJM/ymVciJpc0TGGtccDyeQDBxaoQrr1r4Q9q5CMED/kEXq5KNLmzbfB1WInQZJ7wQhtyyAJiXJxKIeR3hVGR1dfBJGSbIIgYA5sYv8HPnXrorU7XEgDWLkILjSNgCvaGOgC5B4sgTB1pmwPQ173ee3gbn+PCai6saU9lciXeCteQp9YRBBWfwl+DDy5oGsUCgYEA0TB+kXbUgFyatxI46LLYRFGYTHgOPZz6Reu2ZKRaVNWC75NHyFTQdLSxvYLnQTnKGmjLapCTUwapiEAB50tLSko/uVcf4bG44EhCfL4S8hmfS3uCczokhhBjR/tZxnamXb/T1Wn2X06QsPSYQQmZB7EoQ6G0u/K792YgGn/qh+cCgYEAweUWInTK5nIAGyA/k0v0BNOefNTvfgV25wfR6nvXM3SJamHUTuO8wZntekD/epd4EewTP57rEb9kCzwdQnMkAaT1ejr7pQE4RFAZcL86o2C998QS0k25fw5xUhRiOIxSMqK7RLkAlRsThel+6BzHQ+jHxB06te3yyIjxnqP576UCgYA7tvAqbhVzHvw7TkRYiNUbi39CNPM7u1fmJcdHK3NtzBU4dn6DPVLUPdCPHJMPF4QNzeRjYynrBXfXoQ3qDKBNcKyIJ8q+DpGL1JTGLywRWCcU0QkIA4zxiDQPFD0oXi5XjK7XuQvPYQoEuY3M4wSAIZ4w0DRbgosNsGVxqxoz+QKBgClYh3LLguTHFHy0ULpBLQTGd3pZEcTGt4cmZL3isI4ZYKAdwl8cMwj5oOk76P6kRAdWVvhvE+NR86xtojOkR95N5catwzF5ZB01E2e2b3OdUoT9+6F6z35nfwSoshUq3vBLQTGzXYtuHaillNk8IcW6YrbQIM/gsK/Qe+1/O/G9AoGAYJhKegiRuasxY7ig1viAdYmhnCbtKhOa6qsq4cvI4avDL+Qfcgq6E8V5xgUsPsl2QUGz4DkBDw+E0D1Z4uT60y2TTTPbK7xmDs7KZy6Tvb+UKQNYlxL++DKbjFvxz6VJg17btqid8sP+LMhT3oqfRSakyGS74Bn3NBpLUeonYkQ="
        let makerPubKeyBytes = Data(base64Encoded: makerPubKeyB64)!
        let makerPrivKeyBytes = Data(base64Encoded: makerPrivKeyB64)!
        let makerKeyPair = try KeyPair(publicKeyBytes: makerPubKeyBytes, privateKeyBytes: makerPrivKeyBytes)
        let makerPublicKey = try PublicKey(publicKeyBytes: makerPubKeyBytes)
        
        let makerPaymentDetails = [
            "name": "USD-SWIFT",
            "beneficiary": "Make Ker",
            "account": "2039482",
            "bic": "MAK3940"
        ]
        
        //Restore the takers's public and private key and payment info
        let takerPubKeyB64 = "MIIBCgKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQAB"
        let takerPrivKeyB64 = "MIIEowIBAAKCAQEAstQwQCanMBPJIEj1Mjc1m80sL3eJ/y1SDM3iVoDk2oNN6WOZly0GWbv1xjNMM94U8GLnYrzEGUek2IKcicBAVYhwsegeVo2DHOts72g6GpVWOPKndpT87raKCqSkd+IqR2OWAo+olGWmjWgAbesH/ojqJPNHaKlhi4b0JSwNAMfTP2HqcN2lXLXnSbR7F7MnrvjHbUxEUulthmX1mLId/7bznQ2hjyUP2yOQY92C7DFwVl/J33YV2F1GJbx5xGqB/cRRB+0hTRoqQvHscZAlGykWIVgvrdPw2JOsadQVePUhDBU5jvS5qyD6JxAlRWgN7FZsMTFLVM2XNW40N3jMIwIDAQABAoIBADez/Kue3qkNILMbxrSzmdFEIaVPeP6xYUN3xi7ny2F9UQGH8smyTq4Y7D+mru/hF2ihhi2tWu/87w458QS/i8qYy3G/OeQABH03oCEauC6bodXvT9aSJg89cNZL3qcxHbZLAOkfUoWW/EBDyw5yDXVttHF6Dh491JKfoOELTamWD4KxIScR/Nf6ih6UqB/SwmLz1X5+fZpW4iGZXIRsPzOzDtDmoSGajNXoi0Ln2x9DkUeXpx9r7TTT9DBT0jTLbCUiB3LYU4I/VR6upm0bDUKKRi9VTkQjOAV5rD3qdoraPVRCSzjUVqCwL7jqfunXsG/hhRccD+Di5pXaCuPeOsECgYEA3p4LLVHDzLhF269oUcvflMoBUVKo9UNHL/wmyujdV+RwFi5J2sxVLgKHsdKHCy7FdrDmxax7Mrgh57KS3+zfdDhs98w181JLwgFxzEAxIP2PnHd4P3NEbxCxnxhILW4fEotUVzJWjjhEHXe5QhOW2z2yIZIOEqBzFfRx33kWrbMCgYEAzaUrDMaTkIkOoVI7BbNS7n5CBWL/DaPOID1UiL4eHWngeoOwaeI+CB0cxSrxngykue0xM3aI3KVFaeIYSdn7DZAxWAS3U143VApgLxgLyxZBtVX18HYiTZQx/PiTczMH6kFA5z0L7iNlf0uQrQQJgDzM6QY0kKasufoss+Baj9ECgYA1BjvvTXxvtKyfCQa2BPN6QytRLXklAiNgoJS03AZsuvKfteLNhMH9NYkQp+6WkUtjW/t7tfuaNxWMVJJ7V7ZZvl7mHvPywvVcfm+WkOuiygJ86E/x/Qid08Ia/POkLoikKB+srUbElU5UHoI35OaXzfgx2tITSbhf0FuXOQZX1QKBgAj7A4xFR8ByG89ztdwj3qVHoj51+klwM9o4k259Tvdd3k27XoLhPHBCRTVfELokNzVfZFyo+oUYOpXLJ+BhwpLvDxiW7CKZ5LSo11Z3KFywFiKDJIBhyFG2/Q/dEyNewSO7wcfXZKP7q70JYcIMgRW2kgRDHxyKCtT8VeNtEsdhAoGBAJHzNruW/ZS31o0rvQxHu8tBcd8osTsPNZBhuHs60mbPFRHwBaU8JSofl4XjR8B7K9vjYtxVYMEsIX6NqNf1JMXGDva/cTCHXyPuiCnuUMbHkK0YpsFxQABwYA+sOSlujwJwMNPu4ylzHL1HDyv9m4x74/NM20zDFW6MB/zD6G0c"
        let takerPubKeyBytes = Data(base64Encoded: takerPubKeyB64)!
        let takerPrivKeyBytes = Data(base64Encoded: takerPrivKeyB64)!
        let takerKeyPair = try KeyPair(publicKeyBytes: takerPubKeyBytes, privateKeyBytes: takerPrivKeyBytes)
        let takerPublicKey = try PublicKey(publicKeyBytes: takerPubKeyBytes)
        
        let takerPaymentDetails = [
            "name": "USD-SWIFT",
            "beneficiary": "Take Ker",
            "account": "2039482",
            "bic": "TAK3940"
        ]
        
        //Restore offer id
        let offerId = Data(base64Encoded: "9tGMGTr0SbuySqE0QOsAMQ==")!
        
        let room = mxSession.room(withRoomId: "!WEuJJHaRpDvkbSveLu:matrix.org")
        _ = room?.liveTimeline { timeline in
            timeline?.listenToEvents([MXEventType.roomMessage]) { (event, direction, roomState) in
                if let announcedPubKey = try! CommutoCoreInteraction.parsePublicKeyAnnouncement(messageString: event.content["body"] as! String, makerInterfaceId: makerKeyPair.interfaceId as Data, offerId: offerId) {
                    if announcedPubKey.interfaceId == makerPublicKey.interfaceId {
                        pkaExpectation.fulfill()
                    }
                }
            }
            timeline?.resetPagination()
            timeline?.paginate(5, direction: .backwards, onlyFromStore: false) { _ in
            }
        }
        wait(for: [pkaExpectation], timeout: 60.0)
    }
    
    func testGetRoomMessages() throws {
        let setupExpectation = XCTestExpectation(description: "Setup matrix session")
        let homeserverUrl = URL(string: "http://matrix.org")!
        let credentials = MXCredentials(homeServer: "http://matrix.org", userId: "@jimmyt:matrix.org", accessToken: "")
        let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        let mxSession = MXSession(matrixRestClient: mxRestClient)!
        //Launch mxSession: it will first make an initial sync with the homserver
        mxSession.start { response in
            guard response.isSuccess else { return }
            
            //MxSession is ready to be used
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        var messageCount = 0
        let expectation = XCTestExpectation(description: "Get messages from CIN Matrix room")
        let room = mxSession.room(withRoomId: "!WEuJJHaRpDvkbSveLu:matrix.org")
        _ = room?.liveTimeline { timeline in
            timeline?.listenToEvents([MXEventType.roomMessage]) { (event, direction, roomState) in
                print("Another event:")
                print("Message Type:")
                print(event.content["msgtype"])
                print("Body:")
                print(event.content["body"])
                print("Direction")
                print(direction)
                if direction == .forwards {
                    if messageCount >= 4 {
                        expectation.fulfill()
                    } else {
                        messageCount = messageCount + 1
                    }
                }
            }
            timeline?.resetPagination()
            timeline?.paginate(5, direction: .backwards, onlyFromStore: false) { _ in
            }
        }
        wait(for: [expectation], timeout: 60.0)
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
        _ = room?.liveTimeline { timeline in
            timeline?.listenToEvents { (event, direction, roomState) in
                print("Another event:")
                print("Message Type:")
                print(event.content["msgtype"])
                print("Body:")
                print(event.content["body"])
            }
            // Reset the pagination start point to now
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
