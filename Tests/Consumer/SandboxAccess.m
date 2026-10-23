//
//  SandboxAccess.m
//
//  Makes a folder grants' store over a defaults suite of its own. It holds no
//  grant, and it does not read a new temporary folder as readable. A grant's
//  own spelling covers a file inside it. Then removes the folder and the suite.
//

#import <Foundation/Foundation.h>

#import "FolderAccessManager.h"

FOUNDATION_EXTERN BOOL ConsumerSandboxAccessHolds(void);

BOOL ConsumerSandboxAccessHolds(void) {
    NSString *suite = [@"Consumer.SandboxAccess." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil
                                                  error:nil];
    FolderAccessManager *store = [[FolderAccessManager alloc] initWithDefaults:defaults key:@"grants"];
    BOOL empty = store.grantedFolders.count == 0;
    BOOL refused = ![store canReadInsideDirectory:folder];
    BOOL covered = [FolderAccessManager readablePath:[folder stringByAppendingPathComponent:@"track.wav"]
                                    isCoveredByAnyOf:@[folder]];
    [NSFileManager.defaultManager removeItemAtPath:folder error:nil];
    [defaults removePersistentDomainForName:suite];
    if (!empty || !refused || !covered) {
        fprintf(stderr, "consumer: grants store empty %d, temporary folder refused %d, grant covers %d\n",
                empty, refused, covered);
        return NO;
    }
    return YES;
}
