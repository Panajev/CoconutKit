//
//  UIView+HLSViewBinding.m
//  CoconutKit
//
//  Created by Samuel Défago on 18.06.13.
//  Copyright (c) 2013 Hortis. All rights reserved.
//

#import "UIView+HLSViewBinding.h"

#import "HLSLogger.h"
#import "HLSRuntime.h"
#import "HLSViewBindingInformation.h"
#import "UIView+HLSExtensions.h"

// TODO:
//  - for all demos: Add refresh bindings button (will update the date, suffices)
//  - demo with table view
//  - demo with embedded view controller (via placeholder view controller) to test boundaries
//  - demo bound to an object
//  - demo with binding to an object and normal binding
//  - demo with two subview hierarchies bound to different objects

// Keys for associated objects
static void *s_bindKeyPath = &s_bindKeyPath;
static void *s_bindFormatterKey = &s_bindFormatterKey;
static void *s_boundObjectKey = &s_boundObjectKey;
static void *s_bindingInformationKey = &s_bindingInformationKey;
static void *s_awokenFromNibKey = &s_awokenFromNibKey;

// Original implementation of the methods we swizzle
static void (*s_UIView__awakeFromNib_Imp)(id, SEL) = NULL;

// Swizzled method implementations
static void swizzled_UIView__awakeFromNib_Imp(UIView *self, SEL _cmd);

@interface UIView (HLSViewBindingPrivate)

/**
 * Private properties which must be set via user-defined runtime attributes
 */
@property (nonatomic, strong) NSString *bindKeyPath;
@property (nonatomic, strong) NSString *bindFormatter;

@property (nonatomic, strong) id boundObject;
@property (nonatomic, strong) HLSViewBindingInformation *bindingInformation;
@property (nonatomic, assign, getter=isAwokenFromNib) BOOL awokenFromNib;

- (void)bindToObject:(id)object inViewController:(UIViewController *)viewController;
- (void)refreshBindingsInViewController:(UIViewController *)viewController;

- (BOOL)bindsRecursively;
- (void)updateText;

@end

@implementation UIView (HLSViewBinding)

#pragma mark Class methods

+ (void)load
{
    s_UIView__awakeFromNib_Imp = (void (*)(id, SEL))HLSSwizzleSelector(self,
                                                                       @selector(awakeFromNib),
                                                                       (IMP)swizzled_UIView__awakeFromNib_Imp);
}

#pragma mark Bindings

- (void)bindToObject:(id)object
{
    [self bindToObject:object inViewController:[self nearestViewController]];
}

- (void)refreshBindings
{
    [self refreshBindingsInViewController:[self nearestViewController]];
}

@end

@implementation UIView (HLSViewBindingPrivate)

#pragma mark Accessors and mutators

- (NSString *)bindKeyPath
{
    return objc_getAssociatedObject(self, s_bindKeyPath);
}

- (void)setBindKeyPath:(NSString *)bindKeyPath
{
    objc_setAssociatedObject(self, s_bindKeyPath, bindKeyPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)bindFormatter
{
    return objc_getAssociatedObject(self, s_bindFormatterKey);
}

- (void)setBindFormatter:(NSString *)bindFormatter
{
    objc_setAssociatedObject(self, s_bindFormatterKey, bindFormatter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)boundObject
{
    return objc_getAssociatedObject(self, s_boundObjectKey);
}

- (void)setBoundObject:(id)boundObject
{
    objc_setAssociatedObject(self, s_boundObjectKey, boundObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HLSViewBindingInformation *)bindingInformation
{
    return objc_getAssociatedObject(self, s_bindingInformationKey);
}

- (void)setBindingInformation:(HLSViewBindingInformation *)bindingInformation
{
    objc_setAssociatedObject(self, s_bindingInformationKey, bindingInformation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isAwokenFromNib
{
    return [objc_getAssociatedObject(self, s_awokenFromNibKey) boolValue];
}

- (void)setAwokenFromNib:(BOOL)awokenFromNib
{
    objc_setAssociatedObject(self, s_awokenFromNibKey, @(awokenFromNib), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark Bindings

- (void)bindToObject:(id)object inViewController:(UIViewController *)viewController
{
    if (! object) {
        HLSLoggerError(@"An object must be provided");
        return;
    }
    
    self.boundObject = object;
    
    // Stop at view controller boundaries. The following also correctly deals with viewController = nil
    if (self.viewController && self.viewController != viewController) {
        return;
    }
    
    if (self.awokenFromNib) {
        if (self.bindKeyPath) {
            if ([self respondsToSelector:@selector(updateViewWithText:)]) {
                self.bindingInformation = [[HLSViewBindingInformation alloc] initWithObject:object
                                                                                    keyPath:self.bindKeyPath
                                                                              formatterName:self.bindFormatter
                                                                                       view:self];
                [self updateText];
            }
            else {
                HLSLoggerWarn(@"A binding path has been set for %@, but its class does not implement bindings", self);
            }
        }
        
        if ([self bindsRecursively]) {
            for (UIView *subview in self.subviews) {
                [subview bindToObject:object inViewController:viewController];
            }
        }
    }
}

- (void)refreshBindingsInViewController:(UIViewController *)viewController
{
    // Stop at view controller boundaries. The following also correctly deals with viewController = nil
    if (self.viewController && self.viewController != viewController) {
        return;
    }
    
    [self updateText];
    
    if ([self bindsRecursively]) {
        for (UIView *subview in self.subviews) {
            [subview refreshBindings];
        }
    }
}

- (BOOL)bindsRecursively
{
    if ([self respondsToSelector:@selector(updatesSubviewsRecursively)]) {
        return [self updatesSubviewsRecursively];
    }
    else {
        return YES;
    }
}

- (void)updateText
{
    if (! self.bindingInformation) {
        return;
    }
    
    NSString *text = [self.bindingInformation text];
    [self updateViewWithText:text];
}

@end

#pragma mark Swizzled method implementations

static void swizzled_UIView__awakeFromNib_Imp(UIView *self, SEL _cmd)
{
    (*s_UIView__awakeFromNib_Imp)(self, _cmd);
    
    self.awokenFromNib = YES;
    
    if (! self.bindingInformation) {
        if (! self.bindKeyPath) {
            return;
        }
        
        if (! [self respondsToSelector:@selector(updateViewWithText:)]) {
            HLSLoggerWarn(@"A binding path has been set for %@, but its class does not implement bindings", self);
            return;
        }
        
        // TODO: Part of a friend interface
        id object = self.boundObject ?: [(id)self.nearestViewController boundObject];
        
        self.bindingInformation = [[HLSViewBindingInformation alloc] initWithObject:object
                                                                            keyPath:self.bindKeyPath
                                                                      formatterName:self.bindFormatter
                                                                               view:self];
        [self updateText];
    }
}
