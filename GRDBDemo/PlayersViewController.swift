import UIKit
import GRDB

class PlayersViewController: UITableViewController {
    var playersController: FetchedRecordsController<Player>!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let request = playersSortedByScore
        playersController = try! FetchedRecordsController(dbQueue, request: request)
        playersController.trackChanges(
            willChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            onChange: { [unowned self] (controller, record, change) in
                switch change {
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
            didChange: { [unowned self] _ in
                self.tableView.endUpdates()
            })
        try! playersController.performFetch()
        
        navigationItem.leftBarButtonItem = editButtonItem
        
        configureToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}


// MARK: - Navigation

extension PlayersViewController : PlayerEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Edit" {
            let player = playersController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PlayerEditionViewController
            controller.title = player.name
            controller.player = player
            controller.delegate = self // we will save player when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "New" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PlayerEditionViewController
            controller.title = "New Player"
            controller.player = Player(id: nil, name: "", score: 0)
        }
    }
    
    @IBAction func cancelEdition(_ segue: UIStoryboardSegue) {
        // Player creation: cancel button was tapped
    }
    
    @IBAction func commitEdition(_ segue: UIStoryboardSegue) {
        // Player creation: commit button was tapped
        let controller = segue.source as! PlayerEditionViewController
        try! dbQueue.inDatabase { db in
            try controller.player.save(db)
        }
    }
    
    func playerEditionControllerDidComplete(_ controller: PlayerEditionViewController) {
        try! dbQueue.inDatabase { db in
            try controller.player.save(db)
        }
    }
}


// MARK: - UITableViewDataSource

extension PlayersViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = playersController.record(at: indexPath)
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return playersController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playersController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = playersController.record(at: indexPath)
        try! dbQueue.inDatabase { db in
            _ = try player.delete(db)
        }
    }
}


// MARK: - FetchedRecordsController Demo

extension PlayersViewController {
    
    fileprivate func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(title: "Name ⬆︎", style: .plain, target: self, action: #selector(PlayersViewController.sortByName)),
            UIBarButtonItem(title: "Score ⬇︎", style: .plain, target: self, action: #selector(PlayersViewController.sortByScore)),
            UIBarButtonItem(title: "Randomize", style: .plain, target: self, action: #selector(PlayersViewController.randomizeScores)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(PlayersViewController.stressTest))
        ]
    }
    
    @IBAction func sortByName() {
        setEditing(false, animated: true)
        try! playersController.setRequest(playersSortedByName)
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        try! playersController.setRequest(playersSortedByScore)
    }
    
    @IBAction func randomizeScores() {
        setEditing(false, animated: true)
        
        try! dbQueue.inTransaction { db in
            for player in try Player.fetchAll(db) {
                var player = player
                player.score = Player.randomScore()
                try player.update(db)
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
                    if try Player.fetchCount(db) == 0 {
                        // Insert players
                        for _ in 0..<8 {
                            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                            try player.insert(db)
                        }
                    } else {
                        // Insert a player
                        if arc4random_uniform(2) == 0 {
                            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                            try player.insert(db)
                        }
                        // Delete a player
                        if arc4random_uniform(2) == 0 {
                            try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                        }
                        // Update some players
                        for player in try Player.fetchAll(db) {
                            if arc4random_uniform(2) == 0 {
                                var player = player
                                player.score = Player.randomScore()
                                try player.update(db)
                            }
                        }
                    }
                    return .commit
                }
            }
        }
    }
}

private let playersSortedByName = Player.order(Column("name"))
private let playersSortedByScore = Player.order(Column("score").desc, Column("name"))
