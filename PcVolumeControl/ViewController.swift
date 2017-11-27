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
    
    
    var serverConnected: Bool?
    var client: TCPClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Handle the text field's user input through delegate callbacks.
        serverIPField.delegate = self
        serverPortField.delegate = self
        client = TCPClient(address: "192.168.2.78", port: Int32(3000))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: Actions
    @IBAction func connectServer(_ sender: UIButton) {
        let client = TCPClient(address: "www.apple.com", port: 80)
        switch client.connect(timeout: 1) {
        case .success:
            switch client.send(string: "GET / HTTP/1.0\n\n" ) {
            case .success:
                guard let data = client.read(1024*10) else { return }
                
                if let response = String(bytes: data, encoding: .utf8) {
                    print(response)
                }
            case .failure(let error):
                print(error)
            }
        case .failure(let error):
            print(error)
        }
    }
    
    @IBAction func sendButtonAction() {
        guard let client = client else { return }
        
        switch client.connect(timeout: 10) {
        case .success:
            appendToTextField(string: "Connected to host \(client.address)")
            if let response = sendRequest(string: "GET / HTTP/1.0\n\n", using: client) {
                appendToTextField(string: "Response: \(response)")
            }
        case .failure(let error):
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
        guard let response = client.read(1024*10) else { return nil }
        
        return String(bytes: response, encoding: .utf8)
    }
    
    private func appendToTextField(string: String) {
        print(string)
        textView.text = textView.text.appending("\n\(string)")
    }

    

}

