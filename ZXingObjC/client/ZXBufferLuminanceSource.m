/*
 * Copyright 2012 ZXing authors
 * Copyright 2013 Witold Wasilewski
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
#import "ZXBufferLuminanceSource.h"

@implementation ZXBufferLuminanceSource

//returned array should be freed later!
-(uint32_t *)copyBytesFromBuffer:(CVPixelBufferRef)buffer {
    int bytesPerRow = (int)CVPixelBufferGetBytesPerRow(buffer);
    int dataHeight = (int)CVPixelBufferGetHeight(buffer);
    
    CVPixelBufferLockBaseAddress(buffer,0);
    
    uint32_t *baseAddress = (uint32_t *)CVPixelBufferGetBaseAddress(buffer);
    
    int size = bytesPerRow*dataHeight;
    
    uint32_t *bytes = (uint32_t*)malloc(size);
    memcpy(bytes, baseAddress, size);
    
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
        
        mode = true;
        
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
            bgrPixel = data[(Shorter-i-1)*Longer+y];
        } else if(rotation == 180.0f) {
            bgrPixel= data[(Shorter-y-1)*Longer + Shorter - i];
        } else if(rotation == 270.0f) {
            bgrPixel = data[(Shorter - i)*Longer + y];
        } else {
            [NSException raise:NSInvalidArgumentException format:@"Not supported rotation. Make sure degrees are in range: [0, 360) and is multiplication of 90."];
        }
        row[i] = [self processBGRAPixel:bgrPixel];
    }
    
    return row;
}

- (unsigned char *)matrix {
    int area = self.width * self.height;
    
    unsigned char *result = (unsigned char *)malloc(area * sizeof(unsigned char));
    
    //unmultiply whole matrix0
    if(rotation == 0 || rotation == 180) {
        for(int r = 0; r<bufferHeight; r++) {
            for(int c=0; c<bufferWidth; c++) {
                result[r*bufferWidth+c] = [self processBGRAPixel:data[r*bufferWidth+c]];
            }
        }
    } else if(rotation == 90) {
        for(int r = 0; r<bufferWidth; r++) {
            for(int c=0; c<bufferHeight; c++) {
                int column = bufferHeight - c - 1;
                int row = bufferWidth - r - 1;
                result[r*bufferHeight+c] = [self processBGRAPixel:data[column*bufferWidth+(bufferWidth - row)]];
            }
        }
    }
    
    return result;
}

- (void)initializeWithImage:(CGImageRef)cgimage left:(int)_left top:(int)_top width:(int)_width height:(int)_height {
    [NSException raise:@"Not supported" format:@""];
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

- (BOOL)rotateSupported {
    return YES;
}

@end
