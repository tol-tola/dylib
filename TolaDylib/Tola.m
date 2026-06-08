#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <math.h>

static NSString * const TolaMenuTitle = @"TolaiOS";
static NSString * const TolaMenuSubtitle = @"Unknown Developer";
static NSString * const TolaTelegramURL = @"https://t.me/toltola";
static NSString * const TolaTikTokURL = @"https://www.tiktok.com/@tola.wxw";
static NSString * const TolaFacebookURL = @"https://www.facebook.com/tolawxw";
static NSString * const TolaWebsiteURL = @"https://tolaone.com";
static NSString * const TolaFloatingIconFileName = @"tola_icon.png";
static BOOL const TolaStrictAimESP = YES;

static CGFloat TolaDistance(CGPoint a, CGPoint b) {
    CGFloat dx = a.x - b.x;
    CGFloat dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
}

static CGFloat TolaDistancePointToSegment(CGPoint p, CGPoint a, CGPoint b) {
    CGFloat dx = b.x - a.x;
    CGFloat dy = b.y - a.y;
    CGFloat lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 0.0001) {
        return TolaDistance(p, a);
    }

    CGFloat t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;
    t = MIN(MAX(t, 0.0), 1.0);
    CGPoint projection = CGPointMake(a.x + t * dx, a.y + t * dy);
    return TolaDistance(p, projection);
}

static CGPoint TolaPointAlongLine(CGPoint from, CGPoint to, CGFloat distanceFromTo) {
    CGFloat dx = to.x - from.x;
    CGFloat dy = to.y - from.y;
    CGFloat length = sqrt(dx * dx + dy * dy);
    if (length <= 0.0001) {
        return from;
    }

    return CGPointMake(to.x - (dx / length) * distanceFromTo,
                       to.y - (dy / length) * distanceFromTo);
}

static CGPoint TolaNormalizeVector(CGPoint vector) {
    CGFloat length = sqrt(vector.x * vector.x + vector.y * vector.y);
    if (length <= 0.0001) {
        return CGPointZero;
    }
    return CGPointMake(vector.x / length, vector.y / length);
}

static CGFloat TolaDotProduct(CGPoint a, CGPoint b) {
    return a.x * b.x + a.y * b.y;
}

@interface TolaPassthroughWindow : UIWindow
@end

@implementation TolaPassthroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}

@end

@interface TolaPoolBall : NSObject
@property (nonatomic, assign) CGPoint center;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) CGFloat brightness;
@property (nonatomic, assign) CGFloat saturation;
@property (nonatomic, assign) BOOL cueBall;
@end

@implementation TolaPoolBall
@end

@interface TolaPoolPrediction : NSObject
@property (nonatomic, assign) CGPoint start;
@property (nonatomic, assign) CGPoint end;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat width;
@end

@implementation TolaPoolPrediction
@end

@interface TolaLineOverlayView : UIView
@property (nonatomic, strong) NSArray<TolaPoolBall *> *balls;
@property (nonatomic, strong) NSArray<TolaPoolPrediction *> *predictions;
@property (nonatomic, strong) NSArray<NSValue *> *greenPockets;
@property (nonatomic, assign) CGRect detectedTableRect;
@property (nonatomic, assign) CGPoint aimStart;
@property (nonatomic, assign) CGPoint aimEnd;
@property (nonatomic, assign) BOOL hasAimLine;
@property (nonatomic, copy) NSString *statusText;
@end

@implementation TolaLineOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.balls = @[];
        self.predictions = @[];
        self.greenPockets = @[];
        self.statusText = @"Scanning...";
        self.hasAimLine = NO;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawGuideFrom:(CGPoint)start
                   to:(CGPoint)end
                color:(UIColor *)color
                width:(CGFloat)width {
    UIBezierPath *glowPath = [UIBezierPath bezierPath];
    [glowPath moveToPoint:start];
    [glowPath addLineToPoint:end];
    glowPath.lineCapStyle = kCGLineCapRound;
    glowPath.lineJoinStyle = kCGLineJoinRound;
    glowPath.lineWidth = width + 5.0;
    [[color colorWithAlphaComponent:0.18] setStroke];
    [glowPath stroke];

    UIBezierPath *linePath = [UIBezierPath bezierPath];
    [linePath moveToPoint:start];
    [linePath addLineToPoint:end];
    linePath.lineCapStyle = kCGLineCapRound;
    linePath.lineJoinStyle = kCGLineJoinRound;
    linePath.lineWidth = width;
    [[color colorWithAlphaComponent:0.88] setStroke];
    [linePath stroke];
}

- (void)drawDotAt:(CGPoint)point color:(UIColor *)color radius:(CGFloat)radius {
    UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(point.x - radius - 5.0,
                                                                               point.y - radius - 5.0,
                                                                               (radius + 5.0) * 2.0,
                                                                               (radius + 5.0) * 2.0)];
    [[UIColor blackColor] setFill];
    [ringPath fill];

    CGRect dotRect = CGRectMake(point.x - radius, point.y - radius, radius * 2.0, radius * 2.0);
    UIBezierPath *dotPath = [UIBezierPath bezierPathWithOvalInRect:dotRect];
    [[color colorWithAlphaComponent:0.22] setFill];
    [dotPath fill];

    CGRect innerRect = CGRectInset(dotRect, radius * 0.45, radius * 0.45);
    UIBezierPath *innerPath = [UIBezierPath bezierPathWithOvalInRect:innerRect];
    [color setFill];
    [innerPath fill];
}

- (void)drawRect:(CGRect)rect {
    for (TolaPoolPrediction *prediction in self.predictions) {
        [self drawGuideFrom:prediction.start
                         to:prediction.end
                      color:prediction.color
                      width:prediction.width];
    }

    if (self.hasAimLine) {
        [self drawGuideFrom:self.aimStart
                         to:self.aimEnd
                      color:[UIColor colorWithWhite:1.0 alpha:0.92]
                      width:2.2];
    }

    for (NSValue *pocketValue in self.greenPockets) {
        CGPoint pocket = pocketValue.CGPointValue;
        UIBezierPath *pocketPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(pocket.x - 11.0,
                                                                                    pocket.y - 11.0,
                                                                                    22.0,
                                                                                    22.0)];
        [[UIColor colorWithRed:0.1 green:1.0 blue:0.35 alpha:0.22] setFill];
        [pocketPath fill];
        [[UIColor colorWithRed:0.1 green:1.0 blue:0.35 alpha:0.95] setStroke];
        pocketPath.lineWidth = 2.0;
        [pocketPath stroke];
    }

    // Keep the in-game view clean: no debug ball dots or status text.
}

@end

@interface TolaOverlayController : NSObject
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIButton *floatButton;
@property (nonatomic, strong) TolaLineOverlayView *lineOverlayView;
@property (nonatomic, strong) NSTimer *visionTimer;
@property (nonatomic, assign) BOOL lineESPEnabled;
@end

@implementation TolaOverlayController

+ (instancetype)sharedController {
    static TolaOverlayController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [TolaOverlayController new];
    });
    return controller;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self prepareOverlayWindow];
        [self showMenu];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(rebuildMenuForOrientation)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    });
}

- (void)rebuildMenuForOrientation {
    if (!self.menuView) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self showMenu];
    });
}

