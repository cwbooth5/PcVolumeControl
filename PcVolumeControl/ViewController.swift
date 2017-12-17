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
   
    @IBAction func sliderMoved(_ sender: UISlider) {
        soundLevel = sender.value
        print("Sound Level: \(soundLevel)")
        //need to write a function to smash an update toward the server at this point.
    }
    
    var serverConnected: Bool?
    var client: TCPClient?
    var lastState: String?
    var wholeResponse = [UInt8]()
    var sessionNames: [String] = ["placeholder"]
    var sliderValues: [Float] = [20.0]
    var muteValues: [Bool] = [false]
    var fullState: FullState?
    var soundLevel: Float?
    var selectedDefaultDevice: String?

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
        
        constructPicker()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    

    func insertNewSlider(name: String, volume: Float, muted: Bool, index: IndexPath) {

        
        sliderTableView.deleteRows(at: [index], with: .automatic)
        sliderTableView.insertRows(at: [index], with: .automatic)
    }
    
    func buildSliderStack(index: IndexPath){
        // try and special-case the first slider as the master, then
        // draw all the sessions afterward.
//        let indexPath = IndexPath(row: fullState!.deviceIds.count - 1, section: 0)
        //        let stateMirror = Mirror(reflecting: decodedState)
        sliderTableView.beginUpdates()
        for value in fullState!.deviceIds.values {
            print("device added to slider text field: \(value)")
            insertNewSlider(name: value, volume: 75.0, muted: true, index: index)
        }
        sliderTableView.endUpdates()
        DispatchQueue.main.async{
            self.sliderTableView.reloadData()
        }
        
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
        
        let json = lastState!.data(using: .utf8)!
        let decodedState = try! JSONDecoder().decode(FullState.self, from: json)
        dump(decodedState)
        fullState = decodedState //make it pretty much global
        print(decodedState.version)
        let indexPath = IndexPath(row: sessionNames.count - 1, section: 0)
        // HACK, WTF
//        sessionNames = [String]()
//        for x in 0..<fullState!.deviceIds.count {
//            sessionNames.append("placeholder")
//        }
        buildSliderStack(index: indexPath)
        // This reloads the sliderTableView completely.
//        DispatchQueue.main.async{
//            self.sliderTableView.reloadData()
//        }
        
//        insertNewSlider(version: decodedState.defaultDevice.name)
//        let indexPath = IndexPath(row: sessionNames.count - 1, section: 0)
//        insertNewSlider(name: "namestring", volume: 65.0, muted: false, index: indexPath)
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

// This controls the picker view for the master/default device.
extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
   
    func constructPicker() {
        let devicePicker = UIPickerView()
        devicePicker.delegate = self
        pickerTextField.inputView = devicePicker
        createToolbar() // done buttons
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
        return sessionNames[row]
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return sessionNames.count
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedDefaultDevice = sessionNames[row]
        pickerTextField.text = selectedDefaultDevice
    }
}


// This code controls the tableView rows the sliders live in.
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // TODO: the picker is going to have to list all the device IDs...
//        return fullState!.deviceIds.count
        return sessionNames.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // The full table needs to completely reload.
        let cell = tableView.dequeueReusableCell(withIdentifier: "sliderCell") as! SliderCell
        // Different treatment before connection versus after an update
        if fullState != nil {
            // If we have already connected
            sessionNames.removeAll()

            for sessionItem : FullState.Session in fullState!.defaultDevice.sessions {
                sessionNames.append(sessionItem.name)
                sliderValues.append(sessionItem.volume)
                muteValues.append(sessionItem.muted)
                print(sessionItem.volume)
            }
            
//            var allSessions : [FullState.Session] = fullState!.defaultDevice.sessions
//            cell.sliderTextField.text = allSessions[indexPath.row].name
            // or
            cell.sliderTextField.text = sessionNames[indexPath.row]
            cell.sliderTextField.tag = indexPath.row
            
            cell.actualSlider.value = sliderValues[indexPath.row]
            cell.actualSlider.tag = indexPath.row
            
            
//            sessionNames = Array(fullState!.deviceIds.values)
        }
        
//        let elementName = sessionNames[indexPath.row]
//        let elementName = fullState!.deviceIds.values[indexPath.row]
        
        // Identify each cell by a numeric tag.
        cell.tag = indexPath.row
        
        // Slider value is changed to the value read out of the JSON server message.
        cell.sliderMuteButton.tag = indexPath.row
//        print(elementName)
        
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 90.0
    }
    

    

}

