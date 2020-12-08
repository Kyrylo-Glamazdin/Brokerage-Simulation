//
//  DepositFundsViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/3/20.
//

import CoreData
import UIKit
import AVFoundation

//the function from this protocol has to be inplemented by InvestmentsViewController to update its data after the successful transaction
protocol DepositFundsViewControllerDelegate: class {
    func transactionComplete(sender: DepositFundsViewController)
}

//This is the ViewController which processes new deposits made by the user
class DepositFundsViewController: UIViewController {
    
    //outlets
    @IBOutlet weak var depositAmountTextField: UITextField!
    @IBOutlet weak var errorDepositText: UILabel!
    
    var managedObjectContext: NSManagedObjectContext!
    
    //different types of user balances that are fetched from the local database
    var userTotalBalances = [UserTotalBalance]()
    var userTotalDepositBalances = [UserTotalDepositedBalance]()
    var userAvailableBalances = [UserAvailableBalance]()
    
    var amountAdded: ((_ item: Double) -> Void)?
    
    //audio player to play the sound upon transaction completion
    var audioPlayer = AVAudioPlayer()
    weak var delegate: DepositFundsViewControllerDelegate?
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //load the sound into the audio player
        let sound = Bundle.main.path(forResource: "CompleteSound", ofType: "caf")
        do {
            if sound != nil {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
            }
        }
        catch {
            print(error)
        }
        
        //get fetch requests to fetch the data from the database
        let fetchRequest1 = NSFetchRequest<UserTotalBalance>()
        let fetchRequest2 = NSFetchRequest<UserTotalDepositedBalance>()
        let fetchRequest3 = NSFetchRequest<UserAvailableBalance>()
        
        let entity1 = UserTotalBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserTotalDepositedBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserAvailableBalance.entity()
        fetchRequest3.entity = entity3
        
        //sort by date from newest to oldest
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]
        
        //fetch data from the database
        do {
            userTotalBalances = try managedObjectContext.fetch(fetchRequest1)
            userTotalDepositBalances = try managedObjectContext.fetch(fetchRequest2)
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest3)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        afterDelay(0.6){
            self.depositAmountTextField.becomeFirstResponder()
        }
    }
    
    //MARK: - Action Methods
    
    //close this view controller and return to InvestmentsViewController
    @IBAction func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    //this function read the amount that was entered by the user and adds this amount to their available balance
    @IBAction func processDeposit() {
        let date = Date()
        if let enteredAmount = Double(depositAmountTextField.text!) {
            errorDepositText.text! = ""
            
            let userAvailableBalance = UserAvailableBalance(context: managedObjectContext)
            let userTotalDepositedBalance = UserTotalDepositedBalance(context: managedObjectContext)
            let userTotalBalance = UserTotalBalance(context: managedObjectContext)
            
            //check if there are any previous balances.
            //if the user already has some available balance, add the entered amount the their current balance
            if userAvailableBalances.count == 0 {
                userAvailableBalance.availableBalance = enteredAmount
            }
            else {
                userAvailableBalance.availableBalance = userAvailableBalances[0].availableBalance + enteredAmount

            }
            if userTotalDepositBalances.count == 0 {
                userTotalDepositedBalance.totalDepositedBalance = enteredAmount

            }
            else{
                userTotalDepositedBalance.totalDepositedBalance = userTotalDepositBalances[0].totalDepositedBalance + enteredAmount

            }
            if userTotalBalances.count == 0 {
                userTotalBalance.totalBalance = enteredAmount

            }
            else {
                userTotalBalance.totalBalance = userTotalBalances[0].totalBalance + enteredAmount

            }
            
            //add the date to it (used in personal portfolio net worth percentage change computation)
            userAvailableBalance.date = date
            userTotalDepositedBalance.date = date
            userTotalBalance.date = date
            
            //save the new amount into the database, display the animation, and play the completion sound
            do {
                try managedObjectContext.save()
                amountAdded?(enteredAmount)
                let hudView = HudView.hud(inView: view, animated: true)
                hudView.text = "Done"
                audioPlayer.play()
                delegate?.transactionComplete(sender: self)
                afterDelay(0.6){
                    hudView.hide()
                    self.dismiss(animated: true, completion: nil)
                }
            }
            catch {
                fatalError("Error: \(error)")
            }
        }
        else {
            //display an error if the entered amount is invalid. do not process the transaction
            errorDepositText.text! = "Please enter a valid amount"
        }
    }
}
