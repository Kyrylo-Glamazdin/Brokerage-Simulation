//
//  UserInvestmentBalance+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/4/20.
//
//

import Foundation
import CoreData


extension UserInvestmentBalance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserInvestmentBalance> {
        return NSFetchRequest<UserInvestmentBalance>(entityName: "UserInvestmentBalance")
    }

    @NSManaged public var investmentBalance: Double
    @NSManaged public var date: Date

}

extension UserInvestmentBalance : Identifiable {

}
