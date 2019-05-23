//
//  ViewController.swift
//  GitHubCommitsCoreData
//
//  Created by Simon Italia on 5/16/19.
//  Copyright © 2019 Magical Tomato. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UITableViewController {
    
    //Predicates
    var commitPredicate: NSPredicate?
    
    //Property for making NSManagedContextObject.viewContext available to us
    var coreDataContainer: NSPersistentContainer!
    
    //Property to store Core Datat Commit Objects (individual github commits)
    var commits = [Commit]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //NavigatonBar configuration
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(changeFilter))
        
        
        //A. Setup CoreData
        //A1. Creates persistent container
        coreDataContainer = NSPersistentContainer(name: "GitHubCommits")
        
        //A1.1 Load saved database if it exists, if not create it, or return error if something is wrong
        coreDataContainer.loadPersistentStores {
            storeDescription, error in
            self.coreDataContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            if let error = error {
                print("Unresolved error \(error)")
            }
        }
        
        //Trigger fetch of github commits in background with built in selector method
        performSelector(inBackground: #selector(fetchCommits), with: nil)
        
        //Load any saved Core Data commit objects
        loadSavedCoreData()
    }
    
    //A2. Method to read / write Core Data object from / to disk
    func saveCoreDataObjectContext() {
        
        //First check for database changes before saving
        if coreDataContainer.viewContext.hasChanges {
            do {
                try coreDataContainer.viewContext.save()
            
            } catch {
                print("An error occurred when trying to save CoreData object: \(error)")
            }
        }
    }
    
    @objc func fetchCommits() {
        
        //
        let newestCommitDate = getNewestCommitDate()
        
        //Try downlaoding JSON data from github url and create string object
        if let data = try? String(contentsOf: URL(string: "https://api.github.com/repos/apple/swift/commits?per_page=100&since=\(newestCommitDate)")!) {
            
            //Pass feteched json string data object to swiftyJSON to parse and create json objects
            let jsonData = JSON(parseJSON: data)
        
            //Create json array object with json commit objects
            let jsonCommits = jsonData.arrayValue
        
            //Print conformation of new commits fetched
            print("Fetched \(jsonCommits.count) new commits.")
            
            //On main thread, iterate through jsonCommits array object
            DispatchQueue.main.async { [unowned self] in
                for jsonCommit in jsonCommits {
                    
                    //Create commit object inside Core Data NSManagedObjectContext object
                    let commit = Commit(context: self.coreDataContainer.viewContext)
                    self.configure(commit: commit, usingJSON: jsonCommit)
                }
                
                //Save NSManagedContext object to Core Data SQL Database
                self.saveCoreDataObjectContext()
                
                //Display the Core Data objects to screen
                self.loadSavedCoreData()
                
            }
        }
    }//End fetchCommits() method
    
    //A3. Method to convert fetched jsonCommits into Core Data objects
    func configure(commit: Commit, usingJSON json: JSON) {
        
        commit.sha = json["sha"].stringValue
        commit.message = json["commit"] ["message"].stringValue
        commit.url = json ["html_url"].stringValue
        
        //Convert ISO date to Date object format. Create new Date object if any part of the json is missing, broken or not a string
        let dateFormatter = ISO8601DateFormatter()
        commit.date = dateFormatter.date(from: json["commit"] ["committer"] ["date"].stringValue) ?? Date()
        //date(from: ) converst a string to Date format
        
        //Attach Authors Core Data object to Commit object
        //Author property object
        var commitAuthor: Author!

        //Check Author exists
        let authorRequest = Author.createFetchRequest()
        authorRequest.predicate = NSPredicate(format: "name == %@", json["commit"]["committer"]["name"].stringValue)

        if let authors = try? coreDataContainer.viewContext.fetch(authorRequest) {
            if authors.isEmpty == false {
                //This Author is saved already
                commitAuthor = authors[0]
            
            } else {
                print("commitAuthor is nil")
            }
        }
        
        if commitAuthor == nil {
            //Author not saved, create new Author
            let author = Author(context: coreDataContainer.viewContext)
            author.name = json["commit"]["committer"]["name"].stringValue
            author.email = json["commit"]["committer"]["email"].stringValue
            commitAuthor = author
        }
        
        //Use Author, either from saved, or newly created
        commit.author = commitAuthor
        
    }//End configure() method
    
    //A4. Populate commits array property with commit objects with NSFetchRequest, and sort objects inside array
    func loadSavedCoreData() {
        let request = Commit.createFetchRequest()
        let sort = NSSortDescriptor(key: "date", ascending: false)
        request.sortDescriptors = [sort]
        
        //Predicate
        request.predicate = commitPredicate
        
        do {
            commits = try coreDataContainer.viewContext.fetch(request)
            print("Loaded \(commits.count) commits.")
            tableView.reloadData()
            
        } catch {
            print("Fetch failed with error: \(error)")
        }
    }
    
    //Allow user to filter Core Data objects
    @objc func changeFilter() {
        let ac = UIAlertController(title: "Filter commits...", message: nil, preferredStyle: .actionSheet)
        
        //1 CONTAINS keyword, and [c] ignore case syntax (Match commit objects that conatain string
        ac.addAction(UIAlertAction(title: "Show only fixes", style: .default) {
            [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "message CONTAINS[c] 'fix'")
            self.loadSavedCoreData()
        })
        
        //2 NOT and BEGINSWITH keywords (Match commit objects that don't begin with string)
        ac.addAction(UIAlertAction(title: "Ignore Pull requests", style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "NOT message BEGINSWITH 'Merge pull request'")
            self.loadSavedCoreData()
        })
        
        //3 Match commit objects where date = within last 12 hours (43,200 secs)
        ac.addAction(UIAlertAction(title: "Show only recent", style: .default) { [unowned self] _ in
            let twelveHoursAgo = Date().addingTimeInterval(-43200)
            self.commitPredicate = NSPredicate(format: "date > %@", twelveHoursAgo as NSDate)
            self.loadSavedCoreData()
        })

        //Show commit objects by author Durian only
        ac.addAction(UIAlertAction(title: "Show only Durian commits", style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "author.name == 'Joe Groff'")
            self.loadSavedCoreData()
        })
        
        //4 Show all commit objects, no filter applied
        ac.addAction(UIAlertAction(title: "Show all commits", style: .default) { [unowned self] _ in
            self.commitPredicate = nil
            self.loadSavedCoreData()
        })
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func getNewestCommitDate() -> String {
        let formatter = ISO8601DateFormatter()
        
        let newestCommits = Commit.createFetchRequest()
        let sort = NSSortDescriptor(key: "date", ascending: false)
        newestCommits.sortDescriptors = [sort]
        newestCommits.fetchLimit = 1
        
        if let commits = try? coreDataContainer.viewContext.fetch(newestCommits) {
            if commits.count > 0 {
                return formatter.string(from: commits[0].date.addingTimeInterval(1))
                    //add 1 second to prev commit, so we fetch the next commti, not the same commit
            }
        }
        
        return formatter.string(from: Date(timeIntervalSince1970: 0))
        //string(from: ) method is inverse of date(from: ) method.
    }
    
    //MARK: - Table data population methods
    
    //Set number of table sections
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    //Set number of table rows in section
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commits.count
    }
    
    //Configure cell object to display data in table rows
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommitCell", for: indexPath)
        
        let commit = commits[indexPath.row]
        cell.textLabel!.text = commit.message
        cell.detailTextLabel!.text = "By: \(commit.author.name) on \(commit.date.description)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let vc = storyboard?.instantiateViewController(withIdentifier: "DetailVC") as? DetailViewController {
            vc.detailItem = commits[indexPath.row]
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    //Utilize TableView's swipe to delete and NSManagedObjectContext's delete() method to delete Core Data Objects
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            //Delete commit from commit array and TableView
            let commit = commits[indexPath.row]
            commits.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            //Delete from CoreData NSManagedObjectContext
            coreDataContainer.viewContext.delete(commit)
            
            //Update CoreData database
            saveCoreDataObjectContext()
            
            print("Commit Objects: \(commits.count)")
        }
    }
}
