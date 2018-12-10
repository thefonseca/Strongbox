//
//  Kdb1Database.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdb1Database.h"
#import "KdbSerialization.h"
#import "NSArray+Extensions.h"
#import "Kdb1DatabaseMetadata.h"
#import "KeePassConstants.h"
#import "Utils.h"

static const BOOL kLogVerbose = NO;

@interface Kdb1Database ()

@end

@implementation Kdb1Database

+ (NSString *)fileExtension {
    return @"kdb";
}

- (NSString *)fileExtension {
    return [Kdb1Database fileExtension];
}

- (DatabaseFormat)format {
    return kKeePass1;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [KdbSerialization isAValidSafe:candidate];
}

- (void)addKeePassDefaultRootGroup:(Node*)rootGroup {
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:rootGroup uuid:nil];
    [rootGroup addChild:keePassRootGroup];
}

- (nonnull StrongboxDatabase *)create:(nullable NSString *)password {
    return [self create:password keyFileDigest:nil];
}

- (StrongboxDatabase *)create:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    Node* rootGroup = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    
    [self addKeePassDefaultRootGroup:rootGroup];
    
    Kdb1DatabaseMetadata *metadata = [[Kdb1DatabaseMetadata alloc] init];
    
    StrongboxDatabase *ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata masterPassword:password keyFileDigest:keyFileDigest];
    
    return ret;
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password error:(NSError **)error {
    return [self open:data password:password keyFileDigest:nil error:error];
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest error:(NSError **)error {
    KdbSerializationData *serializationData = [KdbSerialization deserialize:data password:password keyFileDigest:keyFileDigest ppError:error];
    
    if(serializationData == nil) {
        NSLog(@"Error getting Decrypting KDB binary: [%@]", *error);
        return nil;
    }

    if(kLogVerbose) {
        NSLog(@"KdbSerializationData = [%@]", serializationData);
    }


    NSArray<DatabaseAttachment*>* attachments;
    Node* rootGroup = [self buildStrongboxModel:serializationData attachments:&attachments];

    if(kLogVerbose) {
        NSLog(@"Attachments: %@", attachments);
    }

    // Metadata

    Kdb1DatabaseMetadata *metadata = [[Kdb1DatabaseMetadata alloc] init];

    metadata.version = serializationData.version;
    metadata.transformRounds = serializationData.transformRounds;
    metadata.flags = serializationData.flags;

    StrongboxDatabase *ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                           masterPassword:password
                                                            keyFileDigest:keyFileDigest
                                                              attachments:attachments];
    ret.adaptorTag = serializationData.metaEntries;
    
    return ret;
}

- (NSData *)save:(StrongboxDatabase *)database error:(NSError**)error {
    if(!database.masterPassword.length && !database.keyFileDigest) { // KeePass 1 does not allow empty Password 
        if(error) {
            *error = [Utils createNSError:@"Master Password or Key File not set." errorCode:-3];
        }
        
        return nil;
    }
    
    KdbSerializationData *serializationData = [[KdbSerializationData alloc] init];
    
    if(database.rootGroup.childGroups.count == 0) {
        // KDB1 Requires at least one group at the top
        [self addKeePassDefaultRootGroup:database.rootGroup];
    }
    
    [self nodeModelToGroupsAndEntries:0
                                group:database.rootGroup
                    serializationData:serializationData
                     existingGroupIds:[NSMutableSet<NSNumber*> set]
                          attachments:database.attachments];
    
    Kdb1DatabaseMetadata* metadata = (Kdb1DatabaseMetadata*)database.metadata;
    
    serializationData.flags = metadata.flags;
    serializationData.version = metadata.version;
    serializationData.transformRounds = metadata.transformRounds;
    
    NSMutableArray<KdbEntry*>* metaEntries = (NSMutableArray<KdbEntry*>*)database.adaptorTag;
    if(metaEntries) {
        [serializationData.metaEntries addObjectsFromArray:metaEntries];
    }
    
    return [KdbSerialization serialize:serializationData password:database.masterPassword keyFileDigest:database.keyFileDigest ppError:error];
}

-(void)nodeModelToGroupsAndEntries:(int)level
                             group:(Node*)group
                 serializationData:(KdbSerializationData*)serializationData
                  existingGroupIds:(NSMutableSet<NSNumber*>*)existingGroupIds
                       attachments:(NSArray<DatabaseAttachment*>*)attachments {
    NSArray<Node*>* subGroups = [group childGroups];
    
    for (Node* subGroup in subGroups) {
        KdbGroup* kdbGroup = groupToKdbGroup(subGroup, level, existingGroupIds);
        [serializationData.groups addObject:kdbGroup];

        NSArray<KdbEntry*> *entries = [[subGroup childRecords] map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return [self recordToKdbEntry:obj kdbGroup:kdbGroup attachments:attachments];
        }];
        
        [serializationData.entries addObjectsFromArray:entries];

        [self nodeModelToGroupsAndEntries:level + 1 group:subGroup serializationData:serializationData
                         existingGroupIds:existingGroupIds attachments:attachments];
    }
}

