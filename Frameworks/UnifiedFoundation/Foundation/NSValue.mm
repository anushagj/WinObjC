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
#include "Foundation/NSString.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSMethodSignature.h"
#import "CoreLocation/CLLocation.h"

#include <type_traits>
#include <objc/encoding.h>

static NSValueType valueTypeFromObjCType(const char* objcType) {
    if (strncmp(objcType, "{CGSize", 7) == 0) {
        return NSValueTypeCGSize;
    } else if (strncmp(objcType, "{CGPoint", 8) == 0) {
        return NSValueTypeCGPoint;
    } else if (strncmp(objcType, "{UIOffset", 9) == 0) {
        return NSValueTypeUIOffset;
    } else if (strncmp(objcType, "{CGRect", 7) == 0) {
        return NSValueTypeCGRect;
    } else if (strncmp(objcType, "{CATransform3D", 14) == 0) {
        return NSValueTypeCATransform3D;
    } else if (strncmp(objcType, "{CGAffineTransform", 18) == 0) {
        return NSValueTypeCGAffineTransform;
    } else if (strncmp(objcType, "{_NSRange", 9) == 0) {
        return NSValueTypeNSRange;
    } else if (strncmp(objcType, "{CLLocationCoordinate2D", 22) == 0) {
        return NSValueTypeCLLocationCoordinate2D;
    } else if (strcmp(objcType, "^v") == 0) {
        return NSValueTypePointer;
    } else if (strcmp(objcType, "@") == 0) {
        return NSValueTypeNonretainedObject;
    }
    return NSValueTypeGeneric;
}

@interface _NSValue_CGSize : NSValue {
    CGSize _val;
}
- (id)initWithCGSize:(CGSize)value;
@end

@implementation _NSValue_CGSize
- (id)initWithCGSize:(CGSize)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeCGSize;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(CGSize);
}

- (CGSize)sizeValue {
    return _val;
}

- (CGSize)CGSizeValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(CGSize));
}

- (NSString*)description {
    return [NSString stringWithFormat:@"{%f, %f}", _val.width, _val.height];
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_CGPoint : NSValue {
    CGPoint _val;
}
- (id)initWithCGPoint:(CGPoint)value;
@end

@implementation _NSValue_CGPoint
- (id)initWithCGPoint:(CGPoint)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeCGPoint;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(CGPoint);
}

- (CGPoint)pointValue {
    return _val;
}

- (CGPoint)CGPointValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(CGPoint));
}

- (NSString*)description {
    return [NSString stringWithFormat:@"{%f, %f}", _val.x, _val.y];
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_CGRect : NSValue {
    CGRect _val;
}
- (id)initWithCGRect:(CGRect)value;
@end

@implementation _NSValue_CGRect
- (id)initWithCGRect:(CGRect)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeCGRect;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(CGRect);
}

- (CGRect)rectValue {
    return _val;
}

- (CGRect)CGRectValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(CGRect));
}

- (NSString*)description {
    return [NSString stringWithFormat:@"{{%f, %f} {%f, %f}}", _val.origin.x, _val.origin.y, _val.size.width, _val.size.height];
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_UIOffset : NSValue {
    UIOffset _val;
}
- (id)initWithUIOffset:(UIOffset)value;
@end

@implementation _NSValue_UIOffset
- (id)initWithUIOffset:(UIOffset)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeUIOffset;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(UIOffset);
}

- (UIOffset)UIOffsetValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(UIOffset));
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_CATransform3D : NSValue {
    CATransform3D _val;
}
- (id)initWithCATransform3D:(CATransform3D)value;
@end

@implementation _NSValue_CATransform3D
- (id)initWithCATransform3D:(CATransform3D)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeCATransform3D;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(CATransform3D);
}

- (CATransform3D)CATransform3DValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(CATransform3D));
}

