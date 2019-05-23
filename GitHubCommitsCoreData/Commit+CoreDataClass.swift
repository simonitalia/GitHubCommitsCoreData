//
//  Commit+CoreDataClass.swift
//  GitHubCommitsCoreData
//
//  Created by Simon Italia on 5/22/19.
//  Copyright © 2019 Magical Tomato. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Commit)
public class Commit: NSManagedObject {
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        
        print("init called")
    }
    
    
}

