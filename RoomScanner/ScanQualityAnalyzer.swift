/*
 ScanQualityAnalyzer.swift
 Purpose: Analyze scan quality, measurement confidence, and geometric validation
 
 Created: December 2025
 */

import Foundation
import simd

/// Quality score for a scan
enum ScanQuality {
    case high
    case medium
    case low
     
    var description: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        }
    }
}

/// Confidence level for measurements
enum MeasurementConfidence {
    case high
    case medium
    case low
    
    var description: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }
}

/// Validation issue found in scan
struct ValidationIssue: Identifiable {
    let id = UUID()
    let severity: IssueSeverity
    let title: String
    let description: String
    let recommendation: String
    
    enum IssueSeverity {
        case critical
        case warning
        case info
        
        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .warning: return "orange"
            case .info: return "blue"
            }
        }
    }
}

/// Complete quality report for a scan
struct ScanQualityReport {
    let overallQuality: ScanQuality
    let qualityScore: Int // 0-100
    let coveragePercentage: Float // 0-100
    let wallConfidence: [String: MeasurementConfidence] // wall ID -> confidence
    let issues: [ValidationIssue]
    let recommendations: [String]
}

class ScanQualityAnalyzer {
    
    // MARK: - Quality Analysis
    
    /// Analyze overall scan quality
    static func analyzeScanQuality(room: CapturedRoomSummary) -> ScanQualityReport {
        var qualityScore = 100
        var issues: [ValidationIssue] = []
        var recommendations: [String] = []
        
        // Check wall count
        let wallCountScore = analyzeWallCount(walls: room.walls, issues: &issues)
        qualityScore -= (100 - wallCountScore)
        
        // Check wall measurements
        let measurementScore = analyzeWallMeasurements(walls: room.walls, issues: &issues)
        qualityScore -= (100 - measurementScore)
        
        // Validate geometry
        let geometryScore = validateGeometry(walls: room.walls, issues: &issues)
        qualityScore -= (100 - geometryScore)
        
        // Check for intersecting walls
        checkWallIntersections(walls: room.walls, issues: &issues)
        
        // Check wall parallelism
        checkWallParallelism(walls: room.walls, issues: &issues)
        
        // Calculate coverage
        let coverage = estimateCoverage(walls: room.walls, openings: room.openings)
        
        // Generate wall confidence map
        let wallConfidence = calculateWallConfidence(walls: room.walls)
        
        // Generate recommendations
        recommendations = generateRecommendations(
            qualityScore: qualityScore,
            coverage: coverage,
            issues: issues
        )
        
        // Determine overall quality
        let overallQuality: ScanQuality
        if qualityScore >= 80 {
            overallQuality = .high
        } else if qualityScore >= 60 {
            overallQuality = .medium
        } else {
            overallQuality = .low
        }
        
        return ScanQualityReport(
            overallQuality: overallQuality,
            qualityScore: max(0, qualityScore),
            coveragePercentage: coverage,
            wallConfidence: wallConfidence,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    // MARK: - Wall Count Analysis
    
    private static func analyzeWallCount(walls: [WallSummary], issues: inout [ValidationIssue]) -> Int {
        let wallCount = walls.count
        
        if wallCount < 3 {
            issues.append(ValidationIssue(
                severity: .critical,
                title: "Insufficient Walls Detected",
                description: "Only \(wallCount) wall(s) detected. A typical room has 4+ walls.",
                recommendation: "Re-scan the room ensuring all walls are visible to the camera."
            ))
            return 30
        } else if wallCount == 3 {
            issues.append(ValidationIssue(
                severity: .warning,
                title: "Incomplete Wall Detection",
                description: "Only 3 walls detected. One or more walls may be missing.",
                recommendation: "Verify all walls were scanned. Move slowly around the entire room."
            ))
            return 70
        }
        
        return 100
    }
    
    // MARK: - Measurement Analysis
    
    private static func analyzeWallMeasurements(walls: [WallSummary], issues: inout [ValidationIssue]) -> Int {
        var score = 100
        var lowConfidenceCount = 0
        
        for wall in walls {
            // Check for missing dimensions
            if wall.length == nil {
                issues.append(ValidationIssue(
                    severity: .warning,
                    title: "Missing Wall Length",
                    description: "Wall \(wall.id) is missing length measurement.",
                    recommendation: "Re-scan this area more slowly for better accuracy."
                ))
                score -= 10
                lowConfidenceCount += 1
            }
            
            // Check for unrealistic dimensions
            let length = wall.length
            if length > 0 {
                if length < 0.5 {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        title: "Unusually Short Wall",
                        description: "Wall \(wall.id.uuidString) is only \(String(format: "%.2f", length))m long.",
                        recommendation: "Verify this measurement. It may indicate a scanning error."
                    ))
                    score -= 5
                } else if length > 20 {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        title: "Unusually Long Wall",
                        description: "Wall \(wall.id.uuidString) is \(String(format: "%.2f", length))m long.",
                        recommendation: "Verify this measurement for large spaces."
                    ))
                    score -= 5
                }
            }
            