- (NSString*)description {
    return [NSString stringWithFormat:@"{%f, %f %f, %f}, {%f, %f %f, %f}, {%f, %f %f, %f}, {%f, %f %f, %f}}",
                                      _val.m11,
                                      _val.m12,
                                      _val.m13,
                                      _val.m14,
                                      _val.m21,
                                      _val.m22,
                                      _val.m23,
                                      _val.m24,
                                      _val.m31,
                                      _val.m32,
                                      _val.m33,
                                      _val.m34,
                                      _val.m41,
                                      _val.m42,
                                      _val.m43,
                                      _val.m44];
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_CGAffineTransform : NSValue {
    CGAffineTransform _val;
}
- (id)initWithCGAffineTransform:(CGAffineTransform)value;
@end

@implementation _NSValue_CGAffineTransform
- (id)initWithCGAffineTransform:(CGAffineTransform)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeCGAffineTransform;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(CGAffineTransform);
}

- (CGAffineTransform)affineTransformValue {
    return _val;
}

- (CGAffineTransform)CGAffineTransformValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(CGAffineTransform));
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_NSRange : NSValue {
    NSRange _val;
}
- (id)initWithNSRange:(NSRange)value;
@end

@implementation _NSValue_NSRange
- (id)initWithNSRange:(NSRange)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeNSRange;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(NSRange);
}

- (NSRange)rangeValue {
    return _val;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"{%d, %d}", _val.location, _val.length];
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(NSRange));
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_Pointer : NSValue {
    void* _val;
}

- (id)initWithPointer:(const void*)value;
@end

@implementation _NSValue_Pointer
- (id)initWithPointer:(const void*)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypePointer;

        // Because +valueWithPointer accepts const void*, and the accessor -pointerValue returns void*, we cast away the const here.
        _val = const_cast<void*>(value);
    }
    return self;
}

- (const char*)objCType {
    return @encode(void*);
}

- (void*)pointerValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(_val));
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_NRO : NSValue {
    __unsafe_unretained id _val;
}
- (id)initWithNonretainedObject:(__unsafe_unretained id)value;
@end

@implementation _NSValue_NRO
- (id)initWithNonretainedObject:(__unsafe_unretained id)value {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeNonretainedObject;
        _val = value;
    }
    return self;
}

- (const char*)objCType {
    return @encode(id);
}

- (__unsafe_unretained id)nonretainedObjectValue {
    return _val;
}

- (void)getValue:(void*)dest {
    memcpy(dest, (char*)&_val, sizeof(id));
}

- (const void*)_rawBytes {
    return &_val;
}

- (size_t)_rawSize {
    return sizeof(_val);
}
@end

@interface _NSValue_Generic : NSValue {
    void* _valPtr;
    const char* _objcType;
}
- (id)initWithBytes:(const void*)bytes objCType:(const char*)objCType;
@end

@implementation _NSValue_Generic
- (NSValue*)initWithBytes:(const void*)ptr objCType:(const char*)ocType {
    if ((self = [super init]) != nil) {
        _valueType = NSValueTypeGeneric;
        _objcType = IwStrDup(ocType);
        size_t size = objc_sizeof_type(ocType);
        _valPtr = IwMalloc(size);
        memcpy(_valPtr, ptr, size);
    }
    return self;
}

- (void)dealloc {
    if (_objcType) {
        IwFree((void*)_objcType);
    }
    if (_valPtr) {
        IwFree(_valPtr);
    }
    [super dealloc];
}

- (const char*)objCType {
    return _objcType;
}

- (void*)pointerValue {
    return _valPtr;
}

- (void)getValue:(void*)dest {
    memcpy(dest, _valPtr, objc_sizeof_type(_objcType));
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<NSValue: %p; %s at %p>", self, _objcType, _valPtr];
}

- (const void*)_rawBytes {
    return _valPtr;
}

- (size_t)_rawSize {
    return objc_sizeof_type(_objcType);
}
@end

