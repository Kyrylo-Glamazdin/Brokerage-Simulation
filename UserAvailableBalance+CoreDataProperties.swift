//
//  UserAvailableBalance+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/4/20.
//
//

import Foundation
import CoreData


extension UserAvailableBalance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserAvailableBalance> {
        return NSFetchRequest<UserAvailableBalance>(entityName: "UserAvailableBalance")
    }

    @NSManaged public var availableBalance: Double
    @NSManaged public var date: Date

}

extension UserAvailableBalance : Identifiable {

}
