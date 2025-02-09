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

#import <Foundation/Foundation.h>
#import <NSLocaleInternal.h>
#import <NSCalendarInternal.h>
#import <NSTimeZoneInternal.h>
#include <unicode/datefmt.h>
#include <unicode/dtfmtsym.h>
#include <unicode/smpdtfmt.h>
#include <unicode/dtptngen.h>

#include <functional>
#include <map>
#include "LoggingNative.h"

static const wchar_t* TAG = L"NSDateFormatter";

static icu::DateFormat::EStyle convertFormatterStyle(NSDateFormatterStyle fmt) {
    switch (fmt) {
        case NSDateFormatterShortStyle:
            return icu::DateFormat::kShort;
        case NSDateFormatterMediumStyle:
            return icu::DateFormat::kMedium;
        case NSDateFormatterLongStyle:
            return icu::DateFormat::kLong;
        case NSDateFormatterFullStyle:
            return icu::DateFormat::kFull;

        default:
            TraceVerbose(TAG, L"Unrecognized formatter style, defaulting to UDAT_NONE.");
        case NSDateFormatterNoStyle:
            return icu::DateFormat::kNone;
    }
}

class ICUPropertyValue {
public:
    bool _boolValue;
    idretaintype(NSObject) _objValue;

    ICUPropertyValue() {
        _boolValue = false;
    }

    ICUPropertyValue(bool boolValue) {
        _boolValue = boolValue;
    }

    ICUPropertyValue(NSObject* obj) {
        _objValue = obj;
    }

    ICUPropertyValue(const ICUPropertyValue& copy) {
        _boolValue = copy._boolValue;
        _objValue = copy._objValue;
    }
};

class ICUPropertyMapper {
public:
    enum PropertyTypes {
        lenient,
        amSymbol,
        pmSymbol,
        shortStandaloneWeekdaySymbols,
        weekdaySymbols,
        shortWeekdaySymbols,
        standaloneWeekdaySymbols,
        standaloneMonthSymbols,
        monthSymbols
    };

private:
    typedef std::function<void(icu::DateFormat*, ICUPropertyValue&, UErrorCode&)> PropertyFunctor;

public:
    PropertyFunctor _setProperty;
    PropertyFunctor _getProperty;
    PropertyTypes _type;

    ICUPropertyMapper() {
    }

    ICUPropertyMapper(const PropertyTypes type, const PropertyFunctor& setter, const PropertyFunctor& getter)
        : _type(type), _setProperty(setter), _getProperty(getter) {
    }

    ICUPropertyMapper(const ICUPropertyMapper& copy) {
        _type = copy._type;
        _getProperty = copy._getProperty;
        _setProperty = copy._setProperty;
    }
};

static NSString* NSStringFromSymbol(icu::DateFormat* formatter, UDateFormatSymbolType symbol, int index, UErrorCode& error) {
    uint32_t len = udat_getSymbols((UDateFormat*)formatter, (UDateFormatSymbolType)symbol, index, NULL, 0, &error);
    UChar* strValue = (UChar*)IwCalloc(len + 1, sizeof(UChar));
    error = U_ZERO_ERROR;
    len = udat_getSymbols((UDateFormat*)formatter, (UDateFormatSymbolType)symbol, index, strValue, len + 1, &error);
    NSString* ret = [NSString stringWithCharacters:(unichar*)strValue length:len];
    IwFree(strValue);

    return ret;
}

static NSArray* NSArrayFromSymbols(icu::DateFormat* formatter, UDateFormatSymbolType symbol, int startIdx, UErrorCode& error) {
    uint32_t count = udat_countSymbols((UDateFormat*)formatter, symbol);

    NSMutableArray* symbolList = [NSMutableArray array];
    for (int i = 0; i < count - startIdx; i++) {
        NSString* string = NSStringFromSymbol(formatter, symbol, i + startIdx, error);
        if (string == nil || error != U_ZERO_ERROR) {
            TraceError(TAG, L"Error retrieving symbol 0x%x index %d", symbol, i);
            return nil;
        }
        [symbolList addObject:string];
    }

    NSArray* ret = [symbolList copy];
    [symbolList release];
    return ret;
}

