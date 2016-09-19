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
    
    func scanningTimeOut(peripherals: Set<String>)

}

public class HBCentral: NSObject, CBCentralManagerDelegate {

    private var _manager: CBCentralManager!

    private var _expected: Set<String> = []

    var unexpected: Set<String> = []

    private var _connected: [UUID : CBPeripheral] = [:]

    private let _delegate: HBCentralDelegate!
    
    private let _time_out_interval: TimeInterval!
    
    private var _time_out_timer: Timer? = nil

    var connected: [UUID : CBPeripheral] {

        get {

            return _connected

        }

    }

    public init(delegate: HBCentralDelegate, timeOutInterval time_out_interval: TimeInterval = 8) {

        _delegate = delegate
        
        _time_out_interval = time_out_interval

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
    
    @objc private func _scanningTimeOut() {
        
        if _manager.isScanning {
        
            _manager.stopScan()
        
        }
        
        if !_expected.isEmpty {
    
            _delegate.scanningTimeOut(peripherals: _expected)
    
        }
        
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
            
            _time_out_timer = Timer.scheduledTimer(timeInterval: _time_out_interval, target: self, selector: #selector(self._scanningTimeOut), userInfo: nil, repeats: false)

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
        
        if _expected.count <= 0 {
            
            print("\rPeripheral: \(peripheral.description)")
            
            print("Advertisment: \(advertisementData.description)")
            
            print("RSSI: \(RSSI)\n")
            
        }
        
        guard let name = peripheral.name else {
            
            return
            
        }
        
        if self.unexpected.contains(name) || peripheral.state == .connected {
            
            return
            
        }
        
        if _expected.contains(name) && _manager.isScanning {
            
            _manager.stopScan()
            
            print("\rPeripheral: \(peripheral.description)")
            
            print("Advertisment: \(advertisementData.description)")
            
            print("RSSI: \(RSSI)\n")
            
            _manager.connect(peripheral, options: nil)
            
        }
        
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        if let name = peripheral.name {
            
            _expected.remove(name)

            print("\rConnect: \(name) - \(peripheral.identifier.uuidString)\n")

        }
        else {

            print("\rConnect: \(peripheral.identifier.uuidString)\n")

        }
        
        if _expected.isEmpty {
            
            if let tt = _time_out_timer {
                
                tt.invalidate()
                
                _time_out_timer = nil
                
            }
            
        }
        else {
            
            self.scan()
            
        }
        
        _connected[peripheral.identifier] = peripheral
        
        _delegate.connected(peripheral: peripheral)

    }

}
