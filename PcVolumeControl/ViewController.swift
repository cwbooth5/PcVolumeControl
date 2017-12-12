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
    @IBOutlet weak var sliderTableView: UITableView!
    
    @IBAction func sliderMoved(_ sender: UISlider) {
        soundLevel = sender.value
        print("Sound Level: \(soundLevel)")
    }
    
    var serverConnected: Bool?
    var client: TCPClient?
    var lastState: String?
    var wholeResponse = [UInt8]()
    var elements: [String] = ["foo", "blah", "duh"]

    var fullState: FullState?
    
    var soundLevel: Float?

    override func viewDidLoad() {
        super.viewDidLoad()
        serverIPField.delegate = self
        serverPortField.delegate = self
        serverIPField.keyboardType = .numbersAndPunctuation
        serverPortField.keyboardType = .numberPad
        
        // table view stuff for the slider screen
        sliderTableView.delegate = self
        sliderTableView.dataSource = self
        sliderTableView.tableFooterView = UIView(frame: CGRect.zero) // remove footer
    }

    func insertNewSlider(version: String) {
        
        elements.append(version)
        let indexPath = IndexPath(row: elements.count - 1, section: 0)
        sliderTableView.beginUpdates()
        sliderTableView.insertRows(at: [indexPath], with: .automatic)
        sliderTableView.endUpdates()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sendButtonAction() {
        let IPaddr: String? = serverIPField.text
        let PortNum: String? = serverPortField.text
        client = TCPClient(address: IPaddr!, port: Int32(PortNum!)!)
        guard let client = client else { return }
        
        // timeout, in seconds
        switch client.connect(timeout: 5) {
        case .success:
            connectionStatus.text = "Connected"
//            appendToTextField(string: "Connected to server \(client.address)")
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
//            appendToTextField(string: String(describing: error))
        }
    }
    
    private func sendRequest(string: String, using client: TCPClient) -> String? {
//        appendToTextField(string: "Sending data ... ")
        
        switch client.send(string: string) {
        case .success:
            return readResponse(from: client)
        case .failure(let error):
//            appendToTextField(string: String(describing: error))
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
    
//    private func appendToTextField(string: String) {
//        print(string)
//        textView.text = textView.text.appending("\n\(string)")
//    }
    
    func getServerVersion() -> Int {
        // Pull the current server version out of the json sent to us.
//        struct State : Codable {
//            struct theDefaultDevice : Codable {
//                let deviceId: String
//                let masterMuted: Bool
//                let masterVolume: Float
//                let name: String
//                let sessions: [Session]
//
//            }
//            struct Session : Codable {
//                let id: String
//                let muted: Bool
//                let name: String
//                let volume: Float
//            }
//            let defaultDevice: theDefaultDevice
//            let deviceIds: [String: String]
//            let version: Int
//        }
        
        let json = lastState!.data(using: .utf8)!
        let decodedState = try! JSONDecoder().decode(FullState.self, from: json)
        dump(decodedState)
        fullState = decodedState //make it pretty much global
        print(decodedState.version)
        insertNewSlider(version: decodedState.defaultDevice.name)
        return 1
    }
    
    class FullState : Codable {
            struct theDefaultDevice : Codable {
                let deviceId: String
                let masterMuted: Bool
                let masterVolume: Float
                let name: String
                let sessions: [Session]
                
            }
            struct Session : Codable {
                let id: String
                let muted: Bool
                let name: String
                let volume: Float
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

}

// This code controls the rows the sliders live in.
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return elements.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let elementName = elements[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "sliderCell") as! SliderCell
        cell.sliderTextField.text = elementName
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 100.0
    }
    

}

