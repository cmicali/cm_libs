//
//  UIView+DarkMode.m
//  vibe-libs
//

#import "UIView+DarkMode.h"

@implementation UIView (DarkMode)

- (BOOL)isDark {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

@end