            // Check wall height
            if wall.height < 2.0 || wall.height > 4.0 {
                issues.append(ValidationIssue(
                    severity: .info,
                    title: "Non-Standard Ceiling Height",
                    description: "Wall \(wall.id) has height of \(String(format: "%.2f", wall.height))m.",
                    recommendation: "Standard ceiling height is 2.4-3.0m. Verify if this is accurate."
                ))
            }
        }
        
        if lowConfidenceCount > walls.count / 2 {
            issues.append(ValidationIssue(
                severity: .warning,
                title: "Low Overall Measurement Quality",
                description: "\(lowConfidenceCount) of \(walls.count) walls have quality issues.",
                recommendation: "Consider re-scanning the entire room for better results."
            ))
        }
        
        return max(0, score)
    }
    
    // MARK: - Geometry Validation
    
    private static func validateGeometry(walls: [WallSummary], issues: inout [ValidationIssue]) -> Int {
        var score = 100
        
        // Check for closed room perimeter
        if !isRoomClosed(walls: walls) {
            issues.append(ValidationIssue(
                severity: .warning,
                title: "Room Perimeter Not Closed", 
                description: "Walls don't form a complete closed boundary.",
                recommendation: "Ensure you scan all corners and wall connections."
            ))
            score -= 20
        }
        
        // Check for reasonable room shape
        let aspectRatio = calculateAspectRatio(walls: walls)
        if aspectRatio > 5.0 {
            issues.append(ValidationIssue(
                severity: .info,
                title: "Unusual Room Shape",
                description: "Room has an unusual aspect ratio (very long/narrow).",
                recommendation: "Verify room dimensions are accurate for this unusual shape."
            ))
        }
        
        return max(0, score)
    }
    
    // MARK: - Wall Intersection Check
    
    private static func checkWallIntersections(walls: [WallSummary], issues: inout [ValidationIssue]) {
        let up = simd_float3(0, 1, 0)
        let defaultThickness: Float = 0.15
        
        for i in 0..<walls.count {
            for j in (i+1)..<walls.count {
                let wall1 = walls[i]
                let wall2 = walls[j]
                
                if wallsIntersect(wall1: wall1, wall2: wall2) {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        title: "Overlapping Walls Detected",
                        description: "Walls \(wall1.id) and \(wall2.id) appear to intersect.",
                        recommendation: "This may indicate a scanning error. Re-scan this area."
                    ))
                }
            }
        }
    }
    
    // MARK: - Wall Parallelism Check
    
    private static func checkWallParallelism(walls: [WallSummary], issues: inout [ValidationIssue]) {
        guard walls.count >= 4 else { return }
        
        let up = simd_float3(0, 1, 0)
        var normals: [simd_float3] = []
        
        for wall in walls {
            let normal = simd_normalize(wall.normal)
            normals.append(normal)
        }
        
        // Check if we have pairs of parallel walls (typical in rectangular rooms)
        var parallelPairs = 0
        for i in 0..<normals.count {
            for j in (i+1)..<normals.count {
                let dot = abs(simd_dot(normals[i], normals[j]))
                if dot > 0.98 { // Nearly parallel (within ~11 degrees)
                    parallelPairs += 1
                }
            }
        }
        
        if parallelPairs == 0 && walls.count == 4 {
            issues.append(ValidationIssue(
                severity: .info,
                title: "Non-Rectangular Room",
                description: "No parallel walls detected. Room may have irregular shape.",
                recommendation: "Verify measurements if a rectangular room was expected."
            ))
        }
    }
    
    // MARK: - Coverage Estimation
    
    private static func estimateCoverage(walls: [WallSummary], openings: [OpeningSummary]) -> Float {
        // Estimate based on wall count and measurements completeness
        var coverage: Float = 0
        
        // Base coverage from wall count (4 walls = 70% base)
        let wallCountFactor = min(Float(walls.count) / 4.0, 1.0) * 70
        coverage += wallCountFactor
        
        // Additional coverage from complete measurements
        let completeWalls = walls.filter { $0.length != nil && $0.thickness != nil }
        let measurementFactor = Float(completeWalls.count) / Float(max(walls.count, 1)) * 20
        coverage += measurementFactor
        
        // Bonus for openings detected
        if !openings.isEmpty {
            coverage += 10
        }
        
        return min(coverage, 100)
    }
    
    // MARK: - Confidence Calculation
    
    private static func calculateWallConfidence(walls: [WallSummary]) -> [String: MeasurementConfidence] {
        var confidenceMap: [String: MeasurementConfidence] = [:]
        
        for wall in walls {
            var confidence: MeasurementConfidence = .high
            
            // Check completeness and dimensions
            let length = wall.length
            if length <= 0 {
                confidence = .low
            } else if length < 0.5 || length > 15 {
                confidence = .medium
            }
            
            confidenceMap[wall.id.uuidString] = confidence
        }
        
        return confidenceMap
    }
    
    // MARK: - Recommendations
    
    private static func generateRecommendations(qualityScore: Int, coverage: Float, issues: [ValidationIssue]) -> [String] {
        var recommendations: [String] = []
        
        if qualityScore < 60 {
            recommendations.append("Consider re-scanning the room for better accuracy")
        }
        
        if coverage < 70 {
            recommendations.append("Scan coverage is incomplete. Move slowly around all walls")
        }
        
        let criticalIssues = issues.filter { $0.severity == .critical }
        if !criticalIssues.isEmpty {
            recommendations.append("Address critical issues before using this scan for planning")
        }
        
        if issues.count > 5 {
            recommendations.append("Multiple quality issues detected. A fresh scan is recommended")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Scan quality is good. Safe to use for measurements")
        }
        
        return recommendations
    }
    
    // MARK: - Helper Functions
    
    private static func isRoomClosed(walls: [WallSummary]) -> Bool {
        // Simple heuristic: if we have 4+ walls, assume closed
        // More sophisticated check would verify wall endpoints connect
        return walls.count >= 4
    }
    
    private static func calculateAspectRatio(walls: [WallSummary]) -> Float {
        let lengths = walls.compactMap { $0.length }
        guard lengths.count >= 2 else { return 1.0 }
        
        let sorted = lengths.sorted()
        return sorted.last! / sorted.first!
    }
    
    private static func wallsIntersect(wall1: WallSummary, wall2: WallSummary) -> Bool {
        // Simplified intersection check: check if wall centers are very close
        let distance = simd_distance(wall1.position, wall2.position)
        let avgLength = ((wall1.length ?? 1.0) + (wall2.length ?? 1.0)) / 2
        
        // If centers are closer than 10% of average length, consider them intersecting
        return distance < avgLength * 0.1
    }
}
