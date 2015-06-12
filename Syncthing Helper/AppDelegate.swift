//
//  AppDelegate.swift
//  Syncthing Helper
//
//  Created by Jelmer van der Linde on 09/06/15.
//  Copyright (c) 2015 Jelmer van der Linde. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SyncthingDelegate {

    @IBOutlet weak var statusBarMenu: NSMenu!
    
    @IBOutlet weak var popover: NSPopover!
    
    var api: SyncthingAPI?
    
    var statusBarItem: NSStatusItem?
    
    var menuItems = [SyncthingFolder: NSMenuItem]()
    
    var popoverTransiencyMonitor: NSEvent?
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let statusBar = NSStatusBar.systemStatusBar();
        statusBarItem = statusBar.statusItemWithLength(-1)
//        statusBarItem?.menu = statusBarMenu
        statusBarItem?.action = Selector("togglePopover:")
        
        if var icon = NSImage(named:"icon template") {
            icon.setTemplate(true)
            statusBarItem?.image = icon
        }
        
        api = SyncthingAPI(delegate: self, apiKey: "IcH5m3SzEoPLZChllFlBw0SvwSHa0DFL", apiBase: "http://localhost:8384/")
        api?.startListening()
    }
    
    func showPopover(sender: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.showRelativeToRect(button.bounds, ofView: button, preferredEdge: NSMinYEdge)
//            popover.contentViewController?.view.window?.level =  Int(CGWindowLevelForKey(Int32(kCGStatusWindowLevelKey)))

            if self.popoverTransiencyMonitor == nil {
//                self.popoverTransiencyMonitor = NSEvent.addGlobalMonitorForEventsMatchingMask(
//                    (NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyUpMask), handler: { (event) -> Void in
//                    self.hidePopover(nil)
//                })
            }
        }
    }
    
    func hidePopover(sender: AnyObject?) {
        if let monitor = self.popoverTransiencyMonitor {
            NSEvent.removeMonitor(monitor)
            self.popoverTransiencyMonitor = nil
        }
        
        popover.performClose(sender)
    }
    
    func togglePopover(sender: AnyObject?) {
        if popover.shown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func updateStatusMenuItem(menuItem: NSMenuItem, folder: SyncthingFolder) {
       switch folder.state {
            case "idle":
                menuItem.image = NSImage(named:NSImageNameLockLockedTemplate)
            case "scanning", "syncing", "cleaning":
                menuItem.image = NSImage(named:NSImageNameLockUnlockedTemplate)
            default:
                menuItem.image = NSImage(named:NSImageNameRefreshTemplate)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        api?.stopListening()
    }

    func syncthingDidAddFolder(folder: SyncthingFolder) {
        let menuItem = NSMenuItem(title: folder.id, action: "openFolder:", keyEquivalent: "")
        menuItem.enabled = true
        menuItem.representedObject = folder.path;
        
        statusBarMenu.insertItem(menuItem, atIndex: 0)
        menuItems[folder] = menuItem
    }
    
    func syncthingFolderDidChangeState(folder: SyncthingFolder) {
        if let menuItem = menuItems[folder] {
            updateStatusMenuItem(menuItem, folder: folder)
        }
    }
    
    @IBAction func openFolder(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openFile(sender.representedObject as! String)
    }
    
    @IBAction func openWebsite(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: api!.apiBase)!)
    }
    
    @IBAction func quit(sender: AnyObject) {
        quit(sender)
    }
}
