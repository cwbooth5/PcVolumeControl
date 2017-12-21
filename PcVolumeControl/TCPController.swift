//
//  TCPController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/19/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import Foundation
import SwiftSocket


protocol TCPControllerDelegate {
    func didGetServerUpdate()
}

class TCPController {
    var client: TCPClient?
    var address: String?
    var port: String?
    var lastState: String?
    var fullState: FullState?
    var serverConnected: Bool
    var delegate: TCPControllerDelegate?
    let TCPTimeout = 5
    
    init(address: String, port: String, delegate: TCPControllerDelegate) {
        // This is run on initial tap of the 'connect' button or on any spontaneous reconnect.
        self.address = address
        self.port = port
        self.serverConnected = false
        self.client = openTCPConnection(address: address, port: port)
        self.delegate = delegate
    }
    
    private func serverUpdated() {
        self.delegate?.didGetServerUpdate()
        
    }
    
    func openTCPConnection(address: String, port: String) -> TCPClient?{
        let c = TCPClient(address: address, port: Int32(port)!)
        // timeout, in seconds
        switch c.connect(timeout: 5) {
        case .success:
            serverConnected = true
            if let response = readResponse(from: c) {
                print("TCP connection established. Response:\n\(response)")
                
                return c
            }
            
        case .failure(let error):
            serverConnected = false
            print("TCP CONNECTION FAILED!")
            return c
        }
        return c
    }
    
    func closeTCPConnection() {
        //TODO: tear down when the app is minimized.
        print("Tearing down TCP Connection...")
        client?.close()
    }
    
    
     func sendRequest(string: String, using client: TCPClient) -> String? {
        // send a request over the socket and return a response as a string.
        // The server doesn't reply with updates in response to anything other than initial connection.
        switch client.send(string: string) {
        case .success:
            let response = readResponse(from: client)
            return response
        case .failure(let error):
            print(error)
            return nil
        }
    }

    func readResponse(from client: TCPClient) -> String? {
        // This has to poll the socket for data.
        // Only the initial connection gets a response automatically.
        // All other updates we push to the server receive no response or ack.
        // The server will push an update to us only when it is changed serverside.
        // The server always sends us full state, so rebuild full state on all updates.
        var wholeResponse = [UInt8]()

        while true {
            guard let data = client.read(1024, timeout: TCPTimeout) else { break }
            wholeResponse += data
        }
        
        let stringResponse = String(bytes: wholeResponse, encoding: .utf8)
        lastState = stringResponse
        fullState = decodePayload(payload: lastState!)
        serverUpdated() // tell the client
        return stringResponse
    }
    
    func decodePayload(payload: String) -> FullState? {
        let json = payload.data(using: .utf8)
        do {
            fs = try JSONDecoder().decode(FullState.self, from: json!)
//            dump(decodedState) //debug
//            fullState = decodedState //make it pretty much global
            return fs
        } catch Swift.DecodingError.dataCorrupted {
            print("oh god, no. error message...todo...")
            //            Alert.showBasic(title: "JSON data corrupted!", message: "The server sent garbage back!", vc: self)
        } catch {
            //what the fuck
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
