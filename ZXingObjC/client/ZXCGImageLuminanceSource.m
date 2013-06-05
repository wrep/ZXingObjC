/*
 * Copyright 2012 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <CoreVideo/CoreVideo.h>
#import "ZXCGImageLuminanceSource.h"
#import "ZXImage.h"

@interface ZXCGImageLuminanceSource ()

- (void)initializeWithImage:(CGImageRef)image left:(int)left top:(int)top width:(int)width height:(int)height;

@end

@implementation ZXCGImageLuminanceSource

+ (CGImageRef)createImageFromBuffer:(CVImageBufferRef)buffer {
    return [self createImageFromBuffer:buffer
                                  left:0
                                   top:0
                                 width:CVPixelBufferGetWidth(buffer)
                                height:CVPixelBufferGetHeight(buffer)];
}

+ (CGImageRef)createImageFromBuffer:(CVImageBufferRef)buffer
                           rotation:(CGFloat)rotation {
    return [self createImageFromBuffer:buffer
                                  left:0
                                   top:0
                                 width:CVPixelBufferGetWidth(buffer)
                                height:CVPixelBufferGetHeight(buffer)
                              rotation:rotation];
}

+ (CGImageRef)createImageFromBuffer:(CVImageBufferRef)buffer
                               left:(size_t)left
                                top:(size_t)top
                              width:(size_t)width
                             height:(size_t)height {
    return [self createImageFromBuffer:buffer
                                  left:left
                                   top:top
                                 width:width
                                height:height
                              rotation:0.0f];
}

+ (CGImageRef)createImageFromBuffer:(CVImageBufferRef)buffer
                               left:(size_t)left
                                top:(size_t)top
                              width:(size_t)width
                             height:(size_t)height
                           rotation:(CGFloat)rotation {
    int bytesPerRow = (int)CVPixelBufferGetBytesPerRow(buffer);
    int dataWidth = (int)CVPixelBufferGetWidth(buffer);
    int dataHeight = (int)CVPixelBufferGetHeight(buffer);
    
    if (left + width > dataWidth ||
        top + height > dataHeight) {
        [NSException raise:NSInvalidArgumentException format:@"Crop rectangle does not fit within image data."];
    }
    
    int newBytesPerRow = ((width*4+0xf)>>4)<<4;
    
    CVPixelBufferLockBaseAddress(buffer,0);
    
    unsigned char *baseAddress =
    (unsigned char *)CVPixelBufferGetBaseAddress(buffer);
    
    int size = newBytesPerRow*height;
    unsigned char *bytes = (unsigned char*)malloc(size);
    if (newBytesPerRow == bytesPerRow) {
        memcpy(bytes, baseAddress+top*bytesPerRow, size);
    } else {
        for(int y=0; y<height; y++) {
            memcpy(bytes+y*newBytesPerRow,
                   baseAddress+left*4+(top+y)*bytesPerRow,
                   newBytesPerRow);
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(bytes,
                                                    width,
                                                    height,
                                                    8,
                                                    newBytesPerRow,
                                                    colorSpace,
                                                    kCGBitmapByteOrder32Little|
                                                    kCGImageAlphaNoneSkipFirst);
    
    CGImageRef result = CGBitmapContextCreateImage(newContext);
    [NSMakeCollectable(result) autorelease];
    
    CGContextRelease(newContext);
    
    free(bytes);
    
    // Adapted from http://blog.coriolis.ch/2009/09/04/arbitrary-rotation-of-a-cgimage/ and https://github.com/JanX2/CreateRotateWriteCGImage
    if(rotation != 0) {
        double radians = rotation * M_PI / 180;
        
#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
        radians = -1 * radians;
#endif
        
        CGRect imgRect = CGRectMake(0, 0, width, height);
        CGAffineTransform _transform = CGAffineTransformMakeRotation(radians);
        CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, _transform);
        
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     rotatedRect.size.width,
                                                     rotatedRect.size.height,
                                                     CGImageGetBitsPerComponent(result),
                                                     0,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedFirst);
        CGContextSetAllowsAntialiasing(context, FALSE);
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGColorSpaceRelease(colorSpace);
        
        CGContextTranslateCTM(context,
                              +(rotatedRect.size.width/2),
                              +(rotatedRect.size.height/2));
        CGContextRotateCTM(context, radians);
        
        CGContextDrawImage(context, CGRectMake(-imgRect.size.width/2,
                                               -imgRect.size.height/2,
                                               imgRect.size.width,
                                               imgRect.size.height),
                           result);
        
        
        result = CGBitmapContextCreateImage(context);
        [NSMakeCollectable(result) autorelease];
        
        CFRelease(context);
    }
    
    CGColorSpaceRelease(colorSpace);
    
    return result;
}

- (id)initWithZXImage:(ZXImage *)_image
                 left:(size_t)_left
                  top:(size_t)_top
                width:(size_t)_width
               height:(size_t)_height {
    self = [self initWithCGImage:_image.cgimage left:(int)_left top:(int)_top width:(int)_width height:(int)_height];
    
    return self;
}

- (id)initWithZXImage:(ZXImage *)_image {
    self = [self initWithCGImage:_image.cgimage];
    
    return self;
}

- (id)initWithCGImage:(CGImageRef)_image
                 left:(size_t)_left
                  top:(size_t)_top
                width:(size_t)_width
               height:(size_t)_height {
    if (self = [super init]) {
        [self initializeWithImage:_image left:(int)_left top:(int)_top width:(int)_width height:(int)_height];
    }
    
    return self;
}

- (id)initWithCGImage:(CGImageRef)_image {
    self = [self initWithCGImage:_image left:0 top:0 width:(int)CGImageGetWidth(_image) height:(int)CGImageGetHeight(_image)];
    
    return self;
}

- (id)initWithBuffer:(CVPixelBufferRef)buffer
                left:(size_t)_left
                 top:(size_t)_top
               width:(size_t)_width
              height:(size_t)_height {
    CGImageRef _image = [ZXCGImageLuminanceSource createImageFromBuffer:buffer left:(int)_left top:(int)_top width:(int)_width height:(int)_height];
    
    self = [self initWithCGImage:_image];
    
    return self;
}

- (id )initWithBuffer:(CVPixelBufferRef)buffer {
    CGImageRef _image = [ZXCGImageLuminanceSource createImageFromBuffer:buffer];
    
    self = [self initWithCGImage:_image];
    
    return self;
}

//returned array should be freed later!
-(uint32_t *)copyBytesFromBuffer:(CVPixelBufferRef)buffer {
    int bytesPerRow = (int)CVPixelBufferGetBytesPerRow(buffer);
    int dataHeight = (int)CVPixelBufferGetHeight(buffer);

    CVPixelBufferLockBaseAddress(buffer,0);
    
    uint32_t *baseAddress = (uint32_t *)CVPixelBufferGetBaseAddress(buffer);
        
    int size = bytesPerRow*dataHeight;
    
    uint32_t *bytes = (uint32_t*)malloc(size);
    memcpy(bytes, baseAddress+top*bytesPerRow, size);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return bytes;
}

-(id)initWithBuffer:(CVPixelBufferRef)buffer rotation:(CGFloat)degrees {
    if (self = [super init]) {
        rotation = degrees;
        
        bufferWidth = CVPixelBufferGetWidth(buffer);
        bufferHeight = CVPixelBufferGetHeight(buffer);
        
        width = bufferWidth;
        height = bufferHeight;
        
        if(degrees == 90 || degrees == 270) {
            width = bufferHeight;
            height = bufferWidth;
        }
        
        data = [self copyBytesFromBuffer: buffer];
    }
    
    return self;
}

- (CGImageRef)image {
    return image;
}

- (void)dealloc {
    if (image) {
        CGImageRelease(image);
    }
    if (data) {
        free(data);
    }
    
    [super dealloc];
}

- (unsigned char *)row:(int)y {
    /* iOS camera is always rotated 90 degrees. We assume that longer is width.*/
    int Longer = bufferWidth;
    int Shorter = bufferHeight;
    int rowLength = self.width;
    int rowCount = self.height;
    
    if (y < 0 || y >= rowCount) {
        [NSException raise:NSInvalidArgumentException format:@"Requested row is outside the image: %d", y];
    }
    
    unsigned char *row = (unsigned char *)malloc(rowLength * sizeof(unsigned char));
    
    for(int i=0; i<rowLength; i++) {
        uint32_t bgrPixel = 0;
        //new scenario with bgra pixels
        if(rotation == 0.0f) {
            bgrPixel = data[y*Longer+i];
        } else if(rotation == 90.0f) {
            bgrPixel = data[(Shorter-i)*Longer+y];
        } else if(rotation == 180.0f) {
            bgrPixel= data[(Shorter-y)*Longer + Shorter - i];
        } else if(rotation == 270.0f) {
            bgrPixel = data[(Shorter - i) + y];
        } else {
            [NSException raise:NSInvalidArgumentException format:@"Not supported rotation. Make sure degrees are in range: [0, 360) and is multiplication of 90."];
        }
        row[i] = [self processBGRAPixel:bgrPixel];
        
    }
    
    return row;
}

