#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YTMDownloadsPlayerDelegate <NSObject>
- (void)playerDidRequestNext;
- (void)playerDidRequestPrev;
- (void)playerDidRequestSeekTo:(float)fraction;
- (void)playerDidTogglePlayPause;
- (void)playerDidToggleRepeat;
- (void)playerDidToggleShuffle;
@end

@interface YTMDownloadsPlayerViewController : UIViewController

@property (nonatomic, weak, nullable) id<YTMDownloadsPlayerDelegate> delegate;

// Call these to keep the UI in sync when playback state changes externally
- (void)updateWithTitle:(NSString *)title
                artwork:(nullable UIImage *)artwork
              isPlaying:(BOOL)isPlaying
          repeatEnabled:(BOOL)repeatEnabled
         shuffleEnabled:(BOOL)shuffleEnabled;

- (void)updateProgress:(float)fraction
       elapsedSeconds:(NSTimeInterval)elapsed
      durationSeconds:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
