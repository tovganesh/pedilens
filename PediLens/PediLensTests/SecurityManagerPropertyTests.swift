//
//  SecurityManagerPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for SecurityManager
//  Feature: pedilens, Property 18: Data Encryption at Rest
//  Validates: Requirements 5.3, 9.1
//

import XCTest
@testable import PediLens

/// Property-based tests for SecurityManager encryption functionality
/// These tests validate universal properties that should hold for all inputs
final class SecurityManagerPropertyTests: XCTestCase {
    
    var securityManager: SecurityManager!
    
    override func setUp() {
        super.setUp()
        securityManager = SecurityManager.shared
        
        // Clean up any existing keys from previous tests
        cleanupKeychain()
    }
    
    override func tearDown() {
        // Clean up after tests
        cleanupKeychain()
        securityManager = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupKeychain() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pedilens.app.encryption",
            kSecAttrAccount as String: "pedilens-master-key"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
    
    /// Generates random data of specified size
    private func generateRandomData(size: Int) -> Data {
        var data = Data(count: size)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, size, bytes.baseAddress!)
        }
        return data
    }
    
    /// Generates random string data
    private func generateRandomString(length: Int) -> Data {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#$%^&*()_+-=[]{}|;:,.<>?/~`"
        let randomString = String((0..<length).map { _ in letters.randomElement()! })
        return randomString.data(using: .utf8)!
    }
    
    /// Generates random unicode string data
    private func generateRandomUnicodeString(length: Int) -> Data {
        let unicodeChars = ["a", "b", "c", "你", "好", "世", "界", "🏥", "🔒", "田", "中", "太", "郎", "α", "β", "γ", "δ"]
        let randomString = String((0..<length).map { _ in unicodeChars.randomElement()! })
        return randomString.data(using: .utf8)!
    }
    
    // MARK: - Property 18: Data Encryption at Rest
    // **Validates: Requirements 5.3, 9.1**
    
    /// Property: For any data encrypted and then decrypted, the result should equal the original data
    /// This is the fundamental round-trip property for encryption
    func testProperty18_EncryptionRoundTrip_PreservesData() throws {
        let iterations = 100
        var failedCases: [(input: Data, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test data of varying sizes
            let dataSize = Int.random(in: 0...10000)
            let originalData = generateRandomData(size: dataSize)
            
            do {
                // Encrypt the data
                let encryptedData = try securityManager.encryptData(originalData)
                
                // Decrypt the data
                let decryptedData = try securityManager.decryptData(encryptedData)
                
                // Verify round-trip property: decrypt(encrypt(data)) == data
                if decryptedData != originalData {
                    failedCases.append((input: originalData, iteration: iteration))
                }
                
                // Additional invariants
                // 1. Encrypted data should be different from original (unless empty)
                if !originalData.isEmpty {
                    XCTAssertNotEqual(encryptedData, originalData,
                                    "Iteration \(iteration): Encrypted data should differ from plaintext")
                }
                
                // 2. Encrypted data should be longer (includes nonce and authentication tag)
                // AES-GCM adds 12 bytes (nonce) + 16 bytes (tag) = 28 bytes minimum overhead
                XCTAssertGreaterThanOrEqual(encryptedData.count, originalData.count,
                                          "Iteration \(iteration): Encrypted data should be at least as long as plaintext")
                
            } catch {
                XCTFail("Iteration \(iteration): Encryption/decryption failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Round-trip property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any data, encrypting it twice should produce different ciphertexts
    /// This validates that encryption uses proper randomization (nonce)
    func testProperty18_EncryptionNonDeterminism_ProducesDifferentCiphertexts() throws {
        let iterations = 100
        var failedCases: [(input: Data, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test data
            let dataSize = Int.random(in: 1...1000)
            let originalData = generateRandomData(size: dataSize)
            
            do {
                // Encrypt the same data twice
                let encrypted1 = try securityManager.encryptData(originalData)
                let encrypted2 = try securityManager.encryptData(originalData)
                
                // Verify non-determinism property: encrypt(data) != encrypt(data)
                // (due to random nonce in AES-GCM)
                if encrypted1 == encrypted2 {
                    failedCases.append((input: originalData, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Encryption failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Non-determinism property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any data encrypted with one key, decryption with a different key should fail
    /// This validates key isolation
    func testProperty18_KeyIsolation_DifferentKeysCannotDecrypt() throws {
        let iterations = 50 // Fewer iterations since this involves key generation
        var failedCases: [(input: Data, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test data
            let dataSize = Int.random(in: 1...1000)
            let originalData = generateRandomData(size: dataSize)
            
            do {
                // Encrypt with first key
                let encryptedData = try securityManager.encryptData(originalData)
                
                // Replace with a new key
                try securityManager.storeEncryptionKey()
                
                // Try to decrypt with the new key - should fail
                do {
                    let _ = try securityManager.decryptData(encryptedData)
                    // If we get here, decryption succeeded when it shouldn't have
                    failedCases.append((input: originalData, iteration: iteration))
                } catch SecurityError.decryptionFailed {
                    // Expected - decryption should fail with wrong key
                    continue
                } catch {
                    XCTFail("Iteration \(iteration): Unexpected error: \(error)")
                }
                
                // Restore key for next iteration
                cleanupKeychain()
                
            } catch {
                XCTFail("Iteration \(iteration): Setup failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Key isolation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any data, tampering with encrypted data should cause decryption to fail
    /// This validates authentication and integrity protection
    func testProperty18_TamperResistance_ModifiedDataFailsDecryption() throws {
        let iterations = 100
        var failedCases: [(input: Data, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test data
            let dataSize = Int.random(in: 10...1000) // At least 10 bytes to tamper with
            let originalData = generateRandomData(size: dataSize)
            
            do {
                // Encrypt the data
                var encryptedData = try securityManager.encryptData(originalData)
                
                // Tamper with a random byte in the encrypted data
                let tamperIndex = Int.random(in: 0..<encryptedData.count)
                encryptedData[tamperIndex] ^= 0xFF
                
                // Try to decrypt tampered data - should fail
                do {
                    let _ = try securityManager.decryptData(encryptedData)
                    // If we get here, decryption succeeded when it shouldn't have
                    failedCases.append((input: originalData, iteration: iteration))
                } catch SecurityError.decryptionFailed {
                    // Expected - decryption should fail with tampered data
                    continue
                } catch {
                    XCTFail("Iteration \(iteration): Unexpected error: \(error)")
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Encryption failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Tamper resistance property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any string data (including unicode), round-trip preserves content
    /// This validates that encryption works correctly with text data
    func testProperty18_StringDataRoundTrip_PreservesContent() throws {
        let iterations = 100
        var failedCases: [(input: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random string data (mix of ASCII and Unicode)
            let useUnicode = Bool.random()
            let stringLength = Int.random(in: 0...500)
            let originalData = useUnicode ? 
                generateRandomUnicodeString(length: stringLength) :
                generateRandomString(length: stringLength)
            
            let originalString = String(data: originalData, encoding: .utf8)!
            
            do {
                // Encrypt the data
                let encryptedData = try securityManager.encryptData(originalData)
                
                // Decrypt the data
                let decryptedData = try securityManager.decryptData(encryptedData)
                
                // Convert back to string
                let decryptedString = String(data: decryptedData, encoding: .utf8)
                
                // Verify round-trip property
                if decryptedString != originalString {
                    failedCases.append((input: originalString, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Encryption/decryption failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "String round-trip property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any data size (including edge cases), encryption should succeed
    /// This validates that encryption handles all data sizes correctly
    func testProperty18_VariableDataSizes_AllSucceed() throws {
        // Test specific edge cases and random sizes
        let testSizes = [
            0,      // Empty
            1,      // Single byte
            16,     // AES block size
            32,     // Common size
            100,    // Small
            1024,   // 1KB
            10240,  // 10KB
            102400  // 100KB
        ]
        
        // Add some random sizes
        let randomSizes = (0..<20).map { _ in Int.random(in: 0...50000) }
        let allSizes = testSizes + randomSizes
        
        var failedCases: [(size: Int, error: Error)] = []
        
        for size in allSizes {
            let testData = generateRandomData(size: size)
            
            do {
                // Encrypt
                let encrypted = try securityManager.encryptData(testData)
                
                // Decrypt
                let decrypted = try securityManager.decryptData(encrypted)
                
                // Verify
                if decrypted != testData {
                    failedCases.append((size: size, error: NSError(domain: "RoundTripFailed", code: 1)))
                }
                
            } catch {
                failedCases.append((size: size, error: error))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Variable size property failed for \(failedCases.count) sizes: \(failedCases.map { $0.size })")
    }
    
    /// Property: Encryption key persistence - data encrypted before app restart can be decrypted after
    /// This validates that keys are properly stored in Keychain
    func testProperty18_KeyPersistence_DataDecryptableAcrossInstances() throws {
        let iterations = 20
        var failedCases: [(input: Data, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test data
            let dataSize = Int.random(in: 1...1000)
            let originalData = generateRandomData(size: dataSize)
            
            do {
                // Encrypt with current instance
                let encryptedData = try securityManager.encryptData(originalData)
                
                // Simulate app restart by getting a fresh reference to the singleton
                // (In a real scenario, this would be a new app launch)
                let newManager = SecurityManager.shared
                
                // Decrypt with "new" instance
                let decryptedData = try newManager.decryptData(encryptedData)
                
                // Verify round-trip property across instances
                if decryptedData != originalData {
                    failedCases.append((input: originalData, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Encryption/decryption failed with error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Key persistence property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
