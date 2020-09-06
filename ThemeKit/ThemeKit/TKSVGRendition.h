//
//  TKSVGRendition.h
//  ThemeKit
//
//  Created by Jeremy on 9/5/20.
//

#import <ThemeKit/TKRawDataRendition.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct CGSVGDocument* CGSVGDocumentRef;

@interface TKSVGRendition : TKRawDataRendition
@property CGSVGDocumentRef svgDocument;
@end

NS_ASSUME_NONNULL_END
