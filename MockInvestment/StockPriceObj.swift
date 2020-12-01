//
//  StockPriceObj.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/15/20.
//

import Foundation

class StockPriceObj: Codable {

  var o: Double? = 0
  var h: Double? = 0
  var l: Double? = 0
  var c: Double? = 0
  var pc: Double? = 0
  var t: Double? = 0
  
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