static void SetSymbolFromNSString(icu::DateFormat* formatter, NSString* value, UDateFormatSymbolType symbol, int index, UErrorCode& error) {
    udat_setSymbols((UDateFormat*)formatter, (UDateFormatSymbolType)symbol, index, (UChar*)[value rawCharacters], [value length], &error);
}

static void SetSymbolsFromNSArray(
    icu::DateFormat* formatter, NSArray* values, UDateFormatSymbolType symbol, int startIdx, UErrorCode& error) {
    for (int i = 0; i < [values count]; i++) {
        NSString* symbolStr = [values objectAtIndex:i];

        udat_setSymbols((UDateFormat*)formatter,
                        (UDateFormatSymbolType)symbol,
                        i + startIdx,
                        (UChar*)[symbolStr rawCharacters],
                        [symbolStr length],
                        &error);
    }
}

static std::map<ICUPropertyMapper::PropertyTypes, ICUPropertyMapper> _icuProperties = {
    { ICUPropertyMapper::lenient,
      ICUPropertyMapper(ICUPropertyMapper::lenient,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            udat_setLenient((UDateFormat*)formatter, value._boolValue);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._boolValue = udat_isLenient((UDateFormat*)formatter);
                        }) },

    { ICUPropertyMapper::amSymbol,
      ICUPropertyMapper(ICUPropertyMapper::amSymbol,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolFromNSString(formatter, (NSString*)value._objValue, (UDateFormatSymbolType)UDAT_AM_PMS, 0, error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSStringFromSymbol(formatter, (UDateFormatSymbolType)UDAT_AM_PMS, 0, error);
                        }) },

    { ICUPropertyMapper::pmSymbol,
      ICUPropertyMapper(ICUPropertyMapper::pmSymbol,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolFromNSString(formatter, (NSString*)value._objValue, (UDateFormatSymbolType)UDAT_AM_PMS, 1, error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSStringFromSymbol(formatter, (UDateFormatSymbolType)UDAT_AM_PMS, 1, error);
                        }) },

    { ICUPropertyMapper::shortStandaloneWeekdaySymbols,
      ICUPropertyMapper(ICUPropertyMapper::shortStandaloneWeekdaySymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter,
                                                  (NSArray*)value._objValue,
                                                  (UDateFormatSymbolType)UDAT_STANDALONE_SHORT_WEEKDAYS,
                                                  1,
                                                  error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue =
                                NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_STANDALONE_SHORT_WEEKDAYS, 1, error);
                        }) },

    { ICUPropertyMapper::weekdaySymbols,
      ICUPropertyMapper(ICUPropertyMapper::weekdaySymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter, (NSArray*)value._objValue, (UDateFormatSymbolType)UDAT_WEEKDAYS, 1, error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_WEEKDAYS, 1, error);
                        }) },

    { ICUPropertyMapper::shortWeekdaySymbols,
      ICUPropertyMapper(ICUPropertyMapper::shortWeekdaySymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter,
                                                  (NSArray*)value._objValue,
                                                  (UDateFormatSymbolType)UDAT_SHORT_WEEKDAYS,
                                                  1,
                                                  error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_SHORT_WEEKDAYS, 1, error);
                        }) },

    { ICUPropertyMapper::standaloneWeekdaySymbols,
      ICUPropertyMapper(ICUPropertyMapper::standaloneWeekdaySymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter,
                                                  (NSArray*)value._objValue,
                                                  (UDateFormatSymbolType)UDAT_STANDALONE_WEEKDAYS,
                                                  1,
                                                  error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_STANDALONE_WEEKDAYS, 1, error);
                        }) },

    { ICUPropertyMapper::standaloneMonthSymbols,
      ICUPropertyMapper(ICUPropertyMapper::standaloneMonthSymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter,
                                                  (NSArray*)value._objValue,
                                                  (UDateFormatSymbolType)UDAT_STANDALONE_MONTHS,
                                                  0,
                                                  error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_STANDALONE_MONTHS, 0, error);
                        }) },

    { ICUPropertyMapper::monthSymbols,
      ICUPropertyMapper(ICUPropertyMapper::monthSymbols,
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            SetSymbolsFromNSArray(formatter, (NSArray*)value._objValue, (UDateFormatSymbolType)UDAT_MONTHS, 0, error);
                        },
                        [](icu::DateFormat* formatter, ICUPropertyValue& value, UErrorCode& error) {
                            value._objValue = NSArrayFromSymbols(formatter, (UDateFormatSymbolType)UDAT_MONTHS, 0, error);
                        }) },
};

