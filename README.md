# Tunes

This is a simple demo app for [Couchbase Lite](https://github.com/couchbase/couchbase-lite-ios). It presents a window with a simple three-column browser showing the user's iTunes music library. The left column lists artists; the middle column shows albums by the selected artist; and the right column shows the tracks of the selected album. Below each column is the total time of the music it contains.

The interesting things demonstrated here are:

1. Bulk-importing data into a database
2. Using query grouping to "drill down" into nested data sets
3. Using a reduce function
4. Binding query results to table views.

**NOTE:** This app's UI is for Mac OS X, but much of the code is also applicable to iOS apps.

## Importing

The `TunesImporter` class does most of the work here.

The `+currentITunesLibraryURL` method looks up the path of the `iTunes Music Library.xml` file that contains an XML property-list dump of the iTunes library.

The `-run` method loads the XML into a JSON-like nested object structure, then iterates through the tracks creating documents from them. The document schema is a subset of the schema used in the property-list file, the most important properties being `Artist`, `Album`, `Name`, `Track Number`, `Total Time`.

Note that `-run` wraps all of the document creation in a single transaction:

    [_database inTransaction: ^BOOL {
        for (NSDictionary* track in [library[@"Tracks"] allValues]) {
            ....
            [self addDocument: props withID: documentID];
        }
        return YES;
    }];

This is _much_ faster than just adding documents one at a time, because it gives SQLite a chance to batch the operations together. It also defers all database-changed notifications until the transaction is complete, which prevents redundant UI updates during the import.

**NOTE:** This iTunes library file only exists on Mac OS; iOS has a dedicated API (the MediaPlayer framework) for querying the music library.

## The Map/Reduce View

All three UI columns are driven by queries of a single map/reduce view. These are set up in `-[TunesAppDelegate setupTables]`. The view's map function simply emits a row for every track document; the emitted key looks like
    ["artist", "album", tracknumber, "track name"]
and the value is the track duration (in milliseconds).

Array-based keys are very powerful because they enable **grouping**, as well as range queries. The array items should be ordered in descending order of priority: in this case the _artist_ is the primary grouping, _album_ is secondary, and _track_ is tertiary.

The view has a reduce function; all it does is add up the input values, which are track times. (You'd be surprised how many complex views use simple totaling for reduction. As JChris put it the other day, "if your reduce function is more complicated than totaling, you're probably doing it wrong.")

### Artists Query

The query for the artist-list column simply uses a group level of 1:

    CBLQuery* q = [view query];
    q.groupLevel = 1;
    self.artistsQueryController.query = q;

The effect is to collapse together all array-based keys that have the same first item (in this case, the artist name.) In the query results, the key of each row will be a one-element key containing the artist name, and the value will be a reduction of all the rows that were grouped together. Since the view's reduce function is a simple sum, the resulting value is the total time of every track by that artist.

### Albums Query

The second column has a group level of two, and is initially set to an empty key range:

    q = [view query];
    q.groupLevel = 2;
    q.startKey = q.endKey = @"";  // show nothing initially
    self.albumsQueryController.query = q;

This query is going to produce rows with _two_-element keys: the artist and album name.

If we didn't constrain the key range, the result would effectively contain every album in the library, sorted by artist, but that's not quite what we want to display: we only want the column to show a single artist, the one selected in column 1. To do that, we have to dynamically alter the `startKey` and `endKey` to restrict the output to a single artist, effectively like this:

    q.startKey = @[artist];
    q.endKey   = @[artist, @[]];

Note the common trick of appending an empty array in the ending key, based on the fact that arrays sort after scalar values like strings. This results in a range containing every key starting with `artist`.

Now, we can't just set this up when the view is created. The key range has to change whenever an artist is selected in column 1. To do this, we use Key-Value Observing (KVO) to watch for a change in the selection property of the `NSArrayController` managing the artist column's UI -- this is set up in the `-applicationDidFinishLaunching:` method. Then the `-observeValueForKeyPath:` method responds by changing the child (album) query's key range.

### Tracks Query

The query for the track-list column doesn't need any grouping, since tracks are the deepest level of nesting. It does, however, need to set the `mapOnly` property of the query, to disable the reduce operation; otherwise all it would produce would be a single row containing the total time.

    q = [view query];
    q.mapOnly = YES;
    q.startKey = q.endKey = @"";  // show nothing initially
    self.tracksQueryController.query = q;

This query, like the album query, also uses a restricted key range which is set as the album selection changes, using the same code described above. In this case the key range starts at `@[artist, album]` and ends at `@[artist, album, @[]]`.

## UI Bindings

You may have noticed that there is no source code that manages the `NSTableView`s -- there aren't even any outlets pointing to them. The tables are managed using array controllers and Cocoa bindings. Here's how it's done:

* The app includes a simple `QueryController` class that maps a `CBLQuery` to a key-value observable NSArray-valued `rows` property.
* There's an instance of `QueryController` for each of the three queries described above.
* There's an `NSArrayController` bound to each `QueryController` (these are instantiated in the MainMenu.xib.)
* Finally, each array controller is bound to the column of the corresponding table. The model key-paths used for the three columns are `key0`, `key1` and `key3`, respectively -- these are convenience properties of `CBLQueryRow` that return an item from an array-based key, namely the artist, album and track title.

**NOTE:** Bindings are very convenient, but are unfortunately only available on Mac OS. On iOS you can use `CBLUITableSource` to drive a `UITableView` from a query, but you'll often still need to write code to configure the cell contents.
