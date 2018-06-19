//
//  DeviceManager.swift
//  BluetoothExample
//
//  Created by Nazire Aslan on 19/06/2018.
//  Copyright © 2018 Identitat. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol DeviceManagerDelegate: class {
  func didUpdateDeviceList(items: [CBPeripheral])
  func didConnectToDevice()
  func didDisconnectFromDevice()
  func didUpdateRSSIValue(value: String)
}

//let sharedDevice = DeviceManager()

class DeviceManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  
  var manager: CBCentralManager!
  var currentDevice: CBPeripheral?
  weak var delegate: DeviceManagerDelegate?
  
  let scanningDelay = 5.0
  var items = [String: CBPeripheral]()
  
  private static var sharedDeviceManager: DeviceManager = {
    let deviceManager = DeviceManager()
    
    return deviceManager
  }()
  
  private override init() {
    super.init()
    manager = CBCentralManager(delegate: self, queue: nil)
  }
  
  // MARK: - Accessors
  
  class func shared() -> DeviceManager {
    return sharedDeviceManager
  }
  
  // MARK: - CBCentralManagerDelegate
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      startScan()
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    didReadPeripheral(peripheral, rssi: RSSI)
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    currentDevice = peripheral
    peripheral.readRSSI()
    delegate?.didConnectToDevice()
    currentDevice?.discoverServices(nil)
  }
  
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    currentDevice = nil
    delegate?.didDisconnectFromDevice()
  }
  
  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    // handle
  }
    
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      peripheral.discoverCharacteristics(nil, for: service)
      print("Service \(service)")
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }
    for characteristic in characteristics {
      if characteristic.properties.contains(CBCharacteristicProperties.read) {
        peripheral.readValue(for: characteristic)
      }
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let e = error {
      print("ERROR didUpdateValue \(e)")
      return
    }
    guard let data = characteristic.value else { return }
    print(data)
  }
  
  // MARK: - CBPeripheralDelegate
  
  func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    didReadPeripheral(peripheral, rssi: RSSI)
    delegate?.didUpdateRSSIValue(value: getStatusStringsFromRSSI(rssi: RSSI))
    delay(scanningDelay) {
      peripheral.readRSSI()
    }
  }
  
  // MARK: - Helpers
  
  func didReadPeripheral(_ peripheral: CBPeripheral, rssi: NSNumber) {
    if let name = peripheral.name {
      items[name] = peripheral
    }
    delegate?.didUpdateDeviceList(items: Array(items.values))
  }
  
  func getStatusStringsFromRSSI(rssi: NSNumber) -> String {
    var statusString = "Unusable"
    if rssi.intValue >= -30 {
      statusString = "Amazing"
    } else if rssi.intValue >= -67, rssi.intValue < -30 {
      statusString = "Very Good"
    } else if rssi.intValue >= -70, rssi.intValue < -67 {
      statusString = "Okay"
    } else if rssi.intValue >= -80, rssi.intValue < -70 {
      statusString = "Not Good"
    }
    
    return statusString
  }
  
  func startScan() {
    if manager.state == .poweredOn {
      manager.scanForPeripherals(withServices: nil, options: nil)
    } else {
      // handle errors
    }
  }
  
  func connectToDevice(device: CBPeripheral) {
    currentDevice = device
    currentDevice?.delegate = self
    manager.stopScan()
    manager.connect(device, options: nil)
  }
  
  func disconnectFromDevice() {
    if let device = currentDevice {
      manager.cancelPeripheralConnection(device)
    }
  }
  
  func delay(_ delay: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
      deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
  }
  
}