KdbGroup* groupToKdbGroup(Node* group, int level,NSMutableSet<NSNumber*> *existingGroupIds) {
    KdbGroup *ret = [[KdbGroup alloc] init];
    
    ret.groupId = newGroupId(existingGroupIds);
    [existingGroupIds addObject:@(ret.groupId)];
    
    ret.name = group.title;
    ret.imageId = group.iconId != nil ? group.iconId : @(48);
    
    if(group.linkedData) {
        KdbGroup* previous = (KdbGroup*)group.linkedData;
        
        ret.creation = previous.creation;
        ret.modification = previous.modification;
        ret.lastAccess = previous.lastAccess;
        ret.expiry = previous.expiry;
        ret.flags = previous.flags;
        ret.imageId = previous.imageId;
    }
    
    ret.level = level;
    return ret;
}

- (KdbEntry*)recordToKdbEntry:(Node*)record kdbGroup:(KdbGroup*)kdbGroup attachments:(NSArray<DatabaseAttachment*>*)attachments {
    KdbEntry* ret = [[KdbEntry alloc] init];
    
    ret.uuid = record.uuid;
    ret.groupId = kdbGroup.groupId;
    ret.imageId = record.iconId != nil ? record.iconId : @(0);
    ret.title = record.title;
    ret.url = record.fields.url;
    ret.username = record.fields.username;
    ret.password = record.fields.password;
    ret.notes = record.fields.notes;
    ret.creation = record.fields.created;
    ret.modified = record.fields.modified;
    ret.accessed = record.fields.accessed;
    
    if(record.fields.attachments.count) { 
        NodeFileAttachment *theAttachment = record.fields.attachments[0];
        
        ret.binaryFileName = theAttachment.filename;
        ret.binaryData = attachments[theAttachment.index].data;
    }
    
    if(record.linkedData) {
        KdbEntry* previous = (KdbEntry*)record.linkedData;
        ret.imageId = previous.imageId;
        ret.expired = previous.expired;
    }
    
    return ret;
}

uint32_t newGroupId(NSSet *existingGroupIds) {
    uint32_t t = 0;
    
    while(true)
    {
        t = getRandomUint32();
        
        if((t == 0) || (t == UINT32_MAX) || ([existingGroupIds containsObject:@(t)])) {
            continue;
        }
        
        return t;
    }
}

void normalizeLevels(NSArray<KdbGroup*> *groups) {
    groups[0].level = 0;
    
    int lastLevel = 0;
    for (KdbGroup *group in groups) {
        if(group.level > lastLevel + 1) {
            group.level = lastLevel + 1;
        }
        
        lastLevel = group.level;
    }
}

- (Node*)buildStrongboxModel:(KdbSerializationData *)serializationData attachments:(NSArray<DatabaseAttachment*>**)attachments {
    Node* ret = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    NSMutableArray<DatabaseAttachment*> *mutableAttachments = [NSMutableArray array];
    
    normalizeLevels(serializationData.groups);
    
    int currentLevel = 0;
    Node* parentNode = ret;
    Node* lastNode = ret;
    
    for (KdbGroup* group in serializationData.groups) {
        if(group.level > currentLevel) {
            parentNode = lastNode;
            currentLevel = group.level;
        }
        else if(group.level < currentLevel) {
            int popCount = currentLevel - group.level;
            while(popCount--) parentNode = parentNode.parent;
            currentLevel = group.level;
        }
        
        Node* node = [[Node alloc] initAsGroup:group.name parent:parentNode uuid:nil];
        node.iconId = group.imageId;
        node.linkedData = group;
        [parentNode addChild:node];
        
        // Add Entries/Records for this group
        
        NSArray<KdbEntry*> *entries = [serializationData.entries filter:^BOOL(KdbEntry * _Nonnull obj) {
            return obj.groupId == group.groupId;
        }];
        
        NSArray<Node*> *childEntries = [entries map:^id (KdbEntry * entry, NSUInteger idx) {
            return [self kdbEntryToRecordNode:entry parent:node attachments:mutableAttachments];
        }];
        
        for (Node* childEntry in childEntries) {
            [node addChild:childEntry];
        }
        
        lastNode = node;
    }
    
    *attachments = mutableAttachments;
    return ret;
}

- (Node*)kdbEntryToRecordNode:(KdbEntry*)entry parent:(Node*)parent attachments:(NSMutableArray<DatabaseAttachment*>*)attachments {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:entry.username
                                                          url:entry.url
                                                     password:entry.password
                                                        notes:entry.notes
                                                        email:@""];
    
    fields.created = entry.creation;
    fields.accessed = entry.accessed;
    fields.modified = entry.modified;
    
    if(entry.binaryFileName.length) {
        DatabaseAttachment *dbAttachment = [[DatabaseAttachment alloc] init];
        dbAttachment.data = entry.binaryData;
        dbAttachment.compressed = NO;
        dbAttachment.protectedInMemory = NO;
        [attachments addObject:dbAttachment];
        
        NodeFileAttachment *attachment = [[NodeFileAttachment alloc] init];
        attachment.filename = entry.binaryFileName;
        attachment.index = (uint32_t)attachments.count - 1;
        
        [fields.attachments addObject:attachment];
    }
    
    Node* ret = [[Node alloc] initAsRecord:entry.title parent:parent fields:fields uuid:entry.uuid];
    ret.linkedData = entry;
    ret.iconId = entry.imageId;
    
    return ret;
}

@end
