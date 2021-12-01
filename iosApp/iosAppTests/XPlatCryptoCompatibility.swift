//
//  XPlatCryptoCompatibility.swift
//  iosAppTests
//
//  Created by jimmyt on 11/10/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import XCTest
@testable import iosApp

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
    
    /**
     * Prints keys according to KMService's specification in B64 format, as well as an original
     * message string and the encrypted message, also in B64 format, for cross platform
     * compatibility testing
     */
    func testprintEncryptedMessage() throws {
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
        let keyPair = try KeyPair(publicKey: publicKey, privateKey: privateKey)
        let originalMessage = "test"
        print("Original Message:\n" + originalMessage)
        print("Encrypted Message:")
        print((try keyPair.encrypt(clearData: originalMessage.data(using: .utf16)!) as NSData).base64EncodedString(options: []))
    }
    
    /**
     * Uses the given public and private key strings to restore a KeyPair object and decrypt the
     * given message, ensuring it matches the original message.
     */
    func testdecryptMessage() throws {
        let originalMessage = "test"
        let pubKey = "MIIBCgKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQAB"
        let privKey = "MIIEogIBAAKCAQEAnnDB4zV2llEwwLHw7c934eV7t69Om52dpLcuctXtOtjGsaKyOAV96egmxX6+C+MptFST3yX4wO6qK3/NSuOHWBXIHkhQGZEdTHOn4HE9hHdw2axJ0F9GQKZeT8t8kw+58+n+nlbQUaFHUw5iypl3WiI1K7En4XV2egfXGk9ujElMqXZO/eFun3eAM+asT1g7o/k2ysOpY5X+sqesLsJ0gzaGH4jfDVuWifS5YhdgFKkBi1i3U1tfPdc3sN53uNCPEhxjjuOuYH5I3WI9VzjpJezYoSlwzI4hYNOjY0cWzZM9kqeUt93KzTpvX4FeQigT9UO20cs23M5NbIW4q7lA4wIDAQABAoIBACWe/ZLfS4DG144x0lUNedhUPsuvXzl5NAj8DBXtcQ6TkZ51VN8TgsHrQ2WKwkKdVnZAzPnkEMxy/0oj5xG8tBL43RM/tXFUsUHJhpe3G9Xb7JprG/3T2aEZP/Sviy16QvvFWJWtZHq1knOIy3Fy/lGTJM/ymVciJpc0TGGtccDyeQDBxaoQrr1r4Q9q5CMED/kEXq5KNLmzbfB1WInQZJ7wQhtyyAJiXJxKIeR3hVGR1dfBJGSbIIgYA5sYv8HPnXrorU7XEgDWLkILjSNgCvaGOgC5B4sgTB1pmwPQ173ee3gbn+PCai6saU9lciXeCteQp9YRBBWfwl+DDy5oGsUCgYEA0TB+kXbUgFyatxI46LLYRFGYTHgOPZz6Reu2ZKRaVNWC75NHyFTQdLSxvYLnQTnKGmjLapCTUwapiEAB50tLSko/uVcf4bG44EhCfL4S8hmfS3uCczokhhBjR/tZxnamXb/T1Wn2X06QsPSYQQmZB7EoQ6G0u/K792YgGn/qh+cCgYEAweUWInTK5nIAGyA/k0v0BNOefNTvfgV25wfR6nvXM3SJamHUTuO8wZntekD/epd4EewTP57rEb9kCzwdQnMkAaT1ejr7pQE4RFAZcL86o2C998QS0k25fw5xUhRiOIxSMqK7RLkAlRsThel+6BzHQ+jHxB06te3yyIjxnqP576UCgYA7tvAqbhVzHvw7TkRYiNUbi39CNPM7u1fmJcdHK3NtzBU4dn6DPVLUPdCPHJMPF4QNzeRjYynrBXfXoQ3qDKBNcKyIJ8q+DpGL1JTGLywRWCcU0QkIA4zxiDQPFD0oXi5XjK7XuQvPYQoEuY3M4wSAIZ4w0DRbgosNsGVxqxoz+QKBgClYh3LLguTHFHy0ULpBLQTGd3pZEcTGt4cmZL3isI4ZYKAdwl8cMwj5oOk76P6kRAdWVvhvE+NR86xtojOkR95N5catwzF5ZB01E2e2b3OdUoT9+6F6z35nfwSoshUq3vBLQTGzXYtuHaillNk8IcW6YrbQIM/gsK/Qe+1/O/G9AoGAYJhKegiRuasxY7ig1viAdYmhnCbtKhOa6qsq4cvI4avDL+Qfcgq6E8V5xgUsPsl2QUGz4DkBDw+E0D1Z4uT60y2TTTPbK7xmDs7KZy6Tvb+UKQNYlxL++DKbjFvxz6VJg17btqid8sP+LMhT3oqfRSakyGS74Bn3NBpLUeonYkQ="
        let encryptedMessageB64 = "i3zw3naNKR6wOzThW6ET1yikx9amrg+UbuxFslVhd7bSCZpEZVmu5MAk3H6fvWf3ckvS/IgCne1jLb0MiZ3u7UI8blyKxlaK3VmA1JcEUu9SDB9I9ye8YbvdJrS8weffGtqtNH/gK7roHyey/Pd/bMXPkAKhkjoPG9wx/6ZAHFtn3Kt+brq+3m4uoKcwDzuYKoQFuyjFFmu6iwrJ6vir+i9v8FhfadgKmG7ggugT06ZYC/c55qeM51hZ9tPbCKEOQ6NEtlZ6iT6BQY9aBse+N4OFLx6xqd6nS/pA3AzDMc9FOAdmemelCv33hbUzquPz6WDc4iupREfvxUi6+8Wg6g=="
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
        let keyPair = try KeyPair(publicKey: publicKey, privateKey: privateKey)
        let encryptedMessageBytes = NSData(base64Encoded: encryptedMessageB64, options: [])! as Data
        let decryptedMessageBytes = try keyPair.decrypt(cipherData: encryptedMessageBytes)
        let decryptedMessage = String(bytes: decryptedMessageBytes, encoding: .utf16)
        XCTAssertEqual(originalMessage, decryptedMessage)
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
