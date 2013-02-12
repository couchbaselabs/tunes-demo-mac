//
//  TunesAppDelegate.m
//  Tunes
//
//  Created by Jens Alfke on 7/20/11.
//  Copyright 2011-2013 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "TunesAppDelegate.h"
#import "TunesImporter.h"
#import "QueryController.h"
#import <CouchbaseLite/CouchbaseLite.h>


@implementation TunesAppDelegate

@synthesize window = _window, artistsQueryController=_artistsQueryController, albumsQueryController=_albumsQueryController, tracksQueryController=_tracksQueryController, totalTime=_totalTime;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.artistsQueryController = [[QueryController alloc] init];
    self.albumsQueryController = [[QueryController alloc] init];
    self.tracksQueryController = [[QueryController alloc] init];

    CBLManager* server = [CBLManager sharedInstance];
    _database = [server databaseNamed: @"itunes" error: NULL];
    if (_database)
        [self setupTables];
    else
        [self rebuild: nil];

    [_artistsController addObserver: self forKeyPath: @"selection"
                            options: NSKeyValueObservingOptionNew context: nil];
    [_albumsController addObserver: self forKeyPath: @"selection"
                           options: NSKeyValueObservingOptionNew context: nil];
}


- (void) setupTables {
    // Define a map function that emits keys of the form [artist, album, track#, trackname]
    // and values that are the track time in milliseconds;
    // and a reduce function that adds up track times.
    CBLView* view = [_database viewNamed: @"tracks"];
    [view setMapBlock: MAPBLOCK({
        NSString* artist = doc[@"Artist"];
        NSString* name = doc[@"Name"];
        if (artist && name) {
            if ([doc[@"Compilation"] boolValue]) {
                artist = @"-Compilations-";
            }
            emit([NSArray arrayWithObjects: artist,
                                            doc[@"Album"] ?: [NSNull null],
                                            doc[@"Track Number"] ?: [NSNull null],
                                            name,
                                            @1,
                                            nil],
                 doc[@"Total Time"]);
        }
    }) reduceBlock: REDUCEBLOCK({
        return [CBLView totalValues: values];
    })
              version: @"3"];

    // The artists query is grouped to level 1, so it collapses all keys with the same artist.
    CBLQuery* q = [view query];
    q.groupLevel = 1;
    self.artistsQueryController.query = q;
    
    // The albums query is grouped to level 2, so it collapses all keys with the same artist+album.
    q = [view query];
    q.groupLevel = 2;
    q.startKey = q.endKey = @"";  // show nothing initially
    self.albumsQueryController.query = q;
    
    // The tracks query has no grouping or reducing, so it will show every track in the key range.
    q = [view query];
    q.mapOnly = YES;
    q.startKey = q.endKey = @"";  // show nothing initially
    self.tracksQueryController.query = q;

    // Compute the total time of everything, to display in the UI:
    q = [view query];
    CBLQueryEnumerator* rows = q.rows;
    self.totalTime = rows.count > 0 ? [[rows rowAtIndex: 0].value longLongValue] : 0;
}


- (IBAction) rebuild:(id)sender {
    self.artistsQueryController.query = nil;
    self.albumsQueryController.query = nil;
    self.tracksQueryController.query = nil;
    NSError* error;
    if (_database && ![_database deleteDatabase: &error])
        NSAssert(NO, @"Couldn't delete database: %@", error);
    _database = [[CBLManager sharedInstance] createDatabaseNamed: @"itunes" error: &error];
    NSAssert(_database, @"Couldn't create database: %@", error);
    
    NSURL* libraryURL = [TunesImporter currentITunesLibraryURL];
    TunesImporter* importer = [[TunesImporter alloc] initWithLibraryURL: libraryURL
                                                               database: _database];
    importer.keysToCopy = @[@"Name", @"Artist", @"Album", @"Genre", @"Year",
                            @"Total Time", @"Track Number", @"Compilation"];

    if (![importer run])
        exit(1);
    [self setupTables];
}


- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context
{
    // 'object' is the controller whose selection has just changed.
    // Based on its selection, set the key range for the next deeper controller:
    QueryController* child = (object == _artistsController ? _albumsQueryController : _tracksQueryController);
    NSArray* selection = [object selectedObjects];
    if (selection.count == 1) {
        // Set the child to show keys that start with the selected key:
        NSArray* key = [selection[0] valueForKey: @"key"];
        child.query.startKey = key;
        child.query.endKey = [key arrayByAddingObject: @[]];
    } else {
        child.query.startKey = child.query.endKey = @""; // show nothing
    }
    
    [child loadRows];
}

@end



/** Converts milliseconds to formatted time strings ("hh:mm:ss"). */
@interface MillisecondsTransformer : NSValueTransformer
@end

@implementation MillisecondsTransformer

- (id)transformedValue:(id)value {
    int seconds = round([value doubleValue] / 1000.0);
    return [NSString stringWithFormat: @"%2d:%02d:%02d",
            seconds/3600, (seconds/60) % 60, seconds % 60];
}


@end

