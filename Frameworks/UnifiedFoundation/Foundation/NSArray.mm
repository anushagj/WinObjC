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
#include "CFArrayInternal.h"
#include "../CoreFoundation/CFDictionaryInternal.h"
#include "NSPropertyListReader.h"
#include "Foundation/NSMutableArray.h"
#include "Foundation/NSMutableData.h"
#include "Foundation/NSEnumerator.h"
#include "Foundation/NSKeyedArchiver.h"
#include "Foundation/NSArray.h"
#include "../Foundation/NSXMLPropertyList.h"
#include "NSEnumeratorInternal.h"
#include "../Foundation/NSPropertyListWriter_binary.h"
#include "CoreFoundation/CFArray.h"
#include "Foundation/NSMutableString.h"
#include "CoreFoundation/CFType.h"
#include "Foundation/NSIndexSet.h"
#include "Foundation/NSNull.h"
#include "NSArrayInternal.h"
#include "VAListHelper.h"
#include "LoggingNative.h"

static const wchar_t* TAG = L"NSArray";

@class NSXMLPropertyList, NSPropertyListReader, NSArrayConcrete, NSMutableArrayConcrete, NSPropertyListWriter_Binary;

/**
 * Internal helper for the variadic initializers
 */
static NSArray* _initWithObjects(NSArray* array, const std::vector<id>& flatArgs) {
    for (id obj : flatArgs) {
        CFArrayAppendValue((CFMutableArrayRef)array, (const void*)obj);
    }

    return array;
}

