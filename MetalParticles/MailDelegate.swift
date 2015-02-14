//
//  MailDelegate.swift
//  Emergent
//
//  Created by Simon Gladman on 14/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import MessageUI
import UIKit

class MailDelegate: NSObject, MFMailComposeViewControllerDelegate
{
    private var viewController: UIViewController
    
    init(viewController: UIViewController)
    {
        self.viewController = viewController
    }
    
    func mailRecipe(#recipeURL: NSURL, image: UIImage?)
    {
        var picker = MFMailComposeViewController()
        picker.mailComposeDelegate = self
        
        picker.setSubject("Swarm Chemistry")
        
        let bodyOne = "Here's a swarm chemistry recipe I created in <a href=\"http://flexmonkey.blogspot.co.uk/search/label/Swarm%20Chemistry\">Emergent</a><br><br>"
        let link = "<a href = \"\(recipeURL)\">\(recipeURL)</a>"
        
        if let image = image
        {
            picker.addAttachmentData(UIImageJPEGRepresentation(image.resizeToBoundingSquare(boundingSquareSideLength: 480), 1.0), mimeType: "image/jpeg", fileName: "SwarmChemistry.jpg")
        }
        
        picker.setMessageBody(bodyOne + link, isHTML: true)
        
        viewController.presentViewController(picker, animated: true, completion: nil)
        
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!)
    {
        viewController.dismissViewControllerAnimated(true, completion: nil)
    }
}
