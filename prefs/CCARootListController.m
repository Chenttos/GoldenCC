#import "CCARootListController.h"
#import <Preferences/PSSpecifier.h>

@implementation CCARootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
@end

