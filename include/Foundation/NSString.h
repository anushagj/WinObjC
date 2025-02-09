//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
// Copyright (c) 2006-2007 Christopher J. W. Lloyd
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
#pragma once

#import <Foundation/FoundationExport.h>
#import <Foundation/NSObject.h>

#import <Foundation/NSLinguisticTagger.h>
@class NSString;
@class NSData;
@class NSError;
@class NSURL;
@class NSArray;
@class NSCharacterSet;
@class NSLocale;
@class NSDictionary;
@class NSOrthography;

typedef unsigned short unichar;

enum {
    NSStringEnumerationByLines = 0,
    NSStringEnumerationByParagraphs = 1,
    NSStringEnumerationByComposedCharacterSequences = 2,
    NSStringEnumerationByWords = 3,
    NSStringEnumerationBySentences = 4,
    NSStringEnumerationReverse = 1UL << 8,
    NSStringEnumerationSubstringNotRequired = 1UL << 9,
    NSStringEnumerationLocalized = 1UL << 10
};

#define NSMaximumStringLength (INT_MAX - 1)

enum {
    NSCaseInsensitiveSearch = 1,
    NSLiteralSearch = 2,
    NSBackwardsSearch = 4,
    NSAnchoredSearch = 8,
    NSNumericSearch = 64,
    NSDiacriticInsensitiveSearch = 128,
    NSWidthInsensitiveSearch = 256,
    NSForcedOrderingSearch = 512,
    NSRegularExpressionSearch = 1024
};

enum { NSStringEncodingConversionAllowLossy = 1, NSStringEncodingConversionExternalRepresentation = 2 };

FOUNDATION_EXPORT NSString* const NSParseErrorException;
FOUNDATION_EXPORT NSString* const NSCharacterConversionException;

enum : unsigned int {
    NSASCIIStringEncoding = 1,
    NSNEXTSTEPStringEncoding = 2,
    NSJapaneseEUCStringEncoding = 3,
    NSUTF8StringEncoding = 4,
    NSISOLatin1StringEncoding = 5,
    NSSymbolStringEncoding = 6,
    NSNonLossyASCIIStringEncoding = 7,
    NSShiftJISStringEncoding = 8,
    NSISOLatin2StringEncoding = 9,
    NSUnicodeStringEncoding = 10,
    NSWindowsCP1251StringEncoding = 11,
    NSWindowsCP1252StringEncoding = 12,
    NSWindowsCP1253StringEncoding = 13,
    NSWindowsCP1254StringEncoding = 14,
    NSWindowsCP1250StringEncoding = 15,
    NSISO2022JPStringEncoding = 21,
    NSMacOSRomanStringEncoding = 30,
    NSUTF16StringEncoding = NSUnicodeStringEncoding,
    NSUTF16BigEndianStringEncoding = 0x90000100,
    NSUTF16LittleEndianStringEncoding = 0x94000100,
    NSUTF32StringEncoding = 0x8c000100,
    NSUTF32BigEndianStringEncoding = 0x98000100,
    NSUTF32LittleEndianStringEncoding = 0x9c000100,
    NSProprietaryStringEncoding = 65536
};

typedef NSUInteger NSStringEnumerationOptions;
typedef NSUInteger NSStringEncoding;
typedef NSUInteger NSStringEncodingConversionOptions;
typedef NSUInteger NSStringCompareOptions;

struct _ConstructedStringData;
struct _ConstructedStringType {
    uint8_t _hashIsCached;
    uint8_t _placementAllocated;
    uint8_t align;
    struct _ConstructedStringData* constructedStr;
    uint32_t _hashCache;
};
struct _NoOwnStringType {
    uint8_t _freeWhenDone;
    uint8_t align[2];
    void* _address;
    uint32_t _length;
    uint32_t _encoding;
};

FOUNDATION_EXPORT_CLASS
@interface NSString : NSObject <NSCopying, NSMutableCopying, NSSecureCoding> {
@public
    union stringData {
        struct _ConstructedStringType ConstructedString;
        struct _NoOwnStringType NoOwnString;
    } * u;
    uint32_t strType;
}

