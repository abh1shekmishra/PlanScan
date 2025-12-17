// DummyRoomPlan.swift
// Dummy RoomPlan types for simulator/macOS builds

#if !canImport(RoomPlan)
import Foundation
import simd
import SwiftUI

public class RoomCaptureSession: NSObject {
    public class Configuration {}
    public var delegate: RoomCaptureSessionDelegate?
    public func run(configuration: Configuration) {}
    public func stop() {}
    public static var isSupported: Bool { false }
}

public protocol RoomCaptureSessionDelegate: AnyObject {}

public class RoomCaptureView: UIView {
    public var delegate: RoomCaptureViewDelegate?
    public var captureSession: RoomCaptureSession? = RoomCaptureSession()
    public override init(frame: CGRect) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

public protocol RoomCaptureViewDelegate: AnyObject {}

public class CapturedRoom: NSObject {
    public var walls: [WallSummary] = []
    public var openings: [OpeningSummary] = []
    public override init() { super.init() }
}

public class CapturedRoomData: NSObject {}
#endif
