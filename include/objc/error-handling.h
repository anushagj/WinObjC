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
#include <stdlib.h>
#include <sys/cdefs.h>

#ifndef OBJCRT_EXPORT
#if defined(__OBJC_RUNTIME_INTERNAL__)
#define OBJCRT_EXPORT __declspec(dllexport)
#else
#define OBJCRT_EXPORT
#endif
#endif

__BEGIN_DECLS

// Should hitting the UNIMPLEMENTED macro cause a fast fail? If this returns false, we still log unimplemented calls but they are not fatal.
OBJCRT_EXPORT bool failFastOnUnimplemented();

// Error-handling exports
OBJCRT_EXPORT unsigned long objc_getCurrentThreadId();
OBJCRT_EXPORT long objc_interlockedIncrementNoFence(long volatile* addend);
OBJCRT_EXPORT unsigned long objc_getLastError();
OBJCRT_EXPORT void objc_copyMemory(void* destination, const void* source, size_t length);
OBJCRT_EXPORT void objc_zeroMemory(void* destination, size_t length);
OBJCRT_EXPORT unsigned long objc_formatMessageW(unsigned long flags, const void* source, unsigned long messageId, unsigned long languageId, wchar_t* buffer, unsigned long size, va_list* arguments);
OBJCRT_EXPORT void objc_outputDebugStringW(wchar_t* outputString);
OBJCRT_EXPORT long objc_interlockedDecrementRelease(long volatile* addend);
OBJCRT_EXPORT void* objc_interlockedCompareExchangePointer(void* volatile* destination, void* exchange, void* comparand);

__END_DECLS