# Writing a Swift iOS app with GRDB and FetchedRecordsController

This repository contains an iOS application that uses the SQLite library [GRDB.swift](http://github.com/groue/GRDB.swift).

It displays a simple Hall of Fame of people sorted by score, and demonstrates how the [FetchedRecordsController](http://github.com/groue/GRDB.swift#fetchedrecordscontroller) class can populate a table view, and automatically update its contents when the database is modified.

<p align="center">
    <img src="https://raw.githubusercontent.com/groue/GRDBDemo/master/ScreenShot.png" alt="Screen Shot">
</p>

To run this app:

1. Clone the repository
2. Install CocoaPods if not done yet, via the Terminal application:
    
    ```
    sudo gem install cocoapods
    ```

3. Go into the repository, and run the Terminal command:

    ```
    cd groue/GRDBDemo
    pod install
    ```

4. Open GRDBDemo.xcworkspace
5. Click the Run button

The main app files are:

- [AppDelegate.swift](GRDBDemo/AppDelegate.swift)
    
    The app delegate opens the connection to the database, and applies the best practices of memory management

- [Database.swift](GRDBDemo/Database.swift)
    
    Create the database file, and perform database setup: creating tables, and filling initial values.

- [Person.swift](GRDBDemo/Person.swift)

    Person is a subclass of the GRDB [Record class](http://github.com/groue/GRDB.swift#records), that provides fetching et persistence methods to your custom types.

- [PersonEditionViewController.swift](GRDBDemo/PersonEditionViewController.swift)

    A simple view controller that edits a person.

- [PersonsViewController.swift](GRDBDemo/PersonsViewController.swift)

    A view controller that manages its table view through a [FetchedRecordsController](http://github.com/groue/GRDB.swift#fetchedrecordscontroller). It displays a few buttons at the bottom of the screeen that perform various transformations to the database in order to demonstrate the automatic table view updates given by the fetched records controller.
    
    The :bomb: button spawns many concurrent threads that update the database, in order to stress test SQLite, GRDB, the fetched records controller, and UITableView.

<p align="center"><strong>Happy GRDB!</strong></p>
