//
//  ViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/2/20.
//

//dispatch group: itnext.io/how-to-use-dispatchgroup-in-swift-4-2-similar-to-async-await-in-javascript-62a2ff04e51e

import CoreData
import UIKit

class InvestmentsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userInvestmentBalanceLabel: UILabel!
    @IBOutlet weak var userAvailableBalanceLabel: UILabel!
    @IBOutlet weak var userInvestmentBalancePercentageChangeLabel: UILabel!
    var managedObjectContext: NSManagedObjectContext!
    var dataTask: URLSessionDataTask?
    var stateController: StateController!
    
    var currentInvestments = [Investment]()
    var userTotalBalances = [UserTotalBalance]()
    var userTotalDepositBalances = [UserTotalDepositedBalance]()
    var userAvailableBalances = [UserAvailableBalance]()
    var userPortfolios = [UserPortfolioState]()
    var availableStocks = [AvailableStock]()
    var portfolioStockPrices = [StockPriceObj]()
    var stockPriceObjects = [StockPrice]()
    var selectedStock: AvailableStock?
    var dailyChange: String = "Loading..."
    var weeklyChange: String = "Loading..."
    var monthlyChange: String = "Loading..."
    var allTimeChange: String = "Loading..."
    var dailyChangeVal: Double = 0
    var weeklyChangeVal: Double = 0
    var monthlyChangeVal: Double = 0
    var allTimeChangeVal: Double = 0
    var dailyChangeGroup = [Double]()
    var weeklyChangeGroup = [Double]()
    var monthlyChangeGroup = [Double]()
    var userInvestmentBalanceTotal: Double = 0
    var canToggleSegmentedControl: Bool = false
    
    let dispatchGroup = DispatchGroup()
    let dispatchGroup2 = DispatchGroup()
    
    struct TableView {
        struct CellIdentifiers {
            static let investmentCell = "InvestmentCell"
            static let noInvestmentsCell = "NoInvestmentsCell"
        }
    }
    
    struct StockPrice {
        var symbol: String = ""
        var price: Double = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataAndLabels), name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.getPersonalPercentageChanges), name: Notification.Name(rawValue: "BalanceComputationCompleted"), object: nil)
        
        updateDataAndLabels()
        userInvestmentBalanceLabel.text! = "Loading..."
        
        //tableView.reloadData()
        
        var cellNib = UINib(nibName: TableView.CellIdentifiers.investmentCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.investmentCell)
        cellNib = UINib(nibName: TableView.CellIdentifiers.noInvestmentsCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.noInvestmentsCell)
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        dispatchGroup.notify(queue: .main){
            self.tableView.reloadData()
            self.updateInvestmentLabel()
        }
    }
    
    @objc func updateDataAndLabels() {
        performDataFetch()
        performStockSymbolFetch()
        fetchPrices()
    }
    
    func performDataFetch(){
        let fetchRequest1 = NSFetchRequest<UserTotalBalance>()
        let fetchRequest2 = NSFetchRequest<UserTotalDepositedBalance>()
        let fetchRequest3 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest4 = NSFetchRequest<UserPortfolioState>()
        
        let entity1 = UserTotalBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserTotalDepositedBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserAvailableBalance.entity()
        fetchRequest3.entity = entity3
        let entity4 = UserPortfolioState.entity()
        fetchRequest4.entity = entity4
        
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]
        fetchRequest4.sortDescriptors = [sortDescriptor]
        
        do {
            userTotalBalances = try managedObjectContext.fetch(fetchRequest1)
            userTotalDepositBalances = try managedObjectContext.fetch(fetchRequest2)
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest3)
            userPortfolios = try managedObjectContext.fetch(fetchRequest4)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        if userAvailableBalances.count == 0 {
            self.userAvailableBalanceLabel.text! = "$0.00"
        }
        else{
            self.userAvailableBalanceLabel.text! = "$" + String(format: "%.2f", userAvailableBalances[0].availableBalance)
        }
        
        currentInvestments = []
        if userPortfolios.count != 0 {
            for stock in userPortfolios[0].stocks {
                let investment = Investment()
                investment.symbol = stock.symbol
                investment.shares = stock.quantity
                investment.percentageChange = "Loading..."
                currentInvestments.append(investment)
            }
        }
        
        tableView.reloadData()
    }
    
    func fetchPrices() {
        stockPriceObjects = []
        portfolioStockPrices = []
        for i in 0..<currentInvestments.count {
            getStockPrice(stockSymbol: currentInvestments[i].symbol, indexInCurrentInvestments: i)
        }
    }
    
    func finnhubURL() -> URL {
        let urlString = "https://finnhub.io/api/v1/stock/symbol?exchange=US&token=API_KEY"
        let url = URL(string: urlString)
        return url!
    }
    
    func parse(data: Data) -> [AvailableStock] {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode([AvailableStock].self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            return []
        }
    }
    
    func performStockSymbolFetch(){
        let url = finnhubURL()
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    self.availableStocks = self.parse(data: data)
                    self.availableStocks.sort(by: <)
                    self.stateController.availableStocks = self.availableStocks
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    func stockPriceURL(stockSymbol: String) -> URL {
        let urlStringFirstHalf = "https://finnhub.io/api/v1/quote?symbol="
        let stockSymbol = stockSymbol
        let urlStringSecondHalf = "&token=API_KEY"
        let fullURL = urlStringFirstHalf + stockSymbol + urlStringSecondHalf
        let url = URL(string: fullURL)
        return url!
    }
    
    func parseStockPrice(data: Data) -> StockPriceObj {
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
    
    func updateInvestmentLabel() {
        var userAvailableBalance: Double = 0
        if userAvailableBalances.count > 0 {
            userAvailableBalance = userAvailableBalances[0].availableBalance
        }
        var totalStockPrices: Double = 0
        for stock in currentInvestments {
            let thisStockShares = stock.shares
            for stockPriceObject in stockPriceObjects {
                if stockPriceObject.symbol == stock.symbol {
                    totalStockPrices = totalStockPrices + Double(stockPriceObject.price * Double(thisStockShares))
                    break
                }
            }
        }
        let userTotalInvestmentBalance = totalStockPrices + userAvailableBalance
        userInvestmentBalanceTotal = userTotalInvestmentBalance
        userInvestmentBalanceLabel.text! = "$" + String(format: "%.2f", userTotalInvestmentBalance)
        postBalanceFetchedNotification()
    }
    
    func getStockPrice(stockSymbol: String, indexInCurrentInvestments: Int){
        dispatchGroup.enter()
        let url = stockPriceURL(stockSymbol: stockSymbol)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let currentStockPrice = (self.parseStockPrice(data: data))
                    self.portfolioStockPrices.append(currentStockPrice)
                    let curPrice = currentStockPrice.currentPrice
                    let previousClose = currentStockPrice.previousClose
                    let dailyPriceChange = curPrice - previousClose
                    let dailyPercentageChange = (dailyPriceChange / previousClose) * 100
                    var percentageChangeString = String(format: "%.2f", dailyPercentageChange)
                    if dailyPercentageChange > 0 {
                        percentageChangeString = "+" + percentageChangeString
                    }
                    self.currentInvestments[indexInCurrentInvestments].percentageChange = percentageChangeString + "%"
                    self.currentInvestments[indexInCurrentInvestments].percentageChangeVal = dailyPercentageChange
                    let curStockPriceObject = StockPrice(symbol: stockSymbol, price: curPrice)
                    self.stockPriceObjects.append(curStockPriceObject)
                    self.dispatchGroup.leave()
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    func candlePriceURL(resolution: Int, stockSymbol: String) -> URL {
        var resolutionChar = "5"
        let curDateTimestamp = Int(Date().timeIntervalSince1970)
        var pastDateTimestamp = curDateTimestamp - 604800
        if resolution == 2 {
            resolutionChar = "30"
            pastDateTimestamp = curDateTimestamp - 2592000
        }
        // using same for day change as for week change due to API inconsistency
        else if resolution == 0 {
            resolutionChar = "5"
            pastDateTimestamp = curDateTimestamp - 604800
        }
        let urlStringSymbol = "https://finnhub.io/api/v1/stock/candle?symbol="
        let stockSymbol = stockSymbol
        let urlStringResolution = "&resolution="
        let urlStringFrom = "&from="
        let urlStringTo = "&to="
        let urlStringToken = "&token=API_KEY"
        let fullURL = urlStringSymbol + stockSymbol + urlStringResolution + resolutionChar + urlStringFrom + String(pastDateTimestamp) + urlStringTo + String(curDateTimestamp) + urlStringToken
        let url = URL(string: fullURL)
        return url!
    }
    
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
    
    @objc func getPersonalPercentageChanges() {
        dailyChangeGroup = []
        weeklyChangeGroup = []
        monthlyChangeGroup = []
        let oneDayToThePast = Int(Date().timeIntervalSince1970) - 86400
        let oneWeekToThePast = Int(Date().timeIntervalSince1970) - 604800
        let oneMonthToThePast = Int(Date().timeIntervalSince1970) - 2592000
        var oneDayAgoInvestments: [PortfolioStock] = []
        var oneWeekAgoInvestments: [PortfolioStock] = []
        var oneMonthAgoInvestments: [PortfolioStock] = []
        
        if userAvailableBalances.count > 0 {
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneDayToThePast {
                dailyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneDayToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneDayToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneDayToThePast {
                        dailyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
            
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneWeekToThePast {
                weeklyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneWeekToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneWeekToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneWeekToThePast {
                        weeklyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
            
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneMonthToThePast {
                monthlyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneMonthToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneMonthToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneMonthToThePast {
                        monthlyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
        }
        
        
        if userPortfolios.count > 0 {
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneDayToThePast {
                oneDayAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneDayToThePast {
                oneDayAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneDayToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneDayToThePast {
                        oneDayAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneWeekToThePast {
                oneWeekAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneWeekToThePast {
                oneWeekAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneWeekToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneWeekToThePast {
                        oneWeekAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneMonthToThePast {
                oneMonthAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneMonthToThePast {
                oneMonthAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneMonthToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneMonthToThePast {
                        oneMonthAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            

            for investment in oneDayAgoInvestments {
                getCandlePrice(resolution: 0, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
            
            for investment in oneWeekAgoInvestments {
                getCandlePrice(resolution: 1, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
            
            for investment in oneMonthAgoInvestments {
                getCandlePrice(resolution: 2, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
        }
        else {
            self.dailyChange = "0.00% ($0.00)"
            self.weeklyChange = "0.00% ($0.00)"
            self.monthlyChange = "0.00% ($0.00)"
        }
        var latestTotalDeposit: Double = 1
        if userTotalDepositBalances.count > 0 {
            latestTotalDeposit = userTotalDepositBalances[0].totalDepositedBalance
            let priceDifference = userInvestmentBalanceTotal - latestTotalDeposit
            let percentageDifference = (priceDifference / latestTotalDeposit) * 100
            if percentageDifference < 0 {
                self.allTimeChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.allTimeChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.allTimeChangeVal = percentageDifference
        }
        else {
            self.allTimeChange = "0.00% ($0.00)"
        }
        
        
        userInvestmentBalancePercentageChangeLabel.text! = dailyChange
        
        dispatchGroup2.notify(queue: .main) {
            self.finishUpdatingPercentageLabels()
        }
    }
    
    func finishUpdatingPercentageLabels() {
        
        var currentInvestmentSum: Double = 0
        if dailyChangeGroup.count > 0 {
            for price in dailyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.dailyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"

            }
            else {
                self.dailyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.dailyChangeVal = percentageDifference
        }
        else {
            self.dailyChange = "0.00% ($0.00)"
        }
        
        
        currentInvestmentSum = 0
        if weeklyChangeGroup.count > 0 {
            for price in weeklyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.weeklyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.weeklyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.weeklyChangeVal = percentageDifference
        }
        else {
            self.weeklyChange = "0.00% ($0.00)"
        }
        
        
        currentInvestmentSum = 0
        if monthlyChangeGroup.count > 0 {
            for price in monthlyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.monthlyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.monthlyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.monthlyChangeVal = percentageDifference
        }
        else {
            self.monthlyChange = "0.00% ($0.00)"
        }
        
        userInvestmentBalancePercentageChangeLabel.text! = dailyChange
        if dailyChangeVal < 0 {
            userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
        }
        canToggleSegmentedControl = true
    }
    
    func getCandlePrice(resolution: Int, stockSymbol: String, quantity: Int){
        dispatchGroup2.enter()
        let url = candlePriceURL(resolution: resolution, stockSymbol: stockSymbol)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let candle = self.parseCandle(data: data)
                    if candle.status != "no_data"{
                        if resolution == 2 {
                            self.monthlyChangeGroup.append(candle.openPrice * Double(quantity))
                        }
                        else if resolution == 1{
                            self.weeklyChangeGroup.append(candle.openPrice * Double(quantity))
                        }
                        else {
                            self.dailyChangeGroup.append(candle.specialOpenPrice * Double(quantity))
                        }
                        self.dispatchGroup2.leave()
                        return
                    }
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    func postBalanceFetchedNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "BalanceComputationCompleted"), object: nil)
    }
    
    
    @IBAction func priceChangeSegmentChanged(_ sender: UISegmentedControl) {
        if canToggleSegmentedControl {
            let segmentedControlValue = sender.selectedSegmentIndex
            if segmentedControlValue == 0 {
                userInvestmentBalancePercentageChangeLabel.text! = dailyChange
                if dailyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
            }
            else if segmentedControlValue == 1 {
                userInvestmentBalancePercentageChangeLabel.text! = weeklyChange
                if weeklyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
            }
            else if segmentedControlValue == 2 {
                userInvestmentBalancePercentageChangeLabel.text! = monthlyChange
                if monthlyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
            }
            else {
                userInvestmentBalancePercentageChangeLabel.text! = allTimeChange
                if allTimeChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DepositFunds" {
            let controller = segue.destination as! DepositFundsViewController
            controller.delegate = self
            controller.managedObjectContext = managedObjectContext
        }
        else if segue.identifier == "ViewIndividualStockFromPortfolio" {
            let controller = segue.destination as! IndividualStockViewController
            controller.managedObjectContext = managedObjectContext
            if selectedStock != nil {
                controller.stockObj = selectedStock
            }
        }
    }
}

extension InvestmentsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView (_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        if currentInvestments.count == 0 {
            return 1
        }
        else {
            return currentInvestments.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let emptyCell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.noInvestmentsCell, for: indexPath)
        if currentInvestments.count == 0 {
            return emptyCell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.investmentCell, for: indexPath) as! InvestmentCell
            let investment = currentInvestments[indexPath.row]
            cell.symbolLabel.text = investment.symbol
            cell.percentageChangeLabel.text = investment.percentageChange
            if investment.percentageChangeVal < 0 {
                cell.percentageChangeLabel.textColor = UIColor.red
            }
            cell.sharesLabel.text = String(investment.shares) + " shares"
            if investment.shares == 1 {
                cell.sharesLabel.text = String(1) + " share"
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if currentInvestments.count > 0 {
            let selectedInvestmentSymbol = currentInvestments[indexPath.row].symbol
            self.selectedStock = nil
            for stock in availableStocks {
                if stock.stockSymbol == selectedInvestmentSymbol {
                    self.selectedStock = stock
                    break
                }
            }
            tableView.deselectRow(at: indexPath, animated: false)
            if self.selectedStock != nil {
                self.performSegue(withIdentifier: "ViewIndividualStockFromPortfolio", sender: self)
            }
        }
        else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
 }

extension InvestmentsViewController: DepositFundsViewControllerDelegate {
    
    func transactionComplete(sender: DepositFundsViewController) {
        self.updateDataAndLabels()
        dispatchGroup.notify(queue: .main){
            self.tableView.reloadData()
            self.updateInvestmentLabel()
        }
    }
}

// delegate protocol tutorial https://useyourloaf.com/blog/quick-guide-to-swift-delegates/
