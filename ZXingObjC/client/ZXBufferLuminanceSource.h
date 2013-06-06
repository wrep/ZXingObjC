//
//  ZXBufferLuminanceSource.h
//  ZXingObjC
//
//  Created by AprisoDev on 6/6/13.
//  Copyright (c) 2013 zxing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZXLuminanceSource.h"

@interface ZXBufferLuminanceSource : ZXLuminanceSource {
    CGImageRef image;
    uint32_t *data;
    int left;
    int top;
    float rotation;
    int bufferWidth;
    int bufferHeight;
    bool mode;
}

- (id)initWithBuffer:(CVPixelBufferRef)buffer rotation:(CGFloat)degrees;

@end
