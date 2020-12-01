//
//  AvailableStock.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/7/20.
//

import Foundation

//class StockArray: Codable {
//  var stocks = [AvailableStock]()
//}

func < (lhs: AvailableStock, rhs: AvailableStock) -> Bool {
  return lhs.stockSymbol.localizedStandardCompare(rhs.stockSymbol) == .orderedAscending
}

func symbolSizeSort (lhs: AvailableStock, rhs: AvailableStock) -> Bool {
    return lhs.stockSymbol.count < rhs.stockSymbol.count
}

class AvailableStock: Codable {

  var description: String? = ""
  var displaySymbol: String? = ""
  var symbol: String? = ""
  var type: String? = ""
  var currency: String? = ""
  
  var stockDescription: String {
    return description ?? ""
  }
  
  var stockDisplaySymbol: String {
    return displaySymbol ?? ""
  }
  
  var stockSymbol: String {
    return symbol ?? ""
  }
    
  var stockType: String {
    return type ?? ""
  }
  
  var stockCurrency: String {
    return currency ?? ""
  }
}
