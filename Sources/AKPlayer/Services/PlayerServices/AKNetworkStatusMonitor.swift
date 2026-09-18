//
//   AKNetworkStatusMonitor.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import Network
import Synchronization

// MARK: - AKNetworkStatusMonitorProtocol

/// A contract for monitoring network status changes via NWPathMonitor.
public protocol AKNetworkStatusMonitorProtocol: AnyObject, Sendable {
    // MARK: - Properties
    
    /// The current network path object.
    var currentPath: NWPath? { get }
    
    /// The current status of the network path.
    var currentNetworkStatus: NWPath.Status { get }
    
    /// A convenience boolean indicating if the network status is currently satisfied.
    var isConnected: Bool { get }
    
    /// An asynchronous stream emitting network status changes.
    var networkStatus: AsyncStream<NWPath.Status> { get }
    
    // MARK: - Methods
    
    /// Begins observing network status updates.
    func startObserving()
    
    /// Stops observing network status updates and cleans up monitoring resources.
    func stopObserving()
}

// MARK: - AKNetworkStatusMonitor

/// A thread-safe monitor class responsible for tracking network connectivity changes using `NWPathMonitor`
/// and exposing status updates through `AsyncStream`.
public final class AKNetworkStatusMonitor: AKNetworkStatusMonitorProtocol, Sendable {
    // MARK: - State
    
    private struct State {
        var networkPathMonitor: NWPathMonitor?
        var isObserving = false
        var latestPath: NWPath?
    }
    
    private let state = Mutex(State())
    
    private let monitorQueue = DispatchQueue(
        label: "com.akplayer.networkmonitor",
        qos: .utility
    )
    
    public var currentPath: NWPath? {
        state.withLock { $0.networkPathMonitor?.currentPath ?? $0.latestPath }
    }
    
    public var currentNetworkStatus: NWPath.Status {
        currentPath?.status ?? .requiresConnection
    }
    
    public var isConnected: Bool {
        currentNetworkStatus == .satisfied
    }
    
    private let eventBroadcaster = AKEventBroadcaster<NWPath.Status>()
    
    public var networkStatus: AsyncStream<NWPath.Status> {
        eventBroadcaster.makeStream()
    }
    
    // MARK: - Init & Deinit
    
    /// Initializes a new instance of the network status monitor.
    public init() {}
    
    deinit {
        let oldMonitor = state.withLock { s -> NWPathMonitor? in
            let m = s.networkPathMonitor
            s.networkPathMonitor = nil
            s.isObserving = false
            return m
        }
        oldMonitor?.pathUpdateHandler = nil
        oldMonitor?.cancel()
        eventBroadcaster.finish()
    }
    
    // MARK: - Control Methods
    
    /// Starts observing network path changes.
    public func startObserving() {
        let shouldStart = state.withLock { s -> Bool in
            guard !s.isObserving else { return false }
            s.isObserving = true
            return true
        }
        
        guard shouldStart else { return }
        
        let monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.state.withLock { $0.latestPath = path }
            self.eventBroadcaster.send(path.status)
        }
        
        state.withLock { $0.networkPathMonitor = monitor }
        monitor.start(queue: monitorQueue)
    }
    
    /// Stops observing network path changes and cancels the path monitor.
    public func stopObserving() {
        let oldMonitor = state.withLock { s -> NWPathMonitor? in
            guard s.isObserving else { return nil }
            let m = s.networkPathMonitor
            s.networkPathMonitor = nil
            s.isObserving = false
            return m
        }
        
        oldMonitor?.pathUpdateHandler = nil
        oldMonitor?.cancel()
    }
}
