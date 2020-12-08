//
//  SellStockViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/15/20.
//

import Foundation
import UIKit
import CoreData
import AVFoundation

//This class is responsible for processing the transactions that simulate selling stocks and adding them to user's portfolio.
//@precondition: this view controller is only accessible if the user has shares of this stock in their portfolio
class SellStockViewController: UIViewController {
    
    //outlets
    @IBOutlet weak var sellSharesLabel: UILabel!
    @IBOutlet weak var marketPriceLabel: UILabel!
    @IBOutlet weak var userSharesLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    
    var managedObjectContext: NSManagedObjectContext!
    var stockObj: AvailableStock!
    var currentStockPrice: StockPriceObj?
    
    //vars for local database fetches
    var userAvailableBalances = [UserAvailableBalance]()
    var userInvestmentBalances = [UserInvestmentBalance]()
    var userPortfolios = [UserPortfolioState]()
    
    var numOfSharesInPortfolio: Int = 0
    //audio player to play the transaction completion sound
    var audioPlayer = AVAudioPlayer()
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sellSharesLabel.text! = "Sell " + stockObj.stockSymbol
        if currentStockPrice != nil{
            marketPriceLabel.text! = "Market price: $" + String(currentStockPrice!.currentPrice)
        }
        else {
            marketPriceLabel.text! = "Market price: $0.00"
        }

        //load sound into audio player
        let sound = Bundle.main.path(forResource: "CompleteSound", ofType: "caf")
        do {
            if sound != nil {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
            }
        }
        catch {
            print(error)
        }
        
        getPersonalFundsData()
        afterDelay(0.6) {
            self.textField.becomeFirstResponder()
        }
    }

    //fetch personal balance and portfolio data from local database
    func getPersonalFundsData() {
        //create requests
        let fetchRequest1 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest2 = NSFetchRequest<UserInvestmentBalance>()
        let fetchRequest3 = NSFetchRequest<UserPortfolioState>()

        let entity1 = UserAvailableBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserInvestmentBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserPortfolioState.entity()
        fetchRequest3.entity = entity3

        //sort by date from newest to oldest
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]

        //fetch data
        do {
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest1)
            userInvestmentBalances = try managedObjectContext.fetch(fetchRequest2)
            userPortfolios = try managedObjectContext.fetch(fetchRequest3)
        }
        catch {
            fatalError("Error: \(error)")
        }

        let latestPortfolio = userPortfolios[0].stocks
        for stock in latestPortfolio {
            if stock.symbol == stockObj.stockSymbol {
                userSharesLabel.text! = "You own " + String(stock.quantity) + " shares of " + stock.symbol
                numOfSharesInPortfolio = stock.quantity
                break
            }
        }

    }
    
    //MARK: - Validate and process transaction
    
    
    @IBAction func placeOrder(_ sender: Any) {
        if let enteredSharesAmount = Double(textField.text!) {
            if enteredSharesAmount == 0 || enteredSharesAmount > Double(numOfSharesInPortfolio){
                errorLabel.text! = "Enter a valid amount of shares"
                afterDelay(5) {
                    self.errorLabel.text! = ""
                }
                return
            }
            if currentStockPrice != nil {
                //process the transaction if number of entered shares is valid
                completeTransaction()
            }
            else {
                //this indicates an API issue, most likely exceeding API call limit. Try again in a minute
                errorLabel.text! = "Price error: Could not place your order"
                afterDelay(5) {
                    self.errorLabel.text! = ""
                }
            }
        }
        else {
            errorLabel.text! = "Enter a valid amount of shares"
            afterDelay(5) {
                self.errorLabel.text! = ""
            }
        }
    }
    
    //process the transaction
    //@precondition: the number of entered shares is less than or equal to the number of shares in user's portfolio
    //@precondition: user's portfolio is not empty
    func completeTransaction() {
        let date = Date()
        let enteredSharesAmount = Double(textField.text!)

        let latestUserPortfolio = userPortfolios[0]
        let availableBalance = UserAvailableBalance(context: managedObjectContext)
        let investmentBalance = UserInvestmentBalance(context: managedObjectContext)
        let userPortfolio = UserPortfolioState(context: managedObjectContext)

        for stock in latestUserPortfolio.stocks {
            if stock.symbol == stockObj.symbol {
                //do not add this stock into user's portfolio if user attempts to sell all shares of this stock
                if Int(enteredSharesAmount!) == stock.quantity {
                    continue
                }
                else {
                    //if the entered shares amount is less than the total amount of shares of this stock, subtract the entered amount from the total amount of shares.
                    let existingStock = stock
                    existingStock.quantity = existingStock.quantity - Int(enteredSharesAmount!)
                    //append the updated stock object
                    userPortfolio.stocks.append(existingStock)
                }
            }
            else {
                //add all other shares to user's portfolio
                userPortfolio.stocks.append(stock)
            }
        }
        let totalTransactionCost = currentStockPrice!.currentPrice * enteredSharesAmount!
        availableBalance.availableBalance = userAvailableBalances[0].availableBalance + totalTransactionCost
        investmentBalance.investmentBalance = userInvestmentBalances[0].investmentBalance - totalTransactionCost

        if userPortfolio.stocks.count == 0 {
            userPortfolio.stocks = []
        }
        userPortfolio.date = date
        availableBalance.date = date
        investmentBalance.date = date

        //save the portfolio, show the animation, and play transaction completion sound
        do {
            try managedObjectContext.save()
            postCompletionNotification()
            self.textField.resignFirstResponder()
            let hudView = HudView.hud(inView: view, animated: true)
            hudView.text = "Done"
            audioPlayer.play()
            afterDelay(0.6){
                hudView.hide()
                self.dismiss(animated: true, completion: nil)
            }
        }
        catch {
            fatalError("Error: \(error)")
        }
    }
    
    //when the entered amount of shares changes, modify the label showing the total transaction profit
    @IBAction func enteredNumberOfSharesDidChange(_ sender: Any) {
        if let enteredSharesAmount = Double(textField.text!) {
            let newTransactionPrice = enteredSharesAmount * (currentStockPrice?.currentPrice ?? 0)
           totalLabel.text! = "$" + String(format: "%.2f", newTransactionPrice)
        }
        else {
            totalLabel.text! = "$0.00"
        }
    }
    
    
    @IBAction func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    //issue a notification indicating that the portfolio has been updated and other controllers must re-fetch data
    func postCompletionNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
    }
}
