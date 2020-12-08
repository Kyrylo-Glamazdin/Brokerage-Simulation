//
//  IndividualStockViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/14/20.
//

import Foundation
import UIKit
import CoreData

class IndividualStockViewController: UIViewController {
    
    //outlets
    @IBOutlet weak var stockSymbolLabel: UILabel!
    @IBOutlet weak var stockNameLabel: UILabel!
    @IBOutlet weak var stockPriceLabel: UILabel!
    @IBOutlet weak var stockPriceChangeLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var userSharesLabel: UILabel!
    @IBOutlet weak var userBalanceLabel: UILabel!
    @IBOutlet weak var sellSharesError: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    @IBOutlet weak var sellButton: UIButton!
    @IBOutlet weak var intervalLabel: UILabel!
    
    var userAvailableBalances = [UserAvailableBalance]()
    var userPortfolios = [UserPortfolioState]()
    
    var stockObj: AvailableStock!
    var dataTask: URLSessionDataTask?
    var managedObjectContext: NSManagedObjectContext!
    
    var currentStockPrice: StockPriceObj? //determines object price
    var canPerformSellSegue: Bool = true //false when user has no shares, true otherwise
    
    //stock price percentage changes
    var dailyChange: Double = 0
    var weeklyChange: Double = 0
    var monthlyChange: Double = 0
    
    var canToggleSegmentedControl: Bool = false //true when historical stock prices are loaded and segmentedControl can be toggled
    
