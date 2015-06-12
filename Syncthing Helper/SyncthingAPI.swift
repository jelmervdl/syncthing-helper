//
//  SyncthingAPI.swift
//  Syncthing Helper
//
//  Created by Jelmer van der Linde on 09/06/15.
//  Copyright (c) 2015 Jelmer van der Linde. All rights reserved.
//

import Cocoa

typealias ServiceResponse = (JSON, NSError?) -> Void

var GlobalBackgroundQueue: dispatch_queue_t {
    return dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.value), 0)
}

struct SyncthingFolder {
    let id: String
    let path: String
    
    var state: String = "unknown"
    
    mutating func changeState(state: String) {
        self.state = state
    }
}

extension SyncthingFolder: Hashable {
    var hashValue: Int {
        return id.hashValue
    }
}

func ==(lhs: SyncthingFolder, rhs: SyncthingFolder) -> Bool {
    return lhs.id == rhs.id
}

protocol SyncthingDelegate {
    func syncthingDidAddFolder(folder: SyncthingFolder)
    
    func syncthingFolderDidChangeState(folder: SyncthingFolder)
}

class SyncthingAPI {
    let apiKey: String
    
    let apiBase: String
    
    var listenForEvents = false;
    
    var folders = [String: SyncthingFolder]()
    
    var delegate: SyncthingDelegate?
    
    var state: String?
    
    init(delegate: SyncthingDelegate, apiKey: String, apiBase: String) {
        self.delegate = delegate;
        self.apiKey = apiKey
        self.apiBase = apiBase
        
        getConfiguration()
    }
    
    internal func getFolderStatus(folderId: String) {
        makeHTTPGetRequest("rest/db/status?folder=\(folderId)", onCompletion: { (json, err) -> Void in
            if var folder = self.folders[folderId], let state = json["state"].string {
                folder.changeState(state)
                self.delegate?.syncthingFolderDidChangeState(folder);
            } else {
                print("could not find folder or state for ", json, appendNewline: false)
            }
        })
    }
    
    internal func getConfiguration() {
        makeHTTPGetRequest("rest/system/config", onCompletion: { (json, err) -> Void in
            self.folders.removeAll(keepCapacity: true)
            
            for (_, folderdata) in json["folders"] {
                if let id = folderdata["id"].string, path = folderdata["path"].string {
                    // Add the folder to our local version
                    let folder = SyncthingFolder(id: id, path: path, state:"unknown")
                    self.folders[id] = folder;
                    
                    // Get more info
                    self.getFolderStatus(id)
                    
                    // Notify our delegate about the new folder
                    self.delegate?.syncthingDidAddFolder(folder);
                }
            }
        })
    }
    
    func startListening() {
        if !listenForEvents {
            listenForEvents = true
            getLastEventId({ (lastEventId) -> Void in
                self.getEvents(lastEventId)
            })
        }
    }
    
    func stopListening() {
        listenForEvents = false
    }
    
    internal func getLastEventId(onCompletion: (Int) -> Void) {
        makeHTTPGetRequest("rest/events?since=0&limit=1", onCompletion: { (json, err) -> Void in
            onCompletion(json[0]["id"].int!)
        })
    }
    
    internal func getEvents(lastEventId: Int) {
        makeHTTPGetRequest("rest/events?since=\(lastEventId)", onCompletion: { (json, err) -> Void in
            var lastEventId = 0
            
            for (_, event) in json {
                self.processEvent(event)
                lastEventId = event["id"].int!
            }
            
            if self.listenForEvents {
                dispatch_async(GlobalBackgroundQueue, {
                    self.getEvents(lastEventId)
                })
            }
        })
    }
    
    internal func processEvent(event: JSON) {
        if let type = event["type"].string {
            switch (type) {
            case "StateChanged":
                if let folderId = event["data"]["folder"].string {
                    if var folder = self.folders[folderId] {
                        folder.changeState(event["data"]["to"].string!)
                        self.delegate?.syncthingFolderDidChangeState(folder);
                    }
                }
            default:
                print("Received unhandled event \(type)", appendNewline: false)
            }
        }
    }
    
    internal func makeHTTPGetRequest(path: String, onCompletion: ServiceResponse) {
        let request = NSMutableURLRequest(URL: NSURL(string: apiBase + path)!)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let session = NSURLSession.sharedSession()
        
        let task = session.dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
            if data != nil {
                onCompletion(JSON(data: data!), error)
            } else {
                print("Error!", error)
            }
        })
        task.resume()
    }
}
