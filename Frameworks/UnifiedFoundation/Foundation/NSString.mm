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
#import "CFConstantString.h"
#define U_STATIC_IMPLEMENTATION 1
#include "unicode/coll.h"
#include "unicode/ucnv.h"
#include "unicode/uniset.h"
#include "unicode/brkiter.h"
#include "unicode/unistr.h"
#include <new>
#include <assert.h>

#include "IcuHelper.h"

#include <Starboard/String.h>
#include "LoggingNative.h"

static const wchar_t* TAG = L"NSString";

NSString* const NSParseErrorException = @"NSParseErrorException";
NSString* const NSCharacterConversionException = @"NSCharacterConversionException";

enum NSStringType {
    NSUninitializedString = 0,
    NSConstructedString_Unicode = 0x7FFFFFFF,
    NSConstructedString_NoOwn = 0x20,
};

struct _ConstructedStringData {
    icu_48::UnicodeString* str;
    char* utf8String;

    _ConstructedStringData();
    ~_ConstructedStringData();
};

//  All NSString access should be made through self class.  It will upgrade/convert strings
//  as needed
_ConstructedStringData::_ConstructedStringData() {
    str = NULL;
    utf8String = NULL;
}

_ConstructedStringData::~_ConstructedStringData() {
    if (utf8String) {
        IwFree(utf8String);
    }
}

struct ConstStrData {
    Class isa;
    const char* c_str;
    size_t len;
};

void UStringHolder::initWithString(NSString* str, int location, int length) {
    static EbrLock _upgradeLock;
    static bool _upgradeLockSet;

    _destroyStr = NULL;

    if (!_upgradeLockSet) {
        EbrLockInit(&_upgradeLock);
        _upgradeLockSet = true;
    }

    if ([str class] == [CFConstantString class]) {
        if (str->strType != NSConstructedString_Unicode) {
            EbrLockEnter(_upgradeLock);
            //  Contention case
            if (str->strType == NSConstructedString_Unicode) {
                EbrLockLeave(_upgradeLock);
            } else {
                ConstStrData* constStr = (ConstStrData*)str;
                _str = new UnicodeString(UnicodeString::fromUTF8(StringPiece((const char*)constStr->c_str, constStr->len)));
                str->u = new stringData();
                str->u->ConstructedString.constructedStr = new _ConstructedStringData();
                str->u->ConstructedString.constructedStr->str = _str;
                str->u->ConstructedString._hashIsCached = FALSE;
                str->u->ConstructedString._placementAllocated = FALSE;
                str->strType = NSConstructedString_Unicode;
                EbrLockLeave(_upgradeLock);
            }
        }
    }

    switch (str->strType) {
        case NSConstructedString_NoOwn:
            switch (str->u->NoOwnString._encoding) {
                case NSWindowsCP1251StringEncoding:
                case NSISOLatin1StringEncoding:
                case NSASCIIStringEncoding: {
                    _str = new UnicodeString((char*)str->u->NoOwnString._address, str->u->NoOwnString._length, US_INV);
                    _destroyStr = _str;
                    break;
                }

                case NSUTF8StringEncoding: {
                    _str = new UnicodeString(
                        UnicodeString::fromUTF8(StringPiece((char*)str->u->NoOwnString._address, str->u->NoOwnString._length)));
                    _destroyStr = _str;
                    break;
                }

                case NSUTF16LittleEndianStringEncoding:
                case NSUnicodeStringEncoding: {
                    _str = new UnicodeString((UChar*)str->u->NoOwnString._address, str->u->NoOwnString._length / 2);
                    _destroyStr = _str;
                    break;
                }
            }
            break;

        case NSConstructedString_Unicode:
            _str = str->u->ConstructedString.constructedStr->str;
            break;

        default:
            assert(0);
            break;
    }

    if (length != -1 && (length != _str->length() || location != 0)) {
        if (_subStr == NULL)
            _subStr = new UnicodeString();
        _subStr->setTo(false, _str->getBuffer() + location, length);
        _str = _subStr;
    }
}

UStringHolder::UStringHolder(id str, int location, int length) : _subStr(0) {
    if (str == nil) {
        _str = new UnicodeString("");
        _destroyStr = _str;
        return;
    }

    if (object_getClass(str) != [NSString class] && object_getClass(str) != [NSMutableString class] &&
        object_getClass(str) != [CFConstantString class]) {
        if (![str isKindOfClass:[NSString class]]) {
            str = [str description];
        }
    }

    initWithString((NSString*)str, location, length);
}

UStringHolder::UStringHolder(NSString* str, int location, int length) : _subStr(NULL) {
    if (str == nil) {
        _str = new UnicodeString("");
        _destroyStr = _str;
        return;
    }

    if (![str isKindOfClass:[NSString class]]) {
        printf("falling back to using description class\n");
        str = [str description];
    }

    initWithString((NSString*)str, location, length);
}

UStringHolder::~UStringHolder() {
    if (_destroyStr) {
        delete _destroyStr;
    }
    if (_subStr) {
        delete _subStr;
    }
}

UnicodeString& UStringHolder::string() {
    if (_str == NULL) {
        //  Very bad!
        *((char*)0) = 0;
    }

    return *_str;
}

inline unichar UStringHolder::getChar(int index) {
    return _str->charAt(index);
}

void setToUnicode(NSString* inst, UnicodeString& str) {
    switch (inst->strType) {
        case NSConstructedString_NoOwn:
            switch (inst->u->NoOwnString._encoding) {
                case NSUTF8StringEncoding: {
                    UErrorCode status = U_ZERO_ERROR;
                    UConverter* u8cnv = getUTF8Converter();

                    char* targetBegin = (char*)inst->u->NoOwnString._address;
                    char* targetStart = targetBegin;
                    char* targetEnd = targetStart + inst->u->NoOwnString._length;
                    const UChar* sourceBegin = str.getBuffer();
                    const UChar* sourceStart = sourceBegin;
                    const UChar* sourceEnd = sourceStart + str.length();

                    ucnv_fromUnicode(u8cnv, &targetStart, targetEnd, &sourceStart, sourceEnd, NULL, TRUE, &status);
                } break;

                default:
                    assert(0);
                    *((char*)0xBAADF00D) = 0;
                    break;
            }

        case NSConstructedString_Unicode:
            inst->u->ConstructedString._hashIsCached = FALSE;

            if (inst->u->ConstructedString.constructedStr->str == &str)
                break;
            inst->u->ConstructedString.constructedStr->str->setTo(str);
            break;

        case NSUninitializedString:
            inst->u = new stringData();
            if ([inst class] == [NSString class] || [inst class] == [NSMutableString class]) {
                inst->u->ConstructedString.constructedStr = new _ConstructedStringData();
                inst->u->ConstructedString.constructedStr->str = new UnicodeString(str);
                inst->u->ConstructedString._hashIsCached = FALSE;
                inst->u->ConstructedString._placementAllocated = TRUE;
            } else {
                inst->u->ConstructedString.constructedStr = new _ConstructedStringData();
                inst->u->ConstructedString.constructedStr->str = new UnicodeString(str);
                inst->u->ConstructedString._hashIsCached = FALSE;
                inst->u->ConstructedString._placementAllocated = FALSE;
            }
            inst->strType = NSConstructedString_Unicode;
            break;

        default:
            *((char*)0) = 0; //  Very bad!
            assert(0);
            break;
    }
}

int formatPrintfU(WORD* out, int maxLen, const WORD* fmt, va_list pReader);

UnicodeString EbrUnicodePrintf(NSString* format, va_list list) {
    UStringHolder ufmt(format);
    const UChar* fmt = ufmt.string().getTerminatedBuffer();

    WORD* strBuf;

    va_list pReaderCopy = list;
    WORD tempBuf[255];

    int len = formatPrintfU(tempBuf, ((sizeof(tempBuf) / sizeof(WORD)) - 1) | 0x40000000, (WORD*)fmt, list);
    if (len >= (sizeof(tempBuf) / sizeof(WORD)) - 1) {
        strBuf = (WORD*)IwMalloc((len + 1) * 2);
        formatPrintfU(strBuf, len, (WORD*)fmt, pReaderCopy);

        UnicodeString str((UChar*)strBuf, len);
        IwFree(strBuf);

        return str;
    } else {
        UnicodeString str((UChar*)tempBuf, len);

        return str;
    }
}

void setToFormat(NSString* inst, NSString* format, va_list list, NSString* string) {
    UnicodeString str = EbrUnicodePrintf(format, list);
    setToUnicode(string, str);
}

@interface NSStringConversion : NSObject {
@public
    BYTE _str[4]; //   Extra will be allocated via NSAllocateObject
}
@end

@implementation NSStringConversion : NSObject

@end

static void* _conversionTempStr(int size) {
    NSStringConversion* ret = [NSAllocateObject([NSStringConversion class], size, nil) autorelease];

    return ret->_str;
}

typedef NSUInteger NSStringCompareOptions;

