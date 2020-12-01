////
////  PortfolioStockTransformer.swift
////  MockInvestment
////
////  Created by Kyrylo Glamazdin on 11/24/20.
////
//
//import Foundation
//
////https://www.kairadiagne.com/2020/01/13/nssecurecoding-and-transformable-properties-in-core-data.html
//
//@objc(PortfolioStockTransformer)
//final class PortfolioStockTransformer: NSSecureUnarchiveFromDataTransformer {
//
//    static let name = NSValueTransformerName(rawValue: String(describing: PortfolioStockTransformer.self))
//
//    override static var allowedTopLevelClasses: [AnyClass] {
//        return [PortfolioStock.self]
//    }
//
//    public static func register() {
//        let transformer = PortfolioStockTransformer()
//        ValueTransformer.setValueTransformer(transformer, forName: name)
//    }
//}