//TODO !!!
- (unsigned char *)matrix {
    int area = self.width * self.height;
    
    unsigned char *result = (unsigned char *)malloc(area * sizeof(unsigned char));
    memcpy(result, data, area * sizeof(unsigned char));
    return result;
}

- (void)initializeWithImage:(CGImageRef)cgimage left:(int)_left top:(int)_top width:(int)_width height:(int)_height {
    data = 0;
    image = CGImageRetain(cgimage);
    left = _left;
    top = _top;
    self->width = _width;
    self->height = _height;
    
    if(left != 0 || top != 0) {
        //we assume that if no offset is set, then image has proper size
        int sourceWidth = (int)CGImageGetWidth(cgimage);
        int sourceHeight = (int)CGImageGetHeight(cgimage);
        
        if (left + self.width > sourceWidth ||
            top + self.height > sourceHeight ||
            top < 0 ||
            left < 0) {
            [NSException raise:NSInvalidArgumentException format:@"Crop rectangle does not fit within image data."];
        }
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(0, self.width, self.height, 8, self.width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(context, FALSE);
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    
    if (top || left) {
        CGContextClipToRect(context, CGRectMake(0, 0, self.width, self.height));
    }
    
    CGContextDrawImage(context, CGRectMake(-left, -top, self.width, self.height), image);
    
    uint32_t *pixelData = (uint32_t *) malloc(self.width * self.height * sizeof(uint32_t));
    memcpy(pixelData, CGBitmapContextGetData(context), self.width * self.height * sizeof(uint32_t));
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    data = (uint32_t *)malloc(self.width * self.height * sizeof(uint32_t));
    
    for (int i = 0; i < self.height * self.width; i++) {
        data[i] = pixelData[i];
    }
    
    free(pixelData);
    
    top = _top;
    left = _left;
}

-(uint32_t)processBGRAPixel:(uint32_t)bgrPixel {
    float alpha = (float)((bgrPixel>>24)&0xFF) / 255.0f;
    float red = (bgrPixel>>16)&0xFF;
    float green = (bgrPixel>>8)&0xFF;
    float blue = (bgrPixel)&0xFF;
    
    // ImageIO premultiplies all PNGs, so we have to "un-premultiply them":
    // http://code.google.com/p/cocos2d-iphone/issues/detail?id=697#c26
    red = round((red / alpha) - 0.001f);
    green = round((green / alpha) - 0.001f);
    blue = round((blue / alpha) - 0.001f);
    
    if (red == green && green == blue) {
        return red;
    } else {
        return (306 * (int)red +
                601 * (int)green +
                117 * (int)blue +
                (0x200)) >> 10; // 0x200 = 1<<9, half an lsb of the result to force rounding
    }
}

-(uint32_t)processRGBPixel:(uint32_t)rgbPixel {
    float red = (rgbPixel>>24)&0xFF;
    float green = (rgbPixel>>16)&0xFF;
    float blue = (rgbPixel>>8)&0xFF;
    float alpha = (float)(rgbPixel & 0xFF) / 255.0f;
    
    // ImageIO premultiplies all PNGs, so we have to "un-premultiply them":
    // http://code.google.com/p/cocos2d-iphone/issues/detail?id=697#c26
    red = round((red / alpha) - 0.001f);
    green = round((green / alpha) - 0.001f);
    blue = round((blue / alpha) - 0.001f);
    
    if (red == green && green == blue) {
        return red;
    } else {
        return (306 * (int)red +
                   601 * (int)green +
                   117 * (int)blue +
                   (0x200)) >> 10; // 0x200 = 1<<9, half an lsb of the result to force rounding
    }
}

- (BOOL)rotateSupported {
    return YES;
}

- (ZXLuminanceSource *)rotateCounterClockwise {
    double radians = 270.0f * M_PI / 180;
    
#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
    radians = -1 * radians;
#endif
    
    int sourceWidth = self.width;
    int sourceHeight = self.height;
    
    CGRect imgRect = CGRectMake(0, 0, sourceWidth, sourceHeight);
    CGAffineTransform transform = CGAffineTransformMakeRotation(radians);
    CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, transform);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 rotatedRect.size.width,
                                                 rotatedRect.size.height,
                                                 CGImageGetBitsPerComponent(self.image),
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    CGContextSetAllowsAntialiasing(context, FALSE);
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(context,
                          +(rotatedRect.size.width/2),
                          +(rotatedRect.size.height/2));
    CGContextRotateCTM(context, radians);
    
    CGContextDrawImage(context, CGRectMake(-imgRect.size.width/2,
                                           -imgRect.size.height/2,
                                           imgRect.size.width,
                                           imgRect.size.height),
                       self.image);
    
    CGImageRef rotatedImage = CGBitmapContextCreateImage(context);
    [NSMakeCollectable(rotatedImage) autorelease];
    
    CFRelease(context);
    
    int _width = self.width;
    return [[[ZXCGImageLuminanceSource alloc] initWithCGImage:rotatedImage left:top top:sourceWidth - (left + _width) width:self.height height:_width] autorelease];
}

@end
