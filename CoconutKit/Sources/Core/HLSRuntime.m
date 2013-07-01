//
//  HLSRuntime.m
//  CoconutKit
//
//  Created by Samuel Défago on 30.06.11.
//  Copyright 2011 Hortis. All rights reserved.
//

#import "HLSRuntime.h"

#import <objc/message.h>

IMP HLSSwizzleClassSelector(Class clazz, SEL selector, IMP newImplementation)
{
    // Get the original implementation we are replacing
    Class metaClass = objc_getMetaClass(class_getName(clazz));
    Method method = class_getClassMethod(metaClass, selector);
    IMP origImp = method_getImplementation(method);
    if (! origImp) {
        return NULL;
    }
    
    class_replaceMethod(metaClass, selector, newImplementation, method_getTypeEncoding(method));
    return origImp;
}

IMP HLSSwizzleSelector(Class clazz, SEL selector, IMP newImplementation)
{
    Method origMethodOnClass = NULL;
    
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
    
    if (! origMethodOnClass) {
        Method origMethodOnParentClass = class_getInstanceMethod(clazz, selector);
        if (! origMethodOnParentClass) {
            return NULL;
        }
        // No SEL argument
        class_addMethod(clazz, selector, imp_implementationWithBlock(^(id self, va_list argp) {
            struct objc_super super;
            super.receiver = self;
            super.super_class = class_getSuperclass(clazz);
            return objc_msgSendSuper(&super, selector, argp);
        }), method_getTypeEncoding(origMethodOnParentClass));
        
        origMethodOnClass = class_getInstanceMethod(clazz, selector);
        if (! origMethodOnClass) {
            return NULL;
        }
    }
    
    IMP origImpOnClass = method_getImplementation(origMethodOnClass);
    if (! origImpOnClass) {
        return NULL;
    }
    
    class_replaceMethod(clazz, selector, newImplementation, method_getTypeEncoding(origMethodOnClass));
    return origImpOnClass;
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
