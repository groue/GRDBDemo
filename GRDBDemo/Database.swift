import GRDB
import UIKit

// The shared database queue.
var dbQueue: DatabaseQueue!

func setupDatabase(_ application: UIApplication) throws {
    
    // Connect to the database
    // See https://github.com/groue/GRDB.swift/#database-connections
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
    let databasePath = documentsPath.appendingPathComponent("db.sqlite")
    dbQueue = try DatabaseQueue(path: databasePath)
    
    
    // Be a nice iOS citizen, and don't consume too much memory
    // See https://github.com/groue/GRDB.swift/#memory-management
    
    dbQueue.setupMemoryManagement(in: application)
    
    
    // Use DatabaseMigrator to setup the database
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("CreatePersonsTable") { db in
        // Compare person names in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/#unicode
        try db.create(table: "persons") { t in
            t.column("id", .integer).primaryKey()
            t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
            t.column("score", .integer).notNull()
        }
    }
    
    migrator.registerMigration("InitialPersons") { db in
        try Person(name: "Arthur", score: 250).insert(db)
        try Person(name: "Barbara", score: 750).insert(db)
        try Person(name: "Craig", score: 500).insert(db)
    }
    
    try migrator.migrate(dbQueue)
}
