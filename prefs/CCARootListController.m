#import "CCARootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>
#import <unistd.h>
#import <notify.h>
#import <UIKit/UIKit.h>

extern char **environ;

static CFStringRef const kCCAPrefsDomain =
    CFSTR("com.futur3sn0w.ccaster.preferences");

static NSString * const kCCAReloadNotification =
    @"com.futur3sn0w.ccaster/ReloadPrefs";

static NSString * const kCCARootResetSpecifierKey =
    @"GoldenCCResetControlCenterLayout";

@interface CCARootListController ()
@end

@implementation CCARootListController

- (NSArray *)specifiers {
    if (!_specifiers) {

        NSMutableArray *specifiers =
            [[self loadSpecifiersFromPlistName:@"Root"
                                        target:self] mutableCopy];

        /*
         * Grupo
         */
        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"Control Center"];

        [group setProperty:
            @"Reset GoldenCC's saved Control Center layout, sizes and duplicate modules."
            forKey:@"footerText"];

        /*
         * Botão
         */
        PSSpecifier *resetButton =
            [PSSpecifier preferenceSpecifierNamed:@"Reset Control Center Layout"
                                            target:self
                                               set:NULL
                                               get:NULL
                                            detail:Nil
                                              cell:PSButtonCell
                                              edit:Nil];

        [resetButton setProperty:kCCARootResetSpecifierKey
                          forKey:@"id"];

        [resetButton setProperty:@"resetControlCenterLayout"
                          forKey:@"action"];

        [specifiers addObject:group];
        [specifiers addObject:resetButton];

        _specifiers = [specifiers copy];
    }

    return _specifiers;
}

/*
 * ---------------------------------------------------------
 * RESET CONTROL CENTER
 * ---------------------------------------------------------
 */

- (void)resetControlCenterLayout {

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Reset Control Center Layout?"
                             message:
        @"This will remove GoldenCC's saved positions, sizes and duplicate modules. The tweak itself will not be removed."
                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancel =
        [UIAlertAction
            actionWithTitle:@"Cancel"
                      style:UIAlertActionStyleCancel
                    handler:nil];

    __weak typeof(self) weakSelf = self;

    UIAlertAction *reset =
        [UIAlertAction
            actionWithTitle:@"Reset"
                      style:UIAlertActionStyleDestructive
                    handler:^(__unused UIAlertAction *action) {

        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        /*
         * GoldenCC salva o layout nestas três chaves.
         *
         * ModuleGridOrigins
         * ModuleGridSizes
         * COSMICDuplicateFamilies
         */

        CFPreferencesSetAppValue(
            CFSTR("ModuleGridOrigins"),
            NULL,
            kCCAPrefsDomain
        );

        CFPreferencesSetAppValue(
            CFSTR("ModuleGridSizes"),
            NULL,
            kCCAPrefsDomain
        );

        CFPreferencesSetAppValue(
            CFSTR("COSMICDuplicateFamilies"),
            NULL,
            kCCAPrefsDomain
        );

        /*
         * Garante que as alterações sejam gravadas imediatamente.
         */
        CFPreferencesAppSynchronize(kCCAPrefsDomain);

        /*
         * A notificação correta que o Tweak.xm realmente registra.
         */
        notify_post(
            [kCCAReloadNotification UTF8String]
        );

        /*
         * Recarrega SpringBoard/Control Center.
         *
         * Isso é importante porque o Tweak.xm carrega os dicionários
         * de layout no %ctor.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.15 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

                const char *sbreloadPath = NULL;

                if (access("/var/jb/usr/bin/sbreload", X_OK) == 0) {
                    sbreloadPath = "/var/jb/usr/bin/sbreload";
                }
                else if (access("/usr/bin/sbreload", X_OK) == 0) {
                    sbreloadPath = "/usr/bin/sbreload";
                }

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
                     * Se o sbreload foi iniciado, não precisamos
                     * mostrar outro alerta.
                     */
                    if (result == 0) {
                        return;
                    }
                }

                /*
                 * Caso sbreload não exista ou falhe,
                 * informa o usuário.
                 */
                UIAlertController *failed =
                    [UIAlertController
                        alertControllerWithTitle:@"GoldenCC"
                                         message:
                    @"The layout was reset, but SpringBoard could not be reloaded automatically. Please respring manually."
                                  preferredStyle:UIAlertControllerStyleAlert];

                [failed
                    addAction:
                        [UIAlertAction
                            actionWithTitle:@"OK"
                                      style:UIAlertActionStyleDefault
                                    handler:nil]];

                [self presentViewController:failed
                                    animated:YES
                                  completion:nil];
            }
        );
    }];

    [alert addAction:cancel];
    [alert addAction:reset];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

/*
 * Cool tweak made by me:3
 * Below is some configurations for PSButtonCell.
 */
- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    PSSpecifier *specifier =
        [self specifierAtIndexPath:indexPath];

    NSString *identifier =
        [specifier propertyForKey:@"id"];

    if ([identifier
            isEqualToString:kCCARootResetSpecifierKey]) {

        [tableView deselectRowAtIndexPath:indexPath
                                 animated:YES];

        [self resetControlCenterLayout];
        return;
    }

    [super tableView:tableView
didSelectRowAtIndexPath:indexPath];
}

@end