+ (instancetype)string;
- (instancetype)init;
- (instancetype)initWithBytes:(const void*)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding;
- (instancetype)initWithBytesNoCopy:(void*)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding freeWhenDone:(BOOL)flag;
- (instancetype)initWithCharacters:(const unichar*)characters length:(NSUInteger)length;
- (instancetype)initWithCharactersNoCopy:(unichar*)characters length:(NSUInteger)length freeWhenDone:(BOOL)flag;
- (instancetype)initWithString:(NSString*)aString;
- (instancetype)initWithCString:(const char*)nullTerminatedCString encoding:(NSStringEncoding)encoding;
- (instancetype)initWithUTF8String:(const char*)bytes;
- (instancetype)initWithFormat:(NSString*)format, ...;
- (instancetype)initWithFormat:(NSString*)format arguments:(va_list)argList;
- (instancetype)initWithFormat:(NSString*)format locale:(id)locale, ... STUB_METHOD;
- (instancetype)initWithFormat:(NSString*)format locale:(id)locale arguments:(va_list)argList STUB_METHOD;
- (instancetype)initWithData:(NSData*)data encoding:(NSStringEncoding)encoding;
+ (instancetype)stringWithFormat:(NSString*)format, ...;
+ (instancetype)localizedStringWithFormat:(NSString*)format, ... STUB_METHOD;
+ (instancetype)stringWithCharacters:(const unichar*)chars length:(NSUInteger)length;
+ (instancetype)stringWithString:(NSString*)aString;
+ (instancetype)stringWithCString:(const char*)cString encoding:(NSStringEncoding)enc;
+ (instancetype)stringWithUTF8String:(const char*)bytes;
+ (id)stringWithCString:(const char*)bytes;
- (id)initWithCString:(const char*)bytes;
+ (id)stringWithCString:(const char*)bytes length:(NSUInteger)length;
- (id)initWithCString:(const char*)bytes length:(NSUInteger)length;
- (id)initWithCStringNoCopy:(char*)bytes length:(NSUInteger)length freeWhenDone:(BOOL)freeBuffer STUB_METHOD;
+ (instancetype)stringWithContentsOfFile:(NSString*)path encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error;
- (instancetype)initWithContentsOfFile:(NSString*)path encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error;
+ (instancetype)stringWithContentsOfFile:(NSString*)path usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error;
- (instancetype)initWithContentsOfFile:(NSString*)path usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error;
+ (id)stringWithContentsOfFile:(NSString*)path;
- (id)initWithContentsOfFile:(NSString*)path;
+ (instancetype)stringWithContentsOfURL:(NSURL*)url encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error STUB_METHOD;
- (instancetype)initWithContentsOfURL:(NSURL*)url encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error STUB_METHOD;
+ (instancetype)stringWithContentsOfURL:(NSURL*)url usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error STUB_METHOD;
- (instancetype)initWithContentsOfURL:(NSURL*)url usedEncoding:(NSStringEncoding*)enc error:(NSError* _Nullable*)error STUB_METHOD;
+ (id)stringWithContentsOfURL:(NSURL*)url STUB_METHOD;
- (id)initWithContentsOfURL:(NSURL*)url STUB_METHOD;
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError* _Nullable*)error;
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile STUB_METHOD;
- (BOOL)writeToURL:(NSURL*)url
        atomically:(BOOL)useAuxiliaryFile
          encoding:(NSStringEncoding)enc
             error:(NSError* _Nullable*)error STUB_METHOD;
- (BOOL)writeToURL:(NSURL*)url atomically:(BOOL)atomically STUB_METHOD;
@property (readonly) NSUInteger length;
- (NSUInteger)lengthOfBytesUsingEncoding:(NSStringEncoding)enc;
- (NSUInteger)maximumLengthOfBytesUsingEncoding:(NSStringEncoding)enc STUB_METHOD;
- (unichar)characterAtIndex:(NSUInteger)index;
- (void)getCharacters:(unichar*)buffer;
- (void)getCharacters:(unichar*)buffer range:(NSRange)aRange;
- (BOOL)getBytes:(void*)buffer
       maxLength:(NSUInteger)maxBufferCount
      usedLength:(NSUInteger*)usedBufferCount
        encoding:(NSStringEncoding)encoding
         options:(NSStringEncodingConversionOptions)options
           range:(NSRange)range
  remainingRange:(NSRangePointer)leftover;
- (const char*)cStringUsingEncoding:(NSStringEncoding)encoding;
- (BOOL)getCString:(char*)buffer maxLength:(NSUInteger)maxBufferCount encoding:(NSStringEncoding)encoding;
@property (readonly) const char* UTF8String;
- (const char*)cString STUB_METHOD;
- (const char*)lossyCString STUB_METHOD;
- (NSUInteger)cStringLength STUB_METHOD;
- (void)getCString:(char*)bytes;
- (void)getCString:(char*)bytes maxLength:(NSUInteger)maxLength;
- (void)getCString:(char*)bytes
         maxLength:(NSUInteger)maxLength
             range:(NSRange)aRange
    remainingRange:(NSRangePointer)leftoverRange STUB_METHOD;
