//
//  UserTotalDepositedBalance+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/6/20.
//
//

import Foundation
import CoreData


extension UserTotalDepositedBalance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserTotalDepositedBalance> {
        return NSFetchRequest<UserTotalDepositedBalance>(entityName: "UserTotalDepositedBalance")
    }

    @NSManaged public var totalDepositedBalance: Double
    @NSManaged public var date: Date

}

extension UserTotalDepositedBalance : Identifiable {

}
