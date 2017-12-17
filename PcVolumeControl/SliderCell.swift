//
//  SliderCell.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/11/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

protocol SliderCellDelegate {
    func didChangeVolume(newvalue: Float)
    func didToggleMute(muted: Bool)
}

// This covers individual cells, with one session per cell.
class SliderCell: UITableViewCell {
    
    @IBOutlet weak var actualSlider: UISlider!
    @IBOutlet weak var sliderTextField: UITextField!
    @IBOutlet weak var sliderMuteButton: UIButton!
    
    var sessionItem: Session!
    var delegate: SliderCellDelegate?
    
    func setSessionParameter(session: Session) {
        sessionItem = session
        sliderTextField.text = session.name
        actualSlider.value = session.volume
        // TODO: mute button toggle
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        delegate?.didChangeVolume(newvalue: sessionItem.volume)
    }
    
    @IBAction func muteTapped(_ sender: UIButton) {
    }
}
