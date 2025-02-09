//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include "Starboard.h"
#include "StubReturn.h"
#include "Foundation/NSMutableSet.h"
#include "Foundation/NSMutableArray.h"

void NSSetTableInit(NSSet* set, NSUInteger capacity);
void NSSetTableInitWithObjects(NSSet* set, id* objects, int count);
void NSSetTableAddObject(NSSet* set, id object);
void NSSetTableFree(NSSet* set);
id NSSetTableMember(NSSet* set, id object);
void NSSetTableRemoveObject(NSSet* set, id object);
void NSSetTableRemoveAllObjects(NSSet* set);
NSUInteger NSSetTableCount(NSSet* set);

@implementation NSMutableSet

/**
 @Status Interoperable
*/
- (id)copyWithZone:(NSZone*)zone {
    return [[NSSet allocWithZone:zone] initWithSet:self];
}

/**
 @Status Interoperable
*/
+ (instancetype)setWithCapacity:(unsigned)capacity {
    return [[[self alloc] initWithCapacity:capacity] autorelease];
}

/**
 @Status Interoperable
*/
- (void)addObjectsFromArray:(NSArray*)array {
    for (id curObj in array) {
        [self addObject:curObj];
    }
}

/**
 @Status Interoperable
*/
- (void)setSet:(NSSet*)other {
    if (self == other) {
        return;
    }

    [self removeAllObjects];

    for (id curObj in other) {
        [self addObject:curObj];
    }
}

/**
 @Status Interoperable
*/
- (void)unionSet:(NSSet*)other {
    for (id curObj in other) {
        [self addObject:curObj];
    }
}

/**
 @Status Interoperable
*/
- (void)removeAllObjects {
    NSSetTableRemoveAllObjects(self);
}

/**
 @Status Interoperable
*/
- (void)minusSet:(NSSet*)other {
    for (id curObj in other) {
        [self removeObject:curObj];
    }
}

/**
 @Status Interoperable
*/
- (void)intersectSet:(NSSet*)other {
    id* removeObjects = NULL;
    int removeObjectsCount = 0, removeObjectsCapacity = 0;

    for (id curObj in self) {
        if ([other member:curObj] == nil) {
            if (removeObjectsCount >= removeObjectsCapacity) {
                removeObjectsCapacity += 128;
                removeObjects = (id*)IwRealloc(removeObjects, sizeof(id*) * removeObjectsCapacity);
            }
            removeObjects[removeObjectsCount++] = curObj;
        }
    }

    for (int i = 0; i < removeObjectsCount; i++) {
        [self removeObject:removeObjects[i]];
    }
    IwFree(removeObjects);
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCapacity:(unsigned)capacity {
    NSSetTableInit(self, capacity);
    return self;
}

/**
 @Status Interoperable
*/
- (void)addObject:(id)object {
    NSSetTableAddObject(self, object);
}

/**
 @Status Interoperable
*/
- (void)removeObject:(id)object {
    NSSetTableRemoveObject(self, object);
}

/**
 @Status Stub
 @Notes
*/
- (void)filterUsingPredicate:(NSPredicate*)predicate {
    UNIMPLEMENTED();
}

@end