@implementation NSString : NSObject
/**
 @Status Interoperable
*/
- (id)initWithCoder:(NSCoder*)coder {
    NSString* str = [coder decodeObjectForKey:@"NS.string"];

    if (str != nil) {
        return [self initWithString:str];
    } else {
        return [self init];
    }
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCString:(const char*)cStr {
    UnicodeString str(cStr, strlen(cStr), US_INV);

    setToUnicode(self, str);
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    UnicodeString str;

    setToUnicode(self, str);
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCString:(const char*)cStr length:(DWORD)length {
    UnicodeString str(cStr, length, US_INV);

    setToUnicode(self, str);
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithUTF8String:(const char*)utf8str {
    UnicodeString str = UnicodeString::fromUTF8(StringPiece(utf8str));
    setToUnicode(self, str);

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithFormat:(NSString*)formatStr, ... {
    va_list reader;
    va_start(reader, formatStr);

    setToFormat(nil, formatStr, reader, self);
    va_end(reader);

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithFormat:(id)formatStr arguments:(va_list)pReader {
    setToFormat(nil, formatStr, pReader, self);

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithString:(NSString*)otherStr {
    UStringHolder s1(otherStr);
    UnicodeString copy = s1.string();

    setToUnicode(self, copy);

    return self;
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithString:(NSString*)str {
    return [[[self alloc] initWithString:str] autorelease];
}

/**
 @Status Interoperable
*/
- (NSString*)stringByAppendingString:(NSString*)str {
    if (str == nil) {
        TraceVerbose(TAG, L"stringByAppendingString: str = nil!");
        return [self copy];
    }

    UStringHolder s1(self);
    UStringHolder s2(str);

    UnicodeString copy = s1.string();
    copy.append(s2.string());

    NSString* ret = [NSString alloc];
    setToUnicode(ret, copy);

    return [ret autorelease];
}

/**
 @Status Caveat
 @Notes Positional formatting is not supported.
*/
- (NSString*)stringByAppendingFormat:(NSString*)formatStr, ... {
    va_list reader;
    va_start(reader, formatStr);
    UnicodeString str = EbrUnicodePrintf(formatStr, reader);
    va_end(reader);

    UStringHolder s1(self);
    UnicodeString copy = s1.string();
    copy.append(str);
    NSString* ret = [NSString alloc];
    setToUnicode(ret, copy);

    return [ret autorelease];
}

/**
 @Status Stub
*/
- (NSString*)stringByAbbreviatingWithTildeInPath {
    UNIMPLEMENTED();
    return [[self copy] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSString*)string {
    return @"";
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithFormat:(NSString*)formatStr, ... {
    va_list reader;
    va_start(reader, formatStr);

    NSString* objRet = [self alloc];
    setToFormat(self, formatStr, reader, objRet);
    va_end(reader);

    return [objRet autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithCString:(char*)str {
    NSString* ret = [[self alloc] initWithCString:str];

    return [ret autorelease];
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
+ (instancetype)stringWithCString:(char*)str encoding:(int)encoding {
    NSString* ret = [[self alloc] initWithCString:str encoding:encoding];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithUTF8String:(char*)str {
    NSString* ret = [[self alloc] initWithUTF8String:str];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithCString:(char*)str length:(DWORD)length {
    NSString* ret = [[self alloc] initWithCString:str length:length];

    return [ret autorelease];
}

/**
 @Status Stub
 @Notes Returns NSASCIIStringEncoding
*/
+ (NSStringEncoding)defaultCStringEncoding {
    UNIMPLEMENTED();
    return NSASCIIStringEncoding;
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
- (instancetype)initWithData:(NSData*)data encoding:(NSStringEncoding)encoding {
    const char* bytes = (const char*)[data bytes];
    DWORD length = [data length];

    if (data == nil) {
        bytes = "";
        length = 0;
    } else {
        bytes = (const char*)[data bytes];
        length = [data length];
    }

    UnicodeString uniStr;

    switch (encoding) {
        case NSUTF8StringEncoding:
        case NSMacOSRomanStringEncoding: {
            uniStr = UnicodeString::fromUTF8(StringPiece(bytes, length));
            break;
        }

        case NSShiftJISStringEncoding:
        case NSISOLatin1StringEncoding:
        case NSISOLatin2StringEncoding:
        case NSASCIIStringEncoding: {
            uniStr = UnicodeString(bytes, length, US_INV);
            break;
        }

        case NSUnicodeStringEncoding: {
            uniStr = UnicodeString((const UChar*)bytes, length / 2);
            break;
        }

        case NSUTF16BigEndianStringEncoding: {
            WORD* tmp = (WORD*)IwMalloc(length);
            WORD* curChar = tmp;
            memcpy(curChar, bytes, length);
            int left = length / 2;

            while (left) {
                *curChar = ((*curChar) & 0xFF) << 8 | ((*curChar) & 0xFF00) >> 8;
                curChar++;
                left--;
            }
            uniStr = UnicodeString((const UChar*)tmp, length / 2);
            IwFree(tmp);
            break;
        }

        case NSUTF32BigEndianStringEncoding: {
            DWORD* tmp = (DWORD*)IwMalloc(length);
            DWORD* curChar = tmp;
            memcpy(curChar, bytes, length);
            int left = length / 4;

            while (left) {
                *curChar =
                    ((*curChar) & 0xFF) << 24 | ((*curChar) & 0xFF00) << 8 | ((*curChar) & 0xFF0000) >> 8 | ((*curChar) & 0xFF000000) >> 24;
                curChar++;
                left--;
            }
            uniStr = UnicodeString::fromUTF32((const UChar32*)tmp, length / 4);
            IwFree(tmp);
            break;
        }

        case static_cast<DWORD>(NSUTF32LittleEndianStringEncoding): {
            uniStr = UnicodeString::fromUTF32((const UChar32*)bytes, length / 4);
            break;
        }

        case NSUTF16LittleEndianStringEncoding: {
            uniStr = UnicodeString((const UChar*)bytes, length / 2);
            break;
        }

        default:
            TraceCritical(TAG, L"Unknown encoding %d", encoding);
            assert(0);
    }

    setToUnicode(self, uniStr);

    return self;
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
- (instancetype)initWithBytes:(const char*)bytes length:(unsigned)length encoding:(NSStringEncoding)encoding {
    switch (encoding) {
        case NSWindowsCP1251StringEncoding:
        case NSWindowsCP1252StringEncoding:
        case NSISOLatin1StringEncoding:
        case NSASCIIStringEncoding: {
            UnicodeString str(bytes, length, US_INV);

            setToUnicode(self, str);
            break;
        }

        case NSUTF8StringEncoding: {
            UnicodeString str(UnicodeString::fromUTF8(StringPiece((char*)bytes, length)));
            setToUnicode(self, str);
            break;
        }

        case NSUTF16LittleEndianStringEncoding:
            TraceWarning(TAG, L"Warning: NSUTF16LittleEndianStringEncoding is being treated as unicode");

        case NSUnicodeStringEncoding: {
            UnicodeString str((UChar*)bytes, length / 2);
            setToUnicode(self, str);
            break;
        }

        case NSUTF32LittleEndianStringEncoding: {
            UnicodeString str = UnicodeString::fromUTF32((UChar32*)bytes, length / 4);
            setToUnicode(self, str);
            break;
        }

        case NSUTF16BigEndianStringEncoding: {
            WORD* pCopy = (WORD*)IwMalloc(length);
            memcpy(pCopy, bytes, length);

            for (DWORD i = 0; i < length / 2; i++) {
                pCopy[i] = (pCopy[i] >> 8 | ((WORD)(pCopy[i] << 8)));
            }

            UnicodeString str((UChar*)pCopy, length / 2);
            setToUnicode(self, str);
            IwFree(pCopy);
            break;
        }

        default:
            assert(0);
            *((char*)0xBAADF00D) = 0;
            break;
    }

    return self;
}

/**
 @Status Caveat
 @Notes Limited encodings available.  CRT types must match when freeWhenDone=YES
*/
- (instancetype)initWithBytesNoCopy:(const char*)bytes
                             length:(unsigned)length
                           encoding:(NSStringEncoding)encoding
                       freeWhenDone:(BOOL)freeWhenDone {
    strType = NSConstructedString_NoOwn;
    u = new stringData();
    u->NoOwnString._address = (void*)bytes;
    u->NoOwnString._length = length;
    u->NoOwnString._encoding = encoding;
    u->NoOwnString._freeWhenDone = freeWhenDone;

    return self;
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithCharacters:(const WORD*)bytes length:(unsigned)length {
    return [[[self alloc] initWithCharacters:bytes length:length] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCharacters:(const WORD*)bytes length:(DWORD)length {
    UnicodeString str((UChar*)bytes, length);

    setToUnicode(self, str);
    return self;
}

/**
 @Status Caveat
 @Notes CRT types must match when freeWhenDone=YES
*/
- (instancetype)initWithCharactersNoCopy:(const WORD*)bytes length:(DWORD)length freeWhenDone:(BOOL)freeWhenDone {
    strType = NSConstructedString_NoOwn;
    u = new stringData();
    u->NoOwnString._address = (void*)bytes;
    u->NoOwnString._length = length * 2;
    u->NoOwnString._encoding = NSUnicodeStringEncoding;
    u->NoOwnString._freeWhenDone = freeWhenDone != FALSE;

    return self;
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
- (instancetype)initWithCString:(char*)bytes encoding:(NSStringEncoding)encoding {
    int len = 0;

    switch (encoding) {
        case NSUTF8StringEncoding:
        case NSISOLatin1StringEncoding:
        case NSWindowsCP1252StringEncoding:
        case NSASCIIStringEncoding:
        case NSMacOSRomanStringEncoding: {
            len = strlen(bytes);
            break;
        }

        case NSUnicodeStringEncoding: {
            WORD* curChar = (WORD*)bytes;
            while (*curChar) {
                len++;
                curChar++;
            }
            break;
        }

        default:
            assert(0);
    }

    NSData* data = [[NSData alloc] initWithBytesNoCopy:bytes length:len freeWhenDone:FALSE];
    NSString* ret = [self initWithData:data encoding:encoding];
    [data release];

    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithContentsOfFile:(NSString*)path {
    if (path == nil) {
        TraceVerbose(TAG, L"NSString: path = nil!");
        return nil;
    }

    const char* fileName = (const char*)[path UTF8String];
    TraceVerbose(TAG, L"NSString:opening %hs", fileName);

    EbrFile* fpIn = EbrFopen(fileName, "rb");
    if (!fpIn) {
        TraceVerbose(TAG, L"Couldn't open file %hs", fileName);
        return nil;
    }

    WORD type = 0;
    DWORD encoding = NSASCIIStringEncoding;
    EbrFread(&type, 1, 2, fpIn);

    int bigendian = 0;

    if (type == 0xFEFF) {
        encoding = NSUnicodeStringEncoding;
    } else if (type == 0xFFFE) {
        encoding = NSUnicodeStringEncoding;
        bigendian = 1;
        assert(0);
        *((char*)0xBAADF00D) = 0;
    } else {
        EbrFseek(fpIn, 0, SEEK_SET);
    }

    int cur = EbrFseek(fpIn, 0, SEEK_CUR);
    EbrFseek(fpIn, 0, SEEK_END);
    int len = EbrFtell(fpIn);
    EbrFseek(fpIn, cur, SEEK_SET);
    char* bytes = (char*)IwMalloc(len);

    len = EbrFread(bytes, 1, len, fpIn);
    EbrFclose(fpIn);

    NSData* data = [[NSData alloc] initWithBytesNoCopy:bytes length:len freeWhenDone:FALSE];
    NSString* ret = [self initWithData:data encoding:encoding];
    [data release];
    IwFree(bytes);

    return ret;
}

/**
 @Status Caveat
 @Notes atomically parameter not supported
*/
- (BOOL)writeToFile:(NSString*)file atomically:(BOOL)atomically encoding:(NSStringEncoding)encoding error:(NSError**)err {
    if (!file) {
        TraceVerbose(TAG, L"WriteToFile: nil!");
        return FALSE;
    }
    UStringHolder s1(self);

    const char* fileName = (const char*)[file UTF8String];
    TraceVerbose(TAG, L"NSString: writing %hs", fileName);

    EbrFile* fpOut = EbrFopen(fileName, "wb");
    if (!fpOut) {
        if (err) {
            assert(0); //  Write NSError
        }
        TraceVerbose(TAG, L"Couldn't open file %hs", fileName);
        return FALSE;
    }

    switch (encoding) {
        case NSUTF8StringEncoding:
        case NSASCIIStringEncoding: {
            int len = s1.string().length();
            for (int i = 0; i < len; i++) {
                WORD out = s1.getChar(i);

                EbrFwrite(&out, 1, 1, fpOut);
            }
            break;
        }

        case NSUnicodeStringEncoding: {
            int len = s1.string().length();

            EbrFputc(0xFF, fpOut);
            EbrFputc(0xFE, fpOut);
            for (int i = 0; i < len; i++) {
                WORD out = s1.getChar(i);

                EbrFwrite(&out, 2, 1, fpOut);
            }
            break;
        }

        default:
            assert(0);
    }

    EbrFclose(fpOut);

    return TRUE;
}

/**
 @Status Caveat
 @Notes Limited encodings available.
*/
- (instancetype)initWithContentsOfFile:(NSString*)path encoding:(NSStringEncoding)encoding error:(NSError**)errorRet {
    if (path == nil) {
        TraceVerbose(TAG, L"initWithContentsOfFile: path = nil!");
        return nil;
    }

    const char* fileName = (const char*)[path UTF8String];
    TraceVerbose(TAG, L"NSString:opening %hs", fileName);

    EbrFile* fpIn = EbrFopen(fileName, "rb");
    if (!fpIn) {
        TraceVerbose(TAG, L"Couldn't open file %hs", fileName);
        if (errorRet) {
            *errorRet = [objc_getClass("NSError") errorWithDomain:@"File not found" code:100 userInfo:nil];
        }
        return nil;
    }

    int bigendian = 0;

    if (encoding == NSUnicodeStringEncoding) {
        WORD type = 0;
        EbrFread(&type, 1, 2, fpIn);

        if (type == 0xFEFF) {
        } else if (type == 0xFFFE) {
            bigendian = 1;
            assert(0);
            *((char*)0xBAADF00D) = 0;
        } else {
            EbrFseek(fpIn, 0, SEEK_SET);
        }
    }

    int cur = EbrFseek(fpIn, 0, SEEK_CUR);
    EbrFseek(fpIn, 0, SEEK_END);
    int len = EbrFtell(fpIn);
    EbrFseek(fpIn, cur, SEEK_SET);
    char* bytes = (char*)IwMalloc(len);

    len = EbrFread(bytes, 1, len, fpIn);
    EbrFclose(fpIn);

    NSData* data = [[NSData alloc] initWithBytesNoCopy:bytes length:len freeWhenDone:FALSE];
    NSString* ret = [self initWithData:data encoding:encoding];
    [data release];
    IwFree(bytes);

    return ret;
}

/**
 @Status Caveat
 @Notes Limited encodings supported
*/
- (unsigned)lengthOfBytesUsingEncoding:(NSStringEncoding)encoding {
    unsigned ret;

    switch (encoding) {
        case NSUTF8StringEncoding:
        case NSASCIIStringEncoding: {
            UStringHolder s1(self);

            std::string realStr;
            s1.string().toUTF8String(realStr);

            ret = realStr.length();
            break;
        }

        case NSUnicodeStringEncoding: {
            UStringHolder s1(self);

            ret = s1.string().length();
            break;
        }

        default:
            assert(0);
    }

    return ret;
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
+ (instancetype)stringWithContentsOfFile:(NSString*)path encoding:(NSStringEncoding)encoding error:(NSError**)errorRet {
    NSString* ret = [[self alloc] initWithContentsOfFile:path encoding:encoding error:errorRet];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithContentsOfURL:(NSURL*)url {
    return [self stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
+ (instancetype)stringWithContentsOfURL:(NSURL*)url encoding:(NSStringEncoding)encoding error:(NSError**)errorRet {
    NSString* ret = [self alloc];

    NSData* data = [[NSData alloc] initWithContentsOfURL:url options:0 error:errorRet];

    ret = [[ret initWithData:data encoding:encoding] autorelease];
    [data release];

    return ret;
}

/**
 @Status Interoperable
*/
+ (instancetype)stringWithContentsOfFile:(NSString*)path {
    return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
+ (instancetype)stringWithContentsOfFile:(NSString*)path usedEncoding:(NSStringEncoding*)usedEncoding error:(NSError**)errorRet {
    NSString* ret = [self alloc];

    *usedEncoding = NSASCIIStringEncoding;
    TraceVerbose(TAG, L"Encoding: ASCII?");

    return [[ret initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:errorRet] autorelease];
}

/**
 @Status Caveat
 @Notes Limited encodings available
*/
- (instancetype)initWithContentsOfFile:(NSString*)path usedEncoding:(NSStringEncoding*)usedEncoding error:(NSError**)errorRet {
    *usedEncoding = NSASCIIStringEncoding;
    TraceVerbose(TAG, L"Encoding: ASCII?");

    return [self initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:errorRet];
}

- (const void*)_quickStringUsingEncoding:(DWORD)encoding {
    if (encoding == NSUnicodeStringEncoding) {
        UStringHolder s1(self);

        if (strType == NSConstructedString_Unicode) {
            return u->ConstructedString.constructedStr->str->getTerminatedBuffer();
        }
    }

    return [self cStringUsingEncoding:encoding];
}

/**
 @Status Caveat
 @Notes Limited encodings supported
*/
- (const char*)cStringUsingEncoding:(DWORD)encoding {
    switch (encoding) {
        case NSASCIIStringEncoding:
        case NSNonLossyASCIIStringEncoding:
        case NSWindowsCP1251StringEncoding:
        case NSWindowsCP1252StringEncoding:
        case NSShiftJISStringEncoding:
        case NSMacOSRomanStringEncoding:
        case NSUTF8StringEncoding: {
            UStringHolder s1(self);

            int len = s1.string().length();
            NSUInteger numBytes = 0;

            [self getBytes:NULL
                     maxLength:0x7FFFFFF
                    usedLength:&numBytes
                      encoding:encoding
                       options:0
                         range:NSMakeRange(0, len)
                remainingRange:NULL];

            if ((object_getClass(self) == [NSString class] || object_getClass(self) == [CFConstantString class]) &&
                strType == NSConstructedString_Unicode) {
                if (u->ConstructedString.constructedStr->utf8String == NULL) {
                    char* pData = (char*)IwMalloc(numBytes + 1);
                    [self getBytes:pData
                             maxLength:numBytes
                            usedLength:NULL
                              encoding:encoding
                               options:0
                                 range:NSMakeRange(0, len)
                        remainingRange:NULL];
                    pData[numBytes] = 0;
                    u->ConstructedString.constructedStr->utf8String = pData;
                }

                return u->ConstructedString.constructedStr->utf8String;
            } else {
                char* pData = (char*)_conversionTempStr(numBytes + 1);
                [self getBytes:pData
                         maxLength:numBytes
                        usedLength:NULL
                          encoding:encoding
                           options:0
                             range:NSMakeRange(0, len)
                    remainingRange:NULL];
                pData[numBytes] = 0;

                return pData;
            }
        }

        case NSUnicodeStringEncoding: {
            UStringHolder s1(self);

            int len = s1.string().length();
            const UChar* ptr = s1.string().getTerminatedBuffer();
            WORD* pData = (WORD*)_conversionTempStr((len + 1) * 2);
            memcpy(pData, ptr, len * 2);
            pData[len] = 0;

            return (const char*)pData;
        }

        case static_cast<DWORD>(NSUTF32LittleEndianStringEncoding): {
            UStringHolder s1(self);

            DWORD* strRet = (DWORD*)_conversionTempStr((s1.string().length() + 1) * 4);
            int i, len = s1.string().length();

            for (i = 0; i < len; i++) {
                strRet[i] = s1.getChar(i);
            }
            strRet[i] = 0;

            return (const char*)strRet;
        }

        default:
            assert(0);
            break;
    }

    return 0;
}

/**
 @Status Interoperable
*/
- (NSStringEncoding)fastestEncoding {
    // Return Unicode encoding as soon as a single non-ASCII character is found. Otherwise, return ASCII encoding.
    UStringHolder s1(self);
    icu_48::UnicodeString unicodeString = s1.string();
    int32_t length = unicodeString.length();

    for (int32_t i = 0; i < length; i++) {
        if (unicodeString[i] > 0x7F) {
            return NSUnicodeStringEncoding;
        }
    }

    return NSASCIIStringEncoding;
}

/**
 @Status Interoperable
*/
- (const char*)UTF8String {
    if (strType == NSConstructedString_Unicode) {
        if (u->ConstructedString.constructedStr->utf8String) {
            return u->ConstructedString.constructedStr->utf8String;
        }
    }

    return (const char*)[self cStringUsingEncoding:NSUTF8StringEncoding];
}

/**
 @Status Caveat
 @Notes options not supported.  Limited encodings supported.
*/
- (BOOL)getBytes:(BYTE*)buffer
       maxLength:(unsigned)maxBuf
      usedLength:(unsigned*)usedLength
        encoding:(NSStringEncoding)encoding
         options:(unsigned)options
           range:(NSRange)range
  remainingRange:(NSRange*)left {
    unsigned offset = range.location, length = range.length;

    DWORD outPos = 0;
    UStringHolder s1(self, offset, length);
    UnicodeString& subStr = s1.string();
    BOOL ret = FALSE;

    switch (encoding) {
        case NSWindowsCP1252StringEncoding:
        case NSASCIIStringEncoding: {
            UErrorCode status = U_ZERO_ERROR;
            UConverter* cnv = getASCIIConverter();

            if (buffer != NULL) {
                char* targetBegin = (char*)buffer;
                char* targetStart = targetBegin;
                char* targetEnd = targetStart + maxBuf;
                const UChar* sourceBegin = subStr.getBuffer();
                const UChar* sourceStart = sourceBegin;
                const UChar* sourceEnd = sourceStart + subStr.length();

                ucnv_fromUnicode(cnv, &targetStart, targetEnd, &sourceStart, sourceEnd, NULL, TRUE, &status);

                if (sourceStart != sourceBegin) {
                    ret = TRUE;
                }

                if (usedLength) {
                    *usedLength = targetStart - targetBegin;
                }
                if (left) {
                    left->location = offset + (sourceStart - sourceBegin);
                    left->length = s1.string().length() - left->location;
                }
            } else {
                if (usedLength) {
                    *usedLength = ucnv_fromUChars(cnv, NULL, 0, subStr.getBuffer(), subStr.length(), &status);
                }
            }
        } break;

        case NSUnicodeStringEncoding: {
            if (buffer != NULL) {
                UChar* targetBegin = (UChar*)buffer;
                UChar* targetStart = targetBegin;
                const UChar* sourceBegin = subStr.getBuffer();
                const UChar* sourceStart = sourceBegin;
                const int maxChars = maxBuf / sizeof(UChar);

                int toCopy = maxChars > subStr.length() ? subStr.length() : maxChars;
                memcpy(targetStart, sourceStart, toCopy * sizeof(UChar));
                targetStart += toCopy;
                sourceStart += toCopy;

                if (sourceStart != sourceBegin) {
                    ret = TRUE;
                }

                if (usedLength) {
                    *usedLength = (targetStart - targetBegin) * sizeof(UChar);
                }
                if (left) {
                    left->location = offset + (sourceStart - sourceBegin);
                    left->length = s1.string().length() - left->location;
                }
            } else {
                if (usedLength) {
                    *usedLength = subStr.length() * sizeof(UChar);
                }
            }
        } break;

        case NSUTF8StringEncoding: {
            UErrorCode status = U_ZERO_ERROR;
            UConverter* cnv = getUTF8Converter();

            if (buffer != NULL) {
                char* targetBegin = (char*)buffer;
                char* targetStart = targetBegin;
                char* targetEnd = targetStart + maxBuf;
                const UChar* sourceBegin = subStr.getBuffer();
                const UChar* sourceStart = sourceBegin;
                const UChar* sourceEnd = sourceStart + subStr.length();

                ucnv_fromUnicode(cnv, &targetStart, targetEnd, &sourceStart, sourceEnd, NULL, TRUE, &status);

                if (sourceStart != sourceBegin) {
                    ret = TRUE;
                }

                if (usedLength) {
                    *usedLength = targetStart - targetBegin;
                }
                if (left) {
                    left->location = offset + (sourceStart - sourceBegin);
                    left->length = s1.string().length() - left->location;
                }
            } else {
                if (usedLength) {
                    *usedLength = ucnv_fromUChars(cnv, NULL, 0, subStr.getBuffer(), subStr.length(), &status);
                }
            }
        } break;

        case NSUTF32BigEndianStringEncoding: {
            UErrorCode status = U_ZERO_ERROR;
            UConverter* cnv = getUTF32BEConverter();

            if (buffer != NULL) {
                char* targetBegin = (char*)buffer;
                char* targetStart = targetBegin;
                char* targetEnd = targetStart + maxBuf;
                const UChar* sourceBegin = subStr.getBuffer();
                const UChar* sourceStart = sourceBegin;
                const UChar* sourceEnd = sourceStart + subStr.length();

                ucnv_fromUnicode(cnv, &targetStart, targetEnd, &sourceStart, sourceEnd, NULL, TRUE, &status);

                if (sourceStart != sourceBegin) {
                    ret = TRUE;
                }

                if (usedLength) {
                    *usedLength = targetStart - targetBegin;
                }
                if (left) {
                    left->location = offset + (sourceStart - sourceBegin);
                    left->length = s1.string().length() - left->location;
                }
            } else {
                if (usedLength) {
                    *usedLength = ucnv_fromUChars(cnv, NULL, 0, subStr.getBuffer(), subStr.length(), &status);
                }
            }
        } break;

        default:
            *((char*)0xBAADF00D) = 0;
            assert(0);
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (void)getCharacters:(unsigned short*)dest range:(NSRange)range {
    UStringHolder s1(self, range.location, range.length);

    assert(range.length <= (DWORD)s1.string().length());

    UErrorCode error = U_ZERO_ERROR;
    s1.string().extract((UChar*)dest, range.length, error);
}

/**
 @Status Interoperable
*/
- (void)getCharacters:(unsigned short*)dest {
    UStringHolder s1(self);

    [self getCharacters:dest range:NSMakeRange(0, s1.string().length())];
}

/**
 @Status Interoperable
*/
- (instancetype)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
- (instancetype)lowercaseString {
    UStringHolder s1(self);

    UnicodeString s2 = s1.string();
    s2.toLower();

    NSString* ret = [NSString alloc];
    setToUnicode(ret, s2);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)capitalizedString {
    UStringHolder s1(self);

    UnicodeString s2 = s1.string();
    s2.toTitle(NULL);

    NSString* ret = [NSString alloc];
    setToUnicode(ret, s2);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)uppercaseString {
    UStringHolder s1(self);

    UnicodeString s2 = s1.string();
    s2.toUpper();

    //  Fastpath - don't create a new string
    if (s2 == s1.string()) {
        if (object_getClass(self) == [CFConstantString class]) {
            return self;
        }

        return [[self copy] autorelease];
    }

    NSString* ret = [NSString alloc];
    setToUnicode(ret, s2);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)stringByDeletingPathExtension {
    UStringHolder s1(self);
    int len = s1.string().length();
    const UChar* chars = s1.string().getBuffer();

    //  Scan backwards for a dot or slash
    int curOffset = 0;
    for (curOffset = len - 1; curOffset >= 0; curOffset--) {
        if (chars[curOffset] == '.') {
            UnicodeString piece = UnicodeString(s1.string(), 0, curOffset);
            NSString* ret = [NSString alloc];
            setToUnicode(ret, piece);
            return [ret autorelease];
        } else if (chars[curOffset] == '/') {
            break;
        }
    }

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)stringByDeletingLastPathComponent {
    UStringHolder s1(self);
    int len = s1.string().length();
    const UChar* chars = s1.string().getBuffer();

    //  Scan backwards for a slash
    int curOffset = 0;
    for (curOffset = len - 1; curOffset >= 0; curOffset--) {
        if (chars[curOffset] == '/') {
            if (curOffset == 0) {
                return @"/";
            } else {
                if (curOffset + 1 < len) {
                    UnicodeString piece = UnicodeString(s1.string(), 0, curOffset);
                    NSString* ret = [NSString alloc];
                    setToUnicode(ret, piece);
                    return [ret autorelease];
                }
            }
        }
    }

    return @"";
}

/**
 @Status Interoperable
*/
- (UChar)characterAtIndex:(unsigned)index {
    UStringHolder s1(self);
    DWORD len = s1.string().length();
    const UChar* chars = s1.string().getBuffer();

    assert(index < len);

    return chars[index];
}

/**
 @Status Interoperable
*/
- (const unichar*)rawCharacters {
    UStringHolder s1(self);
    return (const unichar*)s1.string().getBuffer();
}

/**
 @Status Interoperable
*/
- (const unichar*)_rawTerminatedCharacters {
    UStringHolder s1(self);
    return (const unichar*)s1.string().getTerminatedBuffer();
}

/**
 @Status Interoperable
*/
- (instancetype)stringByAppendingPathComponent:(NSString*)pathStr {
    UStringHolder s1(self);
    int len = s1.string().length();

    if (len == 0) {
        if (pathStr) {
            return [NSString stringWithString:pathStr];
        } else {
            return @"";
        }
    }

    const UChar* chars = s1.string().getBuffer();
    UStringHolder s2(pathStr);
    int pathLen = s2.string().length();

    //  Strip trailing slashes
    int curPos = len - 1;
    while (curPos >= 0) {
        if (chars[curPos] != '/') {
            break;
        }
        curPos--;
    }

    curPos++;
    UnicodeString subStr(s1.string(), 0, curPos);
    subStr.append('/');

    //  Strip leading slashes
    const UChar* pathChars = s2.string().getBuffer();
    for (curPos = 0; curPos < pathLen; curPos++) {
        if (pathChars[curPos] != '/')
            break;
    }

    UnicodeString pathSubStr(s2.string(), curPos, pathLen - curPos);
    subStr.append(pathSubStr);

    NSString* ret = [NSString alloc];
    setToUnicode(ret, subStr);
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)stringByAppendingPathExtension:(NSString*)extension {
    UStringHolder s1(self);
    int len = s1.string().length();

    const UChar* chars = s1.string().getBuffer();

    //  Strip trailing slashes
    int curPos = len - 1;
    while (curPos >= 0) {
        if (chars[curPos] != '/') {
            break;
        }
        curPos--;
    }

    curPos++;
    UnicodeString subStr(s1.string(), 0, curPos);
    subStr.append('.');

    UStringHolder s2(extension);
    subStr.append(s2.string());

    NSString* ret = [NSString alloc];
    setToUnicode(ret, subStr);
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (BOOL)hasSuffix:(NSString*)suffixStr {
    UStringHolder s1(self);
    UStringHolder s2(suffixStr);

    if (s1.string().endsWith(s2.string())) {
        return TRUE;
    } else {
        return FALSE;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)hasPrefix:(NSString*)prefixStr {
    UStringHolder s1(self);
    UStringHolder s2(prefixStr);

    if (s2.string().startsWith("fb")) {
        const char* pStr1 = (const char*)[self UTF8String];
        const char* pStr2 = (const char*)[prefixStr UTF8String];
    }

    if (s1.string().startsWith(s2.string())) {
        return TRUE;
    } else {
        return FALSE;
    }
}

/**
 @Status Interoperable
*/
- (instancetype)pathExtension {
    UStringHolder s1(self);
    int len = s1.string().length();
    const UChar* chars = s1.string().getBuffer();

    //  Skip any single trailing slash
    if (len > 0 && chars[len - 1] == '/') {
        len--;
    }

    //  Scan backwards for a dot or slash
    for (int curOffset = len - 1; curOffset >= 0; curOffset--) {
        if (chars[curOffset] == '.') {
            UnicodeString piece = UnicodeString(s1.string(), curOffset + 1, len - curOffset - 1);
            NSString* ret = [NSString alloc];
            setToUnicode(ret, piece);
            return [ret autorelease];
        } else if (chars[curOffset] == '/') {
            break;
        }
    }

    return @"";
}

/**
 @Status Interoperable
*/
- (instancetype)lastPathComponent {
    UStringHolder s1(self);
    int len = s1.string().length();
    const UChar* chars = s1.string().getBuffer();
    int lastChar = -1;

    //  Scan backwards for a slash
    int curOffset;
    for (curOffset = len - 1; curOffset > -1; curOffset--) {
        if (chars[curOffset] == '/') {
            if (lastChar != -1) {
                break;
            }
        } else {
            if (lastChar == -1)
                lastChar = curOffset;
        }
    }

    if (curOffset != -1) {
        UnicodeString piece = UnicodeString(s1.string(), curOffset + 1, len - curOffset - 1);
        NSString* ret = [NSString alloc];
        setToUnicode(ret, piece);
        return [ret autorelease];
    } else {
        return self;
    }
}

/**
 @Status Interoperable
*/
- (instancetype)substringToIndex:(DWORD)anIndex {
    UStringHolder s1(self);

    UnicodeString piece = UnicodeString(s1.string(), 0, anIndex);
    NSString* ret = [NSString alloc];
    setToUnicode(ret, piece);
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)substringFromIndex:(DWORD)anIndex {
    UStringHolder s1(self);

    UnicodeString piece = UnicodeString(s1.string(), anIndex);
    NSString* ret = [NSString alloc];
    setToUnicode(ret, piece);
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)substringWithRange:(NSRange)range {
    UStringHolder s1(self);

    UnicodeString piece = UnicodeString(s1.string(), range.location, range.length);
    NSString* ret = [NSString alloc];
    setToUnicode(ret, piece);
    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (unsigned)length {
    UStringHolder s1(self);

    return s1.string().length();
}

/**
 @Status Interoperable
*/
- (NSString*)description {
    return self;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToString:(NSString*)compStr {
    if (compStr == nil)
        return FALSE;

    if (object_getClass(compStr) == [NSString class] || object_getClass(compStr) == [CFConstantString class] ||
        [compStr isKindOfClass:[NSString class]]) {
        if (strType == NSConstructedString_Unicode && u->ConstructedString._hashIsCached == TRUE &&
            compStr->strType == NSConstructedString_Unicode && compStr->u->ConstructedString._hashIsCached == TRUE) {
            if (u->ConstructedString._hashCache != compStr->u->ConstructedString._hashCache) {
                return FALSE;
            }
        }

        UStringHolder s1(self);
        return [self compare:(id)compStr options:0 range:NSMakeRange(0, s1.string().length())] == 0;
    } else {
        return [compStr isEqual:self];
    }
}

/**
 @Status Stub
 @Notes Forwards to compare:
*/
- (int)localizedCaseInsensitiveCompare:(NSString*)compStr {
    UNIMPLEMENTED();
    UStringHolder s1(self);
    return [self compare:(id)compStr options:NSCaseInsensitiveSearch range:NSMakeRange(0, s1.string().length())];
}

/**
 @Status Interoperable
*/
- (int)caseInsensitiveCompare:(NSString*)compStr {
    UStringHolder s1(self);
    return [self compare:(id)compStr options:NSCaseInsensitiveSearch range:NSMakeRange(0, s1.string().length())];
}

/**
 @Status Stub
 @Notes Forwards to compare:
*/
- (int)localizedCompare:(NSString*)compStr {
    UNIMPLEMENTED();
    UStringHolder s1(self);
    return [self compare:(id)compStr options:0 range:NSMakeRange(0, s1.string().length())];
}

/**
 @Status Interoperable
*/
- (int)compare:(NSString*)compStr {
    UStringHolder s1(self);
    return [self compare:(id)compStr options:0 range:NSMakeRange(0, s1.string().length())];
}

- (int)versionStringCompare:(NSString*)compStrAddr {
    TraceWarning(TAG, L"Warning: versionStringCompare not implemented");
    char* str = (char*)[self UTF8String];

    if (compStrAddr == nil) {
        TraceVerbose(TAG, L"Compare to nil?");
        return strcmp(str, "");
    }

    const char* compStr = (const char*)[compStrAddr UTF8String];

    int result = strcmp(str, compStr);
    if (result < 0)
        result = -1;
    if (result > 0)
        result = 1;

    return result;
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSAnchoredSearch, NSDiacriticInsensitiveSearch, NSNumericSearch,
        and NSRegularExpression are supported.
*/
- (int)compare:(NSString*)compStr options:(NSStringCompareOptions)options {
    UStringHolder s1(self);
    return [self compare:compStr options:options range:NSMakeRange(0, s1.string().length())];
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSAnchoredSearch, NSDiacriticInsensitiveSearch, NSNumericSearch,
        and NSRegularExpression are supported.
*/
- (int)compare:(NSString*)compStrAddr options:(NSStringCompareOptions)options range:(NSRange)range {
    if (compStrAddr == nil) {
        return -1;
    }
    if (compStrAddr == self) {
        return 0;
    }

    if (options == 0) {
        UStringHolder s1(self, range.location, range.length);
        UStringHolder s2(compStrAddr);

        int result = s1.string().compare(s2.string());
        if (result > 0) {
            return 1;
        } else if (result < 0) {
            return -1;
        }
        return 0;
    } else if (options == NSCaseInsensitiveSearch) {
        UStringHolder s1(self, range.location, range.length);
        UStringHolder s2(compStrAddr);

        int result = s1.string().caseCompare(s2.string(), 0);
        if (result > 0) {
            return 1;
        } else if (result < 0) {
            return -1;
        }
        return 0;
    }

    //  32 == Localized search
    assert((options &
            ~(NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch | NSLiteralSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch |
              NSNumericSearch | 32)) == 0);

    UStringHolder s1(self, range.location, range.length);
    UStringHolder s2(compStrAddr);

    UErrorCode error = U_ZERO_ERROR;
    UCollator* collator = getDefaultLocaleCollator();

    if ((options & NSCaseInsensitiveSearch) && (options & NSDiacriticInsensitiveSearch)) {
        ucol_setStrength(collator, UCOL_PRIMARY);
    } else if (options & NSCaseInsensitiveSearch) {
        ucol_setStrength(collator, UCOL_SECONDARY);
    } else if (options & NSDiacriticInsensitiveSearch) {
        ucol_setStrength(collator, UCOL_PRIMARY);
        ucol_setAttribute(collator, UCOL_CASE_LEVEL, UCOL_ON, &error);
    }

    if (options & NSNumericSearch)
        ucol_setAttribute(collator, UCOL_NUMERIC_COLLATION, UCOL_ON, &error);

    UCollationResult result =
        ucol_strcoll(collator, s1.string().getBuffer(), s1.string().length(), s2.string().getBuffer(), s2.string().length());

    if (result == UCOL_EQUAL) {
        return 0;
    } else if (result == UCOL_LESS) {
        return -1;
    } else if (result == UCOL_GREATER) {
        return 1;
    }

    return 0;
}

/**
 @Status Interoperable
*/
- (int)intValue {
    char* str = (char*)[self UTF8String];

    return strtol(str, NULL, 10);
}

/**
 @Status Interoperable
*/
- (int)integerValue {
    return [self intValue];
}

/**
 @Status Interoperable
*/
- (__int64)longLongValue {
    char* str = (char*)[self UTF8String];

    __int64 ret;
#if defined(WIN32) || defined(WINPHONE)
    ret = _strtoi64(str, NULL, 10);
#else
    ret = strtoll(str, NULL, 10);
#endif

    return ret;
}

- (void)longLongValuePtr:(__int64*)ret {
    char* str = (char*)[self UTF8String];

#if defined(WIN32) || defined(WINPHONE)
    *ret = _strtoi64(str, NULL, 10);
#else
    *ret = strtoll(str, NULL, 10);
#endif
}

/**
 @Status Interoperable
*/
- (float)floatValue {
    char* str = (char*)[self UTF8String];

    float ret = (float)strtod(str, NULL);

    return ret;
}

/**
 @Status Interoperable
*/
- (double)doubleValue {
    char* str = (char*)[self UTF8String];

    double ret = strtod(str, NULL);

    return ret;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqual:(NSString*)objAddr {
    if (objAddr == self)
        return TRUE;
    if (objAddr == nil)
        return FALSE;

    if (object_getClass(objAddr) == [NSString class] || object_getClass(objAddr) == [NSMutableString class] ||
        object_getClass(objAddr) == [CFConstantString class]) {
        if (strType == NSConstructedString_Unicode && u->ConstructedString._hashIsCached == TRUE &&
            objAddr->strType == NSConstructedString_Unicode && objAddr->u->ConstructedString._hashIsCached == TRUE) {
            if (u->ConstructedString._hashCache != objAddr->u->ConstructedString._hashCache) {
                return FALSE;
            }
        }

        UStringHolder s1(self);
        UStringHolder s2(objAddr);

        return (s1.string() == s2.string());
    }
    if (objAddr != nil && [objAddr isKindOfClass:[NSString class]]) {
        return [self isEqualToString:(id)objAddr];
    }

    return FALSE;
}

/**
 @Status Interoperable
*/
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)charSet {
    UStringHolder s1(self);

    NSRange range;
    range = [self rangeOfCharacterFromSet:charSet options:0 range:NSMakeRange(0, s1.string().length())];

    return range;
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSBackwardsSearch options supported
*/
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)charSet options:(DWORD)options {
    UStringHolder s1(self);

    NSRange range;
    range = [self rangeOfCharacterFromSet:charSet options:options range:NSMakeRange(0, s1.string().length())];

    return range;
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSBackwardsSearch options supported
*/
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)charSet options:(DWORD)options range:(NSRange)range {
    NSRange ret;

    UStringHolder s1(self);
    UnicodeString str1(s1.string(), range.location, range.length);
    UnicodeSet* set = charSet->_icuSet;
    bool destroySet = false;

    UErrorCode error = U_ZERO_ERROR;
    if (options & NSCaseInsensitiveSearch) {
        UnicodeString curPattern;
        set->toPattern(curPattern);

        set = new UnicodeSet(curPattern, USET_CASE_INSENSITIVE, NULL, error);
        destroySet = true;
    }

    int32_t pos;

    if (options & NSBackwardsSearch) {
        pos = set->spanBack(str1, INT32_MAX, USET_SPAN_NOT_CONTAINED);
    } else {
        pos = set->span(str1, 0, USET_SPAN_NOT_CONTAINED);
    }
    if (pos == range.length) {
        ret.length = 0;
        ret.location = NSNotFound;
    } else {
        ret.location = pos + range.location;
        ret.length = 1;
    }

    if (destroySet)
        delete set;

    return ret;
}

/**
 @Status Interoperable
*/
- (BOOL)getCString:(char*)buf maxLength:(DWORD)maxLength {
    return [self getCString:buf maxLength:maxLength encoding:NSASCIIStringEncoding];
}

/**
 @Status Interoperable
*/
- (BOOL)getCString:(char*)buf {
    return [self getCString:buf maxLength:0x7FFFFFFF encoding:NSASCIIStringEncoding];
}

/**
 @Status Caveat
 @Notes Limited encodings supported
*/
- (BOOL)getCString:(char*)buf maxLength:(DWORD)maxLength encoding:(DWORD)encoding {
    UStringHolder s1(self);
    int len = s1.string().length();
    NSRange usedRange;

    unsigned usedLength = 0;
    [self getBytes:buf
             maxLength:maxLength
            usedLength:&usedLength
              encoding:encoding
               options:0
                 range:NSMakeRange(0, len)
        remainingRange:&usedRange];
    if (usedLength < maxLength) {
        buf[usedLength] = 0;
    }

    if (usedRange.location == len) {
        return TRUE;
    } else {
        return FALSE;
    }
}

/**
 @Status Interoperable
*/
- (NSArray*)componentsSeparatedByString:(NSString*)separators {
    UStringHolder s1(self);
    UStringHolder s2(separators);
    UnicodeString& str1 = s1.string();
    UnicodeString& str2 = s2.string();
    int curPos = 0, len = str1.length();

    int count = 0;

    for (;;) {
        int pos = str1.indexOf(str2, curPos);
        if (pos == -1) {
            count++;
            break;
        }

        count++;

        curPos = pos + str2.length();
    }

    curPos = 0;
    id* objects = (id*)IwMalloc(count * sizeof(id));
    int objOut = 0;

    for (;;) {
        int pos = str1.indexOf(str2, curPos);
        if (pos == -1) {
            //  Add what's left
            NSString* toAdd = nil;

            if (len - curPos == 0) {
                toAdd = @"";
            } else {
                UnicodeString subStr(str1, curPos, len - curPos);
                toAdd = [NSString alloc];
                setToUnicode(toAdd, subStr);
            }

            objects[objOut++] = toAdd;
            break;
        }

        NSString* toAdd = nil;

        if (pos - curPos == 0) {
            toAdd = @"";
        } else {
            UnicodeString subStr(str1, curPos, pos - curPos);
            toAdd = [NSString alloc];
            setToUnicode(toAdd, subStr);
        }

        objects[objOut++] = toAdd;

        curPos = pos + str2.length();
    }

    NSArray* ret = [NSArray alloc];
    [ret initWithObjectsTakeOwnership:objects count:objOut];

    IwFree(objects);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)componentsSeparatedByCharactersInSet:(NSCharacterSet*)set {
    NSMutableArray* result = [NSMutableArray array];
    int length = [self length];
    NSRange search = NSMakeRange(0, [self length]), patWhere;

    do {
        patWhere = [self rangeOfCharacterFromSet:set options:0 range:search];

        if (patWhere.length > 0) {
            NSString* piece = [self substringWithRange:NSMakeRange(search.location, patWhere.location - search.location)];

            [result addObject:piece];
            search.location = patWhere.location + patWhere.length;
            search.length = length - search.location;
        }
    } while (patWhere.length > 0);

    [result addObject:[self substringWithRange:search]];

    return result;
}

/**
 @Status Interoperable
*/
- (NSString*)stringByReplacingCharactersInRange:(NSRange)range withString:(NSString*)replacement {
    NSString* ret = [self mutableCopy];
    [ret replaceCharactersInRange:range withString:replacement];
    object_setClass(ret, [NSString class]);

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)target withString:(NSString*)replacement {
    int length = [self length];

    return [self stringByReplacingOccurrencesOfString:target withString:replacement options:0 range:NSMakeRange(0, length)];
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSDiacriticInsensitiveSearch, NSNumericSearch, NSBackwardsSearch,
        and NSRegularExpression are supported.
*/
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)target
                                       withString:(NSString*)replacement
                                          options:(DWORD)options
                                            range:(NSRange)range {
    //  Fastpath - make sure there's something to replace
    if ((options & NSRegularExpressionSearch) == 0) {
        NSRange subrange;

        subrange = [self rangeOfString:target options:options range:range];
        if (subrange.location == NSNotFound) {
            //  Nothing to replace
            if (object_getClass(self) == [CFConstantString class]) {
                return self;
            }

            return [[self copy] autorelease];
        }
    }

    NSString* s = [self mutableCopy];
    [s replaceOccurrencesOfString:target withString:replacement options:options range:range];

    NSString* ret = [[s copy] autorelease];
    [s release];
    return ret;
}

/**
 @Status Interoperable
*/
- (NSString*)stringByTrimmingCharactersInSet:(NSCharacterSet*)charSet {
    UStringHolder s1(self);
    UnicodeString& str1 = s1.string();
    NSUInteger length = str1.length();
    UnicodeSet* set = charSet->_icuSet;

    int32_t start, end;

    start = set->span(str1, 0, USET_SPAN_CONTAINED);
    end = set->spanBack(str1, INT32_MAX, USET_SPAN_CONTAINED);

    if (start == 0 && end == length) {
        //  Nothing to remove
        if (object_getClass(self) == [CFConstantString class]) {
            return self;
        }

        return [[self copy] autorelease];
    }

    if (end < start) {
        end = start;
    }

    return [self substringWithRange:NSMakeRange(start, end - start)];
}

/**
 @Status Interoperable
*/
- (NSRange)rangeOfString:(NSString*)subStr {
    UStringHolder s1(self);

    NSRange checkRange;

    checkRange.location = 0;
    checkRange.length = s1.string().length();

    NSRange ret;
    ret = [self rangeOfString:subStr options:0 range:checkRange];

    return ret;
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSDiacriticInsensitiveSearch, NSNumericSearch, NSBackwardsSearch,
        and NSRegularExpression are supported.
*/
- (NSRange)rangeOfString:(NSString*)subStr options:(DWORD)options {
    UStringHolder s1(self);

    NSRange checkRange;

    checkRange.location = 0;
    checkRange.length = s1.string().length();

    NSRange ret;
    ret = [self rangeOfString:subStr options:options range:checkRange];

    return ret;
}

/**
 @Status Caveat
 @Notes Only NSCaseInsensitiveSearch, NSDiacriticInsensitiveSearch, NSNumericSearch, NSBackwardsSearch,
        and NSRegularExpression are supported.
*/
- (NSRange)rangeOfString:(NSString*)subStr options:(DWORD)options range:(NSRange)range {
    NSRange ret;

    UStringHolder s1(self);
    UStringHolder s2(subStr);

    if (options & NSRegularExpressionSearch) {
        NSRegularExpressionOptions regOptions = 0;
        DWORD searchOptions = 0;

        if (options & NSCaseInsensitiveSearch) {
            regOptions |= NSRegularExpressionCaseInsensitive;
        }
        if (options & NSAnchoredSearch) {
            searchOptions = NSMatchingAnchored;
        }

        NSRegularExpression* regExp = [[NSRegularExpression alloc] initWithPattern:subStr options:regOptions error:NULL];

        ret = [regExp rangeOfFirstMatchInString:self options:searchOptions range:range];
        [regExp release];

        return ret;
    }

    UnicodeString str1 = UnicodeString(s1.string(), range.location, range.length);
    UnicodeString str2 = s2.string();

    if (options == 0 || options == NSLiteralSearch) {
        int loc = str1.indexOf(str2);

        if (loc != -1) {
            ret.location = range.location + loc;
            ret.length = str2.length();
        } else {
            ret.location = NSNotFound;
            ret.length = 0;
            return ret;
        }

        return ret;
    }

    assert((options & (~(NSLiteralSearch | NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch | NSNumericSearch | NSBackwardsSearch |
                         NSAnchoredSearch))) == 0);

    UErrorCode error = U_ZERO_ERROR;
    UStringSearch* search = getSearchForOptions(options);

    usearch_reset(search);
    usearch_setPattern(search, str2.getBuffer(), str2.length(), &error);
    usearch_setText(search, str1.getBuffer(), str1.length(), &error);

    int matchPos = 0, matchLen = 0;

    if (options & NSBackwardsSearch) {
        matchPos = usearch_last(search, &error);
        matchLen = usearch_getMatchedLength(search);
    } else {
        matchPos = usearch_first(search, &error);
        matchLen = usearch_getMatchedLength(search);
    }

    if (matchPos != USEARCH_DONE && matchLen != 0) {
        ret.location = range.location + matchPos;
        ret.length = matchLen;
    } else {
        ret.location = NSNotFound;
        ret.length = 0;
    }

    if (options & NSAnchoredSearch) {
        if (options & NSBackwardsSearch) {
            if (ret.location + ret.length != range.location + range.length) {
                ret.location = NSNotFound;
                ret.length = 0;
            }
        } else {
            if (ret.location != 0) {
                ret.location = NSNotFound;
                ret.length = 0;
            }
        }
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (BOOL)isAbsolutePath {
    char* pStr = (char*)[self UTF8String];

    if (pStr[0] != '/') {
        return FALSE;
    } else {
        return TRUE;
    }
}

/**
 @Status Interoperable
*/
- (NSArray*)pathComponents {
    NSMutableArray* ret = [self componentsSeparatedByString:@"/"];
    ret = [[ret mutableCopy] autorelease];

    int count = [ret count];
    for (int i = 0; i < count; i++) {
        id curObj = [ret objectAtIndex:i];

        if ([curObj length] == 0) {
            if (i > 0) {
                [ret removeObjectAtIndex:i];
                i--;
                count--;
                continue;
            } else {
                [ret replaceObjectAtIndex:0 withObject:@"/"];
            }
        }
    }

    return ret;
}

/**
 @Status Caveat
 @Notes Simply returns UTF8 converison
*/
- (const char*)fileSystemRepresentation {
    return [self UTF8String];
}

/**
 @Status Caveat
 @Notes Simply returns UTF8 converison
*/
- (BOOL)getFileSystemRepresentation:(char*)dest maxLength:(DWORD)destMax {
    strncpy_s(dest, destMax, [self UTF8String], destMax);

    return TRUE;
}

/**
 @Status Interoperable
*/
+ (NSString*)pathWithComponents:(NSArray*)components {
    int count = [components count];
    char outStr[1024];

    strcpy_s(outStr, sizeof(outStr), "");

    for (int i = 0; i < count; i++) {
        char* curComponent = (char*)[[components objectAtIndex:i] UTF8String];

        strcat_s(outStr, sizeof(outStr), curComponent);
        if (i < count - 1 && strcmp(curComponent, "/") != 0)
            strcat_s(outStr, sizeof(outStr), "/");
    }

    return [self stringWithCString:outStr];
}

/**
 @Status Caveat
 @Notes Limited encodings supported
*/
- (NSData*)dataUsingEncoding:(NSStringEncoding)encoding {
    UStringHolder s1(self);
    int len = s1.string().length();
    NSUInteger numBytes = 0;

    [self getBytes:NULL maxLength:0x7FFFFFF usedLength:&numBytes encoding:encoding options:0 range:NSMakeRange(0, len) remainingRange:NULL];

    char* pData = (char*)IwMalloc(numBytes);
    [self getBytes:pData maxLength:numBytes usedLength:NULL encoding:encoding options:0 range:NSMakeRange(0, len) remainingRange:NULL];

    NSData* ret = [NSData dataWithBytesNoCopy:pData length:numBytes freeWhenDone:TRUE];

    return ret;
}

/**
 @Status Stub
 @Notes Forwards to dataUsingEncoding:
*/
- (NSData*)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(DWORD)lossy {
    UNIMPLEMENTED();
    assert(encoding == NSASCIIStringEncoding || encoding == NSUTF8StringEncoding);

    return [self dataUsingEncoding:encoding];
}

/**
 @Status Stub
*/
- (NSString*)stringByExpandingTildeInPath {
    UNIMPLEMENTED();
    return self;
}

/**
 @Status Interoperable
*/
- (NSString*)stringByStandardizingPath {
    NSMutableArray* components = [NSMutableArray arrayWithArray:[self componentsSeparatedByString:@"/"]];
    int componentsCount = [components count];
    int lastComponentLen = 0;

    int count = [components count];
    for (int i = 0; i < count; i++) {
        id curObj = [components objectAtIndex:i];
        char* pComponent = (char*)[curObj UTF8String];
        int componentLength = strlen(pComponent);

        if (componentLength == 0) {
            if (i == 0) {
                [components replaceObjectAtIndex:i withObject:@"/"];
                lastComponentLen = componentLength;
                continue;
            }

            if (lastComponentLen == 0) {
                [components removeObjectAtIndex:i];
                i--;
                count--;
                lastComponentLen = componentLength;
                continue;
            }
        }
        lastComponentLen = componentLength;

        if (strcmp(pComponent, ".") == 0) {
            [components removeObjectAtIndex:i];
            i--;
            count--;
            continue;
        }
    }

    return [NSString pathWithComponents:components];
}

/**
 @Status Interoperable
*/
- (Class)classForCoder {
    return [NSString class];
}

/**
 @Status Interoperable
*/
- (NSMutableString*)mutableCopy {
    return [[NSMutableString alloc] initWithString:self];
}

id error(id obj, char* buf, char* error, ...) {
    TraceError(TAG, L"propertyListFromStrings error: %hs", buf);
    // assert(0);

    return nil;
}

typedef unsigned short unichar;

static unichar SwapWord(unichar c) {
    return (c >> 8) | ((c & 0xFF) << 8);
}

static unichar PickWord(unichar c) {
    return c;
}

/**
 @Status Interoperable
*/
- (NSDictionary*)propertyListFromStringsFileFormat {
    NSMutableDictionary* ret = [objc_getClass("NSMutableDictionary") new];
    DWORD length = [self length];

    NSString* key;
    id value;

    UStringHolder s1(self);
    unsigned int index, c, strSize = 0, strMax = 2048;
    char* strBuf = (char*)IwMalloc(strMax);

    enum {
        STATE_WHITESPACE,
        STATE_COMMENT_SLASH,
        STATE_COMMENT_EOL,
        STATE_COMMENT,
        STATE_COMMENT_STAR,
        STATE_STRING,
        STATE_STRING_KEY,
        STATE_STRING_SLASH,
        STATE_STRING_SLASH_X00,
        STATE_STRING_SLASH_XX0
    } state = STATE_WHITESPACE;
    enum { EXPECT_KEY, EXPECT_EQUAL_SEMI, EXPECT_VAL, EXPECT_SEMI } expect = EXPECT_KEY;

    unichar (*mapUC)(unichar);
    if (s1.getChar(0) == 0xFFFE) {
        // reverse endianness
        mapUC = SwapWord;
        index = 1;
    } else if (s1.getChar(0) == 0xFEFF) {
        // native endianness
        mapUC = PickWord;
        index = 1;
    } else {
        // no BOM, assume native endianness
        mapUC = PickWord;
        index = 0;
    }

    if (mapUC(s1.getChar(length - 1)) == 0x0A)
        length--;

    for (; index < length; index++) {
        c = mapUC(s1.getChar(index));
        switch (state) {
            case STATE_WHITESPACE:
                if (c == '/') {
                    state = STATE_COMMENT_SLASH;
                } else if (c == '=') {
                    if (expect == EXPECT_EQUAL_SEMI) {
                        expect = EXPECT_VAL;
                    } else {
                        return error(ret, strBuf, "unexpected character %02X '%c' at %d", c, c, index);
                    }
                } else if (c == ';') {
                    if (expect == EXPECT_SEMI) {
                        [ret setValue:value forKey:key];
                        value = nil;
                        key = nil;
                        expect = EXPECT_KEY;
                    } else if (expect == EXPECT_EQUAL_SEMI) {
                        expect = EXPECT_KEY;
                        assert(0);
                        //[array addObject:[array lastObject]];
                    } else {
                        return error(ret, strBuf, "unexpected character %02X '%c' at %d", c, c, index);
                    }
                } else if (c == '\"') {
                    if (expect != EXPECT_KEY && expect != EXPECT_VAL) {
                        return error(ret, strBuf, "unexpected character %02X '%c' at %d", c, c, index);
                    }

                    strSize = 0;
                    state = STATE_STRING;
                } else if (c > ' ') {
                    if (expect != EXPECT_KEY) {
                        return error(ret, strBuf, "unexpected character %02X '%c' at %d", c, c, index);
                    }

                    strBuf[0] = c;
                    strSize = 1;
                    state = STATE_STRING_KEY;
                }
                break;

            case STATE_COMMENT_SLASH:
                if (c == '*') {
                    state = STATE_COMMENT;
                } else if (c == '/') {
                    state = STATE_COMMENT_EOL;
                } else {
                    return error(ret, strBuf, "unexpected character %02X '%c',after /", c, c);
                }
                break;

            case STATE_COMMENT_EOL:
                if (c == 0x0A) {
                    state = STATE_WHITESPACE;
                }

            case STATE_COMMENT:
                if (c == '*') {
                    state = STATE_COMMENT_STAR;
                }
                break;

            case STATE_COMMENT_STAR:
                if (c == '/') {
                    state = STATE_WHITESPACE;
                } else if (c != '*') {
                    state = STATE_COMMENT;
                }
                break;

            case STATE_STRING_KEY:
                switch (c) {
                    case '\"':
                        return error(ret, strBuf, "unexpected character %02X '%c' at %d", c, c, index);
                    case '=':
                        index -= 2;
                    case ' ':
                        c = '\"';
                }

            case STATE_STRING:
                if (c == '\"') {
                    strBuf[strSize] = '\0';

                    NSString* string = [NSString stringWithUTF8String:strBuf];
                    if (expect == EXPECT_KEY) {
                        key = string;
                    } else {
                        value = string;
                    }

                    state = STATE_WHITESPACE;

                    if (expect == EXPECT_KEY) {
                        expect = EXPECT_EQUAL_SEMI;
                    } else {
                        expect = EXPECT_SEMI;
                    }
                } else {
                    if (strSize >= strMax) {
                        strMax *= 2;
                        strBuf = (char*)IwRealloc(strBuf, strMax);
                    }
                    if (c == '\\') {
                        state = STATE_STRING_SLASH;
                    } else {
                        //  [NOTE: Convert to UTF8 here!]
                        strBuf[strSize] = c;
                        strSize++;
                    }
                }
                break;

            case STATE_STRING_SLASH:
                switch (c) {
                    case 'a':
                        strBuf[strSize++] = '\a';
                        state = STATE_STRING;
                        break;
                    case 'b':
                        strBuf[strSize++] = '\b';
                        state = STATE_STRING;
                        break;
                    case 'f':
                        strBuf[strSize++] = '\f';
                        state = STATE_STRING;
                        break;
                    case 'n':
                        strBuf[strSize++] = '\n';
                        state = STATE_STRING;
                        break;
                    case 'r':
                        strBuf[strSize++] = '\r';
                        state = STATE_STRING;
                        break;
                    case 't':
                        strBuf[strSize++] = '\t';
                        state = STATE_STRING;
                        break;
                    case 'v':
                        strBuf[strSize++] = '\v';
                        state = STATE_STRING;
                        break;
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                        strBuf[strSize++] = c - '0';
                        state = STATE_STRING_SLASH_X00;
                        break;

                    default:
                        strBuf[strSize++] = c;
                        state = STATE_STRING;
                        break;
                }
                break;

            case STATE_STRING_SLASH_X00:
                if (c < '0' || c > '7') {
                    state = STATE_STRING;
                    index--;
                } else {
                    state = STATE_STRING_SLASH_XX0;
                    strBuf[strSize - 1] *= 8;
                    strBuf[strSize - 1] += c - '0';
                }
                break;

            case STATE_STRING_SLASH_XX0:
                state = STATE_STRING;
                if (c < '0' || c > '7') {
                    index--;
                } else {
                    strBuf[strSize - 1] *= 8;
                    strBuf[strSize - 1] += c - '0';
                }
                break;
        }
    }

    IwFree(strBuf);

    if (state != STATE_WHITESPACE) {
        return error(ret, NULL, "unexpected EOF\n");
    }

    switch (expect) {
        case EXPECT_EQUAL_SEMI:
            return error(ret, NULL, "unexpected EOF, expecting = or ;");

        case EXPECT_VAL:
            return error(ret, NULL, "unexpected EOF, expecting value");

        case EXPECT_SEMI:
            return error(ret, NULL, "unexpected EOF, expecting ;");

        default:
            break;
    }

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (unsigned)hash {
    if (strType == NSConstructedString_Unicode && u->ConstructedString._hashIsCached) {
        return u->ConstructedString._hashCache;
    }

    UStringHolder s1(self);

    DWORD hash = s1.string().hashCode();
    if (strType == NSConstructedString_Unicode) {
        u->ConstructedString._hashIsCached = TRUE;
        u->ConstructedString._hashCache = hash;
    }

    return hash;
}

/**
 @Status Interoperable
*/
- (NSString*)stringByPaddingToLength:(int)length withString:(NSString*)withString startingAtIndex:(int)atIndex {
    UStringHolder s1(self);

    NSString* ret = [NSString alloc];
    if (length < s1.string().length()) {
        UnicodeString copy = s1.string();
        copy.truncate(length);
        setToUnicode(ret, copy);
        return ret;
    }

    UStringHolder s2(withString);
    int s2Start = atIndex;
    UnicodeString copy = s1.string();
    while (copy.length() < length) {
        if (s2Start != 0) {
            UnicodeString s2Str(s2.string(), (int32_t)atIndex);
            copy.append(s2Str);
        } else {
            copy.append(s2.string());
        }
    }
    copy.truncate(length);
    setToUnicode(ret, copy);

    return [ret autorelease];
}

/**
 @Status Caveat
 @Notes encoding parameter not supported
*/
- (NSString*)stringByAddingPercentEscapesUsingEncoding:(DWORD)encoding {
    NSUInteger i, length = [self length], resultLength = 0;
    unichar* unicode = (unichar*)IwMalloc(length * 2);
    unichar* result = (unichar*)IwMalloc(length * 3 * 2);
    const char* hex = "0123456789ABCDEF";

    [self getCharacters:unicode];

    for (i = 0; i < length; i++) {
        unichar code = unicode[i];

        if ((code <= 0x20) || (code == 0x22) || (code == 0x23) || (code == 0x25) || (code == 0x3C) || (code == 0x3E) || (code == 0x5B) ||
            (code == 0x5C) || (code == 0x5D) || (code == 0x5E) || (code == 0x60) || (code == 0x7B) || (code == 0x7C) || (code == 0x7D)) {
            result[resultLength++] = '%';
            result[resultLength++] = hex[(code >> 4) & 0xF];
            result[resultLength++] = hex[code & 0xF];
        } else {
            result[resultLength++] = code;
        }
    }

    if (length == resultLength) {
        IwFree(unicode);
        IwFree(result);
        return self;
    }

    NSString* ret = [NSString stringWithCharacters:result length:resultLength];
    IwFree(unicode);
    IwFree(result);

    return ret;
}

NSString* s_percentEncodedFormat = @"%%%s%X";
const int s_oneByte = 16;

/**
 @Status Interoperable
*/
- (NSString*)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet*)set {
    NSMutableString* returnValue = [NSMutableString stringWithCapacity:[self length] * 2];

    NSData* dataOfString = [self dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char* bytesOfString = (const unsigned char*)dataOfString.bytes;
    int lastTouchedCharacterIndex = -1;
    int lengthOfBytes = [dataOfString length];

    for (int i = 0; i < lengthOfBytes; i++) {
        const unsigned char currentCharacter = bytesOfString[i];

        // Check if multibyte character. Highest order bit in utf8 indicates surrogate pairs.
        if (currentCharacter & 0x80 || ![set characterIsMember:currentCharacter]) {
            if (lastTouchedCharacterIndex != (i - 1)) {
                // Get a substring based on the bytes offset by the last touched index to the current index
                // Length is the length everything between i and the last encoded character exclusively.
                NSString* part = [[NSString alloc] initWithBytesNoCopy:(void*)(bytesOfString + (lastTouchedCharacterIndex + 1))
                                                                length:(i - (lastTouchedCharacterIndex + 1))
                                                              encoding:NSUTF8StringEncoding
                                                          freeWhenDone:false];

                [returnValue appendString:part];
                [part release];
            }

            lastTouchedCharacterIndex = i;

            // Append "%XX" where XX is the hex representation of the bytes for the current character.
            [returnValue appendFormat:s_percentEncodedFormat, (currentCharacter < s_oneByte ? "0" : ""), currentCharacter];
        }
    }

    // If we haven't encoded anything.
    if (lastTouchedCharacterIndex == -1) {
        return [[self retain] autorelease];
    } else if (lastTouchedCharacterIndex != lengthOfBytes - 1) {
        // Get the rest of the characters that weren't encoded.
        // Length is the length everything between i and the last encoded character exclusively.
        NSString* part = [[NSString alloc] initWithBytesNoCopy:(void*)(bytesOfString + (lastTouchedCharacterIndex + 1))
                                                        length:(lengthOfBytes - (lastTouchedCharacterIndex + 1))
                                                      encoding:NSUTF8StringEncoding
                                                  freeWhenDone:false];

        [returnValue appendString:part];
        [part release];
    }

    return returnValue;
}

/**
 @Status Caveat
 @Notes Only UTF-8 is supported
*/
- (NSString*)stringByReplacingPercentEscapesUsingEncoding:(DWORD)encoding {
    return (NSString*)[CFURLCreateStringByReplacingPercentEscapesUsingEncoding(nullptr,
                                                                               reinterpret_cast<CFStringRef>(self),
                                                                               nullptr,
                                                                               CFStringConvertNSStringEncodingToEncoding(encoding))
        autorelease];
}

/**
 @Status Interoperable
*/
- (NSString*)stringByRemovingPercentEncoding {
    // This method always replaces the percent encoded characters with matching UTF8 characters.
    // Call stringByReplacingPercentEscapesUsingEncoding with NSUTF8StringEncoding option to
    // to perform the conversion.
    return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

/**
 @Status Stub
*/
- (BOOL)canBeConvertedToEncoding:(DWORD)encoding {
    UNIMPLEMENTED();
    return TRUE; //  [BUG: Blatant lie]
}

/**
 @Status Interoperable
*/
- (NSRange)lineRangeForRange:(NSRange)range {
    NSRange ret;
    int length = [self length];
    UStringHolder s1(self);

    //  Scan backwards for cr/lf
    int start = range.location;

    while (start > 0) {
        int c = s1.getChar(start);

        if (c == 10 || c == 13) {
            if (start != range.location)
                start++;
            break;
        }

        start--;
    }

    ret.location = start;

    //  Scan forward for cr/lf
    int end = range.location + range.length;

    while (end < length) {
        int c = s1.getChar(end);

        if (c == 10)
            break;
        if (c == 13) {
            //  Check for crlf
            if (end < length - 1) {
                if (s1.getChar(end + 1) == 10) {
                    end++;
                }
            }
            break;
        }

        end++;
    }

    end++;
    if (end > length)
        end = length;

    ret.length = end - ret.location;

    return ret;
}

/**
 @Status Interoperable
*/
- (void)getParagraphStart:(DWORD*)startp end:(DWORD*)endp contentsEnd:(DWORD*)contentsEndp forRange:(NSRange)range {
    UStringHolder s1(self);
    /*
    Documentation does not specify exact getParagraphStart: behavior, only mentioning it is similar to getLineStart:
    The difference is that getParagraphStart: does not delimit on line terminators 0x0085 and 0x2028
    */
    NSUInteger start = range.location;
    NSUInteger end = NSMaxRange(range);
    NSUInteger contentsEnd = end;
    NSUInteger length = [self length];
    enum { scanning, gotR, done } state = scanning;

    for (; start != 0; start--) {
        unichar check = s1.getChar(start - 1);

        if (check == 0x2028 || check == 0x000A || check == 0x2029)
            break;

        if (check == 0x000D && s1.getChar(start) != 0x000A)
            break;
    }

    for (; end < length && state != done; end++) {
        unichar check = s1.getChar(end);

        if (state == scanning) {
            if (check == 0x000D) {
                contentsEnd = end;
                state = gotR;
            } else if (check == 0x000A || check == 0x2029) {
                contentsEnd = end;
                state = done;
            }
        } else if (state == gotR) {
            if (check != 0x000A) {
                end--;
            }
            state = done;
        }
    }

    if ((end >= length) && (state != done)) {
        contentsEnd = end;
    }

    if (startp) {
        *startp = start;
    }
    if (endp) {
        *endp = end;
    }
    if (contentsEndp) {
        *contentsEndp = contentsEnd;
    }
}

/**
 @Status Stub
*/
- (NSString*)precomposedStringWithCanonicalMapping {
    UNIMPLEMENTED();
    TraceVerbose(TAG, L"precomposedStringWithCanonicalMapping??");
    return [self retain];
}

/**
 @Status Caveat
 @Notes Only NSStringEnumerationByWords supported
*/
- (void)enumerateSubstringsInRange:(NSRange)range options:(DWORD)options usingBlock:(id)usingBlock {
    switch (options) {
        case NSStringEnumerationByWords: {
            UErrorCode status = U_ZERO_ERROR;
            BreakIterator* wordIterator = getWordIterator();
            UnicodeSet* letters = lettersSet();
            UStringHolder holder(self, range.location, range.length);
            UnicodeString text = holder.string();
            wordIterator->setText(text);

            int lastIterationStart = 0;
            int lastWordStart = -1;
            int lastWordEnd = -1;
            int32_t start = wordIterator->first();
            BOOL stop = FALSE;

            for (int32_t end = wordIterator->next(); end != BreakIterator::DONE; start = end, end = wordIterator->next()) {
                UnicodeString word;
                text.extractBetween(start, end, word);

                if (letters->containsSome(word)) {
                    if (lastWordStart != -1) {
                        NSRange substringRange, enclosingRange;

                        substringRange.location = range.location + lastWordStart;
                        substringRange.length = lastWordEnd - lastWordStart;
                        enclosingRange.location = range.location + lastIterationStart;
                        enclosingRange.length = start - lastIterationStart;
                        UnicodeString subword;
                        text.extractBetween(lastWordStart, lastWordEnd, subword);

                        NSString* wordStr = [NSString alloc];
                        setToUnicode(wordStr, subword);

//  [HACK: On win32 we have to reverse the order of the parameters that will be pushed onto the stack]
#ifdef WIN32
                        EbrCall(usingBlock[3],
                                "ddddddd",
                                usingBlock,
                                (id)wordStr,
                                substringRange,
                                &stop,
                                enclosingRange.length,
                                enclosingRange.location);
#else
                        // EbrCall(usingBlock[3], "ddddddd", usingBlock, (id) wordStr, substringRange, enclosingRange,
                        // &stop);
                        assert(0);
#endif
                        [wordStr release];

                        lastIterationStart = start;
                    }

                    lastWordStart = start;
                    lastWordEnd = end;
                }

                if (stop)
                    break;
            }

            if (!stop) {
                if (lastWordStart != -1) {
                    NSRange substringRange, enclosingRange;

                    substringRange.location = range.location + lastWordStart;
                    substringRange.length = lastWordEnd - lastWordStart;
                    enclosingRange.location = range.location + lastIterationStart;
                    enclosingRange.length = start - lastIterationStart;
                    UnicodeString subword;
                    text.extractBetween(lastWordStart, lastWordEnd, subword);

                    NSString* wordStr = [NSString alloc];
                    setToUnicode(wordStr, subword);

//  [HACK: On win32 we have to reverse the order of the parameters that will be pushed onto the stack]
#ifdef WIN32
                    EbrCall(E2H(usingBlock)[3],
                            "ddddddd",
                            usingBlock,
                            (id)wordStr,
                            substringRange,
                            H2E(&stop),
                            enclosingRange.length,
                            enclosingRange.location);
#else
                    // EbrCall(E2H(usingBlock)[3], "ddddddd", usingBlock, (id) wordStr, substringRange, enclosingRange,
                    // H2E(&stop));
                    assert(0);
#endif
                    [wordStr release];
                }
            }
            wordIterator->setText(UnicodeString());
        } break;

        default:
            assert(0);
            break;
    }
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    switch (strType) {
        case NSConstructedString_NoOwn:
            if (u->NoOwnString._freeWhenDone) {
                IwFree(u->NoOwnString._address);
            }
            break;

        case NSConstructedString_Unicode:
            if (u->ConstructedString._placementAllocated) {
                u->ConstructedString.constructedStr->str->~UnicodeString();
                u->ConstructedString.constructedStr->~_ConstructedStringData();
            } else {
                delete u->ConstructedString.constructedStr->str;
                delete u->ConstructedString.constructedStr;
                u->ConstructedString.constructedStr = NULL;
            }
            break;
    }

    [super dealloc];
}

/**
 @Status Interoperable
*/
- (BOOL)boolValue {
    UStringHolder s1(self);
    int len = s1.string().length();

    for (int i = 0; i < len; i++) {
        int c = s1.getChar(i);

        if (c == ' ' || c == '\t' || c == '\r' || c == '+' || c == '-') {
            continue;
        }

        switch (c) {
            case 'Y':
            case 'y':
            case 'T':
            case 't':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                return TRUE;

            default:
                return FALSE;
        }
    }

    return FALSE;
}

//  Note: locale ignored

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithFormat:(NSString*)format locale:(id)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithFormat:(NSString*)format locale:(id)locale arguments:(va_list)argList {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (id)initWithCStringNoCopy:(char*)bytes length:(NSUInteger)length freeWhenDone:(BOOL)freeBuffer {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithContentsOfURL:(NSURL*)url encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (instancetype)stringWithContentsOfURL:(NSURL*)url usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithContentsOfURL:(NSURL*)url usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (id)initWithContentsOfURL:(NSURL*)url {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)writeToURL:(NSURL*)url atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)writeToURL:(NSURL*)url atomically:(BOOL)atomically {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)maximumLengthOfBytesUsingEncoding:(NSStringEncoding)enc {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (const char*)cString {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (const char*)lossyCString {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)cStringLength {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)getCString:(char*)bytes maxLength:(NSUInteger)maxLength range:(NSRange)aRange remainingRange:(NSRangePointer)leftoverRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)rangeOfString:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)aRange locale:(NSLocale*)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)enumerateLinesUsingBlock:(void (^)(NSString*, BOOL*))block {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)getLineStart:(NSUInteger*)startIndex
                 end:(NSUInteger*)lineEndIndex
         contentsEnd:(NSUInteger*)contentsEndIndex
            forRange:(NSRange)aRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)paragraphRangeForRange:(NSRange)aRange {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)anIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)rangeOfComposedCharacterSequencesForRange:(NSRange)range {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (id)propertyList {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSComparisonResult)compare:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)range locale:(id)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSComparisonResult)localizedStandardCompare:(NSString*)string {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)stringByFoldingWithOptions:(NSStringCompareOptions)options locale:(NSLocale*)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)commonPrefixWithString:(NSString*)aString options:(NSStringCompareOptions)mask {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)capitalizedStringWithLocale:(NSLocale*)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)lowercaseStringWithLocale:(NSLocale*)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)uppercaseStringWithLocale:(NSLocale*)locale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)completePathIntoString:(NSString* _Nonnull*)outputName
                       caseSensitive:(BOOL)flag
                    matchesIntoArray:(NSArray* _Nonnull*)outputArray
                         filterTypes:(NSArray*)filterTypes {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSArray*)stringsByAppendingPaths:(NSArray*)paths {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)enumerateLinguisticTagsInRange:(NSRange)range
                                scheme:(NSString*)tagScheme
                               options:(NSLinguisticTaggerOptions)opts
                           orthography:(NSOrthography*)orthography
                            usingBlock:(void (^)(NSString*, NSRange, NSRange, BOOL*))block {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (NSArray*)linguisticTagsInRange:(NSRange)range
                           scheme:(NSString*)tagScheme
                          options:(NSLinguisticTaggerOptions)opts
                      orthography:(NSOrthography*)orthography
                      tokenRanges:(NSArray* _Nullable*)tokenRanges {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (instancetype)localizedStringWithFormat:(NSString*)format {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (const NSStringEncoding*)availableStringEncodings {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (NSString*)localizedNameOfStringEncoding:(NSStringEncoding)encoding {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (id)mutableCopyWithZone:(NSZone*)zone {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (BOOL)supportsSecureCoding {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    UNIMPLEMENTED();
}

@end

NSString* NSStringFromICU(const icu_48::UnicodeString& str) {
    std::string realStr;
    str.toUTF8String(realStr);
    return [NSString stringWithUTF8String:realStr.c_str()];
}
