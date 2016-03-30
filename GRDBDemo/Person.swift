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
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    /// Initialize from a database row
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        score = row.value(named: "score")
        super.init(row)
    }
    
    /// The values persisted in the database
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "score": score]
    }
    
    /// Update person id after successful insertion
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}
