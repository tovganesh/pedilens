//
//  DuoLayoutHelperTests.swift
//  PediLensTests
//
//  Tests for iPhone Duo layout helper, screen geometry calculations,
//  display mode detection, and hinge crease awareness.
//

import XCTest
import SwiftUI
@testable import PediLens

final class DuoLayoutHelperTests: XCTestCase {
    
    // MARK: - Display Mode Detection Tests
    
    func testCoverScreenDetection_StandardCoverDimensions() {
        // iPhone Duo Cover Screen: 466 x 678 pt (1398 x 2034 px @3x)
        let coverSize = CGSize(width: 466, height: 678)
        let geometry = DuoScreenGeometry(size: coverSize, isRegularWidth: false, isRegularHeight: false)
        
        XCTAssertEqual(geometry.displayMode, .cover)
        XCTAssertTrue(geometry.isCoverScreen)
        XCTAssertFalse(geometry.isInternalExpanded)
        XCTAssertNil(geometry.hingeCreaseRect)
    }
    
    func testInternalScreenDetection_PortraitDimensions() {
        // iPhone Duo Internal Screen Portrait: 669 x 951 pt (2007 x 2853 px @3x)
        let internalSize = CGSize(width: 669, height: 951)
        let geometry = DuoScreenGeometry(size: internalSize, isRegularWidth: true, isRegularHeight: true)
        
        XCTAssertEqual(geometry.displayMode, .internalExpanded)
        XCTAssertTrue(geometry.isInternalExpanded)
        XCTAssertFalse(geometry.isCoverScreen)
        XCTAssertFalse(geometry.isLandscape)
        
        // Hinge should run vertically through center in portrait
        guard let hinge = geometry.hingeCreaseRect else {
            XCTFail("Expected hingeCreaseRect for internal screen")
            return
        }
        XCTAssertEqual(hinge.midX, 669 / 2.0, accuracy: 1.0)
        XCTAssertEqual(hinge.height, 951, accuracy: 0.1)
    }
    
    func testInternalScreenDetection_LandscapeDimensions() {
        // iPhone Duo Internal Screen Landscape: 951 x 669 pt
        let internalSize = CGSize(width: 951, height: 669)
        let geometry = DuoScreenGeometry(size: internalSize, isRegularWidth: true, isRegularHeight: true)
        
        XCTAssertEqual(geometry.displayMode, .internalExpanded)
        XCTAssertTrue(geometry.isInternalExpanded)
        XCTAssertTrue(geometry.isLandscape)
        
        // Hinge should run horizontally through center in landscape
        guard let hinge = geometry.hingeCreaseRect else {
            XCTFail("Expected hingeCreaseRect for internal screen in landscape")
            return
        }
        XCTAssertEqual(hinge.midY, 669 / 2.0, accuracy: 1.0)
        XCTAssertEqual(hinge.width, 951, accuracy: 0.1)
    }
    
    func testStandardPhoneDetection() {
        // Standard iPhone (iPhone 16 / 17: 393 x 852 pt)
        let standardSize = CGSize(width: 393, height: 852)
        let geometry = DuoScreenGeometry(size: standardSize, isRegularWidth: false, isRegularHeight: true)
        
        XCTAssertEqual(geometry.displayMode, .standardPhone)
        XCTAssertFalse(geometry.isCoverScreen)
        XCTAssertFalse(geometry.isInternalExpanded)
        XCTAssertNil(geometry.hingeCreaseRect)
    }
    
    func testMasterPaneWidthCalculations() {
        let portraitInternal = DuoScreenGeometry(size: CGSize(width: 669, height: 951), isRegularWidth: true, isRegularHeight: true)
        let width = portraitInternal.masterPaneWidth
        XCTAssertGreaterThanOrEqual(width, 280)
        XCTAssertLessThanOrEqual(width, 330)
        
        let landscapeInternal = DuoScreenGeometry(size: CGSize(width: 951, height: 669), isRegularWidth: true, isRegularHeight: true)
        let landWidth = landscapeInternal.masterPaneWidth
        XCTAssertGreaterThanOrEqual(landWidth, 300)
        XCTAssertLessThanOrEqual(landWidth, 360)
    }
    
    func testCoverCornerPadding_AppliedOnlyOnCover() {
        let cover = DuoScreenGeometry(size: CGSize(width: 466, height: 678), isRegularWidth: false, isRegularHeight: false)
        XCTAssertGreaterThan(cover.coverCornerPadding.leading, 0)
        XCTAssertGreaterThan(cover.coverCornerPadding.trailing, 0)
        
        let standard = DuoScreenGeometry(size: CGSize(width: 393, height: 852), isRegularWidth: false, isRegularHeight: true)
        XCTAssertEqual(standard.coverCornerPadding.leading, 0)
        XCTAssertEqual(standard.coverCornerPadding.trailing, 0)
    }
}
