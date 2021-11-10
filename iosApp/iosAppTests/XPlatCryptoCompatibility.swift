//
//  XPlatCryptoCompatibility.swift
//  iosAppTests
//
//  Created by James Telzrow on 11/10/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest

/**
 * Prints keys in B64 String format for compatibility testing, and tests the re-creation of key objects given keys in
 * B64 String format saved on other platforms.
 */
class XPlatCryptoCompatibility: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    
    /**
     * Prints keys according to KMService's specification in B64 format, so that they can be pasted into
     * testRestoreRSAKeysFromB64() on other platforms, to ensure that keys saved on any platform can be read on any
     * other.
     */
    func testGenB64RSAKeys() throws {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let privKeyBytes = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let pubKeyB64Str = (pubKeyBytes as NSData).base64EncodedString(options: [])
        let privKeyB64Str = (privKeyBytes as NSData).base64EncodedString(options: [])
        print("Public Key B64:")
        print(pubKeyB64Str)
        print("Private Key B64:")
        print(privKeyB64Str)
    }
    
    /**
     * Attempts to restore keys according to KMService's specification given in B64 format, to ensure that keys saved on
     * other platforms can be restored to key objects on this platform.
     */
    func testRestoreRSAKeysFromB64() throws {
        let pubKey = "MIIBCgKCAQEAsX6zBKrzN+cuAAoBl7WwCg7KyN8SUwPk1sXquIHQ8BWXo03ijO0X69Kh6bnxY+0YJkoqbEIKofDKIcIl0RkE8rEOSKHl/o9rV1hS7iRM3P6PcvvNxwG6oov7iGLwTFur+CrH1FPVDo2oqjF+hJqEoFdH2L9u61mJsvTuKXqzfRDPwPQIvOafisWnLd09TzY8YoMJuu7hKHzYj9rfKypnRDYvXSiRhyJgoCe2qIEjvibRiSY/xV605mkMywuoMRgX5X1f7PpfAmRwJuLVAzCUIUGEdFy/gdA5DlsMWIw9dHQUrLML79KcX8aNh7dVFupsZPOMtLU9dUPTw5JXe9oRBQIDAQAB"
        let privKey = "MIIEpAIBAAKCAQEAsX6zBKrzN+cuAAoBl7WwCg7KyN8SUwPk1sXquIHQ8BWXo03ijO0X69Kh6bnxY+0YJkoqbEIKofDKIcIl0RkE8rEOSKHl/o9rV1hS7iRM3P6PcvvNxwG6oov7iGLwTFur+CrH1FPVDo2oqjF+hJqEoFdH2L9u61mJsvTuKXqzfRDPwPQIvOafisWnLd09TzY8YoMJuu7hKHzYj9rfKypnRDYvXSiRhyJgoCe2qIEjvibRiSY/xV605mkMywuoMRgX5X1f7PpfAmRwJuLVAzCUIUGEdFy/gdA5DlsMWIw9dHQUrLML79KcX8aNh7dVFupsZPOMtLU9dUPTw5JXe9oRBQIDAQABAoIBAATHFw0EB/4kJigV8jMx+WOFQJP1yIxnrALUUCw4FwEbZ69GOFgC8B78LA5lSlgzqIUr/7vVxEEAgQRgcZGmZYHIiSH536hsQQoDGd+zUPFYQHwVHJXOgrD/k8f4988VCZ+UEThygDyUd2rgta8z6egsqUWuPiSuI+d8sdDNLs8p4idinZcQs5Mtjpjtt2XpViyqBD2JBp5jBNLlj5wrlZfOP+FY+dBMo+y9cLscMCXQg0Ko9CKX+skZWe/sNmQiSDJ6b1HYFWqOxw2xbwKb8tthdPum2jj6UITlphJXwLlRmGupBkHS94nnw0suV9/uwyqqPhaeYYE43pT9mBtC9gECgYEA+NM61qGgEGuTr5eyL+PF1zXdFAUWAcAD+VIH85JpYoCnu9oHZICu/H7bwe6iDyGxClr46cJLUpFMnjrHNEkQmiC9I5UbA3vX/HFHllwY848xK90LY7xP0eTRlS2T3rsMYvPvhMPqLNC9HnspQZ6twdmWJk++/9BOT76BUoq1BwUCgYEAtpztHX9s015yinjeij0f3dPkoNhb0bgfNP6FV3uCOqFz0b12sw/j3HltUCeze8ojBpusehQ7OXI5Pp9vRwbakMcKo0/w+crYysKbwmnbyHqCWx1oCg75ZTugz1DreBK9PiWJoDnwlRDo7DWRMzj4SgcBn+GWGCoyC9JxcrhrAgECgYBi5oqPfwSBIlE8TP5dPJqJdPZfm7nojirGMY3JiZtrtJl2+C1SDDgBUmcEyVYOz6Rv6kLfnwOTWP9sMQ62wIfhyzuCZiSrmND7nQcIQ6kDPhocRirdxJ6xXdLUCZ6pvA0rU6wTSE/O6lURRYDbfTexQkwFBFN1mJVX6u+6IDneBQKBgQCqgkJgnZ92iSS4KP3Z5BMCJJzAluS9IId7CwBkW/2QUzp6p8bSkU64iWTJSBityGMGA4t7fbKDBCVxVJspnbutHTzQmo8uHfpo8GdRk1hVjBZ1jzKa2bqCjLetfCgxOIYdJh2oTxFVjrF+BNJsGpCzRnF84L0uGRAbu8aUUKASAQKBgQDxxKLGNCsXOX2WLEXY7oPIIp60HkvlsVY3/5kVQhhCFtZBgU9JsHtuGJ8MvPIkfukOmGBuJrnCPGdv/Sect9GfaqMASJ9GmV69yYpzoWPFXerpeUmvizwLqDLOV+C289w858IaujaJ2rTWJhJo3Pg4yKPIvdscJ4ezmTqdthuOPw=="
        let pubKeyBytes: NSData = NSData(base64Encoded: pubKey, options: [])!
        let privKeyBytes: NSData = NSData(base64Encoded: privKey, options: [])!
        var keyOpts: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(pubKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        keyOpts[kSecAttrKeyClass as String] = kSecAttrKeyClassPrivate
        guard let privateKey = SecKeyCreateWithData(privKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        print("Restored Public Key:")
        print(publicKey)
        print("Restored Private Key:")
        print(privateKey)
    }

}
