//
//  TKRawDataRendition.m
//  ThemeKit
//
//  Created by Alexander Zielenski on 6/14/15.
//  Copyright © 2015 Alex Zielenski. All rights reserved.
//

#import "TKRawDataRendition.h"
#import "TKRendition+Private.h"
#import <SymRez.h>

@import QuartzCore.CATransaction;

NSData *(*_CUIUncompressDataWithLZFSE)(NSData*);
NSData *(*_CUICompressedDataWithLZFSE)(NSData*);

NSString *const TKUTITypeCoreAnimationArchive = @"com.apple.coreanimation-archive";

@interface TKRawDataRendition () {
    CALayer *_rootLayer;
    unsigned int _version;
}
@end

@implementation TKRawDataRendition
@dynamic rootLayer;

- (instancetype)_initWithCUIRendition:(CUIThemeRendition *)rendition csiData:(NSData *)csiData key:(CUIRenditionKey *)key {
    if ((self = [super _initWithCUIRendition:rendition csiData:csiData key:key])) {
        unsigned int listOffset = offsetof(struct csiheader, infolistLength);
        unsigned int listLength = 0;

        [csiData getBytes:&listLength range:NSMakeRange(listOffset, sizeof(listLength))];
        listOffset += listLength + sizeof(unsigned int) * 4;
        
        _version = 0;
        [csiData getBytes:&_version range:NSMakeRange(offsetof(struct csiheader, version), sizeof(_version))];
        
        listOffset += 8;
        unsigned int dataLength = 0;
        [csiData getBytes:&dataLength range:NSMakeRange(listOffset, sizeof(dataLength))];
        
        listOffset += sizeof(dataLength);
        _rawData = [csiData subdataWithRange:NSMakeRange(listOffset, dataLength)];
        
        if (_version != 0) {
            _rawData = _CUIUncompressDataWithLZFSE(_rawData);
        }
        
//         release raw data off of rendition to save ram...
        if ([rendition isKindOfClass:[TKClass(_CUIRawDataRendition) class]]) {
            CFDataRef *dataBytes = (CFDataRef *)TKIvarPointer(self.rendition, "_dataBytes");

            // use __bridge_transfer to transfer ownership to ARC so it releases it at the end
            // of this scope
            CFRelease(*dataBytes);
            // set the variable to NULL
            *dataBytes = NULL;
        }
    }
    
    return self;
}

- (void)computePreviewImageIfNecessary {
    if (self._previewImage)
        return;
    
    if ([self.utiType isEqualToString:TKUTITypeCoreAnimationArchive]) {
        __weak CALayer *layer = self.rootLayer;
        
        self._previewImage = [NSImage imageWithSize:layer.bounds.size
                                            flipped:layer.geometryFlipped
                                     drawingHandler:^BOOL(NSRect dstRect) {
                                         [CATransaction begin];
                                         [CATransaction setDisableActions: YES];
                                         [layer renderInContext:[[NSGraphicsContext currentContext] graphicsPort]];
                                         [CATransaction commit];
                                         return YES;
                                     }];
    } else if (self.utiType != nil) {
        self._previewImage = [[NSWorkspace sharedWorkspace] iconForFileType:self.utiType];
        
    } else {
        [super computePreviewImageIfNecessary];
    }
}

- (CALayer *)copyRootLayer {
    if ([self.utiType isEqualToString:TKUTITypeCoreAnimationArchive]) {
        NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithData:self.rawData];
        CALayer *rootLayer = [archive objectForKey:@"rootLayer"];
        rootLayer.geometryFlipped = [[archive objectForKey:@"geometryFlipped"] boolValue];
        return rootLayer;
    }
    return nil;
}

- (CALayer *)rootLayer {
    if (!_rootLayer) _rootLayer = self.copyRootLayer;
    
    return _rootLayer;
}

- (void)setRootLayer:(CALayer *)rootLayer {
    [self willChangeValueForKey:@"rootLayer"];
    
    self.rawData = [NSKeyedArchiver archivedDataWithRootObject:@{
                                                                 @"rootLayer": rootLayer,
                                                                 @"geometryFlipped": @(rootLayer.geometryFlipped)
                                                                 }];
    _rootLayer = rootLayer;
    self._previewImage = nil;
    [self didChangeValueForKey:@"rootLayer"];
}

- (void)setRawData:(NSData *)rawData {
    [self willChangeValueForKey:@"rawData"];
    _rawData = rawData;
    _rootLayer = nil;
    self._previewImage = nil;
    [self didChangeValueForKey:@"rawData"];
}

+ (NSDictionary *)undoProperties {
    static NSMutableDictionary *TKRawDataProperties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TKRawDataProperties = [NSMutableDictionary dictionary];
        [TKRawDataProperties addEntriesFromDictionary:@{
                                                        TKKey(utiType): @"Change UTI",
                                                        TKKey(rawData): @"Change Data",
                                                        }];
        [TKRawDataProperties addEntriesFromDictionary:[super undoProperties]];
    });
    
    return TKRawDataProperties;
}

- (CSIGenerator *)generator {
    NSData *saveData = self.rawData;
    if (_version != 0) {
        saveData = _CUICompressedDataWithLZFSE(self.rawData);
    }
    
    CSIGenerator *generator = [[CSIGenerator alloc] initWithRawData:saveData
                                                        pixelFormat:self.pixelFormat
                                                             layout:self.layout];
    
    return generator;
}

- (void)setUtiType:(NSString *)utiType {
    [super setUtiType:utiType];
    self._previewImage = nil;
}

+ (void)load {
    symrez_t sr_coreui = symrez_new("CoreUI");
    _CUIUncompressDataWithLZFSE = sr_resolve_symbol(sr_coreui, "_CUIUncompressDataWithLZFSE");
    _CUICompressedDataWithLZFSE = sr_resolve_symbol(sr_coreui, "_CUICompressedDataWithLZFSE");
    free(sr_coreui);
}

@end
