#import "CCARootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>
#import <unistd.h>
#import <notify.h>
#import <UIKit/UIKit.h>

extern char **environ;

/*
 * GoldenCC Preferences Domain
 */
static CFStringRef const kGoldenCCPrefsDomain =
    CFSTR("com.meowly.goldencc.preferences");

/*
 * GoldenCC reload notification
 */
static NSString * const kGoldenCCReloadNotification =
    @"com.meowly.goldencc/ReloadPrefs";

/*
 * Reset button identifier
 */
static NSString * const kGoldenCCResetSpecifierKey =
    @"GoldenCCResetControlCenterLayout";


@interface CCARootListController ()
@end


@implementation CCARootListController


#pragma mark - Specifiers

- (NSArray *)specifiers {

    if (!_specifiers) {

        NSMutableArray *specifiers =
            [[self loadSpecifiersFromPlistName:@"Root"
                                        target:self] mutableCopy];

        /*
         * ---------------------------------------------------------
         * GOLDENCC CONTROL CENTER SECTION
         * ---------------------------------------------------------
         */

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"Control Center"];

        [group setProperty:
            @"Reset GoldenCC's saved Control Center layout, module sizes, positions and duplicate modules."
            forKey:@"footerText"];


        /*
         * ---------------------------------------------------------
         * RESET BUTTON
         * ---------------------------------------------------------
         */

        PSSpecifier *resetButton =
            [PSSpecifier
                preferenceSpecifierNamed:@"Reset Control Center Layout"
                                        target:self
                                           set:NULL
                                           get:NULL
                                        detail:Nil
                                          cell:PSButtonCell
                                          edit:Nil];

        [resetButton setProperty:
            kGoldenCCResetSpecifierKey
            forKey:@"id"];

        [resetButton setProperty:
            @"resetControlCenterLayout"
            forKey:@"action"];


        /*
         * Add the GoldenCC section to the bottom
         * of the preferences.
         */

        [specifiers addObject:group];
        [specifiers addObject:resetButton];


        _specifiers = [specifiers copy];
    }

    return _specifiers;
}


#pragma mark - Reset GoldenCC Control Center

- (void)resetControlCenterLayout {

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Reset Control Center Layout?"
                             message:
        @"This will remove GoldenCC's saved Control Center positions, sizes and duplicate modules. The tweak itself will not be removed."
                      preferredStyle:UIAlertControllerStyleAlert];


    /*
     * CANCEL
     */

    UIAlertAction *cancel =
        [UIAlertAction
            actionWithTitle:@"Cancel"
                      style:UIAlertActionStyleCancel
                    handler:nil];


    __weak typeof(self) weakSelf = self;


    /*
     * RESET
     */

    UIAlertAction *reset =
        [UIAlertAction
            actionWithTitle:@"Reset"
                      style:UIAlertActionStyleDestructive
                    handler:^(__unused UIAlertAction *action) {

        __strong typeof(weakSelf) self = weakSelf;

        if (!self)
            return;


        /*
         * ---------------------------------------------------------
         * GOLDENCC SAVED DATA
         * ---------------------------------------------------------
         *
         * These are the preferences used by GoldenCC for:
         *
         * ModuleGridOrigins
         * ModuleGridSizes
         * COSMICDuplicateFamilies
         *
         */


        /*
         * Module positions
         */

        CFPreferencesSetAppValue(
            CFSTR("ModuleGridOrigins"),
            NULL,
            kGoldenCCPrefsDomain
        );


        /*
         * Module sizes
         */

        CFPreferencesSetAppValue(
            CFSTR("ModuleGridSizes"),
            NULL,
            kGoldenCCPrefsDomain
        );


        /*
         * Duplicate modules
         */

        CFPreferencesSetAppValue(
            CFSTR("COSMICDuplicateFamilies"),
            NULL,
            kGoldenCCPrefsDomain
        );


        /*
         * Force preferences to be written.
         */

        CFPreferencesAppSynchronize(
            kGoldenCCPrefsDomain
        );


        /*
         * Tell GoldenCC to reload preferences.
         */

        notify_post(
            [kGoldenCCReloadNotification UTF8String]
        );


        /*
         * ---------------------------------------------------------
         * RESPRING
         * ---------------------------------------------------------
         *
         * GoldenCC stores some layout information in memory.
         * Therefore SpringBoard must be restarted after the reset.
         */


        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.15 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

                const char *sbreloadPath = NULL;


                /*
                 * Rootless jailbreak
                 */

                if (access(
                        "/var/jb/usr/bin/sbreload",
                        X_OK
                    ) == 0) {

                    sbreloadPath =
                        "/var/jb/usr/bin/sbreload";
                }


                /*
                 * Fallback
                 */

                else if (access(
                            "/usr/bin/sbreload",
                            X_OK
                        ) == 0) {

                    sbreloadPath =
                        "/usr/bin/sbreload";
                }


                /*
                 * Execute sbreload
                 */

                if (sbreloadPath) {

                    const char *args[] = {
                        sbreloadPath,
                        NULL
                    };


                    pid_t pid = 0;


                    int result =
                        posix_spawn(
                            &pid,
                            sbreloadPath,
                            NULL,
                            NULL,
                            (char *const *)args,
                            environ
                        );


                    /*
                     * Successfully started sbreload.
                     */

                    if (result == 0) {

                        return;
                    }
                }


                /*
                 * -------------------------------------------------
                 * FALLBACK MESSAGE
                 * -------------------------------------------------
                 */

                UIAlertController *failed =
                    [UIAlertController
                        alertControllerWithTitle:@"GoldenCC"
                                         message:
                    @"The GoldenCC layout was reset, but SpringBoard could not be reloaded automatically. Please respring manually."
                                  preferredStyle:UIAlertControllerStyleAlert];


                [failed
                    addAction:
                        [UIAlertAction
                            actionWithTitle:@"OK"
                                      style:UIAlertActionStyleDefault
                                    handler:nil]];


                [self
                    presentViewController:failed
                                 animated:YES
                               completion:nil];
            }
        );
    }];


    [alert addAction:cancel];
    [alert addAction:reset];


    [self
        presentViewController:alert
                     animated:YES
                   completion:nil];
}


#pragma mark - PSButtonCell Fallback

/*
 * Some PreferenceLoader versions don't always invoke
 * the PSButtonCell action correctly.
 *
 * This makes the reset button work when the row itself
 * is selected.
 */

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    PSSpecifier *specifier =
        [self specifierAtIndexPath:indexPath];


    NSString *identifier =
        [specifier propertyForKey:@"id"];


    if ([identifier
            isEqualToString:kGoldenCCResetSpecifierKey]) {

        [tableView
            deselectRowAtIndexPath:indexPath
                          animated:YES];


        [self resetControlCenterLayout];

        return;
    }


    [super tableView:tableView
didSelectRowAtIndexPath:indexPath];
}


@end
