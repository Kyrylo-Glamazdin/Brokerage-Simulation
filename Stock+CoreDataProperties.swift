//
//  Stock+CoreDataProperties.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/4/20.
//
//

import Foundation
import CoreData


extension Stock {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Stock> {
        return NSFetchRequest<Stock>(entityName: "Stock")
    }

    @NSManaged public var symbol: String
    @NSManaged public var name: String
    @NSManaged public var quantity: Int32

}

extension Stock : Identifiable {

}