- (void)prepareOverlayWindow {
    if (self.overlayWindow) {
        return;
    }

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }

            window = [[TolaPassthroughWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
            break;
        }
    }

    if (!window) {
        window = [[TolaPassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    UIViewController *rootViewController = [UIViewController new];
    rootViewController.view.backgroundColor = UIColor.clearColor;

    window.frame = UIScreen.mainScreen.bounds;
    window.windowLevel = UIWindowLevelAlert + 10.0;
    window.backgroundColor = UIColor.clearColor;
    window.rootViewController = rootViewController;
    window.hidden = NO;

    self.overlayWindow = window;
}

- (UIColor *)tolaBlue {
    return [UIColor colorWithRed:0.0 green:0.57 blue:1.0 alpha:1.0];
}

- (UIColor *)tolaPurple {
    return [UIColor colorWithRed:0.52 green:0.24 blue:1.0 alpha:1.0];
}

- (UIImage *)systemImageNamed:(NSString *)name {
    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

- (NSArray<NSString *> *)floatingIconSearchPaths {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSString *bundlePath = mainBundle.bundlePath;
    NSString *resourcePath = mainBundle.resourcePath;

    if (bundlePath.length > 0) {
        [paths addObject:[bundlePath stringByAppendingPathComponent:TolaFloatingIconFileName]];
        [paths addObject:[[bundlePath stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:TolaFloatingIconFileName]];
    }

    if (resourcePath.length > 0) {
        [paths addObject:[resourcePath stringByAppendingPathComponent:TolaFloatingIconFileName]];
    }

    uint32_t imageCount = _dyld_image_count();
    for (uint32_t index = 0; index < imageCount; index++) {
        const char *imageName = _dyld_get_image_name(index);
        if (!imageName) {
            continue;
        }

        NSString *imagePath = [NSString stringWithUTF8String:imageName];
        if (![imagePath.lastPathComponent.lowercaseString isEqualToString:@"tola.dylib"]) {
            continue;
        }

        NSString *dylibDirectory = imagePath.stringByDeletingLastPathComponent;
        if (dylibDirectory.length > 0) {
            [paths addObject:[dylibDirectory stringByAppendingPathComponent:TolaFloatingIconFileName]];
        }
    }

    return paths;
}

- (UIImage *)floatingIconImage {
    UIImage *image = [UIImage imageNamed:TolaFloatingIconFileName];
    if (image) {
        return image;
    }

    NSString *fileName = TolaFloatingIconFileName.stringByDeletingPathExtension;
    NSString *extension = TolaFloatingIconFileName.pathExtension;
    NSString *bundlePath = [NSBundle.mainBundle pathForResource:fileName ofType:extension];
    if (bundlePath) {
        image = [UIImage imageWithContentsOfFile:bundlePath];
        if (image) {
            return image;
        }
    }

    for (NSString *path in [self floatingIconSearchPaths]) {
        image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            return image;
        }
    }

    return nil;
}

- (UILabel *)labelWithText:(NSString *)text
                  fontSize:(CGFloat)fontSize
                    weight:(UIFontWeight)weight
                     color:(UIColor *)color
                 alignment:(NSTextAlignment)alignment {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = color;
    label.textAlignment = alignment;
    label.font = [UIFont systemFontOfSize:fontSize weight:weight];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.numberOfLines = 1;
    return label;
}

- (UIControl *)menuRowWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                      iconName:(NSString *)iconName
                   fallbackText:(NSString *)fallbackText
                    accentColor:(UIColor *)accentColor
                         action:(SEL)action
                        compact:(BOOL)compact {
    UIControl *row = [UIControl new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [accentColor colorWithAlphaComponent:0.15];
    row.layer.cornerRadius = compact ? 13.0 : 16.0;
    row.layer.borderWidth = 0.0;
    [row addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tintColor = accentColor;
    imageView.image = [[self systemImageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UILabel *fallbackLabel = [self labelWithText:fallbackText
                                        fontSize:(compact ? 21.0 : 25.0)
                                          weight:UIFontWeightBold
                                           color:accentColor
                                       alignment:NSTextAlignmentCenter];
    fallbackLabel.hidden = (imageView.image != nil);

    UILabel *titleLabel = [self labelWithText:title
                                     fontSize:(compact ? 18.0 : 22.0)
                                       weight:UIFontWeightHeavy
                                        color:accentColor
                                    alignment:NSTextAlignmentLeft];

    [row addSubview:imageView];
    [row addSubview:fallbackLabel];
    [row addSubview:titleLabel];

    CGFloat rowHeight = compact ? 50.0 : 60.0;
    CGFloat iconSize = compact ? 24.0 : 28.0;
    CGFloat leading = compact ? 78.0 : 92.0;
    CGFloat gap = compact ? 12.0 : 14.0;

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:rowHeight],

        [imageView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:leading],
        [imageView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [imageView.widthAnchor constraintEqualToConstant:iconSize],
        [imageView.heightAnchor constraintEqualToConstant:iconSize],

        [fallbackLabel.centerXAnchor constraintEqualToAnchor:imageView.centerXAnchor],
        [fallbackLabel.centerYAnchor constraintEqualToAnchor:imageView.centerYAnchor],
        [fallbackLabel.widthAnchor constraintEqualToConstant:iconSize + 10.0],
        [fallbackLabel.heightAnchor constraintEqualToConstant:iconSize + 10.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:gap],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-24.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];

    return row;
}

- (UIStackView *)stackWithAxis:(UILayoutConstraintAxis)axis spacing:(CGFloat)spacing views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = axis;
    stack.spacing = spacing;
    stack.distribution = UIStackViewDistributionFillEqually;
    return stack;
}

- (UIWindow *)gameWindowForVision {
    NSArray<UIWindow *> *windows = UIApplication.sharedApplication.windows;
    for (UIWindow *window in windows.reverseObjectEnumerator) {
        if (window == self.overlayWindow || window.hidden || window.alpha < 0.01) {
            continue;
        }

        if (window.windowLevel <= UIWindowLevelNormal + 1.0) {
            return window;
        }
    }

    return nil;
}

- (UIImage *)captureGameWindow:(UIWindow *)window sourceSize:(CGSize *)sourceSize {
    if (!window) {
        return nil;
    }

    CGSize windowSize = window.bounds.size;
    if (windowSize.width <= 1.0 || windowSize.height <= 1.0) {
        return nil;
    }

    if (sourceSize) {
        *sourceSize = windowSize;
    }

    CGFloat maxAnalysisWidth = 420.0;
    CGFloat scale = MIN(1.0, maxAnalysisWidth / MAX(windowSize.width, 1.0));
    CGSize analysisSize = CGSizeMake(MAX(1.0, floor(windowSize.width * scale)),
                                     MAX(1.0, floor(windowSize.height * scale)));

    UIGraphicsBeginImageContextWithOptions(analysisSize, YES, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, scale, scale);
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (BOOL)isGreenFeltWithR:(UInt8)r g:(UInt8)g b:(UInt8)b {
    return g > 55 && g > r * 1.16 && g > b * 1.08 && (g - r) > 18;
}

- (BOOL)isBallCandidateWithR:(UInt8)r g:(UInt8)g b:(UInt8)b {
    CGFloat maxValue = MAX(MAX(r, g), b) / 255.0;
    CGFloat minValue = MIN(MIN(r, g), b) / 255.0;
    CGFloat saturation = maxValue <= 0.01 ? 0.0 : (maxValue - minValue) / maxValue;
    CGFloat brightness = (r + g + b) / (255.0 * 3.0);
    BOOL brightWhite = brightness > 0.68 && saturation < 0.24;
    BOOL coloredBall = brightness > 0.24 && saturation > 0.18;
    return brightWhite || coloredBall;
}

- (TolaPoolPrediction *)predictionFrom:(CGPoint)start
                                    to:(CGPoint)end
                                 color:(UIColor *)color
                                 width:(CGFloat)width {
    TolaPoolPrediction *prediction = [TolaPoolPrediction new];
    prediction.start = start;
    prediction.end = end;
    prediction.color = color;
    prediction.width = width;
    return prediction;
}

- (NSArray<NSValue *> *)pocketsForTableRect:(CGRect)tableRect {
    if (CGRectIsEmpty(tableRect)) {
        return @[];
    }

    CGFloat minX = CGRectGetMinX(tableRect);
    CGFloat midX = CGRectGetMidX(tableRect);
    CGFloat maxX = CGRectGetMaxX(tableRect);
    CGFloat minY = CGRectGetMinY(tableRect);
    CGFloat maxY = CGRectGetMaxY(tableRect);

    return @[
        [NSValue valueWithCGPoint:CGPointMake(minX, minY)],
        [NSValue valueWithCGPoint:CGPointMake(midX, minY)],
        [NSValue valueWithCGPoint:CGPointMake(maxX, minY)],
        [NSValue valueWithCGPoint:CGPointMake(minX, maxY)],
        [NSValue valueWithCGPoint:CGPointMake(midX, maxY)],
        [NSValue valueWithCGPoint:CGPointMake(maxX, maxY)]
    ];
}

- (BOOL)lineFrom:(CGPoint)start to:(CGPoint)end intersectsPocket:(CGPoint *)pocket tableRect:(CGRect)tableRect {
    NSArray<NSValue *> *pockets = [self pocketsForTableRect:tableRect];
    CGFloat threshold = MAX(CGRectGetWidth(tableRect), CGRectGetHeight(tableRect)) * 0.035;

    for (NSValue *pocketValue in pockets) {
        CGPoint candidate = pocketValue.CGPointValue;
        CGFloat distance = TolaDistancePointToSegment(candidate, start, end);
        if (distance <= threshold) {
            if (pocket) {
                *pocket = candidate;
            }
            return YES;
        }
    }

    return NO;
}

- (CGPoint)rayFrom:(CGPoint)start direction:(CGPoint)direction intersectionWithTableRect:(CGRect)tableRect {
    direction = TolaNormalizeVector(direction);
    if (CGPointEqualToPoint(direction, CGPointZero) || CGRectIsEmpty(tableRect)) {
        return start;
    }

    CGFloat bestT = CGFLOAT_MAX;

    if (fabs(direction.x) > 0.0001) {
        CGFloat leftT = (CGRectGetMinX(tableRect) - start.x) / direction.x;
        CGFloat rightT = (CGRectGetMaxX(tableRect) - start.x) / direction.x;
        if (leftT > 0.0) {
            CGFloat y = start.y + direction.y * leftT;
            if (y >= CGRectGetMinY(tableRect) && y <= CGRectGetMaxY(tableRect)) {
                bestT = MIN(bestT, leftT);
            }
        }
        if (rightT > 0.0) {
            CGFloat y = start.y + direction.y * rightT;
            if (y >= CGRectGetMinY(tableRect) && y <= CGRectGetMaxY(tableRect)) {
                bestT = MIN(bestT, rightT);
            }
        }
    }

    if (fabs(direction.y) > 0.0001) {
        CGFloat topT = (CGRectGetMinY(tableRect) - start.y) / direction.y;
        CGFloat bottomT = (CGRectGetMaxY(tableRect) - start.y) / direction.y;
        if (topT > 0.0) {
            CGFloat x = start.x + direction.x * topT;
            if (x >= CGRectGetMinX(tableRect) && x <= CGRectGetMaxX(tableRect)) {
                bestT = MIN(bestT, topT);
            }
        }
        if (bottomT > 0.0) {
            CGFloat x = start.x + direction.x * bottomT;
            if (x >= CGRectGetMinX(tableRect) && x <= CGRectGetMaxX(tableRect)) {
                bestT = MIN(bestT, bottomT);
            }
        }
    }

    if (bestT == CGFLOAT_MAX) {
        return start;
    }

    return CGPointMake(start.x + direction.x * bestT,
                       start.y + direction.y * bestT);
}

- (TolaPoolBall *)firstBallHitFrom:(CGPoint)start
                         direction:(CGPoint)direction
                             balls:(NSArray<TolaPoolBall *> *)balls
                            ignore:(TolaPoolBall *)ignoredBall
                         tableRect:(CGRect)tableRect {
    CGPoint end = [self rayFrom:start direction:direction intersectionWithTableRect:tableRect];
    TolaPoolBall *bestBall = nil;
    CGFloat bestDistance = CGFLOAT_MAX;

    for (TolaPoolBall *ball in balls) {
        if (ball == ignoredBall) {
            continue;
        }

        CGFloat lineDistance = TolaDistancePointToSegment(ball.center, start, end);
        if (lineDistance > ball.radius * 1.05) {
            continue;
        }

        CGFloat alongDistance = TolaDistance(start, ball.center);
        if (alongDistance < bestDistance) {
            bestDistance = alongDistance;
            bestBall = ball;
        }
    }

    return bestBall;
}

- (CGPoint)correctedAimDirection:(CGPoint)aimDirection
                          cueBall:(TolaPoolBall *)cueBall
                            balls:(NSArray<TolaPoolBall *> *)balls
                        tableRect:(CGRect)tableRect {
    CGPoint forward = TolaNormalizeVector(aimDirection);
    if (CGPointEqualToPoint(forward, CGPointZero) || !cueBall) {
        return forward;
    }

    CGPoint backward = CGPointMake(-forward.x, -forward.y);
    TolaPoolBall *forwardHit = [self firstBallHitFrom:cueBall.center
                                           direction:forward
                                               balls:balls
                                              ignore:cueBall
                                           tableRect:tableRect];
    TolaPoolBall *backwardHit = [self firstBallHitFrom:cueBall.center
                                            direction:backward
                                                balls:balls
                                               ignore:cueBall
                                            tableRect:tableRect];

    if (!forwardHit && backwardHit) {
        return backward;
    }

    if (forwardHit && backwardHit) {
        CGFloat forwardDistance = TolaDistance(cueBall.center, forwardHit.center);
        CGFloat backwardDistance = TolaDistance(cueBall.center, backwardHit.center);
        if (backwardDistance + cueBall.radius * 2.0 < forwardDistance) {
            return backward;
        }
    }

    return forward;
}

- (BOOL)isPathClearFrom:(CGPoint)start
                     to:(CGPoint)end
                  balls:(NSArray<TolaPoolBall *> *)balls
                 ignore:(NSSet<TolaPoolBall *> *)ignoredBalls
              clearance:(CGFloat)clearance {
    for (TolaPoolBall *ball in balls) {
        if ([ignoredBalls containsObject:ball]) {
            continue;
        }

        CGFloat distance = TolaDistancePointToSegment(ball.center, start, end);
        if (distance < ball.radius + clearance) {
            return NO;
        }
    }

    return YES;
}

- (TolaPoolBall *)likelyCueBallFromBalls:(NSArray<TolaPoolBall *> *)balls tableRect:(CGRect)tableRect {
    TolaPoolBall *cueBall = nil;
    CGFloat bestCueScore = -CGFLOAT_MAX;

    for (TolaPoolBall *ball in balls) {
        CGFloat leftBonus = 1.0 - ((ball.center.x - CGRectGetMinX(tableRect)) / MAX(CGRectGetWidth(tableRect), 1.0));
        CGFloat cueScore = ball.brightness * 2.3 - ball.saturation * 1.2 + leftBonus * 0.25;
        if (cueScore > bestCueScore) {
            bestCueScore = cueScore;
            cueBall = ball;
        }
    }

    cueBall.cueBall = YES;
    return cueBall;
}

- (BOOL)isBrightAimPixelWithR:(UInt8)r g:(UInt8)g b:(UInt8)b {
    NSInteger maxValue = MAX(MAX(r, g), b);
    NSInteger minValue = MIN(MIN(r, g), b);
    return maxValue > 188 && (maxValue - minValue) < 62;
}

- (BOOL)detectAimDirectionForCueBall:(TolaPoolBall *)cueBall
                                 data:(UInt8 *)data
                                width:(size_t)width
                               height:(size_t)height
                               scaleX:(CGFloat)scaleX
                               scaleY:(CGFloat)scaleY
                             outVector:(CGPoint *)outVector {
    if (!cueBall || !data || width < 20 || height < 20) {
        return NO;
    }

    CGFloat cueX = cueBall.center.x / MAX(scaleX, 0.0001);
    CGFloat cueY = cueBall.center.y / MAX(scaleY, 0.0001);
    CGFloat startDistance = MAX(10.0, cueBall.radius / MAX(scaleX, 0.0001) * 1.9);
    CGFloat maxDistance = MIN(width, height) * 0.72;
    CGFloat bestScore = 0.0;
    CGFloat bestAngle = 0.0;

    for (NSInteger degree = 0; degree < 360; degree += 3) {
        CGFloat radians = (CGFloat)degree * (CGFloat)M_PI / 180.0;
        CGFloat dx = cos(radians);
        CGFloat dy = sin(radians);
        CGFloat score = 0.0;
        NSInteger streak = 0;

        for (CGFloat distance = startDistance; distance < maxDistance; distance += 4.0) {
            NSInteger x = (NSInteger)llround(cueX + dx * distance);
            NSInteger y = (NSInteger)llround(cueY + dy * distance);
            if (x < 2 || x >= (NSInteger)width - 2 || y < 2 || y >= (NSInteger)height - 2) {
                break;
            }

            NSInteger offset = (y * (NSInteger)width + x) * 4;
            UInt8 r = data[offset];
            UInt8 g = data[offset + 1];
            UInt8 b = data[offset + 2];

            if ([self isBrightAimPixelWithR:r g:g b:b]) {
                streak++;
                score += 1.0 + MIN(streak, 8) * 0.18;
            } else {
                streak = 0;
                score -= 0.08;
            }
        }

        if (score > bestScore) {
            bestScore = score;
            bestAngle = radians;
        }
    }

    if (bestScore < 5.0) {
        return NO;
    }

    if (outVector) {
        *outVector = CGPointMake(cos(bestAngle), sin(bestAngle));
    }
    return YES;
}

- (NSArray<TolaPoolBall *> *)mergeCloseBalls:(NSArray<TolaPoolBall *> *)balls {
    NSMutableArray<TolaPoolBall *> *merged = [NSMutableArray array];

    for (TolaPoolBall *ball in balls) {
        BOOL duplicate = NO;
        for (TolaPoolBall *existing in merged) {
            CGFloat threshold = MAX(existing.radius, ball.radius) * 1.25 + 5.0;
            if (TolaDistance(existing.center, ball.center) < threshold) {
                duplicate = YES;
                if (ball.radius > existing.radius) {
                    existing.center = ball.center;
                    existing.radius = ball.radius;
                    existing.brightness = ball.brightness;
                    existing.saturation = ball.saturation;
                }
                break;
            }
        }

        if (!duplicate) {
            [merged addObject:ball];
        }
    }

    return merged;
}

- (NSDictionary *)predictionForBalls:(NSArray<TolaPoolBall *> *)balls
                            tableRect:(CGRect)tableRect
                              cueBall:(TolaPoolBall *)cueBall
                         aimDirection:(CGPoint)aimDirection
                       hasAimDirection:(BOOL)hasAimDirection {
    if (balls.count < 2 || CGRectIsEmpty(tableRect)) {
        return @{
            @"balls": @[],
            @"predictions": @[],
            @"pockets": @[],
            @"status": @"Auto ESP: scanning balls"
        };
    }

    if (!cueBall) {
        cueBall = [self likelyCueBallFromBalls:balls tableRect:tableRect];
    }
    cueBall.cueBall = YES;
    aimDirection = TolaNormalizeVector(aimDirection);

    NSArray<NSValue *> *pockets = [self pocketsForTableRect:tableRect];
    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];

    if (TolaStrictAimESP && !hasAimDirection) {
        return @{
            @"balls": cueBall ? @[cueBall] : @[],
            @"predictions": @[],
            @"pockets": @[],
            @"status": @"Auto ESP: aim not detected"
        };
    }

    TolaPoolBall *aimedObjectBall = nil;
    if (hasAimDirection) {
        aimedObjectBall = [self firstBallHitFrom:cueBall.center
                                      direction:aimDirection
                                          balls:balls
                                         ignore:cueBall
                                      tableRect:tableRect];
        if (TolaStrictAimESP && !aimedObjectBall) {
            CGPoint aimEnd = [self rayFrom:cueBall.center direction:aimDirection intersectionWithTableRect:tableRect];
            CGPoint touchedPocket = CGPointZero;
            NSMutableArray<TolaPoolPrediction *> *aimOnly = [NSMutableArray arrayWithObject:
                [self predictionFrom:cueBall.center
                                   to:aimEnd
                                color:[UIColor colorWithWhite:1.0 alpha:0.82]
                                width:2.0]
            ];
            NSMutableArray<NSValue *> *pocketHits = [NSMutableArray array];
            if ([self lineFrom:cueBall.center to:aimEnd intersectsPocket:&touchedPocket tableRect:tableRect]) {
                [pocketHits addObject:[NSValue valueWithCGPoint:touchedPocket]];
            }
            return @{
                @"balls": @[cueBall],
                @"predictions": aimOnly,
                @"pockets": pocketHits,
                @"status": @"Auto ESP: cue path"
            };
        }
    }

    for (TolaPoolBall *objectBall in balls) {
        if (objectBall == cueBall) {
            continue;
        }

        if (TolaStrictAimESP && aimedObjectBall && objectBall != aimedObjectBall) {
            continue;
        }

        for (NSValue *pocketValue in pockets) {
            CGPoint pocket = pocketValue.CGPointValue;
            CGFloat objectToPocketDistance = TolaDistance(objectBall.center, pocket);
            if (objectToPocketDistance < objectBall.radius * 2.0) {
                continue;
            }

            CGPoint ghostPoint = TolaPointAlongLine(objectBall.center,
                                                   pocket,
                                                   (cueBall.radius + objectBall.radius) * 1.08);

            NSSet *objectPocketIgnore = [NSSet setWithObjects:objectBall, nil];
            if (![self isPathClearFrom:objectBall.center
                                    to:pocket
                                 balls:balls
                                ignore:objectPocketIgnore
                             clearance:objectBall.radius * 0.25]) {
                continue;
            }

            NSSet *cueObjectIgnore = [NSSet setWithObjects:cueBall, objectBall, nil];
            if (![self isPathClearFrom:cueBall.center
                                    to:ghostPoint
                                 balls:balls
                                ignore:cueObjectIgnore
                             clearance:cueBall.radius * 0.25]) {
                continue;
            }

            CGFloat aimPenalty = 0.0;
            CGFloat aimDot = 1.0;
            if (hasAimDirection) {
                CGPoint shotDirection = TolaNormalizeVector(CGPointMake(ghostPoint.x - cueBall.center.x,
                                                                        ghostPoint.y - cueBall.center.y));
                aimDot = TolaDotProduct(shotDirection, aimDirection);
                if (aimDot < 0.82) {
                    continue;
                }
                aimPenalty = (1.0 - aimDot) * 4200.0;
            }

            CGFloat cueToGhostDistance = TolaDistance(cueBall.center, ghostPoint);
            CGFloat score = cueToGhostDistance + objectToPocketDistance;
            score += aimPenalty;
            [candidates addObject:@{
                @"score": @(score),
                @"object": objectBall,
                @"ghost": [NSValue valueWithCGPoint:ghostPoint],
                @"pocket": [NSValue valueWithCGPoint:pocket],
                @"aimDot": @(aimDot)
            }];
        }
    }

    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"score"] compare:b[@"score"]];
    }];

    NSMutableArray<TolaPoolPrediction *> *predictions = [NSMutableArray array];
    NSMutableArray<TolaPoolBall *> *shownBalls = [NSMutableArray arrayWithObject:cueBall];
    NSMutableArray<NSValue *> *greenPockets = [NSMutableArray array];
    NSInteger maxCandidates = MIN((NSInteger)candidates.count, 1);

    if (maxCandidates == 0 && hasAimDirection && aimedObjectBall) {
        CGPoint contactPoint = TolaPointAlongLine(cueBall.center,
                                                  aimedObjectBall.center,
                                                  cueBall.radius + aimedObjectBall.radius);
        [predictions addObject:[self predictionFrom:cueBall.center
                                                 to:contactPoint
                                              color:[UIColor colorWithWhite:1.0 alpha:0.95]
                                              width:2.8]];
        [shownBalls addObject:aimedObjectBall];

        return @{
            @"balls": shownBalls,
            @"predictions": predictions,
            @"pockets": greenPockets,
            @"status": @"Auto ESP: first hit"
        };
    }

    for (NSInteger index = 0; index < maxCandidates; index++) {
        NSDictionary *candidate = candidates[index];
        TolaPoolBall *objectBall = candidate[@"object"];
        CGPoint ghostPoint = [candidate[@"ghost"] CGPointValue];
        CGPoint pocket = [candidate[@"pocket"] CGPointValue];

        if (![shownBalls containsObject:objectBall]) {
            [shownBalls addObject:objectBall];
        }
        [greenPockets addObject:[NSValue valueWithCGPoint:pocket]];

        UIColor *cueLineColor = index == 0
            ? [UIColor colorWithRed:1.0 green:0.93 blue:0.18 alpha:1.0]
            : [UIColor colorWithRed:1.0 green:0.48 blue:0.18 alpha:1.0];
        UIColor *pocketLineColor = index == 0
            ? [UIColor colorWithRed:0.25 green:0.95 blue:1.0 alpha:1.0]
            : [UIColor colorWithRed:0.65 green:0.2 blue:1.0 alpha:1.0];

        [predictions addObject:[self predictionFrom:cueBall.center
                                                   to:ghostPoint
                                                color:cueLineColor
                                                width:(index == 0 ? 3.0 : 2.0)]];
        [predictions addObject:[self predictionFrom:objectBall.center
                                                   to:pocket
                                                color:pocketLineColor
                                                width:(index == 0 ? 2.6 : 1.9)]];

        CGFloat dx = objectBall.center.x - ghostPoint.x;
        CGFloat dy = objectBall.center.y - ghostPoint.y;
        CGPoint cueStop = CGPointMake(objectBall.center.x - dy * 0.32,
                                      objectBall.center.y + dx * 0.32);
        [predictions addObject:[self predictionFrom:objectBall.center
                                                   to:cueStop
                                                color:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.9]
                                                width:1.6]];
    }

    NSString *status = maxCandidates > 0
        ? [NSString stringWithFormat:@"Auto ESP: %@ shot", hasAimDirection ? @"aimed" : @"best"]
        : @"Auto ESP: no clear pocket path";

    return @{
        @"balls": shownBalls,
        @"predictions": predictions,
        @"pockets": greenPockets,
        @"status": status
    };
}

