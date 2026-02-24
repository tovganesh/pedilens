# Wound Detection ML Implementation Guide

## Overview
This guide covers three approaches to implement real wound detection in PediLens:
1. Train a custom CoreML model using Kaggle datasets
2. Integrate pre-trained medical segmentation models
3. Use cloud-based medical image analysis APIs

## Approach 1: Custom CoreML Model Training

### Step 1: Data Collection from Kaggle

#### Recommended Datasets
1. **Medetec Wound Database**
   - Search: "wound images dataset" on Kaggle
   - Contains labeled chronic wound images
   
2. **Diabetic Foot Ulcer Dataset**
   - Search: "diabetic foot ulcer" on Kaggle
   - Specific to foot wounds (relevant for PediLens)

3. **DFUC2020 Dataset**
   - Diabetic Foot Ulcer Challenge dataset
   - Contains segmentation masks

#### Data Preparation Steps
```bash
# 1. Download dataset from Kaggle
pip install kaggle
kaggle datasets download -d <dataset-name>

# 2. Extract and organize
unzip dataset.zip -d wound_data/
```

### Step 2: Model Training Pipeline

#### Required Tools
- Python 3.8+
- TensorFlow or PyTorch
- CoreML Tools
- Create ML (optional, for simpler approach)

#### Training Script Structure
```python
# train_wound_segmentation.py
import tensorflow as tf
from tensorflow import keras
import coremltools as ct
import numpy as np
from PIL import Image
import os

# Model Architecture: U-Net for Segmentation
def create_unet_model(input_shape=(512, 512, 3)):
    inputs = keras.Input(shape=input_shape)
    
    # Encoder
    c1 = keras.layers.Conv2D(64, 3, activation='relu', padding='same')(inputs)
    c1 = keras.layers.Conv2D(64, 3, activation='relu', padding='same')(c1)
    p1 = keras.layers.MaxPooling2D(2)(c1)
    
    c2 = keras.layers.Conv2D(128, 3, activation='relu', padding='same')(p1)
    c2 = keras.layers.Conv2D(128, 3, activation='relu', padding='same')(c2)
    p2 = keras.layers.MaxPooling2D(2)(c2)
    
    # Bottleneck
    c3 = keras.layers.Conv2D(256, 3, activation='relu', padding='same')(p2)
    c3 = keras.layers.Conv2D(256, 3, activation='relu', padding='same')(c3)
    
    # Decoder
    u1 = keras.layers.UpSampling2D(2)(c3)
    u1 = keras.layers.concatenate([u1, c2])
    c4 = keras.layers.Conv2D(128, 3, activation='relu', padding='same')(u1)
    
    u2 = keras.layers.UpSampling2D(2)(c4)
    u2 = keras.layers.concatenate([u2, c1])
    c5 = keras.layers.Conv2D(64, 3, activation='relu', padding='same')(u2)
    
    outputs = keras.layers.Conv2D(1, 1, activation='sigmoid')(c5)
    
    model = keras.Model(inputs=[inputs], outputs=[outputs])
    return model

# Training
model = create_unet_model()
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# Load and preprocess data
# ... (data loading code)

# Train
model.fit(train_data, train_masks, epochs=50, validation_split=0.2)

# Convert to CoreML
coreml_model = ct.convert(
    model,
    inputs=[ct.ImageType(name="image", shape=(1, 512, 512, 3))],
    outputs=[ct.ImageType(name="segmentation_mask")]
)

# Save
coreml_model.save("WoundSegmentation.mlmodel")
```

### Step 3: Integration into PediLens

Create a new file for the CoreML model wrapper:


## Approach 2: Pre-trained Medical Segmentation Models

### Option A: DeepLabV3 with Medical Fine-tuning

Apple provides DeepLabV3 models that can be fine-tuned for medical images.

#### Implementation Steps