- (NSString*)stringByAppendingFormat:(NSString*)format, ...;
- (NSString*)stringByAppendingString:(NSString*)aString;
- (NSString*)stringByPaddingToLength:(NSUInteger)newLength withString:(NSString*)padString startingAtIndex:(NSUInteger)padIndex;
- (NSArray*)componentsSeparatedByString:(NSString*)separator;
- (NSArray*)componentsSeparatedByCharactersInSet:(NSCharacterSet*)separator;
- (NSString*)stringByTrimmingCharactersInSet:(NSCharacterSet*)set;
- (NSString*)substringFromIndex:(NSUInteger)anIndex;
- (NSString*)substringWithRange:(NSRange)aRange;
- (NSString*)substringToIndex:(NSUInteger)anIndex;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet options:(NSStringCompareOptions)mask;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet options:(NSStringCompareOptions)mask range:(NSRange)aRange;
- (NSRange)rangeOfString:(NSString*)aString;
- (NSRange)rangeOfString:(NSString*)aString options:(NSStringCompareOptions)mask;
- (NSRange)rangeOfString:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)aRange;
- (NSRange)rangeOfString:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)aRange locale:(NSLocale*)locale STUB_METHOD;
- (void)enumerateLinesUsingBlock:(void (^)(NSString*, BOOL*))block STUB_METHOD;
- (void)enumerateSubstringsInRange:(NSRange)range
                           options:(NSStringEnumerationOptions)opts
                        usingBlock:(void (^)(NSString*, NSRange, NSRange, BOOL*))block;
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)target withString:(NSString*)replacement;
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)target
                                       withString:(NSString*)replacement
                                          options:(NSStringCompareOptions)options
                                            range:(NSRange)searchRange;
- (NSString*)stringByReplacingCharactersInRange:(NSRange)range withString:(NSString*)replacement;
- (void)getLineStart:(NSUInteger*)startIndex
                 end:(NSUInteger*)lineEndIndex
         contentsEnd:(NSUInteger*)contentsEndIndex
            forRange:(NSRange)aRange STUB_METHOD;
- (NSRange)lineRangeForRange:(NSRange)aRange;
- (void)getParagraphStart:(NSUInteger*)startIndex
                      end:(NSUInteger*)endIndex
              contentsEnd:(NSUInteger*)contentsEndIndex
                 forRange:(NSRange)aRange;
- (NSRange)paragraphRangeForRange:(NSRange)aRange STUB_METHOD;
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)anIndex STUB_METHOD;
- (NSRange)rangeOfComposedCharacterSequencesForRange:(NSRange)range STUB_METHOD;
- (id)propertyList STUB_METHOD;
- (NSDictionary*)propertyListFromStringsFileFormat;
- (NSComparisonResult)caseInsensitiveCompare:(NSString*)aString;
- (NSComparisonResult)localizedCaseInsensitiveCompare:(NSString*)aString;
- (NSComparisonResult)compare:(NSString*)aString;
- (NSComparisonResult)localizedCompare:(NSString*)aString;
- (NSComparisonResult)compare:(NSString*)aString options:(NSStringCompareOptions)mask;
- (NSComparisonResult)compare:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)range;
- (NSComparisonResult)compare:(NSString*)aString options:(NSStringCompareOptions)mask range:(NSRange)range locale:(id)locale STUB_METHOD;
- (NSComparisonResult)localizedStandardCompare:(NSString*)string STUB_METHOD;
- (BOOL)hasPrefix:(NSString*)aString;
- (BOOL)hasSuffix:(NSString*)aString;
- (BOOL)isEqualToString:(NSString*)aString;
@property (readonly) NSUInteger hash;
- (NSString*)stringByFoldingWithOptions:(NSStringCompareOptions)options locale:(NSLocale*)locale STUB_METHOD;
- (NSString*)commonPrefixWithString:(NSString*)aString options:(NSStringCompareOptions)mask STUB_METHOD;
@property (readonly, copy) NSString* capitalizedString;
- (NSString*)capitalizedStringWithLocale:(NSLocale*)locale STUB_METHOD;
@property (readonly, copy) NSString* lowercaseString;
- (NSString*)lowercaseStringWithLocale:(NSLocale*)locale STUB_METHOD;
@property (readonly, copy) NSString* uppercaseString;
- (NSString*)uppercaseStringWithLocale:(NSLocale*)locale STUB_METHOD;
@property (readonly, copy) NSString* decomposedStringWithCanonicalMapping;
@property (readonly, copy) NSString* decomposedStringWithCompatibilityMapping;
@property (readonly, copy) NSString* precomposedStringWithCanonicalMapping;
@property (readonly, copy) NSString* precomposedStringWithCompatibilityMapping;
@property (readonly) double doubleValue;
@property (readonly) float floatValue;
@property (readonly) int intValue;
@property (readonly) NSInteger integerValue;
@property (readonly) long long longLongValue;
@property (readonly) BOOL boolValue;
+ (const NSStringEncoding*)availableStringEncodings STUB_METHOD;
+ (NSStringEncoding)defaultCStringEncoding;
+ (NSString*)localizedNameOfStringEncoding:(NSStringEncoding)encoding STUB_METHOD;
- (BOOL)canBeConvertedToEncoding:(NSStringEncoding)encoding;
- (NSData*)dataUsingEncoding:(NSStringEncoding)encoding;
- (NSData*)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag;
@property (readonly, copy) NSString* description;
@property (readonly) NSStringEncoding fastestEncoding;
@property (readonly) NSStringEncoding smallestEncoding;
+ (NSString*)pathWithComponents:(NSArray*)components;
@property (readonly, copy) NSArray* pathComponents;
- (NSUInteger)completePathIntoString:(NSString* _Nonnull*)outputName
                       caseSensitive:(BOOL)flag
                    matchesIntoArray:(NSArray* _Nonnull*)outputArray
                         filterTypes:(NSArray*)filterTypes STUB_METHOD;