@implementation NSDateFormatter {
    NSDateFormatterStyle _dateStyle;
    NSDateFormatterStyle _timeStyle;
    idretaintype(NSString) _dateFormat;
    BOOL _lenient, _lenientSet;
    idretaintype(NSLocale) _locale;
    idretaintype(NSTimeZone) _timeZone;
    idretaintype(NSCalendar) _calendar;

    icu::DateFormat* _formatter;
    BOOL _formatterNeedsRebuilding;

    std::map<ICUPropertyMapper::PropertyTypes, ICUPropertyValue> _valueOverrides;
}

/**
 @Status Caveat
 @Notes options parameter not supported
*/
+ (NSString*)dateFormatFromTemplate:(NSString*)dateTemplate options:(NSUInteger)options locale:(NSLocale*)locale {
    UErrorCode error = U_ZERO_ERROR;
    icu::Locale* icuLocale = [locale _createICULocale];
    DateTimePatternGenerator* pg = DateTimePatternGenerator::createInstance(*icuLocale, error);
    delete icuLocale;
    UStringHolder strTemplate(dateTemplate);

    UnicodeString strSkeleton = pg->getSkeleton(strTemplate.string(), error);
    if (U_FAILURE(error)) {
        delete pg;
        return nil;
    }

    UnicodeString pattern = pg->getBestPattern(strSkeleton, error);
    if (U_FAILURE(error)) {
        delete pg;
        return nil;
    }

    NSString* ret = NSStringFromICU(pattern);

    delete pg;

    return ret;
}

- (ICUPropertyValue)_getFormatterProperty:(ICUPropertyMapper::PropertyTypes)type {
    auto pos = _valueOverrides.find(type);
    if (pos != _valueOverrides.end()) {
        return pos->second;
    } else {
        ICUPropertyValue ret;

        UErrorCode status = U_ZERO_ERROR;
        _icuProperties[type]._getProperty([self _getFormatter], ret, status);

        return ret;
    }
}

- (void)_setFormatterProperty:(ICUPropertyMapper::PropertyTypes)type withValue:(ICUPropertyValue)value {
    _valueOverrides[type] = value;
    _formatterNeedsRebuilding = TRUE;
}

static NSDateFormatterBehavior s_defaultFormatterBehavior = NSDateFormatterBehaviorDefault;

/**
 @Status Stub
*/
+ (NSDateFormatterBehavior)defaultFormatterBehavior {
    return s_defaultFormatterBehavior;
}

/**
 @Status Stub
*/
+ (void)setDefaultFormatterBehavior:(NSDateFormatterBehavior)behavior {
    s_defaultFormatterBehavior = behavior;
}

- (icu::DateFormat*)_getFormatter {
    if (!_formatter || _formatterNeedsRebuilding) {
        _formatterNeedsRebuilding = FALSE;

        if (_formatter)
            delete _formatter;

        UErrorCode status = U_ZERO_ERROR;
        icu::Locale* icuLocale = [_locale _createICULocale];

        if ([_dateFormat length] > 0) {
            UStringHolder fmtString(static_cast<NSString*>(_dateFormat));

            _formatter = new SimpleDateFormat(fmtString.string(), *icuLocale, status);
        } else {
            // Don't instantiate a date/time formatter if only date or time are expected individually.
            if (_timeStyle == NSDateFormatterNoStyle && _dateStyle == NSDateFormatterNoStyle) {
                _formatter = new SimpleDateFormat(NULL, *icuLocale, status);
            } else if (_timeStyle == NSDateFormatterNoStyle) {
                _formatter = icu::DateFormat::createDateInstance(convertFormatterStyle(_dateStyle), *icuLocale);
            } else if (_dateStyle == NSDateFormatterNoStyle) {
                _formatter = icu::DateFormat::createTimeInstance(convertFormatterStyle(_timeStyle), *icuLocale);
            } else {
                _formatter = icu::DateFormat::createDateTimeInstance(convertFormatterStyle(_dateStyle),
                                                                     convertFormatterStyle(_timeStyle),
                                                                     *icuLocale);
            }
        }

        delete icuLocale;

        //  Set calendar
        icu::Calendar* calendar = [_calendar _createICUCalendar];
        _formatter->setCalendar(*calendar);
        delete calendar;

        //  Set all overridden properties
        for (auto& curProperty : _valueOverrides) {
            _icuProperties[curProperty.first]._setProperty(_formatter, curProperty.second, status);
        }

        //  Set timezone
        icu::TimeZone* icuTimezone = [_timeZone _createICUTimeZone];
        _formatter->setTimeZone(*icuTimezone);
        delete icuTimezone;
    }

    return _formatter;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    return [self initWithDateFormat:@"" allowNaturalLanguage:NO];
}

