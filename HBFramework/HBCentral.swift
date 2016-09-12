//
//  HBCentral.swift
//  OnePass
//
//  Created by Jrting on 6/29/16.
//  Copyright © 2016 One-Time Creative Technology Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol HBCentralDelegate {

    func readyToScan()

    func connected(peripheral: CBPeripheral)

}

public class HBCentral: NSObject, CBCentralManagerDelegate {

    private var _manager: CBCentralManager!

    private var _expected: Set<String> = []

    var unexpected: Set<String> = []

    private var _connected: [UUID : CBPeripheral] = [:]

    private let _delegate: HBCentralDelegate!

    var connected: [UUID : CBPeripheral] {

        get {

            return _connected

        }

    }

    public init(delegate: HBCentralDelegate) {

        _delegate = delegate

        super.init()

        _manager = CBCentralManager(delegate: self, queue: nil)

    }

    private func _centralIsWorking() {

        print("[\(type(of: self))] Central is working.")

        _delegate.readyToScan()

    }


    @available(iOS 10.0, *)
    private func _centralIsNotWorking(state: CBManagerState) {

        print("[\(type(of: self))] Central is not working. (\(_manager))")

    }

    @available(iOS, deprecated:10.0)
    private func _centralIsNotWorking(state: CBPeripheralManagerState) {

        print("[\(type(of: self))] Central is not working. (\(_manager))")

    }

    public func connect(name: String) {

        _expected.insert(name)

        self.scan()

    }

    public func disconnect(peripheral: CBPeripheral) {

        _expected.remove(peripheral.name!)

        _manager.cancelPeripheralConnection(peripheral)

    }

    public func scan(withServices services: [CBUUID]? = nil, options: [String : AnyObject]? = nil) {

        if _manager.state == .poweredOn && !_manager.isScanning {

            _manager.scanForPeripherals(withServices: services, options: options)

        }

    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {

        print("[\(type(of: self))] Disconnect Peripheral: \(peripheral.name)")

    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {

        case .poweredOn:

            _centralIsWorking()

        case .poweredOff, .resetting, .unauthorized, .unknown, .unsupported :

            if #available(iOS 10.0, *) {

                _centralIsNotWorking(state: central.state)

            }
            else {

                _centralIsNotWorking(state: CBPeripheralManagerState(rawValue: central.state.rawValue)!)

            }
            
        }

    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if self.unexpected.contains(peripheral.name!) || peripheral.state == .connected {
            
            return
            
        }
        
        if _expected.count <= 0 {
            
            print("\rPeripheral: \(peripheral.description)")
            
            print("Advertisment: \(advertisementData.description)")
            
            print("RSSI: \(RSSI)\n")
            
        }
        
        guard let name = peripheral.name else {
        
            return
            
        }
        
        if _expected.contains(name) && _manager.isScanning {
            
            print("\rPeripheral: \(peripheral.description)")
            
            print("Advertisment: \(advertisementData.description)")
            
            print("RSSI: \(RSSI)\n")
            
            _connected[peripheral.identifier] = peripheral
            
            _manager.connect(_connected[peripheral.identifier]!, options: nil)
            
        }
        
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        if let name = peripheral.name {

            print("\rConnect: \(name) - \(peripheral.identifier.uuidString)\n")

        }
        else {

            print("\rConnect: \(peripheral.identifier.uuidString)\n")

        }
        
        _delegate.connected(peripheral: peripheral)

    }

}
