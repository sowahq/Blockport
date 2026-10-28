#ifndef CMACDISPLAY_H
#define CMACDISPLAY_H

#include <CoreGraphics/CoreGraphics.h>

/// Cursor control from CoreGraphics, declared under new names because the
/// SDK marks it unavailable for Mac Catalyst although it is exported there.
CGError BlockportAssociateMouseAndCursor(boolean_t connected) __asm__("_CGAssociateMouseAndMouseCursorPosition");
CGError BlockportWarpCursor(CGPoint point) __asm__("_CGWarpMouseCursorPosition");
CGError BlockportHideCursor(uint32_t display) __asm__("_CGDisplayHideCursor");
CGError BlockportShowCursor(uint32_t display) __asm__("_CGDisplayShowCursor");
uint32_t BlockportMainDisplay(void) __asm__("_CGMainDisplayID");

#endif
