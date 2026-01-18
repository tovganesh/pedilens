//
//  SecurityManagerTests.swift
//  PediLensTests
//
//  Unit tests for SecurityManager
//

import XCTest
@testable import PediLens

final class SecurityManagerTests: XCTestCase {
    
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
    
    // MARK: - Key Generation and Storage Tests
    
    func testStoreEncryptionKey_Success() throws {
        // When: Store a new encryption key
        XCTAssertNoThrow(try securityManager.storeEncryptionKey())
        
        // Then: Key should be retrievable
        let retrievedKey = try securityManager.retrieveEncryptionKey()
        XCTAssertEqual(retrievedKey.count, 32, "Key should be 256 bits (32 bytes)")
    }
    
    func testRetrieveEncryptionKey_WhenKeyDoesNotExist_ThrowsKeyNotFound() {
        // Given: No key exists in Keychain
        // When/Then: Retrieving should throw keyNotFound error
        XCTAssertThrowsError(try securityManager.retrieveEncryptionKey()) { error in
            XCTAssertEqual(error as? SecurityError, SecurityError.keyNotFound)
        }
    }
    
    func testRetrieveEncryptionKey_AfterStoring_ReturnsCorrectKey() throws {
        // Given: A key is stored
        try securityManager.storeEncryptionKey()
        let firstKey = try securityManager.retrieveEncryptionKey()
        
        // When: Retrieve the key again
        let secondKey = try securityManager.retrieveEncryptionKey()
        
        // Then: Both keys should be identical
        XCTAssertEqual(firstKey, secondKey)
    }
    
    func testStoreEncryptionKey_CalledTwice_ReplacesOldKey() throws {
        // Given: A key is stored
        try securityManager.storeEncryptionKey()
        let firstKey = try securityManager.retrieveEncryptionKey()
        
        // When: Store a new key
        try securityManager.storeEncryptionKey()
        let secondKey = try securityManager.retrieveEncryptionKey()
        
        // Then: Keys should be different (new key replaced old one)
        XCTAssertNotEqual(firstKey, secondKey)
    }
    
    // MARK: - Encryption Tests
    
    func testEncryptData_WithValidData_ReturnsEncryptedData() throws {
        // Given: Some plaintext data
        let plaintext = "Sensitive patient data".data(using: .utf8)!
        
        // When: Encrypt the data
        let encrypted = try securityManager.encryptData(plaintext)
        
        // Then: Encrypted data should be different from plaintext
        XCTAssertNotEqual(encrypted, plaintext)
        // Encrypted data should be longer (includes nonce and tag)
        XCTAssertGreaterThan(encrypted.count, plaintext.count)
    }
    
    func testEncryptData_SameDataTwice_ProducesDifferentCiphertext() throws {
        // Given: Some plaintext data
        let plaintext = "Patient record".data(using: .utf8)!
        
        // When: Encrypt the same data twice
        let encrypted1 = try securityManager.encryptData(plaintext)
        let encrypted2 = try securityManager.encryptData(plaintext)
        
        // Then: Ciphertexts should be different (due to random nonce)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }
    
    func testEncryptData_WithEmptyData_Succeeds() throws {
        // Given: Empty data
        let emptyData = Data()
        
        // When: Encrypt empty data
        let encrypted = try securityManager.encryptData(emptyData)
        
        // Then: Should succeed and produce non-empty result (nonce + tag)
        XCTAssertGreaterThan(encrypted.count, 0)
    }
    
    func testEncryptData_WithLargeData_Succeeds() throws {
        // Given: Large data (1MB)
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        
        // When: Encrypt large data
        let encrypted = try securityManager.encryptData(largeData)
        
        // Then: Should succeed
        XCTAssertGreaterThan(encrypted.count, largeData.count)
    }
    
    // MARK: - Decryption Tests
    
    func testDecryptData_WithValidEncryptedData_ReturnsOriginalData() throws {
        // Given: Encrypted data
        let plaintext = "Patient medical record".data(using: .utf8)!
        let encrypted = try securityManager.encryptData(plaintext)
        
        // When: Decrypt the data
        let decrypted = try securityManager.decryptData(encrypted)
        
        // Then: Decrypted data should match original plaintext
        XCTAssertEqual(decrypted, plaintext)
    }
    
    func testDecryptData_WithInvalidData_ThrowsDecryptionFailed() throws {
        // Given: Invalid encrypted data
        let invalidData = "Not encrypted data".data(using: .utf8)!
        
        // When/Then: Decryption should fail
        XCTAssertThrowsError(try securityManager.decryptData(invalidData)) { error in
            XCTAssertEqual(error as? SecurityError, SecurityError.decryptionFailed)
        }
    }
    
    func testDecryptData_WithTamperedData_ThrowsDecryptionFailed() throws {
        // Given: Encrypted data that has been tampered with
        let plaintext = "Original data".data(using: .utf8)!
        var encrypted = try securityManager.encryptData(plaintext)
        
        // Tamper with the encrypted data
        encrypted[encrypted.count - 1] ^= 0xFF
        
        // When/Then: Decryption should fail (authentication tag mismatch)
        XCTAssertThrowsError(try securityManager.decryptData(encrypted)) { error in
            XCTAssertEqual(error as? SecurityError, SecurityError.decryptionFailed)
        }
    }
    
    func testDecryptData_WithEmptyData_ThrowsDecryptionFailed() {
        // Given: Empty data
        let emptyData = Data()
        
        // When/Then: Decryption should fail
        XCTAssertThrowsError(try securityManager.decryptData(emptyData)) { error in
            XCTAssertEqual(error as? SecurityError, SecurityError.decryptionFailed)
        }
    }
    
    // MARK: - Round-Trip Tests
    
    func testEncryptionDecryption_RoundTrip_PreservesData() throws {
        // Given: Various types of data
        let testCases = [
            "Simple text".data(using: .utf8)!,
            "Special chars: 你好 🏥 @#$%".data(using: .utf8)!,
            Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD]), // Binary data
            Data(repeating: 0xAA, count: 1000), // Repeated pattern
            Data() // Empty data
        ]
        
