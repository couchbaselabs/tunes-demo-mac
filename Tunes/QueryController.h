//
//  QueryController.h
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

#import <Foundation/Foundation.h>
@class CBLQuery;


/** Simple controller for a CBLQuery.
    This class acts as glue between a CBLQuery and an NSArrayController.
    The app can then bind its UI controls to the NSArrayController and get basic CRUD operations
    without needing any code. */
@interface QueryController : NSObject
{
    CBLQuery* _query;
    NSArray* _rows;
}

- (id) init;

@property (readwrite, strong) CBLQuery* query;

- (void) loadRows;

- (BOOL) updateRows;

// This property isn't explicitly defined, but it can be observed via KVO:
// @property (readonly) NSArray* rows;

@end
