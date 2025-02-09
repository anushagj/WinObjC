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

#import <StubReturn.h>

#include "CoreGraphics/CGGeometry.h"
#include "CoreGraphics/CGAffineTransform.h"

#include "Foundation/NSNotificationCenter.h"
#include "QuartzCore/CALayer.h"
#include "UIKit/UIView.h"
#include "UIKit/UIWindow.h"
#include "UIKit/UIApplication.h"
#include "UIKit/UITouch.h"
#include "LoggingNative.h"
#include "UIApplicationInternal.h"

static const wchar_t* TAG = L"UIWindow";

UIWindow* m_pMainWindow = NULL;

UIWindow* _curKeyWindow = nil;

static float curWindowLevel = 1.0f;

NSString* const UIWindowDidBecomeVisibleNotification = @"UIWindowDidBecomeVisibleNotification";
NSString* const UIWindowDidBecomeHiddenNotification = @"UIWindowDidBecomeHiddenNotification";
NSString* const UIWindowDidBecomeKeyNotification = @"UIWindowDidBecomeKeyNotification";
NSString* const UIWindowDidResignKeyNotification = @"UIWindowDidResignKeyNotification";

NSString* const UIKeyboardFrameBeginUserInfoKey = @"UIKeyboardFrameBeginUserInfoKey";
NSString* const UIKeyboardFrameEndUserInfoKey = @"UIKeyboardFrameEndUserInfoKey";
NSString* const UIKeyboardAnimationDurationUserInfoKey = @"UIKeyboardAnimationDurationUserInfoKey";
NSString* const UIKeyboardAnimationCurveUserInfoKey = @"UIKeyboardAnimationCurveUserInfoKey";

NSString* const UIKeyboardWillShowNotification = @"UIKeyboardWillShowNotification";
NSString* const UIKeyboardDidShowNotification = @"UIKeyboardDidShowNotification";
NSString* const UIKeyboardWillHideNotification = @"UIKeyboardWillHideNotification";
NSString* const UIKeyboardDidHideNotification = @"UIKeyboardDidHideNotification";
NSString* const UIKeyboardBoundsUserInfoKey = @"UIKeyboardBoundsUserInfoKey";
NSString* const UIKeyboardCenterBeginUserInfoKey = @"UIKeyboardCenterBeginUserInfoKey";
NSString* const UIKeyboardCenterEndUserInfoKey = @"UIKeyboardCenterEndUserInfoKey";
NSString* const UIKeyboardIsLocalUserInfoKey = @"UIKeyboardIsLocalUserInfoKey";

NSString* const UIKeyboardWillChangeFrameNotification = @"UIKeyboardWillChangeFrameNotification";
NSString* const UIKeyboardDidChangeFrameNotification = @"UIKeyboardDidChangeFrameNotification";

/** @Status Stub */
const UIWindowLevel UIWindowLevelNormal = StubConstant();
/** @Status Stub */
const UIWindowLevel UIWindowLevelAlert = StubConstant();
/** @Status Stub */
const UIWindowLevel UIWindowLevelStatusBar = StubConstant();

@implementation UIWindow {
@private
    idretaintype(UIResponder) _rootViewController;
    float _windowLevel;
}

/**
 @Status Interoperable
*/
- (CGRect)convertRect:(CGRect)rect fromWindow:(UIWindow*)window {
    CGRect ret;

    memcpy(&ret, &rect, sizeof(CGRect));

    return ret;
}

