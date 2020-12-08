//
//  AvailableStock.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/7/20.
//


//This file is used for parsing API results that list all the stocks supported by the finnhub.io API
import Foundation

//sort lexicographically
func < (lhs: AvailableStock, rhs: AvailableStock) -> Bool {
  return lhs.stockSymbol.localizedStandardCompare(rhs.stockSymbol) == .orderedAscending
}

//sort by size
func symbolSizeSort (lhs: AvailableStock, rhs: AvailableStock) -> Bool {
    return lhs.stockSymbol.count < rhs.stockSymbol.count
}

class AvailableStock: Codable {

  var description: String? = "" //stock description or company name
  var displaySymbol: String? = "" //stock symbol
  var symbol: String? = "" //symbol used in the API endpoints
  var type: String? = "" //stock type
  var currency: String? = "" //stock currency
  
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
