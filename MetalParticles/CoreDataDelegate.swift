//
//  CoreDataDelegate.swift
//  Emergent
//
//  Created by Simon Gladman on 14/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import QuartzCore
import CoreData
import UIKit


class CoreDataDelegate: NSObject,  UIPopoverControllerDelegate
{
    
    let appDelegate: AppDelegate
    let managedObjectContext: NSManagedObjectContext
    let browseAndLoadController: BrowseAndLoadController
    let popoverController: UIPopoverController
    let viewController: ViewController
    
    var browseAndLoadDelegate: BrowseAndLoadDelegate?
    
    init(viewController: ViewController)
    {
        self.viewController = viewController
        
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        managedObjectContext = appDelegate.managedObjectContext!
        
        browseAndLoadController = BrowseAndLoadController()
        popoverController = UIPopoverController(contentViewController: browseAndLoadController)
        
        browseAndLoadController.preferredContentSize = CGSize(width: 640, height: 480)
        
        super.init()
        
        popoverController.delegate = self
    }
    
    func save(swarmChemistryRecipe: String, thumbnailImage: UIImage)
    {
        EmergentEntity.createInManagedObjectContext(managedObjectContext, swarmChemistryRecipe: swarmChemistryRecipe, thumbnailImage: thumbnailImage)
        
        appDelegate.saveContext()
    }
    
    func load()
    {
        let fetchRequest = NSFetchRequest(entityName: "EmergentEntity")
        
        if let fetchResults = managedObjectContext.executeFetchRequest(fetchRequest, error: nil) as? [EmergentEntity]
        {
            viewController.isRunning = false
            
            popoverController.presentPopoverFromRect(viewController.view.frame, inView: viewController.view, permittedArrowDirections: UIPopoverArrowDirection.allZeros, animated: true)
            
            browseAndLoadController.fetchResults = fetchResults
        }
    }
    
    func popoverControllerDidDismissPopover(popoverController: UIPopoverController)
    {
        if let _selectedEntity = browseAndLoadController.selectedEntity
        {
            if let browseAndLoadDelegate = browseAndLoadDelegate
            {
                if let swarmChemistryRecipe = NSURL(string: _selectedEntity.swarmChemistryRecipe)
                {
                    browseAndLoadDelegate.swarmChemistryRecipeSelected(swarmChemistryRecipe)
                }
            }
        }
        
        viewController.isRunning = true
    }
    
}


protocol BrowseAndLoadDelegate
{
    func swarmChemistryRecipeSelected(swarmChemistryRecipe: NSURL)
}
