//
//  ViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 11/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import SwiftSocket
import Foundation

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
    
    let protocolVersion = 5
    var serverConnected: Bool?
    var client: TCPClient?
    var lastState: String?
    var wholeResponse = [UInt8]()
    var fullState: FullState?
    var soundLevel: Float?
    var selectedDefaultDevice: (String, String)?
    
    var allSessions = [Session]() // Array used to build slider table
    var processedSessions = [Session]() // Array used to
    var IPaddr: String!
    var PortNum: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Detection that the app was minimized so we can close TCP connections
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        
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
    func appMovedToBackground() {
        // Tear down the TCP connection any time they minimize or exit the app.
        print("App moved to background!")
        closeTCPConnection(client: client!)
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
                allSessions.append(Session(id: x.id, muted: x.muted, name: x.name, volume: Double(x.volume)))
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
    
//    func findDevicePrettyName(id: String) {
//        // Input a long session ID and get back the name from that session.
//        for (key, value) in (fullState?.defaultDevice.sessions) {
////            for (key, value) in item {
////                print(item)
////            }
//        }
////        for (shortId, _) in (fullState?.deviceIds)! {
////            if longName.contains(shortId) {
////                return shortId
////            }
////        }
////        return "DERP"
//
//    }
    
    func openTCPConnection(address: String, portNum: String) -> TCPClient?{
        let c = TCPClient(address: address, port: Int32(portNum)!)
        // timeout, in seconds
        switch c.connect(timeout: 5) {
        case .success:
            client = c // update the global client used by everybody.
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
        IPaddr = serverIPField.text
        PortNum = serverPortField.text
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
        lastState = stringResponse
        let json = stringResponse!.data(using: .utf8)!
        do {
            let decodedState = try JSONDecoder().decode(FullState.self, from: json)
            dump(decodedState) //debug
            fullState = decodedState //make it pretty much global
            print(decodedState.version)
        } catch Swift.DecodingError.dataCorrupted {
            Alert.showBasic(title: "JSON data corrupted!", message: "The server sent garbage back!", vc: self)
        } catch {
            //what the fuck
            print(error.localizedDescription)
        }

        
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
    
    func getDeviceIds() -> [(String, String)] {
        // return an array of tuples showing all available device IDs and pretty names
        var y = [(String, String)]()
        for (shortId, prettyName) in (fullState?.deviceIds)! {
            y.append((shortId, prettyName))
        }
        return y
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
        // When they select the default, we need to update state and send a new master device to the server.
        struct ADefaultDeviceUpdate : Codable {
            struct adflDevice : Codable {
                let deviceId: String
                
            }
            let version: Int
            let defaultDevice: adflDevice
        }
        
        let id = selectedDefaultDevice?.0
        let defaultDevId = ADefaultDeviceUpdate.adflDevice(deviceId: id!)
        let data = ADefaultDeviceUpdate(version: 5, defaultDevice: defaultDevId)
        
        let encoder = JSONEncoder()
        
        do {
            let dataAsBytes = try! encoder.encode(data)
            dump(dataAsBytes)
            print(dataAsBytes)
            // The data is supposed to be an array of Uint8.
            let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
            let dataWithNewline = dataAsString! + "\n"
            //            print(String(data: dataAsBytes, encoding: .utf8)!)
            let response = sendRequest(string: dataWithNewline, using: client!)
            print(response)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    //picker view overrides
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        var deviceids = getDeviceIds()
        return deviceids[row].1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var deviceids = getDeviceIds()
        return deviceids.count
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedDefaultDevice = getDeviceIds()[row]
        pickerTextField.text = getDeviceIds()[row].1
    }
}


// This code controls the tableView rows the sliders live in.
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func insertNewSlider(index: IndexPath) {
        sliderTableView.deleteRows(at: [index], with: .automatic)
        sliderTableView.insertRows(at: [index], with: .automatic)
    }
    
    func buildSliderStack(index: IndexPath){
        
        sliderTableView.beginUpdates()

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
        // TODO: if you slide the table, it needs to read this again. The array is empty after the initial draw, so we need to
        // rebuild, pop, and redraw here. Should have a function.
        if allSessions.count == 0 {
            initSessions()  // populate the sessions array again. We changed the view.
        }
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
    func didChangeVolume(id: String, newvalue: Double, name: String) {
        print("Volume changed on \(id) to: \(newvalue)")
        
        struct ASessionUpdate : Codable {
            struct adflDevice : Codable {
                let sessions: [OneSession]
                let deviceId: String
                
            }
            let version: Int
            let defaultDevice: adflDevice
            
        }
        struct OneSession : Codable {
            let name: String
            let id: String
            let volume: Double
            let muted: Bool
        }
        
        
//        let mySession = SessionUpdate.DefaultDevice.Session(sessionID: "a short session ID", muted: true, volume: newvalue)
        let defaultDeviceShortId = findDeviceId(longName: id)
        
        let encoder = JSONEncoder()
        // TODO: return current muted state and use that to make the onesession instance.
        let onesession = OneSession(name: name, id: id, volume: 90.0, muted: false)
        let adefault = ASessionUpdate.adflDevice(sessions: [onesession], deviceId: defaultDeviceShortId)
        let data = ASessionUpdate(version: 5, defaultDevice: adefault)
        
        do {
            let dataAsBytes = try! encoder.encode(data)
            dump(dataAsBytes)
            print(dataAsBytes)
            // The data is supposed to be an array of Uint8.
            var dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
            var dataWithNewline = dataAsString! + "\n"
//            print(String(data: dataAsBytes, encoding: .utf8)!)
            let response = sendRequest(string: dataWithNewline, using: client!)
            print(response)
        } catch {
            print(error.localizedDescription)
        }
    }
        
    func didToggleMute(id: String, muted: Bool) {
        print("mute button hit")
    }
}

