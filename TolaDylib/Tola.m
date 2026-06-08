#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static NSString * const TolaMenuTitle = @"TolaiOS";
static NSString * const TolaMenuSubtitle = @"Unknown Developer";
static NSString * const TolaTelegramURL = @"https://t.me/toltola";
static NSString * const TolaTikTokURL = @"https://www.tiktok.com/@tola.wxw";
static NSString * const TolaFacebookURL = @"https://www.facebook.com/tolawxw";
static NSString * const TolaWebsiteURL = @"https://tolaone.com";
static NSString * const TolaFloatingIconFileName = @"tola_icon.png";

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

@interface TolaOverlayController : NSObject
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIButton *floatButton;
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

- (void)showMenu {
    [self prepareOverlayWindow];
    [self.floatButton removeFromSuperview];
    self.floatButton = nil;
    [self.menuView removeFromSuperview];
    self.menuView = nil;

    UIView *rootView = self.overlayWindow.rootViewController.view;
    for (UIView *view in [rootView.subviews copy]) {
        [view removeFromSuperview];
    }

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
                                         views:@[telegram, tikTok, facebook, website]];

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
            [view removeFromSuperview];
        }
        self.menuView = nil;
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
