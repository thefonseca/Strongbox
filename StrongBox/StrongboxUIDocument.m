//
//  PasswordSafeUIDocument.m
//  Strongbox
//
//  Created by Mark on 20/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "StrongboxUIDocument.h"

@implementation StrongboxUIDocument

-(instancetype)initWithFileURL:(NSURL *)url {
    if (url && url.isFileURL) {
        return [super initWithFileURL:url];
    }
    else {
        NSLog(@"Invalid File URL: [%@]", url);
        return nil;
    }
}

- (instancetype)initWithData:(NSData*)data fileUrl:(NSURL*)fileUrl {
    if(self = [super initWithFileURL:fileUrl]) {
        self.data = data;
    }
    
    return self;
}

- (id)contentsForType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    return self.data;
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    self.data = contents;
    
    return YES;
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted {
    NSLog(@"UIDocument: error = %@", error);
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
}

@end
