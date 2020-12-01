//
//  UserPortfolioState+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/14/20.
//
//

import Foundation
import CoreData


extension UserPortfolioState {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPortfolioState> {
        return NSFetchRequest<UserPortfolioState>(entityName: "UserPortfolioState")
    }

    @NSManaged public var stocks: [PortfolioStock]
    @NSManaged public var date: Date

}

extension UserPortfolioState : Identifiable {

}
