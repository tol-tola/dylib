#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString * const TolaMenuTitle = @"TolaiOs";
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

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    button.layer.cornerRadius = 10.0;
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithRed:0.08 green:0.10 blue:0.14 alpha:1.0]
                 forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIImage *)floatingIconImage {
    UIImage *image = [UIImage imageNamed:TolaFloatingIconFileName];
    if (image) {
        return image;
    }

    NSString *fileName = TolaFloatingIconFileName.stringByDeletingPathExtension;
    NSString *extension = TolaFloatingIconFileName.pathExtension;
    NSString *path = [NSBundle.mainBundle pathForResource:fileName ofType:extension];
    if (!path) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}

- (void)showMenu {
    [self prepareOverlayWindow];
    [self.floatButton removeFromSuperview];
    self.floatButton = nil;

    UIView *rootView = self.overlayWindow.rootViewController.view;
    rootView.userInteractionEnabled = YES;

    UIView *dimView = [UIView new];
    dimView.translatesAutoresizingMaskIntoConstraints = NO;
    dimView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    dimView.tag = 1001;

    UIView *menuView = [UIView new];
    menuView.translatesAutoresizingMaskIntoConstraints = NO;
    menuView.backgroundColor = UIColor.whiteColor;
    menuView.layer.cornerRadius = 18.0;
    menuView.layer.shadowColor = UIColor.blackColor.CGColor;
    menuView.layer.shadowOpacity = 0.22;
    menuView.layer.shadowRadius = 24.0;
    menuView.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = TolaMenuTitle;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.08 alpha:1.0];

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"Contact";
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self buttonWithTitle:@"Telegram" action:@selector(openTelegram)],
        [self buttonWithTitle:@"TikTok" action:@selector(openTikTok)],
        [self buttonWithTitle:@"Facebook" action:@selector(openFacebook)],
        [self buttonWithTitle:@"Website" action:@selector(openWebsite)]
    ]];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 10.0;
    stackView.distribution = UIStackViewDistributionFillEqually;

    UIButton *closeButton = [self buttonWithTitle:@"Close" action:@selector(closeMenu)];
    closeButton.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.16 alpha:1.0];
    [closeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    [rootView addSubview:dimView];
    [rootView addSubview:menuView];
    [menuView addSubview:titleLabel];
    [menuView addSubview:subtitleLabel];
    [menuView addSubview:stackView];
    [menuView addSubview:closeButton];

    self.menuView = menuView;

    [NSLayoutConstraint activateConstraints:@[
        [dimView.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [dimView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [dimView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [dimView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],

        [menuView.centerXAnchor constraintEqualToAnchor:rootView.centerXAnchor],
        [menuView.centerYAnchor constraintEqualToAnchor:rootView.centerYAnchor],
        [menuView.widthAnchor constraintLessThanOrEqualToConstant:340.0],
        [menuView.widthAnchor constraintEqualToAnchor:rootView.widthAnchor multiplier:0.84],

        [titleLabel.topAnchor constraintEqualToAnchor:menuView.topAnchor constant:24.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor constant:20.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor constant:-20.0],

        [stackView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [stackView.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor constant:22.0],
        [stackView.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor constant:-22.0],
        [stackView.heightAnchor constraintEqualToConstant:206.0],

        [closeButton.topAnchor constraintEqualToAnchor:stackView.bottomAnchor constant:14.0],
        [closeButton.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor constant:22.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor constant:-22.0],
        [closeButton.heightAnchor constraintEqualToConstant:48.0],
        [closeButton.bottomAnchor constraintEqualToAnchor:menuView.bottomAnchor constant:-22.0]
    ]];

    menuView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    menuView.alpha = 0.0;
    [UIView animateWithDuration:0.2 animations:^{
        menuView.transform = CGAffineTransformIdentity;
        menuView.alpha = 1.0;
    }];
}

- (void)closeMenu {
    UIView *rootView = self.overlayWindow.rootViewController.view;
    UIView *dimView = [rootView viewWithTag:1001];

    [UIView animateWithDuration:0.16 animations:^{
        self.menuView.alpha = 0.0;
        dimView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.menuView removeFromSuperview];
        [dimView removeFromSuperview];
        self.menuView = nil;
        [self showFloatButton];
    }];
}

- (void)showFloatButton {
    UIView *rootView = self.overlayWindow.rootViewController.view;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.16 alpha:1.0];
    button.layer.cornerRadius = 28.0;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.25;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 5.0);

    UIImage *iconImage = [self floatingIconImage];
    if (iconImage) {
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.imageEdgeInsets = UIEdgeInsetsMake(9.0, 9.0, 9.0, 9.0);
        [button setImage:[iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                forState:UIControlStateNormal];
    } else {
        button.titleLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
        [button setTitle:@"T" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }

    [button addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handleFloatPan:)];
    [button addGestureRecognizer:pan];

    [rootView addSubview:button];
    self.floatButton = button;

    UILayoutGuide *safeArea = rootView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:56.0],
        [button.heightAnchor constraintEqualToConstant:56.0],
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
