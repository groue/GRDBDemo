import GRDB

class Person: Record {
    var id: Int64?
    var name: String
    var score: Int
    
    init(name: String, score: Int) {
        self.name = name
        self.score = score
        super.init()
    }
    
    // MARK: Record overrides
    
    /// The table name
    override class var databaseTableName: String {
        return "persons"
    }
    
    /// Initialize from a database row
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        score = row.value(named: "score")
        super.init(row: row)
    }
    
    /// The values persisted in the database
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["score"] = score
    }
    
    /// Update person id after successful insertion
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
