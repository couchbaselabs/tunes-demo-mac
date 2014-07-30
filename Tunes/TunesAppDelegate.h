//
//  TunesAppDelegate.h
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

#import <Cocoa/Cocoa.h>
@class CBLDatabase, QueryController;


@interface TunesAppDelegate : NSObject <NSApplicationDelegate> 
{
    IBOutlet NSArrayController* _artistsController;
    IBOutlet NSArrayController* _albumsController;
    IBOutlet NSArrayController* _tracksController;
    IBOutlet NSArrayController* _searchController;
    CBLDatabase* _database;
    NSWindow *_window;
    QueryController* _artistsQueryController;
    QueryController* _albumsQueryController;
    QueryController* _tracksQueryController;
    UInt64 _totalTime;
}

@property (strong) IBOutlet NSWindow *window;
@property (strong) QueryController* artistsQueryController;
@property (strong) QueryController* albumsQueryController;
@property (strong) QueryController* tracksQueryController;

@property (strong) QueryController* searchQueryController;

@property UInt64 totalTime;

- (IBAction) rebuild:(id)sender;
- (IBAction) search:(id)sender;

@end
