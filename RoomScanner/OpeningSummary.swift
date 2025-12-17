// OpeningSummary.swift
// Minimal placeholder for build
import Foundation
import simd

public struct OpeningSummary: Identifiable, Codable {
    public let id: UUID
    public var width: Float
    public var height: Float
    public var position: simd_float3
    public var type: String
    
    public init(id: UUID = UUID(), width: Float = 0, height: Float = 0, 
                position: simd_float3 = .zero, type: String = "") {
        self.id = id
        self.width = width
        self.height = height
        self.position = position
        self.type = type
    }
}