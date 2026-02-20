/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// WearablesViewModel.swift
//
// Primary view model for the CameraAccess app that manages DAT SDK integration.
// Demonstrates how to listen to device availability changes using the DAT SDK's
// device stream functionality and handle permission requests.
//

import MWDATCore
import SwiftUI

#if canImport(MWDATMockDevice)
import MWDATMockDevice
#endif

@MainActor
class WearablesViewModel: ObservableObject {
  @Published var devices: [DeviceIdentifier]
  @Published var hasMockDevice: Bool
  @Published var registrationState: RegistrationState
  @Published var showGettingStartedSheet: Bool = false
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var skipToIPhoneMode: Bool = false

  private var registrationTask: Task<Void, Never>?
  private var deviceStreamTask: Task<Void, Never>?
  private var setupDeviceStreamTask: Task<Void, Never>?
  private let wearables: WearablesInterface
  private var compatibilityListenerTokens: [DeviceIdentifier: AnyListenerToken] = [:]

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    self.devices = wearables.devices
    self.hasMockDevice = false
    self.registrationState = wearables.registrationState

    NSLog("[Wearables] Init — registrationState: %@, devices count: %d", String(describing: wearables.registrationState), wearables.devices.count)
    for device in wearables.devices {
      if let d = wearables.deviceForIdentifier(device) {
        NSLog("[Wearables] Init — found device: %@ (id: %@)", d.nameOrId(), String(describing: device))
      }
    }

    // Set up device stream immediately to handle MockDevice events
    setupDeviceStreamTask = Task {
      await setupDeviceStream()
    }

    registrationTask = Task {
      for await registrationState in wearables.registrationStateStream() {
        let previousState = self.registrationState
        self.registrationState = registrationState
        NSLog("[Wearables] Registration state changed: %@ -> %@", String(describing: previousState), String(describing: registrationState))
        if self.showGettingStartedSheet == false && registrationState == .registered && previousState == .registering {
          self.showGettingStartedSheet = true
        }
      }
    }
  }

  deinit {
    registrationTask?.cancel()
    deviceStreamTask?.cancel()
    setupDeviceStreamTask?.cancel()
  }

  private func setupDeviceStream() async {
    if let task = deviceStreamTask, !task.isCancelled {
      task.cancel()
    }

    NSLog("[Wearables] Setting up device stream...")
    deviceStreamTask = Task {
      for await devices in wearables.devicesStream() {
        NSLog("[Wearables] Device stream update — %d device(s)", devices.count)
        for device in devices {
          if let d = wearables.deviceForIdentifier(device) {
            NSLog("[Wearables]   Device: %@ (id: %@)", d.nameOrId(), String(describing: device))
          } else {
            NSLog("[Wearables]   Device id: %@ (no Device object)", String(describing: device))
          }
        }
        self.devices = devices
        #if canImport(MWDATMockDevice)
        self.hasMockDevice = !MockDeviceKit.shared.pairedDevices.isEmpty
        #endif
        // Monitor compatibility for each device
        monitorDeviceCompatibility(devices: devices)
      }
    }
  }

  private func monitorDeviceCompatibility(devices: [DeviceIdentifier]) {
    // Remove listeners for devices that are no longer present
    let deviceSet = Set(devices)
    compatibilityListenerTokens = compatibilityListenerTokens.filter { deviceSet.contains($0.key) }

    // Add listeners for new devices
    for deviceId in devices {
      guard compatibilityListenerTokens[deviceId] == nil else { continue }
      guard let device = wearables.deviceForIdentifier(deviceId) else {
        NSLog("[Wearables] Could not get Device object for id: %@", String(describing: deviceId))
        continue
      }

      // Log all available device info
      let deviceName = device.nameOrId()
      NSLog("[Wearables] Monitoring device: %@, compatibility: %@", deviceName, String(describing: device.compatibility))

      let token = device.addCompatibilityListener { [weak self] compatibility in
        NSLog("[Wearables] Compatibility changed for '%@': %@", deviceName, String(describing: compatibility))
        guard let self else { return }
        if compatibility == .deviceUpdateRequired {
          Task { @MainActor in
            self.showError("Device '\(deviceName)' requires an update to work with this app")
          }
        }
      }
      compatibilityListenerTokens[deviceId] = token
    }
  }

  func connectGlasses() {
    guard registrationState != .registering else { return }
    Task { @MainActor in
      do {
        try await wearables.startRegistration()
      } catch let error as RegistrationError {
        showError(error.description)
      } catch {
        showError(error.localizedDescription)
      }
    }
  }

  func disconnectGlasses() {
    Task { @MainActor in
      do {
        try await wearables.startUnregistration()
      } catch let error as UnregistrationError {
        showError(error.description)
      } catch {
        showError(error.localizedDescription)
      }
    }
  }

  func showError(_ error: String) {
    errorMessage = error
    showError = true
  }

  func dismissError() {
    showError = false
  }
}