@implementation NSValue
/**
 @Status Interoperable
*/
+ (NSValue*)newWithZone:(NSZone*)zone bytes:(const void*)bytes valueType:(NSValueType)valueType objCType:(const char*)objCType {
    if (valueType == NSValueTypeUnknown) {
        valueType = valueTypeFromObjCType(objCType);
    }

    switch (valueType) {
        case NSValueTypeCGSize: {
            CGSize value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_CGSize alloc] initWithCGSize:value];
        }
        case NSValueTypeCGPoint: {
            CGPoint value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_CGPoint alloc] initWithCGPoint:value];
        }
        case NSValueTypeCGRect: {
            CGRect value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_CGRect alloc] initWithCGRect:value];
        }
        case NSValueTypeUIOffset: {
            UIOffset value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_UIOffset alloc] initWithUIOffset:value];
        }
        case NSValueTypeCATransform3D: {
            CATransform3D value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_CATransform3D alloc] initWithCATransform3D:value];
        }
        case NSValueTypeCGAffineTransform: {
            CGAffineTransform value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_CGAffineTransform alloc] initWithCGAffineTransform:value];
        }
        case NSValueTypeNSRange: {
            NSRange value;
            memcpy(&value, bytes, sizeof(value));
            return [[_NSValue_NSRange alloc] initWithNSRange:value];
        }
        case NSValueTypeCLLocationCoordinate2D: {
            CLLocationCoordinate2D value;
            memcpy(&value, bytes, sizeof(value));
            return [[NSValue valueWithMKCoordinate:value] retain];
        }

        case NSValueTypeNonretainedObject:
            return [[_NSValue_NRO allocWithZone:zone] initWithNonretainedObject:*(id*)bytes];

        case NSValueTypePointer:
            return [[_NSValue_Pointer allocWithZone:zone] initWithPointer:*(void**)bytes];

        default:
            assert(objCType != nullptr);
            return [[_NSValue_Generic allocWithZone:zone] initWithBytes:bytes objCType:objCType];
    }
}

