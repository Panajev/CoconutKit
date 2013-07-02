//
//  HLSRuntime.m
//  CoconutKit
//
//  Created by Samuel Défago on 30.06.11.
//  Copyright 2011 Hortis. All rights reserved.
//

#import "HLSRuntime.h"

#import <objc/message.h>

static IMP HLSSwizzleSelectorCommon(Class clazz, SEL selector, IMP newImplementation);

/**
 * About method swizzling in class hierarchies: 
 * --------------------------------------------
 *
 * Consider the -awakeFromNib method. This method is defined at the NSObject level (in a category) and might be
 * implemented by subclasses. UIView, which is an NSObject subclass, does not implement -awakeFromNib itself.
 * When calling -[UIView awakeFromNib], it is therefore the NSObject implementation (which does nothing) which
 * gets called. Similarly, UILabel is a UIView subclass which does not implement -awakeFromNib.
 *
 * Now imagine we swizzle -awakeFromNib both at the UIView and UILabel levels, just by getting the original
 * implementation (in both cases the one of NSObject since neither UIView nor UILabel actually override
 * -awakeFromNib) and calling class_replaceMethod. When swizzling the methods, we take care of storing pointers
 * to the original implementations. In each of the swizzled method implementations, we can then call the original
 * implementation, so that the original behavior is preserved. Seems correct and safe.
 *
 * What happens now when -awakeFromNib is called on a UIView instance? Well, everything works as expected: The swizzled
 * method implementation gets called, and in turns calls the original implementation we have replaced (the one at the
 * NSObject level).
 *
 * Is everything also working as expected when -awakeFromNib is called on a UILabel instance? The answer is no. Well, 
 * of course the UILabel swizzled method implementation gets called, which in turns calls the original implementation we 
 * have replaced (the one at the NSObject level). But the swizzled -[UIView awakeFromNib] method never gets called. 
 * The reason is obvious: Since UILabel did not actually implement -awakeFromNib before we swizzled it, its original
 * method implementation did not call the super implementation.
 *
 * How can we solve this issue? The obvious answer is to call -[super awakeFromNib] from within the swizzled
 * UILabel method implementation, but this requires some knowledge about the original behavior, which can be
 * a problem, should this behavior change in the future (especially for classes which we cannot control the
 * the implementation of). Can we do better?
 *
 * Well, we can. Assume that SomeClass implements -aMethod. If SomeSubclass is a subclass of SomeClass, then
 * we have three possible cases:
 *
 * 1) SomeSubclass implements -aMethod and calls [super aMethod] from within its implementation: After swizzling
 *    of -[SomeSubclass aMethod], and provided the original implementation is called, the SomeClass implementation
 *    of -aMethod will be called when -[SomeSubclass aMethod] gets called. If -[SomeClass aMethod] gets swizzled as
 *    well, then all swizzled method implementations will be called. The behavior is therefore correct without any 
 *    additional measures
 * 2) SomeSubclass implements -aMethod but does not call [super aMethod] on purpose (to replace it): After swizzling of
 *    -[SomeSubclass aMethod], the SomeClass implementation of -aMethod will not be called when -[SomeSubclass aMethod]
 *    gets called. The behavior is therefore also correct in this case
 * 3) SomeSubclass does not implement -aMethod: Before swizzling of -[SomeSubclass aMethod], when calling -aMethod
 *    on a SomeSubclass instance, the -[SomeClass aMethod] implementation gets called. If -[SomeClass aMethod] has
 *    been swizzled, the swizzled implementation will be called. After swizzling of -[SomeSubclass aMethod], when
 *    calling -aMethod on a SomeSubclass instance, then -[SomeClass aMethod] will not be called anymore, because 
 *    [super aMethod] is never called within -[SomeSubclass aMethod] implementation. Any prior swizzling of 
 *    -[SomeClass aMethod] is therefore lost when calling -[SomeSubclass aMethod]
 *
 * The solution to 3) should now be obvious: Since having a method implementation guarantees correct behavior (see 1) and
 * 2)), the rule is never to swizzle a method on a class which does not implement it itself. If the class does not implement
 * the method itself, and if we want to swizzle it, we must therefore add the method at runtime first. In order for the
 * parent implementation to be called first (so that the behavior stays consistent with the situation prior to swizzling),
 * the added method implementation must consist of a single call to the super method implementation.
 */

IMP HLSSwizzleClassSelector(Class clazz, SEL selector, IMP newImplementation)
{
    return HLSSwizzleSelectorCommon(objc_getMetaClass(class_getName(clazz)), selector, newImplementation);
}

IMP HLSSwizzleSelector(Class clazz, SEL selector, IMP newImplementation)
{
    return HLSSwizzleSelectorCommon(clazz, selector, newImplementation);
}

static IMP HLSSwizzleSelectorCommon(Class clazz, SEL selector, IMP newImplementation)
{
    Method origMethodOnClass = NULL;
    
    // Find whether the method is actually implemented by the class (NOT by one of its superclasses). We do not
    // use method_getImplementation here since we do not want to climb up the parent class hierarchy
    // TODO: A method should be available from CoconutKit, see url-connection branch
    unsigned int numberOfMethods = 0;
    Method *methods = class_copyMethodList(clazz, &numberOfMethods);
    for (unsigned int i = 0; i < numberOfMethods; ++i) {
        Method method = methods[i];
        if (method_getName(method) == selector) {
            origMethodOnClass = method;
            break;
        }
    }
    free(methods);
    
    // Method not implemented by the class: Add a method calling the super counterpart first (see explanation at
    // the top of this file)
    if (! origMethodOnClass) {
        // The method must actually be implemented somewhere along the hierarchy, we cannot swizzle a method
        // which is not implemented
        Method origMethodOnParentClass = class_isMetaClass(clazz) ? class_getClassMethod(clazz, selector) : class_getInstanceMethod(clazz, selector);
        if (! origMethodOnParentClass) {
            return NULL;
        }
        
        // Inject method (block implementations have no SEL argument)
        if (! class_addMethod(clazz, selector, imp_implementationWithBlock(^(id self, va_list argp) {
            struct objc_super super;
            super.receiver = self;
            super.super_class = class_getSuperclass(clazz);
            return objc_msgSendSuper(&super, selector, argp);
        }), method_getTypeEncoding(origMethodOnParentClass))) {
            return NULL;
        }
    }
    
    // Swizzle the implementation
    return class_replaceMethod(clazz, selector, newImplementation, method_getTypeEncoding(origMethodOnClass));
}

BOOL HLSIsSubclassOfClass(Class subclass, Class superclass)
{
    for (Class class = subclass; class != Nil; class = class_getSuperclass(class)) {
        if (class == superclass) {
            return YES;
        }
    }
    return NO;
}