1. **Download Pre-trained Model**
```swift
// Use Apple's DeepLabV3 model
import CoreML
import Vision

class PretrainedWoundDetection {
    private var model: VNCoreMLModel?
    
    init() {
        // Download from Apple's model gallery or use custom trained
        if let modelURL = Bundle.main.url(forResource: "DeepLabV3", withExtension: "mlmodelc") {
            do {
                let mlModel = try MLModel(contentsOf: modelURL)
                self.model = try VNCoreMLModel(for: mlModel)
            } catch {
                print("Failed to load model: \\(error)")
            }
        }
    }
    
    func detectWound(in image: UIImage) async throws -> [[Bool]] {
        guard let model = model else {
            throw WoundDetectionError.modelLoadFailed
        }
        
        guard let cgImage = image.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNPixelBufferObservation],
                      let segmentation = results.first else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                // Convert pixel buffer to mask
                let mask = self.convertToMask(segmentation.pixelBuffer)
                continuation.resume(returning: mask)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func convertToMask(_ pixelBuffer: CVPixelBuffer) -> [[Bool]] {
        // Convert CVPixelBuffer to 2D boolean array
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return []
        }
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x
                let pixel = baseAddress.load(fromByteOffset: pixelOffset, as: UInt8.self)
                mask[y][x] = pixel > 128 // Threshold for wound class
            }
        }
        
        return mask
    }
}
```

### Option B: MONAI (Medical Open Network for AI)

MONAI provides pre-trained models specifically for medical imaging.

#### Steps to Use MONAI Models

1. **Train/Fine-tune in Python**
```python
# monai_wound_training.py
from monai.networks.nets import UNet
from monai.transforms import Compose, LoadImage, ScaleIntensity
import torch

# Load MONAI pre-trained model
model = UNet(
    spatial_dims=2,
    in_channels=3,
    out_channels=1,
    channels=(16, 32, 64, 128, 256),
    strides=(2, 2, 2, 2),
)

# Fine-tune on wound dataset
# ... training code ...

# Export to ONNX
torch.onnx.export(model, dummy_input, "wound_model.onnx")

# Convert ONNX to CoreML
import coremltools as ct
mlmodel = ct.converters.onnx.convert(model="wound_model.onnx")
mlmodel.save("WoundSegmentationMONAI.mlmodel")
```

## Approach 3: Cloud-Based Medical Image Analysis APIs

### Option A: Azure Health Bot / Azure AI for Health

#### Setup
1. Create Azure account
2. Enable Azure Cognitive Services for Health
3. Get API key

#### Implementation
```swift
// AzureWoundAnalysisService.swift
import Foundation

class AzureWoundAnalysisService {
    private let apiKey: String
    private let endpoint: String
    
    init(apiKey: String, endpoint: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }
    
    func analyzeWound(image: UIImage) async throws -> WoundBoundary {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw WoundDetectionError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Prepare request
        var request = URLRequest(url: URL(string: "\\(endpoint)/vision/v3.2/analyze")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "image": base64Image,
            "features": ["segmentation", "objects"],
            "model": "medical-wound-v1"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WoundDetectionError.detectionFailed
        }
        
        // Parse response
        let result = try JSONDecoder().decode(AzureWoundResponse.self, from: data)
        return convertToWoundBoundary(result)
    }
    
    private func convertToWoundBoundary(_ response: AzureWoundResponse) -> WoundBoundary {
        // Convert API response to WoundBoundary
        // ... conversion logic ...
        fatalError("Implement conversion")
    }
}

struct AzureWoundResponse: Codable {
    let segmentation: SegmentationResult
    let confidence: Float
}

struct SegmentationResult: Codable {
    let mask: String // Base64 encoded mask
    let boundingBox: BoundingBox
}

struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
```

### Option B: Google Cloud Healthcare API

#### Setup
1. Enable Google Cloud Healthcare API
2. Create service account
3. Download credentials JSON

