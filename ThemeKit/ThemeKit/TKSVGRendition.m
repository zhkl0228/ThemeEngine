//
//  TKSVGRendition.m
//  ThemeKit
//
//  Created by Jeremy on 9/5/20.
//  Copyright © 2020 Alex Zielenski. All rights reserved.
//

#import "TKSVGRendition.h"
#import "TKRendition+Private.h"
#import <CoreUI/Renditions/_CUIThemeSVGRendition.h>
#import <objc/objc-runtime.h>

extern void CGSVGDocumentRelease(CGSVGDocumentRef);

/* Not exported
@interface _NSSVGImageRep : NSImageRep {

    CGSVGDocumentRef _document;

}
-(id)initWithSVGDocument:(CGSVGDocumentRef)arg1 ;
-(id)initWithCoder:(id)arg1 ;
-(void)dealloc;
-(void)encodeWithCoder:(id)arg1 ;
-(id)initWithData:(id)arg1 ;
-(char)draw;
@end
 */

@interface TKSVGRendition ()
@end


@implementation TKSVGRendition

- (instancetype)_initWithCUIRendition:(CUIThemeRendition *)rendition csiData:(NSData *)csiData key:(CUIRenditionKey *)key {
    if ((self = [super _initWithCUIRendition:rendition csiData:csiData key:key])) {
        self.svgDocument = ((CGSVGDocumentRef (*)(id, SEL)) objc_msgSend)(rendition, sel_getUid("svgDocument"));
        self.utiType = (__bridge_transfer NSString *)kUTTypeScalableVectorGraphics;
    }
    return self;
}

- (void)computePreviewImageIfNecessary {
    if (self._previewImage)
        return;
    
    id svgImageRep = ((id (*)(id, SEL))objc_msgSend)(objc_lookUpClass("_NSSVGImageRep"), sel_getUid("alloc"));

    id imgRep = ((id (*)(id, SEL, CGSVGDocumentRef))objc_msgSend)(svgImageRep, sel_getUid("initWithSVGDocument:"), self.svgDocument);
    
    self._previewImage = [[NSImage alloc] init];
    [self._previewImage addRepresentation:imgRep];
}

+ (NSSet *)keyPathsForValuesAffectingRawData {
    return [NSSet setWithObject:@"svg"];
}

@end