- (NSDictionary *)analyzePoolImage:(UIImage *)image sourceSize:(CGSize)sourceSize {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        return nil;
    }

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width < 20 || height < 20) {
        return nil;
    }

    size_t bytesPerPixel = 4;
    size_t bytesPerRow = width * bytesPerPixel;
    UInt8 *data = calloc(height * bytesPerRow, sizeof(UInt8));
    if (!data) {
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    if (!context) {
        free(data);
        return nil;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);

    NSInteger *rowGreenCounts = calloc(height, sizeof(NSInteger));
    NSInteger *columnGreenCounts = calloc(width, sizeof(NSInteger));
    NSInteger greenCount = 0;

    if (!rowGreenCounts || !columnGreenCounts) {
        free(data);
        free(rowGreenCounts);
        free(columnGreenCounts);
        return nil;
    }

    for (NSInteger y = 0; y < (NSInteger)height; y++) {
        for (NSInteger x = 0; x < (NSInteger)width; x++) {
            NSInteger offset = (y * (NSInteger)width + x) * 4;
            UInt8 r = data[offset];
            UInt8 g = data[offset + 1];
            UInt8 b = data[offset + 2];

            if ([self isGreenFeltWithR:r g:g b:b]) {
                greenCount++;
                rowGreenCounts[y]++;
                columnGreenCounts[x]++;
            }
        }
    }

    if (greenCount < 800) {
        free(data);
        free(rowGreenCounts);
        free(columnGreenCounts);
        return nil;
    }

    NSInteger minGreenY = 0;
    NSInteger maxGreenY = 0;
    NSInteger bestRowStart = 0;
    NSInteger bestRowEnd = 0;
    NSInteger currentRowStart = -1;
    NSInteger rowThreshold = MAX(24, (NSInteger)(width * 0.24));

    for (NSInteger y = 0; y < (NSInteger)height; y++) {
        BOOL dense = rowGreenCounts[y] >= rowThreshold;
        if (dense && currentRowStart < 0) {
            currentRowStart = y;
        }

        if ((!dense || y == (NSInteger)height - 1) && currentRowStart >= 0) {
            NSInteger currentRowEnd = dense ? y : y - 1;
            if ((currentRowEnd - currentRowStart) > (bestRowEnd - bestRowStart)) {
                bestRowStart = currentRowStart;
                bestRowEnd = currentRowEnd;
            }
            currentRowStart = -1;
        }
    }

    minGreenY = bestRowStart;
    maxGreenY = bestRowEnd;

    NSInteger minGreenX = 0;
    NSInteger maxGreenX = 0;
    NSInteger bestColumnStart = 0;
    NSInteger bestColumnEnd = 0;
    NSInteger currentColumnStart = -1;
    NSInteger tableHeight = MAX(1, maxGreenY - minGreenY + 1);
    NSInteger columnThreshold = MAX(16, (NSInteger)(tableHeight * 0.22));

    for (NSInteger x = 0; x < (NSInteger)width; x++) {
        NSInteger tableColumnGreenCount = 0;
        for (NSInteger y = minGreenY; y <= maxGreenY; y++) {
            NSInteger offset = (y * (NSInteger)width + x) * 4;
            UInt8 r = data[offset];
            UInt8 g = data[offset + 1];
            UInt8 b = data[offset + 2];
            if ([self isGreenFeltWithR:r g:g b:b]) {
                tableColumnGreenCount++;
            }
        }

        BOOL dense = tableColumnGreenCount >= columnThreshold;
        if (dense && currentColumnStart < 0) {
            currentColumnStart = x;
        }

        if ((!dense || x == (NSInteger)width - 1) && currentColumnStart >= 0) {
            NSInteger currentColumnEnd = dense ? x : x - 1;
            if ((currentColumnEnd - currentColumnStart) > (bestColumnEnd - bestColumnStart)) {
                bestColumnStart = currentColumnStart;
                bestColumnEnd = currentColumnEnd;
            }
            currentColumnStart = -1;
        }
    }

    minGreenX = bestColumnStart;
    maxGreenX = bestColumnEnd;
    free(rowGreenCounts);
    free(columnGreenCounts);

    NSInteger tablePixelWidth = maxGreenX - minGreenX;
    NSInteger tablePixelHeight = maxGreenY - minGreenY;
    if (tablePixelWidth < (NSInteger)(width * 0.35) || tablePixelHeight < (NSInteger)(height * 0.25)) {
        free(data);
        return nil;
    }

    CGFloat scaleX = sourceSize.width / MAX((CGFloat)width, 1.0);
    CGFloat scaleY = sourceSize.height / MAX((CGFloat)height, 1.0);
    CGRect tableRect = CGRectMake(minGreenX * scaleX,
                                  minGreenY * scaleY,
                                  MAX(1, maxGreenX - minGreenX) * scaleX,
                                  MAX(1, maxGreenY - minGreenY) * scaleY);

    NSInteger pixelCount = (NSInteger)(width * height);
    UInt8 *mask = calloc(pixelCount, sizeof(UInt8));
    UInt8 *visited = calloc(pixelCount, sizeof(UInt8));
    int *stack = malloc(sizeof(int) * pixelCount);

    if (!mask || !visited || !stack) {
        free(data);
        free(mask);
        free(visited);
        free(stack);
        return nil;
    }

    NSInteger insetX = MAX(3, (maxGreenX - minGreenX) / 90);
    NSInteger insetY = MAX(3, (maxGreenY - minGreenY) / 70);

    for (NSInteger y = minGreenY + insetY; y <= maxGreenY - insetY; y++) {
        for (NSInteger x = minGreenX + insetX; x <= maxGreenX - insetX; x++) {
            NSInteger offset = (y * (NSInteger)width + x) * 4;
            UInt8 r = data[offset];
            UInt8 g = data[offset + 1];
            UInt8 b = data[offset + 2];
            BOOL green = [self isGreenFeltWithR:r g:g b:b];
            BOOL ballCandidate = [self isBallCandidateWithR:r g:g b:b];
            if (!green && ballCandidate) {
                mask[y * (NSInteger)width + x] = 1;
            }
        }
    }

    NSMutableArray<TolaPoolBall *> *detectedBalls = [NSMutableArray array];

    for (NSInteger y = minGreenY + insetY; y <= maxGreenY - insetY; y++) {
        for (NSInteger x = minGreenX + insetX; x <= maxGreenX - insetX; x++) {
            NSInteger startIndex = y * (NSInteger)width + x;
            if (!mask[startIndex] || visited[startIndex]) {
                continue;
            }

            NSInteger top = 0;
            stack[top++] = (int)startIndex;
            visited[startIndex] = 1;

            NSInteger area = 0;
            NSInteger minX = x;
            NSInteger minY = y;
            NSInteger maxX = x;
            NSInteger maxY = y;
            CGFloat sumX = 0.0;
            CGFloat sumY = 0.0;
            CGFloat sumBrightness = 0.0;
            CGFloat sumSaturation = 0.0;

            while (top > 0) {
                NSInteger index = stack[--top];
                NSInteger px = index % (NSInteger)width;
                NSInteger py = index / (NSInteger)width;

                NSInteger offset = index * 4;
                UInt8 r = data[offset];
                UInt8 g = data[offset + 1];
                UInt8 b = data[offset + 2];
                CGFloat maxValue = MAX(MAX(r, g), b) / 255.0;
                CGFloat minValue = MIN(MIN(r, g), b) / 255.0;
                CGFloat saturation = maxValue <= 0.01 ? 0.0 : (maxValue - minValue) / maxValue;
                CGFloat brightness = (r + g + b) / (255.0 * 3.0);

                area++;
                sumX += px;
                sumY += py;
                sumBrightness += brightness;
                sumSaturation += saturation;
                minX = MIN(minX, px);
                minY = MIN(minY, py);
                maxX = MAX(maxX, px);
                maxY = MAX(maxY, py);

                NSInteger neighbors[4] = {
                    index - 1,
                    index + 1,
                    index - (NSInteger)width,
                    index + (NSInteger)width
                };

                for (NSInteger neighborIndex = 0; neighborIndex < 4; neighborIndex++) {
                    NSInteger next = neighbors[neighborIndex];
                    if (next < 0 || next >= pixelCount || visited[next] || !mask[next]) {
                        continue;
                    }

                    NSInteger nx = next % (NSInteger)width;
                    NSInteger ny = next / (NSInteger)width;
                    if (nx < minGreenX + insetX || nx > maxGreenX - insetX ||
                        ny < minGreenY + insetY || ny > maxGreenY - insetY) {
                        continue;
                    }

                    visited[next] = 1;
                    stack[top++] = (int)next;
                }
            }

            NSInteger componentWidth = maxX - minX + 1;
            NSInteger componentHeight = maxY - minY + 1;
            CGFloat ratio = (CGFloat)MAX(componentWidth, componentHeight) / MAX((CGFloat)MIN(componentWidth, componentHeight), 1.0);

            if (area < 12 || area > 900 ||
                componentWidth < 4 || componentHeight < 4 ||
                componentWidth > 36 || componentHeight > 36 ||
                ratio > 2.25) {
                continue;
            }

            TolaPoolBall *ball = [TolaPoolBall new];
            ball.center = CGPointMake((sumX / area) * scaleX, (sumY / area) * scaleY);
            ball.radius = MAX(componentWidth * scaleX, componentHeight * scaleY) / 2.0;
            ball.brightness = sumBrightness / area;
            ball.saturation = sumSaturation / area;
            [detectedBalls addObject:ball];
        }
    }

    NSArray<TolaPoolBall *> *balls = [self mergeCloseBalls:detectedBalls];
    TolaPoolBall *cueBall = [self likelyCueBallFromBalls:balls tableRect:tableRect];
    CGPoint aimDirection = CGPointZero;
    BOOL hasAimDirection = [self detectAimDirectionForCueBall:cueBall
                                                         data:data
                                                        width:width
                                                       height:height
                                                       scaleX:scaleX
                                                       scaleY:scaleY
                                                    outVector:&aimDirection];
    if (hasAimDirection) {
        aimDirection = [self correctedAimDirection:aimDirection
                                           cueBall:cueBall
                                             balls:balls
                                         tableRect:tableRect];
    }
    NSDictionary *prediction = [self predictionForBalls:balls
                                              tableRect:tableRect
                                                cueBall:cueBall
                                           aimDirection:aimDirection
                                         hasAimDirection:hasAimDirection];

    free(data);
    free(mask);
    free(visited);
    free(stack);

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:prediction];
    result[@"table"] = [NSValue valueWithCGRect:tableRect];
    result[@"hasAim"] = @(hasAimDirection);
    if (hasAimDirection && cueBall) {
        CGPoint aimEnd = [self rayFrom:cueBall.center direction:aimDirection intersectionWithTableRect:tableRect];
        result[@"aimStart"] = [NSValue valueWithCGPoint:cueBall.center];
        result[@"aimEnd"] = [NSValue valueWithCGPoint:aimEnd];
    }
    return result;
}

