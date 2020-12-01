//
//  UserTotalBalance+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/4/20.
//
//

import Foundation
import CoreData


extension UserTotalBalance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserTotalBalance> {
        return NSFetchRequest<UserTotalBalance>(entityName: "UserTotalBalance")
    }

    @NSManaged public var totalBalance: Double
    @NSManaged public var date: Date

}

extension UserTotalBalance : Identifiable {

}
