// WallSummary.swift
// Minimal placeholder for build
import Foundation
import simd

public struct WallSummary: Identifiable, Codable {
    public let id: UUID
    public var length: Float
    public var height: Float
    public var thickness: Float
    public var normal: simd_float3
    public var start: simd_float3
    public var end: simd_float3
    public var position: simd_float3
    
    public init(id: UUID = UUID(), length: Float = 0, height: Float = 0, thickness: Float = 0, 
                normal: simd_float3 = .zero, start: simd_float3 = .zero, end: simd_float3 = .zero,
                position: simd_float3 = .zero) {
        self.id = id
        self.length = length
        self.height = height
        self.thickness = thickness
        self.normal = normal
        self.start = start
        self.end = end
        self.position = position
    }
}