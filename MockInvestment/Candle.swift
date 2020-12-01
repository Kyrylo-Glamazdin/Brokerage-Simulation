//
//  Candle.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/26/20.
//

import Foundation

class Candle: Codable {

    var c = [Double]()
  var h = [Double]()
  var l = [Double]()
  var o = [Double]()
  var s = ""
  var t = [Double]()
  var v = [Int]()
  
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
    
    var specialOpenPrice: Double {
        if o.count > 0 {
            return o[o.count - 1]
        }
        return 0
    }
}
