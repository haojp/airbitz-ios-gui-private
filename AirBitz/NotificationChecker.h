//
//  NotificationChecker.h
//  AirBitz
//
//  Created by Allan on 11/24/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NotificationChecker : NSObject
{
}
+ (void)initAll;
+ (NSDictionary *)firstNotification:(BOOL)seen;
@end
