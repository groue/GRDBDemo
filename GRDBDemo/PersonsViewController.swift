import UIKit
import GRDB

class PersonsViewController: UITableViewController {
    var personsController: FetchedRecordsController<Person>!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let request = personsSortedByScore
        personsController = FetchedRecordsController(dbQueue, request: request, compareRecordsByPrimaryKey: true)
        personsController.trackChanges(
            recordsWillChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            tableViewEvent: { [unowned self] (controller, record, event) in
                switch event {
                case .Insertion(let indexPath):
                    self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                    
                case .Deletion(let indexPath):
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                    
                case .Update(let indexPath, _):
                    if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                        self.configureCell(cell, atIndexPath: indexPath)
                    }
                    
                case .Move(let indexPath, let newIndexPath, _):
                    // Actually move cells around for more demo effect :-)
                    let cell = self.tableView.cellForRowAtIndexPath(indexPath)
                    self.tableView.moveRowAtIndexPath(indexPath, toIndexPath: newIndexPath)
                    if let cell = cell {
                        self.configureCell(cell, atIndexPath: newIndexPath)
                    }
                    
                    // A quieter animation:
                    // self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                    // self.tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
                }
            },
            recordsDidChange: { [unowned self] _ in
                self.tableView.endUpdates()
            })
        personsController.performFetch()
        
        navigationItem.leftBarButtonItem = editButtonItem()
        
        configureToolbar()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.toolbarHidden = false
    }
}


// MARK: - Navigation

extension PersonsViewController : PersonEditionViewControllerDelegate {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "EditPerson" {
            let person = personsController.recordAtIndexPath(tableView.indexPathForSelectedRow!)
            let controller = segue.destinationViewController as! PersonEditionViewController
            controller.title = person.name
            controller.person = person
            controller.delegate = self // we will save person when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPerson" {
            setEditing(false, animated: true)
            let navigationController = segue.destinationViewController as! UINavigationController
            let controller = navigationController.viewControllers.first as! PersonEditionViewController
            controller.title = "New Person"
            controller.person = Person(name: "", score: 0)
        }
    }
    
    @IBAction func cancelPersonEdition(segue: UIStoryboardSegue) {
        // Person creation: cancel button was tapped
    }
    
    @IBAction func commitPersonEdition(segue: UIStoryboardSegue) {
        // Person creation: commit button was tapped
        let controller = segue.sourceViewController as! PersonEditionViewController
        controller.applyChanges()
        if !controller.person.name.isEmpty {
            try! dbQueue.inDatabase { db in
                try controller.person.save(db)
            }
        }
    }
    
    func personEditionControllerDidComplete(controller: PersonEditionViewController) {
        // Person edition: back button was tapped
        controller.applyChanges()
        if !controller.person.name.isEmpty {
            try! dbQueue.inDatabase { db in
                try controller.person.save(db)
            }
        }
    }
}


// MARK: - UITableViewDataSource

extension PersonsViewController {
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let person = personsController.recordAtIndexPath(indexPath)
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = abs(person.score) > 1 ? "\(person.score) points" : "0 point"
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return personsController.sections.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personsController.sections[section].numberOfRecords
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Person", forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Delete the person
        let person = personsController.recordAtIndexPath(indexPath)
        try! dbQueue.inDatabase { db in
            try person.delete(db)
        }
    }
}


// MARK: - FetchedRecordsController Demo

extension PersonsViewController {
    
    private func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(title: "Name ⬆︎", style: .Plain, target: self, action: #selector(PersonsViewController.sortByName)),
            UIBarButtonItem(title: "Score ⬇︎", style: .Plain, target: self, action: #selector(PersonsViewController.sortByScore)),
            UIBarButtonItem(title: "Randomize", style: .Plain, target: self, action: #selector(PersonsViewController.randomizeScores)),
            UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .Plain, target: self, action: #selector(PersonsViewController.stressTest))
        ]
    }
    
    @IBAction func sortByName() {
        setEditing(false, animated: true)
        personsController.setRequest(personsSortedByName)
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        personsController.setRequest(personsSortedByScore)
    }
    
    @IBAction func randomizeScores() {
        setEditing(false, animated: true)
        
        try! dbQueue.inTransaction { db in
            for person in Person.fetch(db) {
                person.score = randomScore()
                try person.update(db)
            }
            return .Commit
        }
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        
        // Spawn some concurrent background jobs
        for _ in 0..<20 {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                try! dbQueue.inTransaction { db in
                    if Person.fetchCount(db) == 0 {
                        // Insert persons
                        for _ in 0..<8 {
                            try Person(name: randomName(), score: randomScore()).insert(db)
                        }
                    } else {
                        // Insert a person
                        if arc4random_uniform(2) == 0 {
                            let person = Person(name: randomName(), score: randomScore())
                            try person.insert(db)
                        }
                        // Delete a person
                        if arc4random_uniform(2) == 0 {
                            if let person = Person.order(sql: "RANDOM()").fetchOne(db) {
                                try person.delete(db)
                            }
                        }
                        // Update some persons
                        for person in Person.fetchAll(db) {
                            if arc4random_uniform(2) == 0 {
                                person.score = randomScore()
                                try person.update(db)
                            }
                        }
                    }
                    return .Commit
                }
            }
        }
    }
}

private let personsSortedByName = Person.order(SQLColumn("name"))
private let personsSortedByScore = Person.order(SQLColumn("score").desc, SQLColumn("name"))



// MARK: Random

private let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]

private func randomName() -> String {
    return names[Int(arc4random_uniform(UInt32(names.count)))]
}

private func randomScore() -> Int {
    return 10 * Int(arc4random_uniform(101))
}

