//
//  ViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 11/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import SwiftSocket

class ViewController: UIViewController, UITextFieldDelegate {
    
    //MARK: Properties
    @IBOutlet weak var serverIPField: UITextField!
    @IBOutlet weak var serverPortField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var connectbutton: UIButton!
    @IBOutlet weak var connectionStatus: UILabel!
    
    var serverConnected: Bool?
    var client: TCPClient?
    var lastState: String?
//    var allData: Array<UInt8>
    var wholeResponse = [UInt8]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Handle the text field's user input through delegate callbacks.
        serverIPField.delegate = self
        serverPortField.delegate = self
        serverIPField.keyboardType = .numbersAndPunctuation
        serverPortField.keyboardType = .numberPad
       
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: Actions
//    @IBAction func connectServer(_ sender: UIButton) {
//        let IPaddr = serverIPField.text
//        let PortNum = serverPortField.text.toInt()
//        client = TCPClient(address: IPaddr, port: Int32(PortNum))
//        let client = TCPClient(address: "www.apple.com", port: 80)
//        switch client.connect(timeout: 1) {
//        case .success:
//            switch client.send(string: "GET / HTTP/1.0\n\n" ) {
//            case .success:
//                guard let data = client.read(1024*10) else { return }
//
//                if let response = String(bytes: data, encoding: .utf8) {
//                    print(response)
//                }
//            case .failure(let error):
//                print(error)
//            }
//        case .failure(let error):
//            print(error)
//        }
//    }
    
    @IBAction func sendButtonAction() {
        let IPaddr: String? = serverIPField.text
        let PortNum: String? = serverPortField.text
        client = TCPClient(address: IPaddr!, port: Int32(PortNum!)!)
        guard let client = client else { return }
        
        // timeout, in seconds
        switch client.connect(timeout: 5) {
        case .success:
            connectionStatus.text = "Connected"
            appendToTextField(string: "Connected to server \(client.address)")
//            if let response = sendRequest(string: "{'fooblah'}", using: client) {
//                appendToTextField(string: "Response: \(response)")
//            }
            if let response = readResponse(from: client) {
                print("got a response...")
                print(getServerVersion())
//                appendToTextField(string: "Response: \(response)")
            }
            
        case .failure(let error):
            connectionStatus.text = "Disconnected"
            appendToTextField(string: String(describing: error))
        }
    }
    
    private func sendRequest(string: String, using client: TCPClient) -> String? {
        appendToTextField(string: "Sending data ... ")
        
        switch client.send(string: string) {
        case .success:
            return readResponse(from: client)
        case .failure(let error):
            appendToTextField(string: String(describing: error))
            return nil
        }
    }
    
    private func readResponse(from client: TCPClient) -> String? {
//        guard let response = client.read(10*10) else { return nil }
        
        while true {
            guard let data = client.read(1024*10, timeout: 2) else { break }
            wholeResponse += data
        }
        
        let stringResponse = String(bytes: wholeResponse, encoding: .utf8)
        lastState = stringResponse
        
        return stringResponse
    }
    
    private func appendToTextField(string: String) {
        print(string)
        textView.text = textView.text.appending("\n\(string)")
    }
    
    func getServerVersion() -> Int {
        // Pull the current server version out of the json sent to us.
        struct session : Codable {
            let id: String
            let muted: Bool
            let name: String
            let volume: Double
        }
        struct State : Codable {
            struct defaultDevice : Codable {
                let deviceId: String
                let masterMuted: Bool
                let masterVolume: Double
                let name: String
                let sessions: Array<session>
                
            }
            let deviceIds: [String: String]
            let version: Int
        }

        let json = lastState!.data(using: .utf8)!
        let decodedState = try! JSONDecoder().decode(State.self, from: json)
        dump(decodedState)

        return 1
    }

}

