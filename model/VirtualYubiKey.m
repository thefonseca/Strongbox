//
//  VirtualYubiKey.m
//  Strongbox
//
//  Created by Strongbox on 16/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "VirtualYubiKey.h"
#import "SecretStore.h"
#import "Utils.h"

@interface VirtualYubiKey ()

@property NSString* secret;

@end

@implementation VirtualYubiKey

+ (instancetype)keyWithName:(NSString *)name secret:(NSString *)secret autoFillOnly:(BOOL)autoFillOnly {
    return [[VirtualYubiKey alloc] initWithName:name secret:secret autoFillOnly:autoFillOnly];
}

- (instancetype)initWithName:(NSString *)name secret:(NSString *)secret autoFillOnly:(BOOL)autoFillOnly {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
        _name = name;
        _autoFillOnly = autoFillOnly;
        self.secret = secret;
    }
    
    return self;
}

- (instancetype)initFromIdentidier:(NSString *)identifier name:(NSString *)name autoFillOnly:(BOOL)autoFillOnly {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _name = name;
        _autoFillOnly = autoFillOnly;
    }
    
    return self;
}

- (NSDictionary *)getJsonSerializationDictionary {
    return @{
        @"identifier" : self.identifier,
        @"name" : self.name,
        @"autoFillOnly" : @(self.autoFillOnly),
    };
}

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)dictionary {
    NSString* identifier = dictionary[@"identifier"];
    NSString* name = dictionary[@"name"];
    NSNumber* numAfOnly = dictionary[@"autoFillOnly"];
    
    return [[VirtualYubiKey alloc] initFromIdentidier:identifier name:name autoFillOnly:numAfOnly.boolValue];
}

- (NSString *)secret {
    NSString *key = [NSString stringWithFormat:@"%@-virtual-yubikey", self.identifier];
    return [SecretStore.sharedInstance getSecureString:key];
}

- (void)setSecret:(NSString * _Nonnull)secret {
    NSString *key = [NSString stringWithFormat:@"%@-virtual-yubikey", self.identifier];

    if(secret) {
        [SecretStore.sharedInstance setSecureString:secret forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSData *)doChallengeResponse:(NSData *)challenge {
    return [VirtualYubiKey getDummyYubikeyResponse:challenge secret:self.secret];
}

+ (NSData*)getDummyYubikeyResponse:(NSData*)challenge secret:(NSString*)secret {
    if (challenge == nil || secret == nil) {
        NSLog(@"WARNWARN: NIL Secret or Challenge to Dummy YubiKey: Challenge = [%@] - Secret = [%@]", challenge, secret);
        return nil;
    }
    // Some people program the Yubikey with Fixed Length "Fixed 64 byte input" and others with "Variable Input"
    // To cover both cases the KeePassXC model appears to be to always send 64 bytes with extraneous bytes above
    // and beyond the actual challenge padded PKCS#7 style-ish... MMcG - 1-Mar-2020
    //
    // Further Reading: https://github.com/Yubico/yubikey-personalization-gui/issues/86
    
    // May need to pad challenge
    
    const NSInteger kChallengeSize = 64;
    const NSInteger paddingLengthAndCharacter = kChallengeSize - challenge.length;
    uint8_t challengeBuffer[kChallengeSize];
    for(int i=0;i<kChallengeSize;i++) {
        challengeBuffer[i] = paddingLengthAndCharacter;
    }
    [challenge getBytes:challengeBuffer length:challenge.length];
    NSData* paddedChallenge = [NSData dataWithBytes:challengeBuffer length:kChallengeSize];
    
    // Get actual secret
    
    BOOL paddingRequired = [secret hasPrefix:@"P"];
    NSString* sec = secret;
    
    if (paddingRequired) {
        sec = [sec substringFromIndex:1];
    }
    NSData* yubikeySecretData = [Utils dataFromHexString:sec];
    
    NSData *actualChallenge = paddingRequired ? paddedChallenge : challenge;
    
    NSData* challengeResponse = hmacSha1(actualChallenge, yubikeySecretData);
    
    return challengeResponse;
}

- (void)clearSecret {
    self.secret = nil;
}

@end
