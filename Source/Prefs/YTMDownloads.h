#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "../Headers/YTAlertView.h"
#import "../Headers/YTMToastController.h"
#import "../Headers/Localization.h"

@interface YTMDownloads : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *audioFiles;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *label;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *currentPlayerItem;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL isRepeatEnabled;
@property (nonatomic, assign) BOOL isShuffleEnabled;

@property (nonatomic, strong) UIView *playerBarView;
@property (nonatomic, strong) UIImageView *playerArtwork;
@property (nonatomic, strong) UILabel *playerTitleLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) id timeObserverToken;

@end