/**
 @Status Interoperable
*/
- (instancetype)copyWithZone:(NSZone*)zone {
    NSDateFormatter* copy = [super copyWithZone:zone];

    copy->_dateStyle = _dateStyle;
    copy->_timeStyle = _timeStyle;
    copy->_dateFormat = _dateFormat;
    copy->_locale = _locale;
    copy->_timeZone = _timeZone;
    copy->_valueOverrides = _valueOverrides;

    return copy;
}

/**
 @Status Caveat
 @Notes allowNaturalLanguage parameter not supported
*/
- (instancetype)initWithDateFormat:(NSString*)format allowNaturalLanguage:(BOOL)flag {
    return [self initWithDateFormat:format allowNaturalLanguage:flag locale:[NSLocale currentLocale]];
}

/**
 @Status Caveat
 @Notes allowNaturalLanguage parameter not supported
*/
- (instancetype)initWithDateFormat:(NSString*)format allowNaturalLanguage:(BOOL)flag locale:(NSLocale*)locale {
    if (flag == YES) {
        [NSException raiseWithLogging:@"NSDateFormatterException" format:@"allowNatrualLanguage = YES not supported"];
    }

    [super init];
    _formatter = 0;
    _dateFormat.attach([format copy]);
    _locale = locale;

    _timeZone = [NSTimeZone defaultTimeZone];
    _calendar = [NSCalendar currentCalendar];

    return self;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    _dateFormat = nil;
    _locale = nil;
    _timeZone = nil;

    if (_formatter)
        delete _formatter;

    return [super dealloc];
}

/**
 @Status Interoperable
*/
- (void)setCalendar:(NSCalendar*)cal {
    if (_calendar == cal)
        return;

    _calendar = cal;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSCalendar*)calendar {
    return _calendar;
}

/**
 @Status Interoperable
*/
- (void)setTimeZone:(NSTimeZone*)zone {
    if (_timeZone == zone)
        return;

    _timeZone = zone;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSTimeZone*)timeZone {
    return _timeZone;
}

/**
 @Status Interoperable
*/
- (void)setLocale:(NSLocale*)locale {
    if (_locale == locale)
        return;

    _locale = locale;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSLocale*)locale {
    return _locale;
}

/**
 @Status Interoperable
*/
- (void)setLenient:(BOOL)lenient {
    [self _setFormatterProperty:ICUPropertyMapper::lenient withValue:ICUPropertyValue(lenient)];
}

/**
 @Status Interoperable
*/
- (BOOL)lenient {
    return [self _getFormatterProperty:ICUPropertyMapper::lenient]._boolValue;
}

/**
 @Status Interoperable
*/
- (void)setDateFormat:(NSString*)format {
    if (_dateFormat == format)
        return;

    _dateFormat = format;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSString*)dateFormat {
    return _dateFormat;
}

/**
 @Status Interoperable
*/
- (void)setDateStyle:(NSDateFormatterStyle)style {
    if (_dateStyle == style)
        return;
    _dateStyle = style;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSDateFormatterStyle)dateStyle {
    return _dateStyle;
}

/**
 @Status Interoperable
*/
- (void)setTimeStyle:(NSDateFormatterStyle)style {
    if (_timeStyle == style)
        return;
    _timeStyle = style;
    _formatterNeedsRebuilding = TRUE;
}

/**
 @Status Interoperable
*/
- (NSDateFormatterStyle)timeStyle {
    return _timeStyle;
}

/**
 @Status Interoperable
*/
- (NSString*)stringFromDate:(NSDate*)date {
    if (date == nil)
        return nil;

    UnicodeString str;

    [self _getFormatter]->format([date timeIntervalSince1970] * 1000.0, str);

    return NSStringFromICU(str);
}

/**
 @Status Interoperable
 */