/**
 @Status Interoperable
*/
- (NSValue*)initWithBytes:(const void*)bytes objCType:(const char*)objCType {
    [self release];
    return [NSValue newWithZone:nil bytes:bytes valueType:NSValueTypeUnknown objCType:objCType];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithBytes:(const void*)bytes objCType:(const char*)objCType {
    return [[self newWithZone:nil bytes:bytes valueType:NSValueTypeUnknown objCType:objCType] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSValue*)value:(const void*)bytes withObjCType:(const char*)objCType {
    return [[self newWithZone:nil bytes:bytes valueType:NSValueTypeUnknown objCType:objCType] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithCGSize:(CGSize)value {
    return [[[_NSValue_CGSize alloc] initWithCGSize:value] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithCGPoint:(CGPoint)value {
    return [[[_NSValue_CGPoint alloc] initWithCGPoint:value] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithCGRect:(CGRect)value {
    return [[[_NSValue_CGRect alloc] initWithCGRect:value] autorelease];
}

/**
 @Status Stub
*/
+ (NSValue*)valueWithCGAffineTransform:(CGAffineTransform)transform {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithRange:(NSRange)value {
    return [[[_NSValue_NSRange alloc] initWithNSRange:value] autorelease];
}

/**
 @Status Interoperable
 @Notes Not sure if this should be exposed
*/
+ (NSValue*)valueWithCATransform3D:(CATransform3D)value {
    return [[[_NSValue_CATransform3D alloc] initWithCATransform3D:value] autorelease];
}

/**
 @Status Caveat
 @Notes initWithX is a private IW extension on NSValue used internally
*/
- (NSValue*)initWithCGSize:(CGSize)value {
    [self release];
    return [[_NSValue_CGSize alloc] initWithCGSize:value];
}

/**
 @Status Caveat
 @Notes initWithX is a private IW extension on NSValue used internally
*/
- (NSValue*)initWithCGPoint:(CGPoint)value {
    [self release];
    return [[_NSValue_CGPoint alloc] initWithCGPoint:value];
}

/**
 @Status Caveat
 @Notes initWithX is a private IW extension on NSValue used internally
*/
- (NSValue*)initWithCGRect:(CGRect)value {
    [self release];
    return [[_NSValue_CGRect alloc] initWithCGRect:value];
}

- (NSValue*)initWithCATransform3D:(CATransform3D)value {
    [self release];
    return [[_NSValue_CATransform3D alloc] initWithCATransform3D:value];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithPointer:(const void*)pointer {
    return [[[_NSValue_Pointer alloc] initWithPointer:pointer] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSValue*)valueWithNonretainedObject:(__unsafe_unretained id)object {
    return [[[_NSValue_NRO alloc] initWithNonretainedObject:object] autorelease];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (Class)classForCoder {
    return [NSValue class];
}

/**
 @Status Interoperable
*/
- (NSValue*)initWithCoder:(NSKeyedUnarchiver*)coder {
    _valueType = (NSValueType)[coder decodeIntForKey:@"NSV.type"];
    unsigned size;
    void* data = (void*)[coder decodeBytesForKey:@"NSV.data" returnedLength:&size];
    assert(size != 0 && data != NULL);

    const char* objcType = [[coder decodeObjectForKey:@"NSV.objcType"] UTF8String];

    [self release];
    return [NSValue newWithZone:nil bytes:data valueType:_valueType objCType:objcType];
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSKeyedArchiver*)coder {
    [coder encodeInt:(int)_valueType forKey:@"NSV.type"];
    [coder encodeObject:[NSString stringWithUTF8String:[self objCType]] forKey:@"NSV.objcType"];
    [coder encodeBytes:static_cast<const unsigned char*>([self _rawBytes]) length:[self _rawSize] forKey:@"NSV.data"];
}

/**
 @Status Interoperable
*/
- (const char*)objCType {
    return nullptr;
}

- (const void*)_rawBytes {
    return nullptr;
}
- (size_t)_rawSize {
    return 0;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToValue:(NSValue*)other {
    return [self class] == [other class] && _valueType == other->_valueType && [self _rawSize] == [other _rawSize] &&
           memcmp([self _rawBytes], [other _rawBytes], [self _rawSize]) == 0;
}

static unsigned hashBytes(const void* bytes, size_t len) {
    unsigned ret = 0;
    char* cur = (char*)bytes;

    while (len--) {
        ret = (ret << 8) | (ret >> 24);
        ret ^= *cur;
        cur++;
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (unsigned)hash {
    return hashBytes([self _rawBytes], [self _rawSize]);
}

/**
 @Status Interoperable
*/
- (NSObject*)copyWithZone:(NSZone*)zone {
    return [NSValue newWithZone:zone bytes:[self _rawBytes] valueType:_valueType objCType:[self objCType]];
}

/**
 @Status Stub
*/
+ (NSValue*)valueWithMKCoordinate:(CLLocationCoordinate2D)coordinate {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status Stub
*/
- (CLLocationCoordinate2D)MKCoordinateValue {
    UNIMPLEMENTED();
    return { 0, 0 };
}

/**
 @Status Interoperable
*/
- (CGSize)sizeValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGSize." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGSize)CGSizeValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGSize." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGPoint)pointValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGPoint." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGPoint)CGPointValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGPoint." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGRect)rectValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGRect." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGRect)CGRectValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGRect." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (UIOffset)UIOffsetValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a UIOffset." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CATransform3D)CATransform3DValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CATransform3D." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGAffineTransform)affineTransformValue {
    @throw
        [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGAffineTransform." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (CGAffineTransform)CGAffineTransformValue {
    @throw
        [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a CGAffineTransform." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (NSRange)rangeValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException reason:@"This value does not store a NSRange." userInfo:nil];
}

/**
 @Status Interoperable
*/
- (__unsafe_unretained id)nonretainedObjectValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException
                                   reason:@"This value does not store a nonretained object."
                                 userInfo:nil];
}

/**
 @Status Interoperable
*/
- (void*)pointerValue {
    @throw [NSException exceptionWithName:NSDestinationInvalidException
                                   reason:@"This value does not store an unguarded pointer."
                                 userInfo:nil];
}

/**
 @Status Interoperable
*/
- (void)getValue:(void* __attribute__((unused)))dest {
    @throw [NSException exceptionWithName:NSDestinationInvalidException
                                   reason:@"Attempted to get raw data from a non-specialized NSValue instance."
                                 userInfo:nil];
}

@end
