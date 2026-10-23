//
//  NSView+DarkMode.h
//  vibe-libs
//

#import <AppKit/AppKit.h>

@interface NSAppearance (DarkMode)

// The one spelling of the Aqua/DarkAqua bestMatch fold.
- (BOOL)isDark;

@end

@interface NSView (DarkMode)

- (BOOL)isDark;

@end
