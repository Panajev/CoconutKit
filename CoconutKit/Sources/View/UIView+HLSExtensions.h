//
//  UIView+HLSExtensions.h
//  CoconutKit
//
//  Created by Samuel Défago on 18.08.11.
//  Copyright 2011 Hortis. All rights reserved.
//

#define HLSViewAutoresizingAll UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |         \
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |                               \
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin

@interface UIView (HLSExtensions)

/**
 * Return the view controller from which the receiver is the view, nil otherwise
 */
@property (nonatomic, readonly, weak) UIViewController *viewController;

/**
 * Return the nearest view controller which displays the view, nil if none
 */
@property (nonatomic, readonly, weak) UIViewController *nearestViewController;

/**
 * Use this property if you want to tag your view with a string instead of an integer
 */
@property (nonatomic, retain) NSString *tag_hls;

/**
 * Use this dictionary to convey additional information about your views
 */
@property (nonatomic, retain) NSDictionary *userInfo_hls;

/**
 * Return the view and all its subview flattened as a UIImage
 */
- (UIImage *)flattenedImage;

/**
 * Convenience method to apply a mask to a view, fading in the specified directions from a given fraction of the
 * width / height.
 *
 * This method replaces any mask layer which might have been applied. Only one effect can be applied
 */
- (void)fadeLeft:(CGFloat)left right:(CGFloat)right;
- (void)fadeTop:(CGFloat)top bottom:(CGFloat)bottom;

@end
