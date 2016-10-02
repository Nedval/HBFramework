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
    
    func readyForConnect(peripheral: CBPeripheral, willAutoConnect will_auto_connect: Bool)

    func connected(peripheral: CBPeripheral)
    
    func scanningTimeOut(peripherals: Set<String>)

}

public class HBCentral: NSObject, CBCentralManagerDelegate {

    private var _manager: CBCentralManager!

    private var _expected: Set<String> = []

    var unexpected: Set<String> = []

    private var _connected: [UUID : CBPeripheral] = [:]
    
    private var _waiting_for_connect: [UUID : CBPeripheral] = [:]

    private let _delegate: HBCentralDelegate!
    
    private let _time_out_interval: TimeInterval!
    
    private let _auto_connect: Bool
    
    private var _time_out_timer: Timer? = nil
    
    var connected: [UUID : CBPeripheral] {

        get {

            return _connected

        }

    }

    public init(delegate: HBCentralDelegate, timeOutInterval time_out_interval: TimeInterval = 8, autoConnect auto_connect: Bool) {

        _delegate = delegate
        
        _time_out_interval = time_out_interval
        
        _auto_connect = auto_connect

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

    public func expect(name: String) {

        _expected.insert(name)

    }
    
    public func expect(withNameList list: [String]) {
        
        for name in list {
        
            self.expect(name: name)
        
        }
        
    }
    
    public func connect(peripheral: CBPeripheral, options: [String : Any]? = nil) {
    
        _manager.connect(peripheral, options: options)
    
    }

    public func disconnect(peripheral: CBPeripheral) {

        _expected.remove(peripheral.name!)

        _manager.cancelPeripheralConnection(peripheral)

    }

    public func scan(withServices services: [CBUUID]? = nil, options: [String : AnyObject]? = nil) {

        if _manager.state == .poweredOn && !_manager.isScanning {
            
            _manager.scanForPeripherals(withServices: services, options: options)
            
            if _auto_connect {
            
                self.enableTimer(timeOutInterval: _time_out_interval)

            }
            
        }

    }
    
    public func enableTimer(timeOutInterval time_out_interval: TimeInterval) {
    
        _time_out_timer = Timer.scheduledTimer(timeInterval: time_out_interval, target: self, selector: #selector(self._scanningTimeOut), userInfo: nil, repeats: false)
    
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
            
            print("\rPeripheral: \(peripheral.description)")
            
            print("Advertisment: \(advertisementData.description)")
            
            print("RSSI: \(RSSI)\n")
            
            _expected.remove(name)
            
            _waiting_for_connect[peripheral.identifier] = peripheral
            
            _delegate.readyForConnect(peripheral: peripheral, willAutoConnect: _auto_connect)
            
            if _auto_connect {
                
                _manager.stopScan()
                
                _manager.connect(_waiting_for_connect[peripheral.identifier]!)
            
            }
            
        }
        
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        _connected[peripheral.identifier] = peripheral
        
        if let name = peripheral.name {
            
            _waiting_for_connect.removeValue(forKey: peripheral.identifier)
            
            print("\rConnect: \(name) - \(peripheral.identifier.uuidString)\n")

        }
        else {

            print("\rConnect: \(peripheral.identifier.uuidString)\n")

        }
        
        _delegate.connected(peripheral: peripheral)
        
        if _expected.isEmpty {
            
            if let tt = _time_out_timer {
                
                tt.invalidate()
                
                _time_out_timer = nil
                
            }
            
        }
        else {
            
            self.scan()
            
        }
        
    }

}