- (void)updateLineESPOverlay {
    UIView *rootView = self.overlayWindow.rootViewController.view;

    if (!self.lineESPEnabled) {
        [self.visionTimer invalidate];
        self.visionTimer = nil;
        [self.lineOverlayView removeFromSuperview];
        self.lineOverlayView = nil;
        return;
    }

    if (self.lineOverlayView) {
        [self.lineOverlayView setNeedsDisplay];
        return;
    }

    TolaLineOverlayView *lineOverlay = [[TolaLineOverlayView alloc] initWithFrame:rootView.bounds];
    lineOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    [rootView insertSubview:lineOverlay atIndex:0];
    self.lineOverlayView = lineOverlay;

    [NSLayoutConstraint activateConstraints:@[
        [lineOverlay.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [lineOverlay.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [lineOverlay.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [lineOverlay.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor]
    ]];
}

- (void)refreshAutoLineESP {
    if (!self.lineESPEnabled || !self.lineOverlayView) {
        return;
    }

    UIWindow *gameWindow = [self gameWindowForVision];
    CGSize sourceSize = CGSizeZero;
    UIImage *image = [self captureGameWindow:gameWindow sourceSize:&sourceSize];
    NSDictionary *result = image ? [self analyzePoolImage:image sourceSize:sourceSize] : nil;

    if (!result) {
        self.lineOverlayView.balls = @[];
        self.lineOverlayView.predictions = @[];
        self.lineOverlayView.greenPockets = @[];
        self.lineOverlayView.detectedTableRect = CGRectZero;
        self.lineOverlayView.hasAimLine = NO;
        self.lineOverlayView.statusText = @"Auto ESP: cannot see table";
        [self.lineOverlayView setNeedsDisplay];
        return;
    }

    self.lineOverlayView.balls = result[@"balls"] ?: @[];
    self.lineOverlayView.predictions = result[@"predictions"] ?: @[];
    self.lineOverlayView.greenPockets = result[@"pockets"] ?: @[];
    self.lineOverlayView.detectedTableRect = [result[@"table"] CGRectValue];
    self.lineOverlayView.hasAimLine = [result[@"hasAim"] boolValue];
    if (self.lineOverlayView.hasAimLine) {
        self.lineOverlayView.aimStart = [result[@"aimStart"] CGPointValue];
        self.lineOverlayView.aimEnd = [result[@"aimEnd"] CGPointValue];
    }
    self.lineOverlayView.statusText = result[@"status"] ?: @"Auto ESP";
    [self.lineOverlayView setNeedsDisplay];
}

- (void)startVisionTimerIfNeeded {
    if (!self.lineESPEnabled || self.visionTimer) {
        return;
    }

    [self refreshAutoLineESP];
    self.visionTimer = [NSTimer timerWithTimeInterval:0.20
                                               target:self
                                             selector:@selector(refreshAutoLineESP)
                                             userInfo:nil
                                              repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.visionTimer forMode:NSRunLoopCommonModes];
}

- (void)toggleLineESP {
    self.lineESPEnabled = !self.lineESPEnabled;
    [self updateLineESPOverlay];
    [self startVisionTimerIfNeeded];
    [self showMenu];
}

- (void)showMenu {
    [self prepareOverlayWindow];
    [self.floatButton removeFromSuperview];
    self.floatButton = nil;
    [self.menuView removeFromSuperview];
    self.menuView = nil;

    UIView *rootView = self.overlayWindow.rootViewController.view;
    for (UIView *view in [rootView.subviews copy]) {
        if (view != self.lineOverlayView) {
            [view removeFromSuperview];
        }
    }
    [self updateLineESPOverlay];

    BOOL compact = CGRectGetHeight(rootView.bounds) < 620.0 || CGRectGetWidth(rootView.bounds) < 370.0;

    UIView *panelView = [UIView new];
    panelView.translatesAutoresizingMaskIntoConstraints = NO;
    panelView.backgroundColor = [UIColor colorWithRed:0.055 green:0.055 blue:0.075 alpha:0.98];
    panelView.layer.cornerRadius = compact ? 20.0 : 24.0;
    panelView.layer.shadowColor = UIColor.blackColor.CGColor;
    panelView.layer.shadowOpacity = 0.42;
    panelView.layer.shadowRadius = 22.0;
    panelView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    panelView.clipsToBounds = NO;

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    closeButton.layer.cornerRadius = compact ? 16.0 : 18.0;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:(compact ? 18.0 : 21.0) weight:UIFontWeightHeavy];
    [closeButton setTitle:@"X" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0]
                      forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];

    UIImageView *topIconView = [UIImageView new];
    topIconView.translatesAutoresizingMaskIntoConstraints = NO;
    topIconView.contentMode = UIViewContentModeScaleAspectFit;
    topIconView.tintColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    UIImage *logoImage = [self floatingIconImage];
    if (logoImage) {
        topIconView.image = [logoImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        topIconView.image = [[self systemImageNamed:@"flame.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    UILabel *titleLabel = [self labelWithText:TolaMenuTitle
                                     fontSize:(compact ? 26.0 : 32.0)
                                       weight:UIFontWeightHeavy
                                        color:UIColor.whiteColor
                                    alignment:NSTextAlignmentCenter];
    UILabel *subtitleLabel = [self labelWithText:TolaMenuSubtitle
                                        fontSize:(compact ? 18.0 : 22.0)
                                          weight:UIFontWeightBold
                                           color:[UIColor colorWithWhite:0.58 alpha:1.0]
                                      alignment:NSTextAlignmentCenter];

    UIControl *lineESP = [self menuRowWithTitle:(self.lineESPEnabled ? @"Line ESP: ON" : @"Line ESP: OFF")
                                       subtitle:@"Auto vision prediction"
                                       iconName:(self.lineESPEnabled ? @"eye.fill" : @"eye.slash.fill")
                                   fallbackText:@"ESP"
                                    accentColor:(self.lineESPEnabled ? [UIColor colorWithRed:0.16 green:0.86 blue:0.35 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.56 blue:0.18 alpha:1.0])
                                         action:@selector(toggleLineESP)
                                        compact:compact];

    UIControl *telegram = [self menuRowWithTitle:@"Telegram"
                                        subtitle:@"Join our Telegram Channel"
                                        iconName:@"paperplane.fill"
                                    fallbackText:@"TG"
                                     accentColor:[self tolaBlue]
                                          action:@selector(openTelegram)
                                         compact:compact];
    UIControl *tikTok = [self menuRowWithTitle:@"TikTok"
                                      subtitle:@"Follow our TikTok"
                                      iconName:@"music.note"
                                  fallbackText:@"TK"
                                   accentColor:UIColor.whiteColor
                                        action:@selector(openTikTok)
                                       compact:compact];
    tikTok.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.76];

    UIControl *facebook = [self menuRowWithTitle:@"Facebook"
                                        subtitle:@"Follow our Facebook Page"
                                        iconName:@"f.cursive.circle.fill"
                                    fallbackText:@"f"
                                     accentColor:[self tolaBlue]
                                          action:@selector(openFacebook)
                                         compact:compact];
    UIControl *website = [self menuRowWithTitle:@"Website"
                                       subtitle:@"Visit our Website"
                                       iconName:@"globe"
                                   fallbackText:@"W"
                                    accentColor:[self tolaPurple]
                                         action:@selector(openWebsite)
                                        compact:compact];
    UIStackView *rowsView = [self stackWithAxis:UILayoutConstraintAxisVertical
                                        spacing:(compact ? 12.0 : 16.0)
                                         views:@[lineESP, telegram, tikTok, facebook, website]];

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        topIconView,
        titleLabel,
        subtitleLabel,
        rowsView
    ]];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.spacing = compact ? 12.0 : 18.0;
    [contentStack setCustomSpacing:(compact ? 18.0 : 28.0) afterView:subtitleLabel];

    [rootView addSubview:panelView];
    [panelView addSubview:scrollView];
    [panelView addSubview:closeButton];
    [scrollView addSubview:contentStack];

    self.menuView = panelView;

    UILayoutGuide *safeArea = rootView.safeAreaLayoutGuide;
    NSLayoutConstraint *panelWidth = [panelView.widthAnchor constraintEqualToConstant:(compact ? 360.0 : 430.0)];
    panelWidth.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *panelHeight = [panelView.heightAnchor constraintEqualToConstant:(compact ? 430.0 : 560.0)];
    panelHeight.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [panelView.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [panelView.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
        [panelView.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:14.0],
        [panelView.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-14.0],
        [panelView.topAnchor constraintGreaterThanOrEqualToAnchor:safeArea.topAnchor constant:10.0],
        [panelView.bottomAnchor constraintLessThanOrEqualToAnchor:safeArea.bottomAnchor constant:-10.0],
        panelWidth,
        panelHeight,

        [closeButton.topAnchor constraintEqualToAnchor:panelView.topAnchor constant:(compact ? 14.0 : 18.0)],
        [closeButton.trailingAnchor constraintEqualToAnchor:panelView.trailingAnchor constant:(compact ? -14.0 : -18.0)],
        [closeButton.widthAnchor constraintEqualToConstant:(compact ? 32.0 : 36.0)],
        [closeButton.heightAnchor constraintEqualToConstant:(compact ? 32.0 : 36.0)],

        [scrollView.topAnchor constraintEqualToAnchor:panelView.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:panelView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:panelView.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:panelView.bottomAnchor],

        [contentStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:(compact ? 30.0 : 38.0)],
        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:(compact ? 32.0 : 34.0)],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:(compact ? -32.0 : -34.0)],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:(compact ? -28.0 : -34.0)],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:(compact ? -64.0 : -68.0)],

        [topIconView.widthAnchor constraintEqualToConstant:(compact ? 48.0 : 58.0)],
        [topIconView.heightAnchor constraintEqualToConstant:(compact ? 48.0 : 58.0)],
        [titleLabel.widthAnchor constraintEqualToAnchor:contentStack.widthAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:contentStack.widthAnchor],
        [rowsView.widthAnchor constraintEqualToAnchor:contentStack.widthAnchor]
    ]];

    panelView.alpha = 0.0;
    panelView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.2 animations:^{
        panelView.alpha = 1.0;
        panelView.transform = CGAffineTransformIdentity;
    }];
}