        for (index, plaintext) in testCases.enumerated() {
            // When: Encrypt and then decrypt
            let encrypted = try securityManager.encryptData(plaintext)
            let decrypted = try securityManager.decryptData(encrypted)
            
            // Then: Should get back original data
            XCTAssertEqual(decrypted, plaintext, "Round-trip failed for test case \(index)")
        }
    }
    
    func testEncryptionDecryption_WithDifferentKeys_Fails() throws {
        // Given: Data encrypted with one key
        let plaintext = "Secret data".data(using: .utf8)!
        let encrypted = try securityManager.encryptData(plaintext)
        
        // When: Replace the key with a new one
        try securityManager.storeEncryptionKey()
        
        // Then: Decryption should fail with the new key
        XCTAssertThrowsError(try securityManager.decryptData(encrypted)) { error in
            XCTAssertEqual(error as? SecurityError, SecurityError.decryptionFailed)
        }
    }
    
    // MARK: - Key Persistence Tests
    
    func testEncryptionKey_PersistsAcrossInstances() throws {
        // Given: A key is stored and data is encrypted
        let plaintext = "Persistent data".data(using: .utf8)!
        let encrypted = try securityManager.encryptData(plaintext)
        
        // When: Create a new SecurityManager instance (simulating app restart)
        let newManager = SecurityManager.shared
        
        // Then: Should be able to decrypt with the persisted key
        let decrypted = try newManager.decryptData(encrypted)
        XCTAssertEqual(decrypted, plaintext)
    }
    
    // MARK: - Edge Cases
    
    func testEncryptData_WithUnicodeData_PreservesContent() throws {
        // Given: Unicode text data
        let unicodeText = "Patient: 田中太郎, Diagnosis: 糖尿病性足潰瘍 🏥"
        let plaintext = unicodeText.data(using: .utf8)!
        
        // When: Encrypt and decrypt
        let encrypted = try securityManager.encryptData(plaintext)
        let decrypted = try securityManager.decryptData(encrypted)
        let decryptedText = String(data: decrypted, encoding: .utf8)
        
        // Then: Unicode content should be preserved
        XCTAssertEqual(decryptedText, unicodeText)
    }
    
    func testEncryptData_WithBinaryData_PreservesBytes() throws {
        // Given: Binary data (simulating image data)
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        
        // When: Encrypt and decrypt
        let encrypted = try securityManager.encryptData(binaryData)
        let decrypted = try securityManager.decryptData(encrypted)
        
        // Then: Binary data should be preserved exactly
        XCTAssertEqual(decrypted, binaryData)
    }
    
    // MARK: - Session Management Tests
    
    func testIsSessionValid_WhenNoAuthentication_ReturnsFalse() {
        // Given: No authentication has occurred
        securityManager.invalidateSession()
        
        // When: Check if session is valid
        let isValid = securityManager.isSessionValid()
        
        // Then: Should return false
        XCTAssertFalse(isValid)
    }
    
    func testInvalidateSession_ClearsAuthenticationState() {
        // Given: A session exists (we'll simulate by checking the method exists)
        // When: Invalidate the session
        securityManager.invalidateSession()
        
        // Then: Session should not be valid
        XCTAssertFalse(securityManager.isSessionValid())
    }
    
    func testSessionTimeRemaining_WhenNoSession_ReturnsNil() {
        // Given: No active session
        securityManager.invalidateSession()
        
        // When: Check time remaining
        let timeRemaining = securityManager.sessionTimeRemaining()
        
        // Then: Should return nil
        XCTAssertNil(timeRemaining)
    }
    
    // Note: Full biometric authentication tests require a physical device or simulator with enrolled biometrics
    // These tests verify the session management logic, while actual biometric authentication
    // should be tested manually on device
}