#### Implementation
```swift
// GoogleHealthcareWoundService.swift
import Foundation

class GoogleHealthcareWoundService {
    private let projectId: String
    private let location: String
    private let datasetId: String
    
    func analyzeWound(image: UIImage) async throws -> WoundBoundary {
        // Similar structure to Azure implementation
        // Use Google Cloud Vision API with Healthcare extensions
        
        let url = "https://healthcare.googleapis.com/v1/projects/\\(projectId)/locations/\\(location)/datasets/\\(datasetId)/dicomWeb/studies"
        
        // Implementation details...
        fatalError("Implement Google Healthcare API")
    }
}
```

### Option C: AWS HealthLake + Rekognition Custom Labels

#### Setup
1. Create AWS account
2. Enable Amazon Rekognition Custom Labels
3. Train custom model with wound images

#### Implementation
```swift
// AWSWoundDetectionService.swift
import Foundation
import AWSRekognition

class AWSWoundDetectionService {
    private let rekognition: AWSRekognition
    private let projectArn: String
    
    init(projectArn: String) {
        self.projectArn = projectArn
        self.rekognition = AWSRekognition.default()
    }
    
    func detectWound(image: UIImage) async throws -> WoundBoundary {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw WoundDetectionError.invalidImage
        }
        
        let request = AWSRekognitionDetectCustomLabelsRequest()
        request?.image = AWSRekognitionImage()
        request?.image?.bytes = imageData
        request?.projectVersionArn = projectArn
        
        return try await withCheckedThrowingContinuation { continuation in
            rekognition.detectCustomLabels(request!) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let labels = response?.customLabels else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                // Process labels and extract wound boundary
                let boundary = self.processLabels(labels)
                continuation.resume(returning: boundary)
            }
        }
    }
    
    private func processLabels(_ labels: [AWSRekognitionCustomLabel]) -> WoundBoundary {
        // Convert AWS labels to WoundBoundary
        fatalError("Implement label processing")
    }
}
```

## Recommended Approach for PediLens

### Hybrid Strategy

1. **Start with Custom CoreML Model** (Best for privacy & offline use)
   - Train on Kaggle datasets
   - Deploy in app bundle
   - No internet required
   - HIPAA compliant (data stays on device)

2. **Add Cloud API as Optional Enhancement** (For improved accuracy)
   - Make it opt-in
   - Use for second opinion
   - Require explicit user consent
   - Anonymize images before upload

3. **Implementation Priority**
   ```
   Phase 1: Basic CoreML model (U-Net architecture)
   Phase 2: Improve with more training data
   Phase 3: Add cloud API option for users who consent
   Phase 4: Continuous learning from user corrections
   ```

## Privacy & Compliance Considerations

### HIPAA Compliance
- ✅ On-device CoreML: Fully compliant
- ⚠️ Cloud APIs: Requires BAA (Business Associate Agreement)
- ✅ Anonymization: Remove all metadata before cloud upload
- ✅ Encryption: Use TLS 1.3 for API calls

### User Consent Flow
```swift
// Add to app settings
struct MLSettings {
    var useCloudEnhancement: Bool = false
    var hasConsentedToCloudProcessing: Bool = false
    var preferredProvider: CloudProvider = .none
}

enum CloudProvider {
    case none
    case azure
    case google
    case aws
}
```

## Next Steps

1. **Immediate**: Set up Python environment for model training
2. **Week 1**: Download and prepare Kaggle datasets
3. **Week 2**: Train initial U-Net model
4. **Week 3**: Convert to CoreML and integrate
5. **Week 4**: Test and refine
6. **Future**: Add cloud API option with consent

## Resources

### Datasets
- Kaggle: https://www.kaggle.com/datasets (search "wound", "ulcer", "diabetic foot")
- DFUC2020: https://dfu-challenge.github.io/
- Medetec: http://www.medetec.co.uk/

### Tools
- CoreML Tools: https://apple.github.io/coremltools/
- Create ML: https://developer.apple.com/machine-learning/create-ml/
- MONAI: https://monai.io/
- TensorFlow: https://www.tensorflow.org/

### Documentation
- Apple ML: https://developer.apple.com/machine-learning/
- Vision Framework: https://developer.apple.com/documentation/vision
- Azure Health: https://azure.microsoft.com/en-us/products/health-bot
