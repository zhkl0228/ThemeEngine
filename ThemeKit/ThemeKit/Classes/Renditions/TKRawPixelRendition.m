//
//  TKRawPixelRendition.m
//  ThemeKit
//
//  Created by Alexander Zielenski on 7/6/15.
//  Copyright © 2015 Alex Zielenski. All rights reserved.
//

#import "TKRawPixelRendition.h"
#import "TKRendition+Private.h"

struct CUIRawPixelRendition {
    uint32_t tag;
    uint32_t version;
    uint32_t rawDataLength;
    uint8_t rawData[];
} __attribute__((packed));

@interface TKRawPixelRendition ()
@property (strong) NSData *rawData;
@property (strong) NSMutableData *csiData;
@end

@implementation TKRawPixelRendition

- (instancetype)_initWithCUIRendition:(CUIThemeRendition *)rendition csiData:(NSData *)csiData key:(CUIRenditionKey *)key {
    if ((self = [super _initWithCUIRendition:rendition csiData:csiData key:key])) {
        
        self.csiData = [csiData mutableCopy];
        
        unsigned int listOffset = offsetof(struct csiheader, infolistLength);
        unsigned int listLength = 0;
        [csiData getBytes:&listLength range:NSMakeRange(listOffset, sizeof(listLength))];
        listOffset += listLength + sizeof(unsigned int) * 4;
        
        unsigned int type = 0;
        [csiData getBytes:&type range:NSMakeRange(listOffset, sizeof(type))];
        
        listOffset += 8;
        unsigned int dataLength = 0;
        [csiData getBytes:&dataLength range:NSMakeRange(listOffset, sizeof(dataLength))];
        
        listOffset += sizeof(dataLength);
        self.rawData = [csiData subdataWithRange:NSMakeRange(listOffset, dataLength)];
        
        self.image = [[NSBitmapImageRep alloc] initWithData:self.rawData];
    }
    
    return self;
}

- (void)computePreviewImageIfNecessary {
    if (self._previewImage)
        return;
    
    if (self.image) {
        // Just get the image of the rendition
        self._previewImage = [[NSImage alloc] initWithSize:self.image.size];
        [self._previewImage addRepresentation:self.image];
    }
}

- (void)setImage:(NSBitmapImageRep *)image {
    if (self.pixelFormat == 'JPEG') { //Check to see if we need to change colorspace/pixelFormat
        CGColorSpaceRef newColorSpace = CGImageGetColorSpace(image.CGImage);
        CGColorSpaceRef oldColorSpace = CGImageGetColorSpace(self.image.CGImage);
        if (newColorSpace != oldColorSpace) {
            CGColorSpaceModel oldModel = CGColorSpaceGetModel(oldColorSpace);
            if (oldModel == kCGColorSpaceModelMonochrome) {
                CGImageRef origImg = self.image.CGImage;
                NSSize size = NSMakeSize(CGImageGetWidth(origImg), CGImageGetHeight(origImg));
                CGContextRef ctx = CGBitmapContextCreate(NULL, CGImageGetWidth(origImg), CGImageGetHeight(origImg), CGImageGetBitsPerComponent(origImg), 0, CGColorSpaceCreateWithName(kCGColorSpaceSRGB), kCGImageAlphaPremultipliedLast);

                CGRect r = CGRectMake(0, 0, size.width, size.height);
                CGContextDrawImage(ctx, r, image.CGImage);

                CGImageRef newImg = CGBitmapContextCreateImage(ctx);
                _image = [[NSBitmapImageRep alloc] initWithCGImage:newImg];
            }
        }
    }
    return [super setImage:image];
}

- (void)commitToStorage {
    //Can't use jpeg data with CSIGenerator
    NSData *jpegData = [self.image representationUsingType:NSBitmapImageFileTypeJPEG properties:[NSDictionary dictionary]];
    
    void *csiData = self.csiData.mutableBytes;
    struct csiheader *csiHeader = (struct csiheader*)csiData;
    struct CUIRawPixelRendition *rawPix = (struct CUIRawPixelRendition *)(csiData + sizeof(struct csiheader) + csiHeader->infolistLength);
    
    float compressionFactor = (rawPix->rawDataLength) / jpegData.length;
    jpegData = [self.image representationUsingType:NSBitmapImageFileTypeJPEG properties:
                [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor]];
    
    csiHeader->bitmaps.payloadSize = ((unsigned int)jpegData.length + sizeof(struct CUIRawPixelRendition));
    rawPix->rawDataLength = (uint32_t)jpegData.length;
    
    NSMutableData *finalCsiData = [NSMutableData dataWithBytes:csiData length:288];
    [finalCsiData appendBytes:jpegData.bytes length:jpegData.length];
    
    [self.cuiAssetStorage setAsset:finalCsiData forKey:self.keyData];
}

@end
