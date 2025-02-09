//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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

#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIFont.h>

@interface UIFont ()
+ (UIFont*)defaultFont;
+ (UIFont*)fontWithData:(NSData*)data;
+ (UIFont*)titleFont;
+ (UIFont*)messageFont;
- (void)_setName:(NSString*)name;
- (uint32_t)_sizingFontHandle;
- (bool)_CTFontManagerRegisterGraphicsFont:(CGFontRef)font withError:(CFErrorRef*)error;
- (bool)_CTFontManagerRegisterFontsForURL:(CFURLRef)fontURL withScope:(CTFontManagerScope)scope withError:(CFErrorRef*)error;
@end