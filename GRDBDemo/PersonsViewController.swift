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
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .fade)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }
                    
                case .move(let indexPath, let newIndexPath, _):
                    // Actually move cells around for more demo effect :-)
                    let cell = self.tableView.cellForRow(at: indexPath)
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                }
            },
            recordsDidChange: { [unowned self] _ in
                self.tableView.endUpdates()
            })
        personsController.performFetch()
        
        navigationItem.leftBarButtonItem = editButtonItem
        
        configureToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}


// MARK: - Navigation

extension PersonsViewController : PersonEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPerson" {
            let person = personsController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PersonEditionViewController
            controller.title = person.name
            controller.person = person
            controller.delegate = self // we will save person when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPerson" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PersonEditionViewController
            controller.title = "New Person"
            controller.person = Person(name: "", score: 0)
        }
    }
    
    @IBAction func cancelPersonEdition(_ segue: UIStoryboardSegue) {
        // Person creation: cancel button was tapped
    }
    
    @IBAction func commitPersonEdition(_ segue: UIStoryboardSegue) {
        // Person creation: commit button was tapped
        let controller = segue.source as! PersonEditionViewController
        try! dbQueue.inDatabase { db in
            try controller.person.save(db)
        }
    }
    
    func personEditionControllerDidComplete(_ controller: PersonEditionViewController) {
        try! dbQueue.inDatabase { db in
            try controller.person.save(db)
        }
    }
}


// MARK: - UITableViewDataSource

extension PersonsViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let person = personsController.record(at: indexPath)
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = abs(person.score) > 1 ? "\(person.score) points" : "0 point"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return personsController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personsController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Person", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the person
        let person = personsController.record(at: indexPath)
        try! dbQueue.inDatabase { db in
            _ = try person.delete(db)
        }
    }
}


// MARK: - FetchedRecordsController Demo

extension PersonsViewController {
    
    fileprivate func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(title: "Name ⬆︎", style: .plain, target: self, action: #selector(PersonsViewController.sortByName)),
            UIBarButtonItem(title: "Score ⬇︎", style: .plain, target: self, action: #selector(PersonsViewController.sortByScore)),
            UIBarButtonItem(title: "Randomize", style: .plain, target: self, action: #selector(PersonsViewController.randomizeScores)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(PersonsViewController.stressTest))
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
            return .commit
        }
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        
        // Spawn some concurrent background jobs
        for _ in 0..<20 {
            DispatchQueue.global().async {
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
                    return .commit
                }
            }
        }
    }
}

private let personsSortedByName = Person.order(Column("name"))
private let personsSortedByScore = Person.order(Column("score").desc, Column("name"))



// MARK: Random

private let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]

private func randomName() -> String {
    return names[Int(arc4random_uniform(UInt32(names.count)))]
}

private func randomScore() -> Int {
    return 10 * Int(arc4random_uniform(101))
}

