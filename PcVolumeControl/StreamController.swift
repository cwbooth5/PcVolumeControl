//
//  StreamController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/20/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import Foundation
import UIKit

protocol StreamControllerDelegate {
    func didGetServerUpdate()
}

class StreamController: NSObject {
    var inputStream: InputStream!
    var outputStream: OutputStream!
    let maxReadLength = 8192
    
    var address: String?
    var port: String?
    var lastState: String?
    var fullState: FullState?
    var serverConnected: Bool?
    var delegate: StreamControllerDelegate?
    let TCPTimeout = 5
    
    enum CodingError: Error {
        case JSONDecodeProblem
    }
    
    init(address: String, port: String, delegate: StreamControllerDelegate) {
        // This is run on initial tap of the 'connect' button or on any spontaneous reconnect.
        self.address = address
        self.port = port
        self.serverConnected = false
        self.delegate = delegate
    }
    
    private func serverUpdated() {
        self.delegate?.didGetServerUpdate()
        
    }
    
    func setupNetworkCommunication() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        let intport = UInt32(self.port!)!
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           address as! CFString,
                                           intport,
                                           &readStream,
                                           &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        inputStream.delegate = self
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        inputStream.open()
        outputStream.open()
        serverConnected = true
    }
    
    func sendString(input: String) {
        let data = input.data(using: .utf8)!

        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
}

extension StreamController: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
            
        case Stream.Event.endEncountered:
            print("new message end encountered")
        case Stream.Event.errorOccurred:
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
            break
        }
    }
    private func readAvailableBytes(stream: InputStream) {

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        while stream.hasBytesAvailable {
   
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                print(message)
                lastState = message
                
            // encode JSON and update fullstate.
                do {
                    try JSONDecode(input: lastState!)
                } catch CodingError.JSONDecodeProblem {
                    // It was a partial update. Append and move on. The next update should complete it.
                    print("partial update received...")
                    if lastState != nil {
                        lastState? += message
                    } else {
                        lastState = message
                    }
                    
                } catch {
                    print("fell off the end...")
                }
            }
        }
        
    }
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                        length: Int) -> String? {

        let stringArray = String(bytesNoCopy: buffer,
                                 length: length,
                                 encoding: .utf8,
                                 freeWhenDone: true)
        return stringArray
    }
    
    func JSONDecode(input: String) throws {
        // try to decode a JSON string. If it's partial, throw an error.
        let json = input.data(using: .utf8)
        do {
            guard let fs = try JSONDecoder().decode(FullState?.self, from: json!) else {
                return
            }
            fullState = fs
            serverUpdated()
        } catch Swift.DecodingError.dataCorrupted {
            // partial message received, probably
            throw CodingError.JSONDecodeProblem
        } catch {
            // should never get here?
            print(error.localizedDescription)
        }
        
    }
    
}

class FullState : Codable {
    struct theDefaultDevice : Codable {
        let deviceId: String
        let masterMuted: Bool
        let masterVolume: Double
        let name: String
        let sessions: [Session]
        
    }
    struct Session : Codable {
        let id: String
        let muted: Bool
        let name: String
        let volume: Double
    }
    let defaultDevice: theDefaultDevice
    let deviceIds: [String: String]
    let version: Int
    
    init(version: Int, deviceIds: [String:String], defaultDevice: theDefaultDevice) {
        self.version = version
        self.deviceIds = deviceIds
        self.defaultDevice = defaultDevice
    }
}
