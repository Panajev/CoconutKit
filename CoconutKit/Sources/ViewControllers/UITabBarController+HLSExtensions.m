//
//  UITabBarController+HLSExtensions.m
//  CoconutKit
//
//  Created by Samuel Défago on 10/16/12.
//  Copyright (c) 2012 Samuel Défago. All rights reserved.
//

#import "UITabBarController+HLSExtensions.h"

#import "HLSRuntime.h"

// Associated object keys
static void *s_autorotationModeKey = &s_autorotationModeKey;

// Original implementation of the methods we swizzle
static BOOL (*s_UITabBarController__shouldAutorotate_Imp)(id, SEL) = NULL;
static NSUInteger (*s_UITabBarController__supportedInterfaceOrientations_Imp)(id, SEL) = NULL;

// Swizzled method implementations
static BOOL swizzled_UITabBarController__shouldAutorotate_Imp(UITabBarController *self, SEL _cmd);
static NSUInteger swizzled_UITabBarController__supportedInterfaceOrientations_Imp(UITabBarController *self, SEL _cmd);

@implementation UITabBarController (HLSExtensions)

#pragma mark Class methods

+ (void)load
{
    s_UITabBarController__shouldAutorotate_Imp = (BOOL (*)(id, SEL))hls_class_swizzleSelector(self,
                                                                                              @selector(shouldAutorotate),
                                                                                              (IMP)swizzled_UITabBarController__shouldAutorotate_Imp);
    s_UITabBarController__supportedInterfaceOrientations_Imp = (NSUInteger (*)(id, SEL))hls_class_swizzleSelector(self,
                                                                                                                  @selector(supportedInterfaceOrientations),
                                                                                                                  (IMP)swizzled_UITabBarController__supportedInterfaceOrientations_Imp);
}

#pragma mark Accessors and mutators

- (HLSAutorotationMode)autorotationMode
{
    NSNumber *autorotationModeNumber = objc_getAssociatedObject(self, s_autorotationModeKey);
    if (! autorotationModeNumber) {
        return HLSAutorotationModeContainer;
    }
    else {
        return [autorotationModeNumber integerValue];
    }
}

- (void)setAutorotationMode:(HLSAutorotationMode)autorotationMode
{
    objc_setAssociatedObject(self, s_autorotationModeKey, @(autorotationMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static BOOL swizzled_UITabBarController__shouldAutorotate_Imp(UITabBarController *self, SEL _cmd)
{
    // The container always decides first (does not look at children)
    if (! (*s_UITabBarController__shouldAutorotate_Imp)(self, _cmd)) {
        return NO;
    }
    
    switch (self.autorotationMode) {
        case HLSAutorotationModeContainerAndAllChildren:
        case HLSAutorotationModeContainerAndTopChildren: {
            for (UIViewController *viewController in self.viewControllers) {
                if (! [viewController shouldAutorotate]) {
                    return NO;
                }
            }
            break;
        }
            
        case HLSAutorotationModeContainerAndNoChildren:
        case HLSAutorotationModeContainer:
        default: {
            break;
        }
    }
    
    return YES;
}

static NSUInteger swizzled_UITabBarController__supportedInterfaceOrientations_Imp(UITabBarController *self, SEL _cmd)
{
    // The container always decides first (does not look at children)
    NSUInteger containerSupportedInterfaceOrientations = (*s_UITabBarController__supportedInterfaceOrientations_Imp)(self, _cmd);
    
    switch (self.autorotationMode) {
        case HLSAutorotationModeContainerAndAllChildren:
        case HLSAutorotationModeContainerAndTopChildren: {
            for (UIViewController *viewController in self.viewControllers) {
                containerSupportedInterfaceOrientations &= [viewController supportedInterfaceOrientations];
            }
            break;
        }
            
        case HLSAutorotationModeContainerAndNoChildren:
        case HLSAutorotationModeContainer:
        default: {
            break;
        }
    }
    
    return containerSupportedInterfaceOrientations;
}
