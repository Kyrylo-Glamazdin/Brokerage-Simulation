//
//  SearchStocksViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/7/20.
//

import UIKit
import CoreData

//This class creates an infrastructure to search the stocks that are supported by the finnhub.io API
class SearchStocksViewController: UIViewController {
    //outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    //state controller used for the communication with InvestmentsViewController (on a different tab)
    var stateController: StateController!
    
    //an array of type AvailableStock that would be the source for displaying search results in the tableView
    var stockSearchResults: [AvailableStock] = []
    
    var segmentedControlValue: Int = 0
    var searchBarInput: String = ""
    
    //stock that has been selected by the user and will be passed to IndividualStockViewController
    var selectedStock: AvailableStock?
    //managedObjectContext will not be used in this ViewController but would be passed down to IndividualStockViewController
    var managedObjectContext: NSManagedObjectContext!

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        afterDelay(0.6){
            self.searchBar.becomeFirstResponder()
        }
        
        let cellNib = UINib(nibName: "NoResultsCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NoResultsCell")
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    //the selected segment on SegmentedControl will determine whether the search will be conducted by stock symbol (0) or company name (1)
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        segmentedControlValue = sender.selectedSegmentIndex
        if searchBarInput.count > 0 {
            performLocalStockSearch()
        }
    }
    
    //performs stock search based on the user search input using substrings
    //due to the absence of an API endpoint that would allow to query the stocks, the stocks are queried locally after downloading the supporting data in InvestmentsViewController and passed through the StateController
    func performLocalStockSearch(){
        stockSearchResults = []
        if searchBarInput.count == 0 {
        }
        else {
            //search by company name
            if segmentedControlValue == 1 {
                for stock in stateController.availableStocks {
                    if stock.stockDescription.index(of: searchBarInput) != nil {
                        stockSearchResults.append(stock)
                    }
                }
            }
            //search by stock symbol
            else {
                for stock in stateController.availableStocks {
                    if stock.stockSymbol.index(of: searchBarInput) != nil && stock.stockDescription.count > 0 {
                        stockSearchResults.append(stock)
                    }
                }
                self.stockSearchResults.sort(by: symbolSizeSort)

            }
        }
        tableView.reloadData()
    }
    
}

//MARK: - TableView and SearchBar delegate methods, segue-related functions

extension SearchStocksViewController: UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    func tableView (_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        if (stockSearchResults.isEmpty){
            //if there are no search results but the search bar isn't empty, return 1 to show the "No Results" cell
            if searchBarInput.count > 0 {
                return 1
            }
            //else search bar is empty so show nothing
            else {
                return 0
            }
        }
        //return the number of results that satisfy the search
        else {
            return stockSearchResults.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let emptyCell = tableView.dequeueReusableCell(withIdentifier: "NoResultsCell", for: indexPath)
        //if there are no search results, return "No Results" cell
        if stockSearchResults.isEmpty {
            return emptyCell
        }
        
        let cellIdentifier = "StockSearchResultCell"
        
        //show stock info on each table cell
        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        }

        let stock = stockSearchResults[indexPath.row]
        cell.textLabel!.text = stock.stockDescription
        cell.detailTextLabel!.text = stock.stockSymbol
        return cell
    }
    
    //perform a segue to IndividualStockViewController when the user selects a row that isn't a "No Results" cell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if stockSearchResults.count > 0 {
            self.selectedStock = stockSearchResults[indexPath.row]
            tableView.deselectRow(at: indexPath, animated: false)
            self.performSegue(withIdentifier: "ViewIndividualStock", sender: self)
        }
        else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    //perform a stock search when user input changes
    func searchBar(_ searchBar: UISearchBar, textDidChange: String){
        searchBarInput = searchBar.text!.uppercased() //uppercased to match API results
        performLocalStockSearch()
    }
    
    //passes the relevant segue info to IndividualStockViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let individualStockViewController = segue.destination as! IndividualStockViewController
        individualStockViewController.managedObjectContext = managedObjectContext
        if selectedStock != nil {
            individualStockViewController.stockObj = selectedStock
        }
    }
    
 }


//string protocol that allows to use substrings (reference in Source_Citations.txt)
extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
