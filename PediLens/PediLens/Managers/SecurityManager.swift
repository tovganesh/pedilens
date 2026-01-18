//
//  SecurityManager.swift
//  PediLens
//
//  Created by PediLens Team
//  Security and encryption management for HIPAA-compliant data protection
//

import Foundation
import Security
import CryptoKit

/// Protocol defining security operations for data encryption and key management
protocol SecurityManagerProtocol {
    func encryptData(_ data: Data) throws -> Data
    func decryptData(_ data: Data) throws -> Data
    func storeEncryptionKey() throws
    func retrieveEncryptionKey() throws -> Data
    func authenticateUser() async throws -> Bool
}

/// Errors that can occur during security operations
enum SecurityError: LocalizedError {
    case keyGenerationFailed
    case keyStorageFailed
    case keyRetrievalFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyStorageFailed:
            return "Failed to store encryption key in Keychain"
        case .keyRetrievalFailed:
            return "Failed to retrieve encryption key from Keychain"
        case .keyNotFound:
            return "Encryption key not found in Keychain"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid data format"
        case .authenticationFailed:
            return "User authentication failed"
        }
    }
}

/// Manages encryption, decryption, and secure key storage for PediLens
/// Implements AES-256 encryption with keys stored in iOS Keychain
class SecurityManager: SecurityManagerProtocol {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = SecurityManager()
    
    /// Keychain service identifier
    private let keychainService = "com.pedilens.app.encryption"
    
    /// Keychain account identifier for the encryption key
    private let keychainAccount = "pedilens-master-key"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Encrypts data using AES-256-GCM encryption
    /// - Parameter data: The data to encrypt
    /// - Returns: Encrypted data with nonce prepended
    /// - Throws: SecurityError if encryption fails
    func encryptData(_ data: Data) throws -> Data {
        // Retrieve or generate encryption key
        let key = try getOrCreateEncryptionKey()
        
        // Create symmetric key from raw key data
        let symmetricKey = SymmetricKey(data: key)
        
        // Generate a sealed box (includes nonce, ciphertext, and authentication tag)
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            
            // Return the combined data (nonce + ciphertext + tag)
            guard let combined = sealedBox.combined else {
                throw SecurityError.encryptionFailed
            }
            
            return combined
        } catch {
            throw SecurityError.encryptionFailed
        }
    }
    
    /// Decrypts data that was encrypted with AES-256-GCM
    /// - Parameter data: The encrypted data (with nonce prepended)
    /// - Returns: Decrypted plaintext data
    /// - Throws: SecurityError if decryption fails
    func decryptData(_ data: Data) throws -> Data {
        // Retrieve encryption key
        let key = try retrieveEncryptionKey()
        
        // Create symmetric key from raw key data
        let symmetricKey = SymmetricKey(data: key)
        
        // Create sealed box from combined data
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            
            // Decrypt and verify authentication
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            
            return decryptedData
        } catch {
            throw SecurityError.decryptionFailed
        }
    }
    
    /// Generates and stores a new encryption key in the Keychain
    /// - Throws: SecurityError if key generation or storage fails
    func storeEncryptionKey() throws {
        // Generate a 256-bit (32-byte) random key
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw SecurityError.keyGenerationFailed
        }
        
        // Store in Keychain with strict accessibility
        try storeKeyInKeychain(keyData)
    }
    
    /// Retrieves the encryption key from the Keychain
    /// - Returns: The encryption key data
    /// - Throws: SecurityError if key retrieval fails
    func retrieveEncryptionKey() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecurityError.keyNotFound
            }
            throw SecurityError.keyRetrievalFailed
        }
        
        guard let keyData = result as? Data else {
            throw SecurityError.keyRetrievalFailed
        }
        
        return keyData
    }
    
    /// Authenticates the user using biometric or device passcode
    /// - Returns: True if authentication succeeds
    /// - Throws: SecurityError if authentication fails
    func authenticateUser() async throws -> Bool {
        // This is a placeholder for LocalAuthentication integration
        // Will be implemented in task 2.3
        return true
    }
    
    // MARK: - Private Methods
    
    /// Gets existing encryption key or creates a new one if it doesn't exist
    /// - Returns: The encryption key data
    /// - Throws: SecurityError if key operations fail
    private func getOrCreateEncryptionKey() throws -> Data {
        do {
            // Try to retrieve existing key
            return try retrieveEncryptionKey()
        } catch SecurityError.keyNotFound {
            // Key doesn't exist, create a new one
            try storeEncryptionKey()
            return try retrieveEncryptionKey()
        } catch {
            throw error
        }
    }
    
    /// Stores the encryption key in the iOS Keychain with strict security settings
    /// - Parameter keyData: The key data to store
    /// - Throws: SecurityError if storage fails
    private func storeKeyInKeychain(_ keyData: Data) throws {
        // First, delete any existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key with strict accessibility
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            // Key is only accessible when device is unlocked and cannot be backed up
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecurityError.keyStorageFailed
        }
    }
}
