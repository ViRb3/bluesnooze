//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Copyright © 2020 Oliver Peate. All rights reserved.
//

import Cocoa
import IOBluetooth
import LaunchAtLogin
import CoreWLAN

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var prevBlueState: Int32 = IOBluetoothPreferenceGetControllerPowerState()
    private var prevWifiState: Bool = CWWiFiClient.shared().interface()!.powerOn()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initStatusItem()
        setLaunchAtLoginState()
        setupNotificationHandlers()
    }

    // MARK: Click handlers

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        setLaunchAtLoginState()
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: Notification handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:))
        ].forEach { notification, sel in
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: sel, name: notification, object: nil)
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"),
                                         object: nil, queue: .main) { notification in
            self.onPowerUp(note:notification)
        }
    }

    @objc func onPowerDown(note: NSNotification) {
        prevBlueState = IOBluetoothPreferenceGetControllerPowerState()
        setBluetooth(powerOn: false)
        prevWifiState = CWWiFiClient.shared().interface()!.powerOn()
        setWifi(powerOn: false)
    }

    func onPowerUp(note: Notification) {
        if prevBlueState != 0 {
            setBluetooth(powerOn: true)
        }
        if prevWifiState {
            setWifi(powerOn: true)
        }
    }

    private func setBluetooth(powerOn: Bool) {
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    private func setWifi(powerOn: Bool) {
        var tries = 0
        while (tries < 10) {
            do {
                try CWWiFiClient.shared().interface()!.setPower(powerOn)
                return
            } catch {
                tries += 1
                usleep(100000)
            }
        }
    }

    // MARK: UI state

    private func initStatusItem() {
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            return
        }

        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }
        statusItem.menu = statusMenu
    }

    private func setLaunchAtLoginState() {
        let state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
        launchAtLoginMenuItem.state = state
    }
}