/**
 @Status Stub
*/
- (CGRect)convertRect:(CGRect)toConvert fromView:(UIView*)fromView toView:(UIView*)toView {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (CGPoint)convertPoint:(CGPoint)point fromView:(UIView*)fromView toView:(UIView*)toView {
    return [CALayer convertPoint:point fromLayer:[fromView layer] toLayer:[toView layer]];
}

/**
 @Status Stub
*/
- (CGPoint)convertPoint:(CGPoint)toConvert fromLayer:(CALayer*)fromView toLayer:(CALayer*)toView {
    UNIMPLEMENTED();
    return StubReturn();
}

static void initInternal(UIWindow* self, CGRect pos) {
    if (m_pMainWindow == NULL) {
        m_pMainWindow = (UIWindow*)(id)self;
    }

    CALayer* ourLayer = [self layer];
    [ourLayer setOpaque:FALSE];
    [ourLayer _setRootLayer:TRUE];

    [CATransaction _addSublayerToTop:ourLayer];
    GetCACompositor()->setNodeTopMost((DisplayNode*)[ourLayer _presentationNode], true);

    [self setWindowLevel:curWindowLevel];
    curWindowLevel += 1.0f;

    [[UIApplication sharedApplication] _popupWindow];
}

- (void)_destroy {
    m_pMainWindow = NULL;
    [CATransaction _removeLayer:[self layer]];
    [[[UIApplication sharedApplication] windows] removeObject:self];
    [self resignKeyWindow];
}

/**
 @Status Interoperable
*/
- (UIWindow*)initWithFrame:(CGRect)pos {
    [[[UIApplication sharedApplication] windows] addObject:self];

    if (![[UIApplication sharedApplication] keyWindow]) {
        [self makeKeyWindow];
    }

    //  We are ourself, a view
    [super initWithFrame:pos];

    initInternal((UIWindow*)self, pos);

    return self;
}

- (UIWindow*)_initWithContentRect:(CGRect)pos {
    [self initWithFrame:pos];

    return self;
}

/**
 @Status Caveat
 @Notes May not be fully implemented
*/
- (NSObject*)initWithCoder:(NSCoder*)coder {
    [[[UIApplication sharedApplication] windows] addObject:self];

    id ret = [super initWithCoder:coder];

    CGRect frame;
    frame = [self frame];

#ifdef RUN_NATIVE_RESOLUTION
    frame.size.width = GetCACompositor()->screenWidth();
    frame.size.height = GetCACompositor()->screenHeight();
    [super setFrame:frame];
#else
    if (frame.size.height == 480.0f && GetCACompositor()->screenHeight() == 568.0f) {
        frame.size.height = GetCACompositor()->screenHeight();
        [super setFrame:frame];
    }
#endif

    initInternal((UIWindow*)self, frame);

    return self;
}

- (NSObject*)_getWindowInternal {
    return self;
}

/**
 @Status Interoperable
*/
+ (UIWindow*)mainWindow {
    return (UIWindow*)m_pMainWindow;
}

/**
 @Status Interoperable
*/
- (void)makeKeyAndVisible {
    [self setHidden:FALSE];
    [self makeKeyWindow];
    [self setWindowLevel:curWindowLevel];
    curWindowLevel += 1.0f;
}

/**
 @Status Interoperable
*/
- (void)makeKeyWindow {
    [self becomeKeyWindow];
}

/**
 @Status Interoperable
*/
- (void)becomeKeyWindow {
    _curKeyWindow = self;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIWindowDidBecomeKeyNotification" object:self];
}

/**
 @Status Interoperable
*/
- (void)resignKeyWindow {
    _curKeyWindow = nil;
}

/**
 @Status Interoperable
*/
- (BOOL)isKeyWindow {
    if (_curKeyWindow == self) {
        return TRUE;
    } else {
        return FALSE;
    }
}

/**
 @Status Interoperable
*/
- (UIResponder*)nextResponder {
    return [UIApplication sharedApplication];
}

/**
 @Status Interoperable
*/
- (UIResponder*)rootViewController {
    return (UIResponder*)_rootViewController;
}

/**
 @Status Interoperable
*/
- (void)setRootViewController:(UIViewController*)controller {
    _rootViewController = controller;

    id controllerView = [controller view];

    if (controllerView != nil) {
        [self addSubview:controllerView];
        CGRect screenFrame;
        if ([_rootViewController wantsFullScreenLayout]) {
            screenFrame = [[UIScreen mainScreen] bounds];
        } else {
            screenFrame = [[UIScreen mainScreen] applicationFrame];
        }

        [[_rootViewController view] setFrame:screenFrame];
    }

    if (controller && [controller respondsToSelector:@selector(preferredInterfaceOrientationForPresentation)]) {
        int ourOrientation = [controller preferredInterfaceOrientationForPresentation];
        [[UIDevice currentDevice] setOrientation:ourOrientation animated:FALSE];
    }
}

- (void)_setRootViewController:(UIViewController*)controller {
    _rootViewController = controller;
    if (controller) {
        id view = [controller view];

        if ([[view superview] isKindOfClass:[UIWindow class]]) {
            TraceVerbose(TAG, L"Setting root controller to %hs", object_getClassName(controller));
            CGRect screenFrame;
            screenFrame = [[UIScreen mainScreen] applicationFrame];
            [view setFrame:screenFrame];
        }
    } else {
        TraceVerbose(TAG, L"Setting root controller to nil");
    }
}

- (NSInteger)_compareWindowLevel:(id)other {
    float level1 = [self windowLevel];
    float level2 = [other windowLevel];

    if (level1 > level2) {
        return 1;
    } else if (level1 < level2) {
        return -1;
    } else {
        return 0;
    }
}

/**
 @Status Stub
*/
- (void)setWindowLevel:(float)level {
    UNIMPLEMENTED();
    _windowLevel = level;
    CALayer* ourLayer = [self layer];
    GetCACompositor()->setNodeTopWindowLevel((DisplayNode*)[ourLayer _presentationNode], level);
    GetCACompositor()->SortWindowLevels();
    [[[UIApplication sharedApplication] windows] sortUsingSelector:@selector(_compareWindowLevel:)];
}

/**
 @Status Stub
*/
- (float)windowLevel {
    UNIMPLEMENTED();
    return _windowLevel;
}

/**
 @Status Stub
*/
- (void)setScreen:(UIScreen*)screen {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    m_pMainWindow = NULL;
    [CATransaction _removeLayer:[self layer]];
    [[[UIApplication sharedApplication] windows] removeObject:self];

    [super dealloc];
}

/**
 @Status Stub
*/
- (CGPoint)convertPoint:(CGPoint)point toWindow:(UIWindow*)window {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (CGPoint)convertPoint:(CGPoint)point fromWindow:(UIWindow*)window {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (CGRect)convertRect:(CGRect)rect toWindow:(UIWindow*)window {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (void)sendEvent:(UIEvent*)event {
    UNIMPLEMENTED();
}

@end