    let dispatchGroup = DispatchGroup() //dispatchGroup is used to wait for all historical stock prices to get fetched
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataAndLabels), name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
        stockSymbolLabel.text! = stockObj.stockSymbol
        stockNameLabel.text! = stockObj.stockDescription
        buyButton.setTitle(String("Buy " + stockObj.stockSymbol), for: .normal)
        sellButton.setTitle(String("Sell " + stockObj.stockSymbol), for: .normal)
        updateDataAndLabels()
        
        //wait for historical stock prices to get fetched and allow segmentedControl to be toggled
        dispatchGroup.notify(queue: .main){
            self.canToggleSegmentedControl = true
        }
    }
    
    //MARK: - Data fetches and label updates
    
    //when segmented control value changes, compute the price percentage change and update the labels
    @IBAction func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        if canToggleSegmentedControl {
            let segmentedControlValue = sender.selectedSegmentIndex
            //daily price change
            if segmentedControlValue == 0 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let dailyPriceChange = curPrice - self.currentStockPrice!.previousClose
                    let dailyPercentageChange = (dailyPriceChange/self.currentStockPrice!.previousClose) * 100
                    if dailyPriceChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else{
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Today)"
            }
            //weekly price change
            else if segmentedControlValue == 1 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let weeklyPercentageChange = (weeklyChange / curPrice) * 100
                    if weeklyPercentageChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", weeklyPercentageChange) + "% ($" + String(format: "%.2f", weeklyChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", weeklyPercentageChange) + "% ($" + String(format: "%.2f", weeklyChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else {
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Week)"
            }
            //monthly price change
            else if segmentedControlValue == 2 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let monthlyPercentageChange = (monthlyChange / curPrice) * 100
                    if monthlyPercentageChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", monthlyPercentageChange) + "% ($" + String(format: "%.2f", monthlyChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", monthlyPercentageChange) + "% ($" + String(format: "%.2f", monthlyChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else {
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Month)"
            }
        }
    }
    
    //update the whole view controller
    @objc func updateDataAndLabels() {
        getStockPrice()
        performDataFetch()
        callPercentageFetches()
    }
    
    //fetch portfolio data from local database
    func performDataFetch(){
        //fetch requests
        let fetchRequest1 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest2 = NSFetchRequest<UserPortfolioState>()

        let entity1 = UserAvailableBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserPortfolioState.entity()
        fetchRequest2.entity = entity2
        
        //sort by descending date
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)

        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        
        do {
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest1)
            userPortfolios = try managedObjectContext.fetch(fetchRequest2)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        //update the labels
        if userAvailableBalances.count == 0 {
            self.userBalanceLabel.text! = "$0.00"
        }
        else{
            self.userBalanceLabel.text! = "$" + String(format: "%.2f", userAvailableBalances[0].availableBalance)
        }
        
        if userPortfolios.count == 0 {
            self.userSharesLabel.text! = "You don't have any " + stockObj.stockDisplaySymbol + " shares"
        }
        else {
            var stockFound = false
            let latestPortfolio = userPortfolios[0]
            for stock in latestPortfolio.stocks {
                if stock.symbol == stockObj.stockSymbol {
                    stockFound = true
                    if stock.quantity == 1 {
                        self.userSharesLabel.text! = "You own 1 share of " + stock.symbol
                    }
                    else {
                        self.userSharesLabel.text! = "You own " + String(stock.quantity) + " shares of " + stock.symbol
                    }
                }
            }
            if !stockFound {
                self.userSharesLabel.text! = "You don't have any " + stockObj.stockDisplaySymbol + " shares"
            }
        }
    }
    
    //get stock percentage change (1 week & 1 month)
    func callPercentageFetches() {
        getCandlePrices(resolution: 1)
        getCandlePrices(resolution: 2)
    }
    
    //MARK: - Stock Price Fetches
    
    //url for fetching current stock price
    func stockPriceURL() -> URL {
        let urlStringFirstHalf = "https://finnhub.io/api/v1/quote?symbol="
        let stockSymbol = stockObj.stockSymbol
        let urlStringSecondHalf = "&token=" + apiKey
        let fullURL = urlStringFirstHalf + stockSymbol + urlStringSecondHalf
        let url = URL(string: fullURL)
        return url!
    }
    
    //parse stock price object
    func parse(data: Data) -> StockPriceObj {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(StockPriceObj.self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            let emptyCurrentPrice = StockPriceObj()
            return emptyCurrentPrice
        }
    }
    
    //get current stock price using finnhub.io API
    func getStockPrice(){
        let url = stockPriceURL()
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    self.currentStockPrice = self.parse(data: data)
                    //when stock price is fetched, compute price & percentage changes, update the labels
                    DispatchQueue.main.async {
                        self.stockPriceLabel.text! = "$" + String(format: "%.2f", self.currentStockPrice?.currentPrice ?? 0.00)
                        if let curPrice = self.currentStockPrice?.currentPrice {
                            let dailyPriceChange = curPrice - self.currentStockPrice!.previousClose
                            self.dailyChange = dailyPriceChange
                            let dailyPercentageChange = (dailyPriceChange/self.currentStockPrice!.previousClose) * 100
                            if dailyPriceChange < 0 {
                                self.stockPriceChangeLabel.text! = String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange * (-1)) + ")"
                                self.stockPriceChangeLabel.textColor = UIColor.red
                            }
                            else {
                                self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange) + ")"
                                self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                            }
                        }
                        else{
                            self.stockPriceChangeLabel.text! = "0% ($0.00)"
                        }
                    }
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    //candles are used for historical stock prices
    //if @resolution == 2, get monthly candle, otherwise get weekly candle
    func candlePriceURL(resolution: Int) -> URL {
        var resolutionChar = "5"
        let curDateTimestamp = Int(Date().timeIntervalSince1970)
        var pastDateTimestamp = curDateTimestamp - 604800
        if resolution == 2 {
            resolutionChar = "30"
            pastDateTimestamp = curDateTimestamp - 2592000
        }
        let urlStringSymbol = "https://finnhub.io/api/v1/stock/candle?symbol="
        let stockSymbol = stockObj.stockSymbol
        let urlStringResolution = "&resolution="
        let urlStringFrom = "&from="
        let urlStringTo = "&to="
        let urlStringToken = "&token=" + apiKey
        let fullURL = urlStringSymbol + stockSymbol + urlStringResolution + resolutionChar + urlStringFrom + String(pastDateTimestamp) + urlStringTo + String(curDateTimestamp) + urlStringToken
        let url = URL(string: fullURL)
        return url!
    }
    
    //parse candle object
    func parseCandle(data: Data) -> Candle {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(Candle.self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            let emptyCandle = Candle()
            return emptyCandle
        }
    }
    
    //get stock candles from finnhub API
    func getCandlePrices(resolution: Int){
        dispatchGroup.enter()
        let url = candlePriceURL(resolution: resolution)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let candle = self.parseCandle(data: data)
                    //update object variables
                    DispatchQueue.main.async {
                        if resolution == 2 {
                            if self.currentStockPrice != nil {
                                self.monthlyChange = self.currentStockPrice!.currentPrice - candle.openPrice
                            }
                        }
                        else {
                            if self.currentStockPrice != nil {
                                self.weeklyChange = self.currentStockPrice!.currentPrice - candle.openPrice
                            }
                        }
                    }
                    self.dispatchGroup.leave()
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    //MARK: - Segue-related methods
    
    //SellStock segue must be disabled if the user doesn't have any shares of this stock
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "SellStock" {
            if userPortfolios.count == 0 {
                sellSharesError.text! = "You don't have any " + stockObj.stockSymbol + " shares"
                afterDelay(5){
                    self.sellSharesError.text! = ""
                }
                return false
            }
            else {
                let latestPortfolio = userPortfolios[0].stocks
                for stock in latestPortfolio {
                    if stock.symbol == stockObj.stockSymbol {
                        self.sellSharesError.text! = ""
                        return true
                    }
                }
                sellSharesError.text! = "You don't have any " + stockObj.stockSymbol + " shares"
                afterDelay(5){
                    self.sellSharesError.text! = ""
                }
                return false
            }
        }
        return true //true if segue is other than "SellStock"
    }
    
    //pass stock info to child controllers
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "BuyStock" {
            let controller = segue.destination as! BuyStockViewController
            controller.managedObjectContext = managedObjectContext
            controller.stockObj = stockObj
            controller.currentStockPrice = currentStockPrice
        }
        else if segue.identifier == "SellStock" {
            let controller = segue.destination as! SellStockViewController
            controller.managedObjectContext = managedObjectContext
            controller.stockObj = stockObj
            controller.currentStockPrice = currentStockPrice
        }
    }
    
//    @IBAction func back() {
//        navigationController?.popViewController(animated: true)
//    }
    
}
