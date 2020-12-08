//
//  StockPriceObj.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/15/20.
//


//This file is used for parsing stock price object provided by finnhub.io
import Foundation

class StockPriceObj: Codable {

  var o: Double? = 0 //open price
  var h: Double? = 0 //high price
  var l: Double? = 0 //low price
  var c: Double? = 0 //close price
  var pc: Double? = 0 //previous close
  var t: Double? = 0 //timestamp
  
  var openPrice: Double {
    return o ?? 0
  }
  
  var highPrice: Double {
    return h ?? 0
  }
  
  var lowPrice: Double {
    return l ?? 0
  }
    
  var currentPrice: Double {
    return c ?? 0
  }
  
  var previousClose: Double {
    return pc ?? 0
  }
    
    var timestamp: Double {
        return t ?? 0
    }
}

