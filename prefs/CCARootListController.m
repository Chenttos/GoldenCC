#import "CCARootListController.h"
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <unistd.h>
#import <notify.h>
#import <UIKit/UIKit.h>

extern char **environ;

static NSString * const kCCARootResetSpecifierKey = @"GoldenCCResetControlCenterLayout";

@interface CCARootListController ()
@property (nonatomic, assign) BOOL initialEnabledValue;
@end

@implementation CCARootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers =
            [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];

        // Add the reset button programmatically so no change to Root.plist is
        // required. It appears at the bottom of the existing GoldenCC settings.
        PSSpecifier *resetButton =
            [PSSpecifier preferenceSpecifierNamed:@"Reset Control Center Layout"
                                            target:self
                                               set:NULL
                                               get:NULL
                                            detail:Nil
                                              cell:PSButtonCell
                                              edit:Nil];

        [resetButton setProperty:kCCARootResetSpecifierKey forKey:@"id"];
        [resetButton setProperty:@"resetControlCenterLayout" forKey:@"action"];
        [resetButton setProperty:@YES forKey:@"isController"];

        PSSpecifier *resetGroup =
            [PSSpecifier groupSpecifierWithName:@"Control Center"];

        [resetGroup setProperty:
            @"Clears GoldenCC's saved module positions, sizes, and duplicate-module state without removing the tweak."
            forKey:@"footerText"];

        [specifiers addObject:resetGroup];
        [specifiers addObject:resetButton];

        _specifiers = [specifiers copy];
    }

    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    for (PSSpecifier *specifier in self.specifiers) {
        if ([[specifier propertyForKey:@"key"] isEqualToString:@"Enabled"]) {
            self.initialEnabledValue =
                [[self readPreferenceValue:specifier] boolValue];
            break;
        }
    }

    self.navigationItem.rightBarButtonItem = nil;
}

- (void)setMasterEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [self setPreferenceValue:value specifier:specifier];

    BOOL needsRespring =
        [value boolValue] != self.initialEnabledValue;

    if (!needsRespring) {
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }

    if (self.navigationItem.rightBarButtonItem) return;

    UIImage *image = [UIImage systemImageNamed:@"arrow.clockwise"];
    UIBarButtonItem *button =
        [[UIBarButtonItem alloc] initWithImage:image
                                        style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(respring)];

    button.accessibilityLabel = @"Respring";
    self.navigationItem.rightBarButtonItem = button;
}

- (void)resetControlCenterLayout {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Reset Control Center Layout?"
                                            message:@"This will remove GoldenCC's saved module positions, sizes, and duplicate-module state. Your normal Control Center configuration will not be deleted."
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil];

    __weak typeof(self) weakSelf = self;

    UIAlertAction *reset =
        [UIAlertAction actionWithTitle:@"Reset"
                                 style:UIAlertActionStyleDestructive
                               handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        notify_post("com.futur3sn0w.ccaster/ResetControlCenterLayout");

        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *done =
                [UIAlertController alertControllerWithTitle:@"GoldenCC"
                                                    message:@"Control Center layout reset."
                                             preferredStyle:UIAlertControllerStyleAlert];

            [done addAction:
                [UIAlertAction actionWithTitle:@"OK"
                                         style:UIAlertActionStyleDefault
                                       handler:nil]];

            [self presentViewController:done animated:YES completion:nil];
        });
    }];

    [alert addAction:cancel];
    [alert addAction:reset];

    [self presentViewController:alert animated:YES completion:nil];
}

// Fallback for PreferenceLoader versions that don't invoke the PSButtonCell
// "action" property consistently.
- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];

    NSString *identifier = [specifier propertyForKey:@"id"];
    if ([identifier isEqualToString:kCCARootResetSpecifierKey]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self resetControlCenterLayout];
        return;
    }

    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)respring {
    const char *path = access("/var/jb/usr/bin/sbreload", X_OK) == 0
        ? "/var/jb/usr/bin/sbreload"
        : "/usr/bin/sbreload";

    const char *arguments[] = { path, NULL };

    pid_t pid = 0;
    posix_spawn(&pid,
                path,
                NULL,
                NULL,
                (char *const *)arguments,
                environ);
}

@end