- (void)closeMenu {
    UIView *menuView = self.menuView;
    [UIView animateWithDuration:0.16 animations:^{
        menuView.alpha = 0.0;
    } completion:^(BOOL finished) {
        UIView *rootView = self.overlayWindow.rootViewController.view;
        for (UIView *view in [rootView.subviews copy]) {
            if (view != self.lineOverlayView) {
                [view removeFromSuperview];
            }
        }
        self.menuView = nil;
        [self updateLineESPOverlay];
        [self showFloatButton];
    }];
}

- (void)showFloatButton {
    UIView *rootView = self.overlayWindow.rootViewController.view;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithRed:0.02 green:0.06 blue:0.11 alpha:0.95];
    button.layer.cornerRadius = 30.0;
    button.layer.borderWidth = 1.2;
    button.layer.borderColor = [[self tolaBlue] colorWithAlphaComponent:0.7].CGColor;
    button.layer.shadowColor = [self tolaBlue].CGColor;
    button.layer.shadowOpacity = 0.34;
    button.layer.shadowRadius = 13.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 5.0);

    UIImage *iconImage = [self floatingIconImage];
    if (iconImage) {
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.imageEdgeInsets = UIEdgeInsetsMake(7.0, 7.0, 7.0, 7.0);
        [button setImage:[iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                forState:UIControlStateNormal];
    } else {
        button.titleLabel.font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightHeavy];
        [button setTitle:@"T" forState:UIControlStateNormal];
        [button setTitleColor:[self tolaBlue] forState:UIControlStateNormal];
    }

    [button addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handleFloatPan:)];
    [button addGestureRecognizer:pan];

    [rootView addSubview:button];
    self.floatButton = button;

    UILayoutGuide *safeArea = rootView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:60.0],
        [button.heightAnchor constraintEqualToConstant:60.0],
        [button.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-18.0],
        [button.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-28.0]
    ]];
}