@property (readonly) const char* fileSystemRepresentation;
- (BOOL)getFileSystemRepresentation:(char*)buffer maxLength:(NSUInteger)maxLength;
@property (readonly, getter=isAbsolutePath) BOOL absolutePath;
@property (readonly, copy) NSString* lastPathComponent;
@property (readonly, copy) NSString* pathExtension;
@property (readonly, copy) NSString* stringByAbbreviatingWithTildeInPath;
- (NSString*)stringByAppendingPathComponent:(NSString*)aString;
- (NSString*)stringByAppendingPathExtension:(NSString*)ext;
@property (readonly, copy) NSString* stringByDeletingLastPathComponent;
@property (readonly, copy) NSString* stringByDeletingPathExtension;
@property (readonly, copy) NSString* stringByExpandingTildeInPath;
@property (readonly, copy) NSString* stringByResolvingSymlinksInPath;
@property (readonly, copy) NSString* stringByStandardizingPath;
- (NSArray*)stringsByAppendingPaths:(NSArray*)paths STUB_METHOD;
- (NSString*)stringByAddingPercentEscapesUsingEncoding:(NSStringEncoding)encoding;
- (NSString*)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)encoding;
- (NSString*)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet*)allowedCharacters;
@property (readonly, copy) NSString* stringByRemovingPercentEncoding;
- (void)enumerateLinguisticTagsInRange:(NSRange)range
                                scheme:(NSString*)tagScheme
                               options:(NSLinguisticTaggerOptions)opts
                           orthography:(NSOrthography*)orthography
                            usingBlock:(void (^)(NSString*, NSRange, NSRange, BOOL*))block STUB_METHOD;
- (NSArray*)linguisticTagsInRange:(NSRange)range
                           scheme:(NSString*)tagScheme
                          options:(NSLinguisticTaggerOptions)opts
                      orthography:(NSOrthography*)orthography
                      tokenRanges:(NSArray* _Nullable*)tokenRanges STUB_METHOD;

// HACKHACK: WinObjC addition
- (const unichar*)rawCharacters;
@end

#if defined(STARBOARD_PORT) && defined(__cplusplus)
namespace icu_48 {
class UnicodeString;
}
class UStringHolder {
private:
    icu_48::UnicodeString *_str, *_destroyStr;
    icu_48::UnicodeString* _subStr;

    void initWithString(NSString* str, int location, int length);

public:
    UStringHolder(NSString* str, int location = 0, int length = -1);
    UStringHolder(id str, int location = 0, int length = -1);
    ~UStringHolder();

    icu_48::UnicodeString& string();
    inline unichar getChar(int index);
};
NSString* NSStringFromICU(const icu_48::UnicodeString& str);
#endif
