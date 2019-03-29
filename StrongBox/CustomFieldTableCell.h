//
//  CustomFieldTableCell.h
//  Strongbox-iOS
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const CustomFieldCellHeightChanged;

NS_ASSUME_NONNULL_BEGIN

@interface CustomFieldTableCell : UITableViewCell

@property NSString* key;
@property NSString* value;
@property BOOL hidden;
@property BOOL isHideable;

@end

NS_ASSUME_NONNULL_END