+ (NSString*)localizedStringFromDate:(NSDate*)date dateStyle:(NSDateFormatterStyle)dateStyle timeStyle:(NSDateFormatterStyle)timeStyle {
    NSString* formattedDate = [self _formatDateForLocale:date
                                                  locale:[NSLocale currentLocale]
                                               dateStyle:dateStyle
                                               timeStyle:timeStyle
                                                timeZone:[NSTimeZone systemTimeZone]];

    return formattedDate;
}

+ (NSString*)_formatDateForLocale:(NSDate*)date
                           locale:(NSLocale*)locale
                        dateStyle:(NSDateFormatterStyle)dateStyle
                        timeStyle:(NSDateFormatterStyle)timeStyle
                         timeZone:(NSTimeZone*)timeZone {
    static NSDateFormatter* s_formatterForLocale = [[NSDateFormatter alloc] init];

    // Set time zone and locale
    [s_formatterForLocale setLocale:locale];
    [s_formatterForLocale setTimeZone:timeZone];

    // Update calendar to use proper time zone
    NSCalendar* calendar = [s_formatterForLocale calendar];
    [calendar setTimeZone:timeZone];
    [s_formatterForLocale setCalendar:calendar];

    s_formatterForLocale.dateStyle = dateStyle;
    s_formatterForLocale.timeStyle = timeStyle;

    return [s_formatterForLocale stringFromDate:date];
}

/**
 @Status Interoperable
*/
- (NSDate*)dateFromString:(NSString*)str {
    UStringHolder uStr(str);
    UErrorCode status = U_ZERO_ERROR;
    UDate date = [self _getFormatter]->parse(uStr.string(), status);

    if (!U_SUCCESS(status))
        return nil;
    return [NSDate dateWithTimeIntervalSince1970:date / 1000.0];
}

/**
 @Status Interoperable
*/
- (BOOL)getObjectValue:(out id _Nullable*)outObj forString:(id)str errorDescription:(out NSString* _Nullable*)err {
    if (err) {
        *err = nil;
    }

    if (outObj) {
        *outObj = [self dateFromString:str];
    }

    return TRUE;
}

/**
 @Status Interoperable
*/
- (NSString*)stringForObjectValue:(NSObject*)object {
    if ([object isKindOfClass:[NSDate class]]) {
        return [self stringFromDate:(NSDate*)object];
    } else {
        return nil;
    }
}

/**
 @Status Interoperable
*/
- (void)setAMSymbol:(NSString*)symbol {
    [self _setFormatterProperty:ICUPropertyMapper::amSymbol withValue:ICUPropertyValue(symbol)];
}

/**
 @Status Interoperable
*/
- (NSString*)AMSymbol {
    return (NSString*)[self _getFormatterProperty:ICUPropertyMapper::amSymbol]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setPMSymbol:(NSString*)symbol {
    [self _setFormatterProperty:ICUPropertyMapper::pmSymbol withValue:ICUPropertyValue(symbol)];
}

/**
 @Status Interoperable
*/
- (NSString*)PMSymbol {
    return (NSString*)[self _getFormatterProperty:ICUPropertyMapper::pmSymbol]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setShortStandaloneWeekdaySymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::shortStandaloneWeekdaySymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)shortStandaloneWeekdaySymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::shortStandaloneWeekdaySymbols]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setWeekdaySymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::weekdaySymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)weekdaySymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::weekdaySymbols]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setShortWeekdaySymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::shortWeekdaySymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)shortWeekdaySymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::shortWeekdaySymbols]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setStandaloneWeekdaySymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::standaloneWeekdaySymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)standaloneWeekdaySymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::standaloneWeekdaySymbols]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setStandaloneMonthSymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::standaloneMonthSymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)standaloneMonthSymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::standaloneMonthSymbols]._objValue;
}

/**
 @Status Interoperable
*/
- (void)setMonthSymbols:(NSArray*)symbols {
    [self _setFormatterProperty:ICUPropertyMapper::monthSymbols withValue:ICUPropertyValue(symbols)];
}

/**
 @Status Interoperable
*/
- (NSArray*)monthSymbols {
    return (NSArray*)[self _getFormatterProperty:ICUPropertyMapper::monthSymbols]._objValue;
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)getObjectValue:(id _Nullable*)obj forString:(NSString*)string range:(NSRange*)rangep error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
