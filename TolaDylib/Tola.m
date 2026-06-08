#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static NSString * const TolaMenuTitle = @"TolaiOS";
static NSString * const TolaMenuSubtitle = @"Unknown Developer";
static NSString * const TolaTelegramURL = @"https://t.me/your_username";
static NSString * const TolaTikTokURL = @"https://www.tiktok.com/@your_username";
static NSString * const TolaFacebookURL = @"https://www.facebook.com/your_username";
static NSString * const TolaWebsiteURL = @"https://example.com";
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
    row.backgroundColor = [accentColor colorWithAlphaComponent:0.13];
    row.layer.cornerRadius = compact ? 18.0 : 24.0;
    row.layer.borderWidth = 1.4;
    row.layer.borderColor = [accentColor colorWithAlphaComponent:0.38].CGColor;
    [row addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIView *iconHolder = [UIView new];
    iconHolder.translatesAutoresizingMaskIntoConstraints = NO;
    iconHolder.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
    iconHolder.layer.cornerRadius = compact ? 21.0 : 28.0;

    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tintColor = accentColor;
    imageView.image = [[self systemImageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UILabel *fallbackLabel = [self labelWithText:fallbackText
                                        fontSize:(compact ? 22.0 : 31.0)
                                          weight:UIFontWeightBold
                                           color:accentColor
                                       alignment:NSTextAlignmentCenter];
    fallbackLabel.hidden = (imageView.image != nil);

    UILabel *titleLabel = [self labelWithText:title
                                     fontSize:(compact ? 19.0 : 25.0)
                                       weight:UIFontWeightBold
                                        color:accentColor
                                    alignment:NSTextAlignmentLeft];
    UILabel *subtitleLabel = [self labelWithText:subtitle
                                       fontSize:(compact ? 13.0 : 18.0)
                                         weight:UIFontWeightMedium
                                          color:[UIColor colorWithWhite:0.68 alpha:1.0]
                                      alignment:NSTextAlignmentLeft];

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = compact ? 3.0 : 7.0;

    [row addSubview:iconHolder];
    [iconHolder addSubview:imageView];
    [iconHolder addSubview:fallbackLabel];
    [row addSubview:textStack];

    CGFloat rowHeight = compact ? 86.0 : 116.0;
    CGFloat iconSize = compact ? 42.0 : 56.0;
    CGFloat leading = compact ? 16.0 : 24.0;
    CGFloat gap = compact ? 14.0 : 22.0;

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:rowHeight],

        [iconHolder.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:leading],
        [iconHolder.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconHolder.widthAnchor constraintEqualToConstant:iconSize],
        [iconHolder.heightAnchor constraintEqualToConstant:iconSize],

        [imageView.centerXAnchor constraintEqualToAnchor:iconHolder.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:iconHolder.centerYAnchor],
        [imageView.widthAnchor constraintEqualToAnchor:iconHolder.widthAnchor multiplier:0.72],
        [imageView.heightAnchor constraintEqualToAnchor:iconHolder.heightAnchor multiplier:0.72],

        [fallbackLabel.topAnchor constraintEqualToAnchor:iconHolder.topAnchor],
        [fallbackLabel.leadingAnchor constraintEqualToAnchor:iconHolder.leadingAnchor],
        [fallbackLabel.trailingAnchor constraintEqualToAnchor:iconHolder.trailingAnchor],
        [fallbackLabel.bottomAnchor constraintEqualToAnchor:iconHolder.bottomAnchor],

        [textStack.leadingAnchor constraintEqualToAnchor:iconHolder.trailingAnchor constant:gap],
        [textStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-leading],
        [textStack.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
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

    BOOL landscape = CGRectGetWidth(rootView.bounds) > CGRectGetHeight(rootView.bounds);
    BOOL compact = landscape || CGRectGetHeight(rootView.bounds) < 720.0;
    CGFloat contentWidthMultiplier = landscape ? 0.92 : 0.88;
    CGFloat maxContentWidth = landscape ? 760.0 : 460.0;

    UIView *backgroundView = [UIView new];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundView.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.08 alpha:0.96];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    UIView *contentView = [UIView new];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self labelWithText:TolaMenuTitle
                                     fontSize:(compact ? 42.0 : 54.0)
                                       weight:UIFontWeightHeavy
                                        color:[self tolaBlue]
                                    alignment:NSTextAlignmentCenter];
    UILabel *subtitleLabel = [self labelWithText:TolaMenuSubtitle
                                        fontSize:(compact ? 20.0 : 26.0)
                                          weight:UIFontWeightBold
                                           color:[UIColor colorWithWhite:0.68 alpha:1.0]
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
    tikTok.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;

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
    UIControl *close = [self menuRowWithTitle:@"Close"
                                     subtitle:@"Close this menu"
                                     iconName:@"xmark"
                                 fallbackText:@"X"
                                  accentColor:[UIColor colorWithWhite:0.72 alpha:1.0]
                                       action:@selector(closeMenu)
                                      compact:compact];
    close.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.76];
    close.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;

    UIView *rowsView = nil;
    if (landscape) {
        UIStackView *firstRow = [self stackWithAxis:UILayoutConstraintAxisHorizontal
                                           spacing:14.0
                                            views:@[telegram, tikTok]];
        UIStackView *secondRow = [self stackWithAxis:UILayoutConstraintAxisHorizontal
                                            spacing:14.0
                                             views:@[facebook, website]];
        UIStackView *landscapeRows = [self stackWithAxis:UILayoutConstraintAxisVertical
                                                spacing:14.0
                                                 views:@[firstRow, secondRow, close]];
        rowsView = landscapeRows;
    } else {
        UIStackView *portraitRows = [self stackWithAxis:UILayoutConstraintAxisVertical
                                                spacing:(compact ? 14.0 : 20.0)
                                                 views:@[telegram, tikTok, facebook, website, close]];
        rowsView = portraitRows;
    }

    [rootView addSubview:backgroundView];
    [rootView addSubview:scrollView];
    [scrollView addSubview:contentView];
    [contentView addSubview:titleLabel];
    [contentView addSubview:subtitleLabel];
    [contentView addSubview:rowsView];

    self.menuView = backgroundView;

    UILayoutGuide *safeArea = rootView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [backgroundView.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [backgroundView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [backgroundView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [backgroundView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],

        [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
        [contentView.heightAnchor constraintGreaterThanOrEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:(compact ? 20.0 : 64.0)],
        [titleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [titleLabel.widthAnchor constraintLessThanOrEqualToConstant:maxContentWidth],
        [titleLabel.widthAnchor constraintEqualToAnchor:contentView.widthAnchor multiplier:contentWidthMultiplier],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:(compact ? 4.0 : 12.0)],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:titleLabel.widthAnchor],

        [rowsView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:(compact ? 18.0 : 46.0)],
        [rowsView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [rowsView.widthAnchor constraintEqualToAnchor:titleLabel.widthAnchor],
        [rowsView.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-24.0],
        [rowsView.centerYAnchor constraintLessThanOrEqualToAnchor:contentView.centerYAnchor constant:(landscape ? 46.0 : 120.0)]
    ]];

    backgroundView.alpha = 0.0;
    rowsView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.2 animations:^{
        backgroundView.alpha = 1.0;
        rowsView.transform = CGAffineTransformIdentity;
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
