//
//  Candle.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/26/20.
//


//This file is used for parsing stock price candle provided by finnhub.io
import Foundation

class Candle: Codable {

  var c = [Double]() //candle close price
  var h = [Double]() //candle high price
  var l = [Double]() //candle low price
  var o = [Double]() //candle open price
  var s = "" //request status
  var t = [Double]() //timestamp
  var v = [Int]() //candle trade volume
  
  var openPrice: Double {
    if o.count > 0 {
        return o[0]
    }
    return 0
  }
  
  var highPrice: Double {
    if h.count > 0 {
        return h[0]
    }
    return 0
  }
  
  var lowPrice: Double {
    if l.count > 0 {
        return l[0]
    }
    return 0
  }
    
  var closePrice: Double {
    if c.count > 0 {
        return c[0]
    }
    return 0
  }
  
  var status: String {
    return s
  }
    
    var timestamp: Double {
        if s.count > 0 {
            return t[0]
        }
        return 0
    }
    
    var volume: Int {
        if v.count > 0 {
            return v[0]
        }
        return 0
    }
    
    //specialOpenPrice is the opening price of the last day candle in one week time period.
    //it is used due to API limitation with 1 day candles. Used to get personal percentage updates
    var specialOpenPrice: Double {
        if o.count > 0 {
            return o[o.count - 1]
        }
        return 0
    }
}
