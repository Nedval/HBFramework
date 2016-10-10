//
//  HBPeripheral.swift
//  OnePass
//
//  Created by Jrting on 8/31/16.
//  Copyright © 2016 One-Time Creative Technology Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol HBPeripheralDelegate {
    
    func readyForCommunicate(peripheral: HBPeripheral)
    
    func receive(peripheral: HBPeripheral, data: Data?, fromCharacteristic characteristic: CBCharacteristic)
    
}

open class HBPeripheral: NSObject, CBPeripheralDelegate {

    private var _discover: [CBUUID: [CBUUID: Set<CBUUID>]]? = nil
    
    private let _peripheral: CBPeripheral!
    
    public var peripheral: CBPeripheral {
    
        get {
        
            return _peripheral
        
        }
        
    }
    
    private let _delegate: HBPeripheralDelegate!
    
    private var _communicate_service_uuid: CBUUID? = nil
    
    private var _communicate_characteristic_uuid: CBUUID? = nil
    
    private var _communicate_characteristic: CBCharacteristic? = nil
    
    public init(peripheral: CBPeripheral, delegate: HBPeripheralDelegate) {
        
        _delegate = delegate
        
        _peripheral = peripheral
        
        super.init()
        
        _peripheral.delegate = self
        
    }
    
    public func setCommunicateCharacteristic(service: CBUUID, characteristic: CBUUID) {
    
        _communicate_service_uuid = service
        
        _communicate_characteristic_uuid = characteristic
        
        _peripheral.discoverServices([_communicate_service_uuid!])
        
    }
    
    public func write(data: Data) {
        
        guard let characteristic = _communicate_characteristic else {
        
            print("[\(type(of: self))] no communicate characteristic")
            
            return
            
        }
        
        print("[\(type(of: self))] Write: \(String(data: data, encoding: .utf8)!)")
        
        _peripheral.setNotifyValue(true, for: characteristic)
        
        let count = Int(data.count/16)
        
        for counter in 0 ... count {
            
            let lower = counter * 16
            
            var upper = (counter + 1) * 16
            
            if data.count < upper {
            
                upper = data.count
                
            }
            
            if lower == upper  {
            
                break
            
            }
            
            _peripheral.writeValue(data.subdata(in: Range(uncheckedBounds: (lower, upper))), for: characteristic, type: .withResponse)
        
        }
        
        
    
    }
    
    public func discoverAllServices() {
    
        _peripheral.discoverServices(nil)
    
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else {
            
            return
            
        }
        
        if services.count == 0 {
            
            print("[\(type(of: self))] No Service.")
            
            return
            
        }
        
        _discover = [:]
        
        for service in services {
            
            _discover![service.uuid] = [:]
            
            if let ccuuid = _communicate_characteristic_uuid , _communicate_characteristic == nil && _communicate_service_uuid == service.uuid {
            
                peripheral.discoverCharacteristics([ccuuid], for: service)
                
                return
                
            }
            
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
        
    }
    /*
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
     
        guard let services = service.includedServices else {
     
            return
     
        }
     
        if services.count <= 0 {
     
            return
     
        }
     
        for service in services {
     
            peripheral.discoverIncludedServices(nil, for: service)
     
            peripheral.discoverCharacteristics(nil, for: service)
     
        }
     
    }
    */
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else {
            
            return
            
        }
        
        if characteristics.count == 0 {
            
            _discover!.removeValue(forKey: service.uuid)
            
            if _discover!.count == 0 {
                
                _finishDiscover(peripheral: peripheral)
                
            }
            
            return
            
        }
        
        for characteristic in characteristics {
            
            _discover![service.uuid]![characteristic.uuid] = []
            
            peripheral.discoverDescriptors(for: characteristic)
            
        }
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let descriptors = characteristic.descriptors else {
            
            return
            
        }
        
        if descriptors.count == 0 {
            
            peripheral.readValue(for: characteristic)
            
            return
            
        }
        
        for descriptor in descriptors {
            
            _discover![characteristic.service.uuid]![characteristic.uuid]!.insert(descriptor.uuid)
            
            peripheral.readValue(for: descriptor)
            
        }
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        
        if let value = descriptor.value {
            
            print("\rValue for Descriptor: \(peripheral.name!) > \(descriptor.characteristic.service.uuid) > \(descriptor.characteristic.uuid) > \(descriptor.uuid)")
            
            print("Value: \(value)\n")
            
        }
        
        if _discover == nil {
            
            return
            
        }
        
        _discover![descriptor.characteristic.service.uuid]![descriptor.characteristic.uuid]!.subtract([descriptor.uuid])
        
        if _discover![descriptor.characteristic.service.uuid]![descriptor.characteristic.uuid]!.count == 0 {
            
            peripheral.readValue(for: descriptor.characteristic)
            
        }
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if _discover == nil {
            
            _delegate.receive(peripheral: self, data: characteristic.value, fromCharacteristic: characteristic)
            
            return
            
        }
        
        if let value = characteristic.value {
            
            print("\rValue for Characteristic: \(peripheral.name!) > \(characteristic.service.uuid) > \(characteristic.uuid)")
            
            if let v = String(data: value, encoding: .utf8) {
                
                print("Value: \(v) \(value)\n")
                
            }
            else {
                
                print("Value: \(value)\n")
                
            }
            
            if let csu = _communicate_service_uuid, let ccu = _communicate_characteristic_uuid {
            
                if csu == characteristic.service.uuid && ccu == characteristic.uuid {
                    
                    _communicate_characteristic = characteristic
                    
                    _delegate.readyForCommunicate(peripheral: self)
                    
                }
            
            }
            
        }
        
        _discover![characteristic.service.uuid]!.removeValue(forKey: characteristic.uuid)
        
        if _discover![characteristic.service.uuid]!.count == 0 {
            
            _discover!.removeValue(forKey: characteristic.service.uuid)
            
            if _discover!.count == 0 {
                
                _finishDiscover(peripheral: peripheral)
                
            }
            
        }
        
    }
    
    private func _finishDiscover(peripheral: CBPeripheral) {
        
        _discover = nil
        
        print("[\(type(of: self))] Discover All Value.")
        
    }
    
}