@implementation NSArray

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObjects:(NSObject*)first, ... {
    va_list argList;
    va_start(argList, first);
    std::vector<id> flatArgs = ConvertVAListToVector((id)first, argList);
    va_end(argList);
    return [_initWithObjects([self new], flatArgs) autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObject:(NSObject*)obj {
    NSArray* ret = [self new];
    CFArrayAppendValue((CFMutableArrayRef)ret, (const void*)obj);

    return [ret autorelease];
}

- (instancetype)initWithObject:(NSObject*)obj {
    [self init];

    CFArrayAppendValue((CFMutableArrayRef)self, (const void*)obj);

    return self;
}

/**
 @Status Interoperable
*/
+ (instancetype)array {
    NSArray* ret = [self new];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObjects:(id*)objs count:(NSUInteger)count {
    NSArray* ret = [self alloc];

    _CFArrayInitInternalWithObjects((CFArrayRef)ret, (const void**)objs, count, true);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithArray:(NSArray*)arrayToCopy {
    NSArray* ret = [[self alloc] initWithArray:arrayToCopy];
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (NSArray*)arrayWithContentsOfFile:(NSString*)filename {
    id ret = [[self alloc] initWithContentsOfFile:filename];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(NSObject*)first, ... {
    va_list argList;
    va_start(argList, first);
    std::vector<id> flatArgs = ConvertVAListToVector((id)first, argList);
    va_end(argList);
    return _initWithObjects([self init], flatArgs);
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(id*)objs count:(NSUInteger)count {
    _CFArrayInitInternalWithObjects((CFArrayRef)self, (const void**)objs, count, true);

    return self;
}

- (instancetype)initWithObjectsTakeOwnership:(NSObject**)objs count:(NSUInteger)count {
    _CFArrayInitInternalWithObjects((CFArrayRef)self, (const void**)objs, count, false);

    return self;
}

/**
 @Status Interoperable
*/
- (NSArray*)initWithContentsOfFile:(NSString*)filename {
    const char* file = (char*)[filename UTF8String];

    NSData* data = [NSData dataWithContentsOfFile:filename];

    if (data == nil) {
        [self release];
        return nil;
    }

    char* pData = (char*)[data bytes];

    id arrayData =
        [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:0 errorDescription:0];
    if (![arrayData isKindOfClass:[NSArray class]]) {
        arrayData = [arrayData objectForKey:@"$objects"];
        if (![(id)arrayData isKindOfClass:[NSArray class]]) {
            TraceWarning(TAG, L"object %hs is not an array", [[arrayData description] UTF8String]);
            [self release];
            return nil;
        }
    }

    [self initWithArray:arrayData];

    return self;
}

/**
 @Status Interoperable
*/
- (NSUInteger)count {
    return CFArrayGetCount((CFArrayRef)self);
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    _CFArrayInitInternal((CFArrayRef)self);
    return self;
}

/**
 @Status Interoperable
*/
- (NSObject*)lastObject {
    int count = [self count];

    if (count == 0) {
        return nil;
    }

    return [self objectAtIndex:count - 1];
}

/**
 @Status Interoperable
*/
- (NSObject*)firstObject {
    int count = [self count];

    if (count == 0) {
        return nil;
    }

    return [self objectAtIndex:0];
}

/**
 @Status Interoperable
*/
- (id)objectAtIndex:(NSUInteger)index {
    if (index >= CFArrayGetCount((CFArrayRef)self)) {
        TraceCritical(TAG, L"objectAtIndex: index > count (%d > %d), throwing exception", index, CFArrayGetCount((CFArrayRef)self));
        [NSException raise:@"Array out of bounds" format:@""];
        return nil;
    }
    return (id)CFArrayGetValueAtIndex((CFArrayRef)self, index);
}

/**
 @Status Interoperable
*/
- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(id)obj {
    int count = CFArrayGetCount((CFArrayRef)self);

    for (int i = 0; i < count; i++) {
        id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
        if ([obj isEqual:value]) {
            return i;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSIndexSet*)indexesOfObjectsPassingTest:(BOOL (^)(id, NSUInteger, BOOL*))pred {
    int count = CFArrayGetCount((CFArrayRef)self);

    NSMutableIndexSet* ret = [NSMutableIndexSet indexSet];
    for (int i = 0; i < count; i++) {
        id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
        BOOL shouldStop = false;

        if (pred(value, i, &shouldStop)) {
            [ret addIndex:i];
        }

        if (shouldStop) {
            break;
        }
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(id, NSUInteger, BOOL*))pred {
    int count = CFArrayGetCount((CFArrayRef)self);

    for (int i = 0; i < count; i++) {
        id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
        BOOL shouldStop = false;

        if (pred(value, i, &shouldStop)) {
            return i;
        }

        if (shouldStop) {
            break;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(id)obj inRange:(NSRange)range {
    unsigned count = CFArrayGetCount((CFArrayRef)self);

    for (unsigned i = range.location; i < count && i < (range.location + range.length); i++) {
        id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
        if ([obj isEqual:value]) {
            return i;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectIdenticalTo:(id)obj {
    int count = CFArrayGetCount((CFArrayRef)self);

    for (int i = 0; i < count; i++) {
        if ((id)CFArrayGetValueAtIndex((CFArrayRef)self, i) == obj) {
            return i;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Caveat
 @Notes Only supports NSKeyedArchiver NSCoder type.
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) {
        id array = [coder decodeObjectOfClasses:coder.allowedClasses forKey:@"NS.objects"];

        [self initWithArray:array];
        return self;
    } else {
        UNIMPLEMENTED_WITH_MSG("initWithCoder only supports NSKeyedUnarchiver coder type!");
        [self release];
        return nil;
    }
}

/**
 @Status Interoperable
*/
- (instancetype)initWithArray:(NSArray*)arrayToCopy {
    if (arrayToCopy != nil &&
        (object_getClass(arrayToCopy) == [NSArrayConcrete class] || object_getClass(arrayToCopy) == [NSMutableArrayConcrete class])) {
        int objCount = CFArrayGetCount((CFArrayRef)arrayToCopy);
        id* objs = NULL;

        if (objCount > 0) {
            objs = (id*)_CFArrayGetPtr((CFArrayRef)arrayToCopy);
        }

        _CFArrayInitInternalWithObjects((CFArrayRef)self, (const void**)objs, objCount, true);
    } else {
        id* objs = NULL;
        int objCount = 0;

        int count = [arrayToCopy count];
        objs = (id*)IwMalloc(count * sizeof(id));

        for (int i = 0; i < count; i++) {
            objs[objCount++] = [arrayToCopy objectAtIndex:i];
        }

        _CFArrayInitInternalWithObjects((CFArrayRef)self, (const void**)objs, objCount, true);
        IwFree(objs);
    }

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithArray:(id)arrayToCopy copyItems:(BOOL)copyFlag {
    [self init];

    int count = [arrayToCopy count];
    for (int i = 0; i < count; i++) {
        id curVal = [arrayToCopy objectAtIndex:i];

        if (copyFlag) {
            id copy = [curVal copyWithZone:nil];
            CFArrayAppendValue((CFMutableArrayRef)self, (const void*)copy);
            [copy release];
        } else {
            CFArrayAppendValue((CFMutableArrayRef)self, (const void*)curVal);
        }
    }

    return self;
}

/**
 @Status Interoperable
*/
- (NSObject*)valueForKey:(NSString*)key {
    id ret = [NSMutableArray array];

    id enumerator = [self objectEnumerator];
    id curVal = [enumerator nextObject];

    while (curVal != nil) {
        id newvalue = [curVal valueForKey:key];
        if (newvalue == nil) {
            [ret addObject:[NSNull null]];
        } else {
            [ret addObject:newvalue];
        }

        curVal = [enumerator nextObject];
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(NSUInteger)maxCount {
    if (state->state == 0) {
        state->mutationsPtr = (unsigned long*)&state->extra[1];
        state->extra[0] = (unsigned long)[self objectEnumerator];
        state->state = 1;
    }
    assert(maxCount > 0);

    NSUInteger numRet = 0;
    state->itemsPtr = stackBuf;

    while (maxCount > 0) {
        id next = [(id)state->extra[0] nextObject];
        if (next == nil) {
            break;
        }

        *stackBuf = next;
        stackBuf++;
        numRet++;
        maxCount--;
    }

    return numRet;
}

/**
 @Status Interoperable
*/
- (void)makeObjectsPerformSelector:(SEL)selector {
    id enumerator = [self objectEnumerator];

    id nextObject = [enumerator nextObject];

    while (nextObject != nil) {
        [nextObject performSelector:selector];
        nextObject = [enumerator nextObject];
    }
}

/**
 @Status Interoperable
*/
- (void)setValue:(NSObject*)value forKey:(NSString*)key {
    for (NSObject* cur in self) {
        [cur setValue:value forKey:key];
    }
}

/**
 @Status Interoperable
*/
- (void)makeObjectsPerformSelector:(SEL)selector withObject:(NSObject*)obj {
    id enumerator = [self objectEnumerator];

    id nextObject = [enumerator nextObject];

    while (nextObject != nil) {
        [nextObject performSelector:selector withObject:obj];
        nextObject = [enumerator nextObject];
    }
}

/**
 @Status Interoperable
*/
- (BOOL)containsObject:(NSObject*)obj {
    for (NSObject* curObj in self) {
        if ([curObj isEqual:obj]) {
            return TRUE;
        }
    }

    return FALSE;
}

/**
 @Status Interoperable
*/
- (NSString*)componentsJoinedByString:(NSString*)str {
    id ret = [NSMutableString new];
    id enumerator = [self objectEnumerator];
    id nextObject = [enumerator nextObject];

    bool addSeparator = false;

    while (nextObject != nil) {
        if (addSeparator) {
            [ret appendString:str];
        }
        addSeparator = true;
        [ret appendString:nextObject];

        nextObject = [enumerator nextObject];
    }

    return [ret autorelease];
}

typedef NSInteger (*compFuncType)(id, id, void*);

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingFunction:(compFuncType)compFunc context:(void*)context {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];
    [ret sortUsingFunction:compFunc context:context];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingComparator:(NSComparator)comparator {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];

    [ret sortUsingFunction:CFNSBlockCompare context:comparator];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)filteredArrayUsingPredicate:(NSPredicate*)predicate {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];
    [ret filterUsingPredicate:predicate];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSObject*)mutableCopy {
    return [self mutableCopyWithZone:nil];
}

/**
 @Status Interoperable
*/
- (NSObject*)mutableCopyWithZone:(NSZone*)zone {
    return [[NSMutableArray alloc] initWithArray:self];
}

/**
 @Status Interoperable
*/
- (NSObject*)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)objectEnumerator {
    id ret = [NSEnumerator enumeratorWithIterator:(initIteratorFunc)CFArrayGetValueEnumerator
                                        forObject:self
                                     nextFunction:(nextValueFunc)CFArrayGetNextValue];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)reverseObjectEnumerator {
    return [NSEnumerator enumeratorWithArrayReverse:self];
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingSelector:(SEL)selector {
    NSMutableArray* newArray = [NSMutableArray alloc];
    [newArray initWithArray:self];

    [newArray sortUsingSelector:selector];

    return [newArray autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingDescriptors:(NSArray*)descriptors {
    NSMutableArray* newArray = [NSMutableArray alloc];
    [newArray initWithArray:self];

    [newArray sortUsingDescriptors:descriptors];

    return [newArray autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)subarrayWithRange:(NSRange)range {
    NSArray* newArray = [NSArray new];

    for (NSUInteger i = range.location; i < range.location + range.length; i++) {
        id obj = [self objectAtIndex:i];
        CFArrayAppendValue((CFMutableArrayRef)newArray, (const void*)obj);
    }

    return [newArray autorelease];
}

/**
 @Status Interoperable
*/
- (NSObject*)firstObjectCommonWithArray:(NSArray*)array {
    int i, count = [self count];

    for (i = 0; i < count; i++) {
        id obj = [self objectAtIndex:i];

        if ([array indexOfObject:obj] != NSNotFound) {
            return obj;
        }
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (NSArray*)arrayByAddingObject:(NSObject*)obj {
    NSArray* newArray = [[[self class] alloc] initWithArray:self];

    CFArrayAppendValue((CFMutableArrayRef)newArray, (const void*)obj);

    return [newArray autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)arrayByAddingObjectsFromArray:(NSArray*)arr {
    NSArray* newArray = [[[self class] alloc] initWithArray:self];

    id arrEnum = [arr objectEnumerator];
    id curObj = [arrEnum nextObject];

    while (curObj != nil) {
        CFArrayAppendValue((CFMutableArrayRef)newArray, (const void*)curObj);
        curObj = [arrEnum nextObject];
    }

    return [newArray autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)pathsMatchingExtensions:(NSArray*)extensions {
    id ret = [[NSMutableArray alloc] init];

    id arrEnum = [self objectEnumerator];
    id curObj = [arrEnum nextObject];

    int extCount = [extensions count];

    while (curObj != nil) {
        id ext = [curObj pathExtension];

        for (int i = 0; i < extCount; i++) {
            id curExt = [extensions objectAtIndex:i];

            if ([curExt isEqualToString:ext]) {
                [ret addObject:curExt];
            }
        }
        curObj = [arrEnum nextObject];
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(NSObject*)obj
              inSortedRange:(NSRange)range
                    options:(NSBinarySearchingOptions)options
            usingComparator:(NSComparator)comparator {
    if (range.length == 0) {
        if (options & NSBinarySearchingInsertionIndex) {
            return range.location;
        }

        return NSNotFound;
    }
    if (range.length == 1) {
        id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, range.location);
        int cmp = comparator(obj, value);

        if (cmp == NSOrderedSame) {
            return range.location;
        } else if (cmp <= NSOrderedAscending) {
            if (options & NSBinarySearchingInsertionIndex) {
                return range.location;
            } else {
                return NSNotFound;
            }
        } else {
            //  NSOrderedDescending
            if (options & NSBinarySearchingInsertionIndex) {
                return range.location + 1;
            } else {
                return NSNotFound;
            }
        }
    } else {
        //  Not positive if the logic is right here .. need to run some tests (and also optimize properly)
        int count = CFArrayGetCount((CFArrayRef)self);
        int start = range.location;
        int end = range.location + range.length;
        int inc = 1;
        int insertIdx = end;

        if (options & NSBinarySearchingLastEqual) {
            for (int i = end - 1; i < count && i >= start; i--) {
                id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
                int cmp = comparator(obj, value);

                if (cmp == 0) {
                    return i;
                }
                if (cmp > 0) {
                    insertIdx = i;
                }
            }
        } else {
            //  First equal
            for (int i = start; i < count && i < end; i++) {
                id value = (id)CFArrayGetValueAtIndex((CFArrayRef)self, i);
                int cmp = comparator(obj, value);

                if (cmp == 0) {
                    return i;
                }
                if (cmp > 0 && insertIdx == end) {
                    insertIdx = i;
                }
            }
        }

        if (options & NSBinarySearchingInsertionIndex) {
            return insertIdx;
        }

        return NSNotFound;
    }
}

/**
 @Status Caveat
 @Notes atomically parameter not supported
*/
- (BOOL)writeToFile:(NSString*)file atomically:(BOOL)atomically {
    TraceVerbose(TAG, L"Writing array to file %hs", [file UTF8String]);

    id data = [NSMutableData data];
    [NSPropertyListWriter_Binary serializePropertyList:self intoData:data];
    return [data writeToFile:file atomically:atomically];
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedArchiver class]]) {
        [coder _encodeArrayOfObjects:self forKey:@"NS.objects"];
    } else {
        int i, count = [self count];

        [coder encodeValueOfObjCType:"i" at:&count];
        for (i = 0; i < count; i++) {
            [coder encodeObject:[self objectAtIndex:i]];
        }
    }
}

/**
 @Status Interoperable
*/
- (NSString*)description {
    UNIMPLEMENTED();
    return [super description];
}

/**
 @Status Interoperable
*/
+ (NSObject*)allocWithZone:(NSZone*)zone {
    if (self == [NSArray class]) {
        return NSAllocateObject((Class)[NSArrayConcrete class], 0, zone);
    }

    return NSAllocateObject((Class)self, 0, zone);
}

/**
 @Status Interoperable
*/
- (void)getObjects:(id*)objects {
    NSUInteger i, count = [self count];

    for (i = 0; i < count; i++) {
        objects[i] = [self objectAtIndex:i];
    }
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsUsingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    [self enumerateObjectsWithOptions:0 usingBlock:block];
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    id<NSFastEnumeration> enumerator;
    __block NSUInteger index;
    __block BOOL reverse;
    if (options & NSEnumerationReverse) {
        enumerator = [self reverseObjectEnumerator];
        index = [self count] - 1;
        reverse = true;
    } else {
        enumerator = self;
        index = 0;
        reverse = false;
    }

    _enumerateWithBlock(enumerator,
                        options,
                        ^(id key, BOOL* stop) {
                            block(key, index, stop);
                            if (reverse) {
                                index--;
                            } else {
                                index++;
                            }
                        });
}

/**
 @Status Interoperable
*/
- (void)getObjects:(id*)objects range:(NSRange)range {
    unsigned count = [self count];
    unsigned loc = range.location;

    if (range.location + range.length > count) {
        // NSRaiseException(NSRangeException,self,_cmd,@"range %@ beyond count %d",
        // NSStringFromRange(range),[self count]);
        assert(0);
    }

    for (unsigned i = 0; i < range.length; i++) {
        objects[i] = [self objectAtIndex:loc + i];
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isEqual:(NSObject*)other {
    if (self == other) {
        return YES;
    }

    if (![other isKindOfClass:[NSArray class]]) {
        return NO;
    }

    return [self isEqualToArray:other];
}

/**
 @Status Interoperable
*/
- (NSArray*)allObjects {
    return self;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToArray:(NSArray*)otherArray {
    if ([self count] != [otherArray count]) {
        return NO;
    }

    int i, count = [self count];
    for (i = 0; i < count; i++) {
        id obj1 = [self objectAtIndex:i];
        id obj2 = [otherArray objectAtIndex:i];

        if (![obj1 isEqual:obj2]) {
            return NO;
        }
    }

    return YES;
}

/**
 @Status Interoperable
*/
- (NSArray*)objectsAtIndexes:(NSIndexSet*)indexes {
    unsigned idx = [indexes firstIndex];
    id ret = [NSMutableArray array];
    unsigned count = [self count];

    while (idx != NSNotFound) {
        if (idx >= count) {
            TraceCritical(TAG, L"objectsAtIndexes: index > count (%d > %d), throwing exception", idx, count);
            [NSException raise:@"Array out of bounds" format:@""];
            return nil;
        }
        [ret addObject:[self objectAtIndex:idx]];
        idx = [indexes indexGreaterThanIndex:idx];
    }
    return ret;
}

/**
 @Status Stub
 @Notes
*/
- (void)addObserver:(NSObject*)anObserver
 toObjectsAtIndexes:(NSIndexSet*)indexes
         forKeyPath:(NSString*)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void*)context {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)removeObserver:(NSObject*)anObserver fromObjectsAtIndexes:(NSIndexSet*)indexes forKeyPath:(NSString*)keyPath {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)removeObserver:(NSObject*)observer fromObjectsAtIndexes:(NSIndexSet*)indexes forKeyPath:(NSString*)keyPath context:(void*)context {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
+ (NSArray*)arrayWithContentsOfURL:(NSURL*)aURL {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)descriptionWithLocale:(id)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)enumerateObjectsAtIndexes:(NSIndexSet*)indexSet
                          options:(NSEnumerationOptions)opts
                       usingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (NSIndexSet*)indexesOfObjectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSIndexSet*)indexesOfObjectsAtIndexes:(NSIndexSet*)indexSet
                                 options:(NSEnumerationOptions)opts
                             passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSArray*)initWithContentsOfURL:(NSURL*)aURL {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)writeToURL:(NSURL*)aURL atomically:(BOOL)flag {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSArray*)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)cmptr {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSArray*)sortedArrayUsingFunction:(NSInteger (*)(id, id, void*))comparator context:(void*)context hint:(NSData*)hint {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet*)indexSet
                             options:(NSEnumerationOptions)opts
                         passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    UNIMPLEMENTED();
    return StubReturn();
}

@end

NSUInteger _NSArrayConcreteCountByEnumeratingWithState(NSArray* self, NSFastEnumerationState* state) {
    auto count = CFArrayGetCount((CFArrayRef)self);

    if (state->state >= count) {
        return 0;
    }

    auto internalPointer = reinterpret_cast<id*>(_CFArrayGetPtr(static_cast<CFArrayRef>(self)));
    state->itemsPtr = internalPointer;
    state->state = count;
    state->mutationsPtr = reinterpret_cast<unsigned long*>(self);

    return count;
}

@implementation NSArrayConcrete
/**
 @Status Interoperable
 Note: NSArrayConcrete ignores the passed-in stackbuf+size, as it has its own contiguous storage for its internal object pointers.
*/
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(NSUInteger)maxCount {
    return _NSArrayConcreteCountByEnumeratingWithState(self, state);
}

- (void)dealloc {
    CFArrayRemoveAllValues((CFArrayRef)self);
    _CFArrayDestroyInternal((CFArrayRef)self);

    [super dealloc];
}
@end