- (void)handleFloatPan:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    UIView *rootView = button.superview;
    CGPoint translation = [gesture translationInView:rootView];

    button.center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:rootView];

    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGFloat halfWidth = CGRectGetWidth(button.bounds) / 2.0;
        CGFloat halfHeight = CGRectGetHeight(button.bounds) / 2.0;
        CGFloat minX = halfWidth + 8.0;
        CGFloat maxX = CGRectGetWidth(rootView.bounds) - halfWidth - 8.0;
        CGFloat minY = halfHeight + 8.0;
        CGFloat maxY = CGRectGetHeight(rootView.bounds) - halfHeight - 8.0;
        CGFloat targetX = MIN(MAX(button.center.x, minX), maxX);
        CGFloat targetY = MIN(MAX(button.center.y, minY), maxY);

        [UIView animateWithDuration:0.18 animations:^{
            button.center = CGPointMake(targetX, targetY);
        }];
    }
}

- (void)openURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;
    if (![application canOpenURL:url]) {
        return;
    }

    [application openURL:url options:@{} completionHandler:nil];
}

- (void)openTelegram {
    [self openURLString:TolaTelegramURL];
}

- (void)openTikTok {
    [self openURLString:TolaTikTokURL];
}

- (void)openFacebook {
    [self openURLString:TolaFacebookURL];
}

- (void)openWebsite {
    [self openURLString:TolaWebsiteURL];
}

@end

__attribute__((constructor))
static void TolaDylibMain(void) {
    NSLog(@"[tola.dylib] Loaded successfully.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   ^{
                       [[TolaOverlayController sharedController] start];
                   });
}
