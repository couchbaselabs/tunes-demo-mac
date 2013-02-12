//
//  QueryController.m
//  Tunes
//
//  Created by Jens Alfke on 7/19/11.
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

#import "QueryController.h"
#import <CouchbaseLite/CouchbaseLite.h>


@implementation QueryController


- (id) init {
    self = [super init];
    if (self != nil) {
        // Listen for external changes:
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(updateRows)
                                                     name: kCBLDatabaseChangeNotification
                                                   object: nil];
    }
    return self;
}


- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (CBLQuery*)query {
    return _query;
}


- (void) setQuery:(CBLQuery *)query {
    if (query != _query) {
        _query = query;
        [self loadRows];
    }
}


- (void) loadRows {
    [self loadRowsFrom: [_query rows]];
}


- (void) loadRowsFrom: (CBLQueryEnumerator*)rowEnumerator {
    [self willChangeValueForKey: @"rows"];
    _rows = [rowEnumerator.allObjects copy];
    [self didChangeValueForKey: @"rows"];
}


- (BOOL) updateRows {
    _query.prefetch = NO;   // prefetch disables rowsIfChanged optimization
    CBLQueryEnumerator* rows = [_query rowsIfChanged];
    if (!rows)
        return NO;
    [self loadRowsFrom: rows];
    return YES;
}


#pragma mark -
#pragma mark ROWS PROPERTY:


- (NSUInteger) countOfRows {
    return _rows.count;
}


- (CBLQueryRow*)objectInRowsAtIndex: (NSUInteger)index {
    return _rows[index];
}


@end
