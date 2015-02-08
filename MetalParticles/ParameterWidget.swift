//
//  ParameterWidget.swift
//  MetalReactionDiffusion
//
//  Created by Simon Gladman on 23/10/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import UIKit

class ParameterWidget: UIControl, UIPopoverControllerDelegate
{
    let label = UILabel(frame: CGRectZero)
    let slider = UISlider(frame: CGRectZero)

    override func didMoveToSuperview()
    {
        
        label.textColor = UIColor.whiteColor()
        layer.backgroundColor = UIColor.darkGrayColor().CGColor
        
        layer.cornerRadius = 5
        
        layer.shadowColor = UIColor.blackColor().CGColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowOpacity = 0.5
        
        addSubview(label)
        addSubview(slider)
        
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        
        slider.addTarget(self, action: "sliderChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
    }
    

    
    func sliderChangeHandler()
    {
        value = slider.value
        
        popoulateLabel()
        
        sendActionsForControlEvents(UIControlEvents.ValueChanged)
    }
    
    func popoulateLabel()
    {
        if let fieldName = fieldName
        {
            label.text = fieldName + " = " + NSString(format: "%.2f", value)
        }
    }
    
    var fieldName: String?
    {
        didSet
        {
            popoulateLabel();
        }
    }
    
    var value: Float = 0
    {
        didSet
        {
            slider.setValue(value, animated: true)
            popoulateLabel()
        }
    }
    
    var minimumValue: Float = 0.0
    {
        didSet
        {
            slider.minimumValue = minimumValue
        }
    }
    
    var maximumValue: Float = 1
    {
        didSet
        {
            slider.maximumValue = maximumValue
        }
    }
    
    override func layoutSubviews()
    {
        label.frame = CGRect(x: 5, y: -3, width: frame.width, height: frame.height / 2)
        slider.frame = CGRect(x: 0, y: frame.height - 30, width: frame.width, height: frame.height / 2)
    }
    
}
