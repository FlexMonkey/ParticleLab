//
//  EmergentEntity.swift
//  Emergent
//
//  Created by Simon Gladman on 14/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class EmergentEntity: NSManagedObject
{

    @NSManaged var swarmChemistryRecipe: String
    @NSManaged var thumbnailImage: NSData

    var pendingDelete: Bool = false
    
    class func createInManagedObjectContext(moc: NSManagedObjectContext, swarmChemistryRecipe: String, thumbnailImage: UIImage) -> EmergentEntity
    {
        let newItem = NSEntityDescription.insertNewObjectForEntityForName("EmergentEntity", inManagedObjectContext: moc) as! EmergentEntity

        newItem.thumbnailImage = UIImagePNGRepresentation(thumbnailImage)
        newItem.swarmChemistryRecipe = swarmChemistryRecipe
        
        return newItem
    }
    
}
