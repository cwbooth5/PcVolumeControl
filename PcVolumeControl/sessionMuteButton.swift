//
//  sessionMuteButton.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/17/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

@objcMembers
class sessionMuteButton: UIButton {

    var isMuted = false
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        initButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initButton()
    }
    
    func initButton() {
        layer.borderWidth = 2.0
        layer.cornerRadius = frame.size.height/2
        addTarget(self, action: #selector(sessionMuteButton.buttonPressed), for: .touchUpInside)
    }
    
    func buttonPressed() {
        // change to the opposite of what it's at meow.
        activateButton(bool: !isMuted)
    }
    
    func activateButton(bool: Bool) {
        isMuted = bool
        
        let title = bool ? " Mute " : "Unmute"
        setTitle(title, for: .normal)
    }

}
