//
//  ViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 11/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import SwiftSocket

@objcMembers //wtf:: forced to do this in the picker #selector. huh?
class ViewController: UIViewController, UITextFieldDelegate {
    
    //MARK: Properties
    @IBOutlet weak var serverIPField: UITextField!
    @IBOutlet weak var serverPortField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var connectbutton: UIButton!
    @IBOutlet weak var connectionStatus: UILabel!
    
    // picker
    @IBOutlet weak var pickerTextField: UITextField!
    @IBOutlet weak var masterPickerLabel: UITextField!
 
    // top slider for master channel
    @IBOutlet weak var masterSliderCell: UITableViewCell!
    
    // bottom sliders for sessions
    @IBOutlet weak var sliderTableView: UITableView!
    
    var serverConnected: Bool?
    var client: TCPClient?
    var lastState: String?
    var wholeResponse = [UInt8]()
    var fullState: FullState?
    var soundLevel: Float?
    var selectedDefaultDevice: String?
    
    var allSessions = [Session]() // Array used to build slider table
    var processedSessions = [Session]() // Array used to
    
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
        
        initSessions()  // populate the initial session with _something_
        constructPicker()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initSessions() {
        
        if fullState != nil {
            // Connecting for the first time.
            allSessions.removeAll()
            
            for x : FullState.Session in fullState!.defaultDevice.sessions {
                // build an array of all the sessions.
                allSessions.append(Session(id: x.id, muted: x.muted, name: x.name, volume: x.volume))
            }
        } else {
            print("This is the initial screen draw, prior to the sessions being loded after connect.")
//            allSessions.append(Session(id: "123", muted: false, name: "placeholder", volume: 20.0))
        }
    }
    
    func findDeviceId(longName: String) -> String {
        // Look through the device IDs to get the short-form device ID.
        // This takes in the long-form session ID as input.
        for (shortId, _) in (fullState?.deviceIds)! {
            if longName.contains(shortId) {
                return shortId
            }
        }
        return "DERP"
    }
    
    func openTCPConnection(address: String, portNum: String) -> TCPClient?{
        var c = TCPClient(address: address, port: Int32(portNum)!)
        // timeout, in seconds
        switch c.connect(timeout: 5) {
        case .success:
            connectionStatus.text = "Connected"
            if let response = readResponse(from: c) {
                print("got a response...")
                reloadTheWorld() //update global state.
                serverConnected = true
                return c
            }
            
        case .failure(let error):
            connectionStatus.text = "Disconnected"
            serverConnected = false
            return c
        }
        return c
    }
    
    func closeTCPConnection(client: TCPClient) {
        //TODO: tear down when the app is minimized.
        print("Tearing down TCP Connection...")
        client.close()
    }
   
    @IBAction func sendButtonAction() {
        let IPaddr: String! = serverIPField.text
        let PortNum: String! = serverPortField.text
        client = openTCPConnection(address: IPaddr, portNum: PortNum)
    }
    
    private func sendRequest(string: String, using client: TCPClient) -> String? {

        switch client.send(string: string) {
        case .success:
            return readResponse(from: client)
        case .failure(let error):
            print(error)
            return nil
        }
    }
    
    private func readResponse(from client: TCPClient) -> String? {
        while true {
            guard let data = client.read(1024*10, timeout: 5) else { break }
            wholeResponse += data
        }
        
        let stringResponse = String(bytes: wholeResponse, encoding: .utf8)
//        lastState = stringResponse
        let json = stringResponse!.data(using: .utf8)!
        let decodedState = try! JSONDecoder().decode(FullState.self, from: json)
        dump(decodedState) //debug
        fullState = decodedState //make it pretty much global
        print(decodedState.version)
        return stringResponse
    }
    
    func reloadTheWorld() {
        // Reload everything! All the things!
        
        // re-populate the array of current sessions and reload the sliders.
        let indexPath = IndexPath(row: allSessions.count - 1, section: 0)
        buildSliderStack(index: indexPath)
        initSessions()
        
        // This reloads the sliderTableView completely.
        DispatchQueue.main.async{
            self.sliderTableView.reloadData()
        }
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

// This controls the picker view for the master/default device.
extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
   
    func constructPicker() {
        let devicePicker = UIPickerView()
        devicePicker.delegate = self
        pickerTextField.inputView = devicePicker
        createToolbar() // done button
    }
    
    func createToolbar() {
        // make a toolbar with a 'done' button for the picker.
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self,
                                         action: #selector(ViewController.dismissKeyboard))
        toolBar.setItems([doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        pickerTextField.inputAccessoryView = toolBar
        
        toolBar.barTintColor = .black
        toolBar.tintColor = .white
        
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
        // TODO: When they select the default, we need to update state and send a new master device to the server.
    }
    
    //picker view overrides
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        return allSessions[row]
        return allSessions[0].name
//        return "TODO"
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return allSessions.count
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//        selectedDefaultDevice = allSessions[row]
//        pickerTextField.text = selectedDefaultDevice
    }
}


// This code controls the tableView rows the sliders live in.
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func insertNewSlider(index: IndexPath) {
        sliderTableView.deleteRows(at: [index], with: .automatic)
        sliderTableView.insertRows(at: [index], with: .automatic)
    }
    
    func buildSliderStack(index: IndexPath){
        
        sliderTableView.beginUpdates()  //TODO: needed? Where am I ending?

        // for all sessions
        for session in allSessions {
            print(session.name)
            print(" - \(session.id)")
            print(" - \(session.muted)")
            print(" - \(session.volume)")
            insertNewSlider(index: index)
            allSessions = allSessions.filter { $0 !== session }
            print("Removing session: \(session)")
        }
        
        sliderTableView.endUpdates()
        DispatchQueue.main.async{
            self.sliderTableView.reloadData()
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // TODO: the picker is going to have to list all the device IDs...
//        return sessionNames.count
        return allSessions.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // The full table needs to completely reload.
        let cell = tableView.dequeueReusableCell(withIdentifier: "sliderCell") as! SliderCell
        cell.delegate = self
        let targetSession = allSessions.removeFirst()
        cell.setSessionParameter(session: targetSession)
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 90.0
    }
}

extension ViewController: SliderCellDelegate {
    func didChangeVolume(id: String, newvalue: Float) {
//        let roundedVolume = String(format: "%.1f", newvalue)
        let roundedVolume = round(newvalue)
        print("Volume changed on \(id) to: \(roundedVolume)")
        
        struct ASessionUpdate : Codable {
            struct adflDevice : Codable {
                let deviceId: String
                let sessions: [OneSession]
            }
            let defaultDevice: adflDevice
            let version: Int
        }
        struct OneSession : Codable {
            let id: String
            let muted: Bool
            let volume: Float
        }
        
        
//        let mySession = SessionUpdate.DefaultDevice.Session(sessionID: "a short session ID", muted: true, volume: newvalue)
        var defaultDeviceShortId = findDeviceId(longName: id)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // helpful
        // TODO: return current muted state and use that to make the onesession instance.
        let onesession = OneSession(id: id, muted: false, volume: roundedVolume)
        let adefault = ASessionUpdate.adflDevice(deviceId: defaultDeviceShortId ,sessions: [onesession])
        let data = ASessionUpdate(defaultDevice: adefault, version: 5)
        
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        print(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
        print(String(data: dataAsBytes, encoding: .utf8)!)
        let response = sendRequest(string: dataAsString!, using: client!)
        print(response)
    }
        
    func didToggleMute(id: String, muted: Bool) {
        print("mute button hit")
    }
}

