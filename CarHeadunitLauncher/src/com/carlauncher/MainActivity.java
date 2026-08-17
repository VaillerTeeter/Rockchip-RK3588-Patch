package com.carlauncher;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ActivityOptions;
import android.app.ActivityTaskManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.media.AudioManager;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Bundle;
import android.os.Handler;
import android.provider.Settings;
import android.util.Log;
import android.view.Display;
import android.view.KeyEvent;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.window.WindowContainerTransaction;
import android.window.WindowOrganizer;

import java.util.List;

/**
 * Car headunit home screen.
 *
 * The wallpaper comes from the system wallpaper window (ImageWallpaper),
 * enabled via windowShowWallpaper in Theme.CarLauncher. No wallpaper
 * handling code is needed here — the wallpaper window is composed
 * below this activity and always shows the current image.
 */
public class MainActivity extends Activity {

    private static final String TAG = "CarLauncher";
    private static final String AMAP_PACKAGE = "com.autonavi.amapauto";
    private static final String CLOUDMUSIC_PACKAGE = "com.netease.cloudmusic";
    private static final String XIMALAYA_PACKAGE = "com.ximalaya.ting.android";
    private static final String DOUYIN_PACKAGE = "com.ss.android.ugc.aweme";
    private static final String BILIBILI_PACKAGE = "tv.danmaku.bilibilihd";
    private static final String EMBY_PACKAGE = "com.mb.android";

    private boolean mMapLaunched = false;
    private boolean mMusicLaunched = false;
    private boolean mXimalayaLaunched = false;
    private boolean mDouyinLaunched = false;
    /**
     * True while the embedded freeform windows are (or are about to be)
     * occluded by a fullscreen window — set in onStop() and before raising
     * home in hideCloudMusicViaHome(). restoreEmbeddedWindows() only
     * re-raises the
     * windows when this is set, so focus-only onResume() callbacks (e.g.
     * touching the launcher while a freeform window is up) don't cause
     * redundant reorders that visibly flicker the map.
     */
    private boolean mWindowsCovered = false;
    private ImageView mBtnPlay;
    private ImageView mMusicAppIcon;
    private ImageView mXimalayaAppIcon;
    private ImageView mDouyinAppIcon;
    private ImageView mBilibiliAppIcon;
    private ImageView mEmbyAppIcon;
    private AudioManager mAudioManager;
    private MediaSessionManager mMediaSessionManager;
    private TextView mMediaAppLabel;
    private final Handler mPlaybackHandler = new Handler();

    // The app the controls currently target: the one shown in the sidebar,
    // or the last one pulled down when the sidebar is back to vehicle info.
    private String mControlPackage;
    private MediaController mControlController;
    private PlaybackState mControlState;
    private ComponentName mListenerComponent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Settings.System.putInt(getContentResolver(),
                Settings.System.ACCELEROMETER_ROTATION, 0);
        Settings.System.putInt(getContentResolver(),
                Settings.System.USER_ROTATION, 0);

        Settings.Global.putInt(getContentResolver(),
                "enable_freeform_support", 1);
        Settings.Global.putInt(getContentResolver(),
                "force_resizable_activities", 1);
        Settings.Global.putInt(getContentResolver(),
                "development_settings_enabled", 1);

        try {
            Runtime.getRuntime().exec(new String[] {
                    "am", "force-stop", AMAP_PACKAGE
            });
        } catch (Exception e) {
        }

        try {
            Runtime.getRuntime().exec(new String[] {
                    "appops", "set", AMAP_PACKAGE,
                    "SYSTEM_ALERT_WINDOW", "allow"
            });
        } catch (Exception e) {
        }

        final View mapContainer = findViewById(R.id.map_container);
        mapContainer.post(() -> launchMapInBounds(mapContainer));

        // Music icon card — load app icon and wire click toggle
        mMusicAppIcon = findViewById(R.id.music_app_icon);
        PackageManager pm = getPackageManager();
        try {
            mMusicAppIcon.setImageDrawable(
                    pm.getApplicationIcon(CLOUDMUSIC_PACKAGE));
        } catch (PackageManager.NameNotFoundException e) {
            // App not installed; leave placeholder
        }

        final View cardMusic = findViewById(R.id.card_music);
        final View musicOverlay = findViewById(R.id.music_overlay);
        cardMusic.setOnClickListener(v -> {
            if (mMusicLaunched) {
                // Music is visible — hide it, show vehicle info
                hideCloudMusic();
            } else {
                // Music not visible — launch into sidebar
                // Mutual exclusion: hide Ximalaya first if open.
                if (mXimalayaLaunched) {
                    hideXimalaya();
                }
                // Mutual exclusion: hide Douyin first if open.
                if (mDouyinLaunched) {
                    hideDouyin();
                }
                setControlPackage(CLOUDMUSIC_PACKAGE);
                musicOverlay.post(() -> launchMusicInBounds(musicOverlay));
            }
        });

        // Ximalaya icon card — load app icon and wire click toggle
        mXimalayaAppIcon = findViewById(R.id.ximalaya_app_icon);
        try {
            mXimalayaAppIcon.setImageDrawable(
                    pm.getApplicationIcon(XIMALAYA_PACKAGE));
        } catch (PackageManager.NameNotFoundException e) {
            // App not installed; leave placeholder
        }

        final View ximalayaOverlay = findViewById(R.id.ximalaya_overlay);
        final View cardXimalaya = findViewById(R.id.card_ximalaya);
        cardXimalaya.setOnClickListener(v -> {
            if (mXimalayaLaunched) {
                hideXimalaya();
            } else {
                // Mutual exclusion: hide CloudMusic first if open.
                if (mMusicLaunched) {
                    hideCloudMusic();
                }
                // Mutual exclusion: hide Douyin first if open.
                if (mDouyinLaunched) {
                    hideDouyin();
                }
                setControlPackage(XIMALAYA_PACKAGE);
                ximalayaOverlay.post(() -> launchXimalayaInBounds(ximalayaOverlay));
            }
        });

        // Douyin icon card — load app icon and wire click toggle
        mDouyinAppIcon = findViewById(R.id.douyin_app_icon);
        try {
            mDouyinAppIcon.setImageDrawable(
                    pm.getApplicationIcon(DOUYIN_PACKAGE));
        } catch (PackageManager.NameNotFoundException e) {
            // App not installed; leave placeholder
        }

        final View douyinOverlay = findViewById(R.id.douyin_overlay);
        final View cardDouyin = findViewById(R.id.card_douyin);
        cardDouyin.setOnClickListener(v -> {
            if (mDouyinLaunched) {
                hideDouyin();
            } else {
                // Mutual exclusion: hide CloudMusic first if open.
                if (mMusicLaunched) {
                    hideCloudMusic();
                }
                // Mutual exclusion: hide Ximalaya first if open.
                if (mXimalayaLaunched) {
                    hideXimalaya();
                }
                setControlPackage(DOUYIN_PACKAGE);
                douyinOverlay.post(() -> launchDouyinInBounds(douyinOverlay));
            }
        });

        // Bilibili icon card — load app icon and wire fullscreen launch.
        mBilibiliAppIcon = findViewById(R.id.bilibili_app_icon);
        try {
            mBilibiliAppIcon.setImageDrawable(
                    pm.getApplicationIcon(BILIBILI_PACKAGE));
        } catch (PackageManager.NameNotFoundException e) {
            // App not installed; leave placeholder
        }

        final View cardBilibili = findViewById(R.id.card_bilibili);
        cardBilibili.setOnClickListener(v -> launchBilibiliFullscreen());

        // Emby icon card — load app icon and wire fullscreen launch.
        mEmbyAppIcon = findViewById(R.id.emby_app_icon);
        try {
            mEmbyAppIcon.setImageDrawable(
                    pm.getApplicationIcon(EMBY_PACKAGE));
        } catch (PackageManager.NameNotFoundException e) {
            // App not installed; leave placeholder
        }

        final View cardEmby = findViewById(R.id.card_emby);
        cardEmby.setOnClickListener(v -> launchEmbyFullscreen());

        // Media playback controls
        mAudioManager = (AudioManager) getSystemService(AUDIO_SERVICE);

        mBtnPlay = findViewById(R.id.btn_play);
        mMediaAppLabel = findViewById(R.id.media_app_label);
        findViewById(R.id.btn_prev).setOnClickListener(v -> onPrevClicked());
        mBtnPlay.setOnClickListener(v -> onPlayPauseClicked());
        findViewById(R.id.btn_next).setOnClickListener(v -> onNextClicked());

        // Poll a single source of truth for the play/pause icon.
        mPlaybackHandler.post(mPlaybackPoller);

        // Resolve the target app's MediaController. Audio apps publish one and
        // we control them precisely through it; video apps like Douyin don't
        // maintain a reliable session, so their icon/control fall back to the
        // media-key/focus path.
        mMediaSessionManager = (MediaSessionManager) getSystemService(MEDIA_SESSION_SERVICE);
        mListenerComponent = new ComponentName(this, getClass());
        mMediaSessionManager.addOnActiveSessionsChangedListener(
                mSessionsListener, mListenerComponent);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (mMediaSessionManager != null) {
            mMediaSessionManager.removeOnActiveSessionsChangedListener(mSessionsListener);
        }
        if (mControlController != null) {
            mControlController.unregisterCallback(mControlCb);
            mControlController = null;
        }
        mPlaybackHandler.removeCallbacksAndMessages(null);
    }

    private void dispatchMediaKey(int keyCode) {
        KeyEvent event = new KeyEvent(KeyEvent.ACTION_DOWN, keyCode);
        mAudioManager.dispatchMediaKeyEvent(event);
        KeyEvent upEvent = new KeyEvent(KeyEvent.ACTION_UP, keyCode);
        mAudioManager.dispatchMediaKeyEvent(upEvent);
    }

    // ---- Media playback state + current app tracking ----

    private boolean isAudioPackage(String pkg) {
        return CLOUDMUSIC_PACKAGE.equals(pkg) || XIMALAYA_PACKAGE.equals(pkg);
    }

    private void setControlPackage(String pkg) {
        mControlPackage = pkg;
        updateControlController();
        updateMediaAppLabel();
    }

    private void updateControlController() {
        if (mControlController != null) {
            mControlController.unregisterCallback(mControlCb);
            mControlController = null;
        }
        mControlState = null;
        if (mMediaSessionManager == null || mListenerComponent == null) {
            return;
        }
        try {
            List<MediaController> active = mMediaSessionManager.getActiveSessions(
                    mListenerComponent);
            if (active != null && mControlPackage != null) {
                for (MediaController c : active) {
                    if (mControlPackage.equals(c.getPackageName())) {
                        mControlController = c;
                        mControlController.registerCallback(mControlCb, mPlaybackHandler);
                        mControlState = mControlController.getPlaybackState();
                        break;
                    }
                }
            }
        } catch (SecurityException e) {
            // Control falls back to media keys.
        }
    }

    private final MediaController.Callback mControlCb = new MediaController.Callback() {
        @Override
        public void onPlaybackStateChanged(PlaybackState state) {
            mControlState = state;
            refreshPlayIcon();
        }
    };

    private final MediaSessionManager.OnActiveSessionsChangedListener mSessionsListener =
            controllers -> {
                if (mControlPackage != null) {
                    updateControlController();
                    refreshPlayIcon();
                }
            };

    private final Runnable mPlaybackPoller = new Runnable() {
        @Override
        public void run() {
            refreshPlayIcon();
            mPlaybackHandler.postDelayed(this, 100);
        }
    };

    private void refreshPlayIcon() {
        boolean playing;
        if (isAudioPackage(mControlPackage) && mControlState != null) {
            playing = mControlState.getState() == PlaybackState.STATE_PLAYING;
        } else {
            playing = mAudioManager != null && mAudioManager.isMusicActive();
        }
        mBtnPlay.setImageResource(playing
                ? R.drawable.ic_pause
                : R.drawable.ic_play);
    }

    private void onPrevClicked() {
        if (isAudioPackage(mControlPackage) && mControlController != null) {
            mControlController.getTransportControls().skipToPrevious();
        } else {
            dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS);
        }
    }

    private void onPlayPauseClicked() {
        if (isAudioPackage(mControlPackage) && mControlController != null) {
            boolean playing = mControlState != null
                    && mControlState.getState() == PlaybackState.STATE_PLAYING;
            if (playing) {
                mControlController.getTransportControls().pause();
            } else {
                mControlController.getTransportControls().play();
            }
        } else {
            dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE);
        }
    }

    private void onNextClicked() {
        if (isAudioPackage(mControlPackage) && mControlController != null) {
            mControlController.getTransportControls().skipToNext();
        } else {
            dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_NEXT);
        }
    }

    private void updateMediaAppLabel() {
        if (mMediaAppLabel == null) {
            return;
        }
        String pkg = mControlPackage;
        if (pkg == null || pkg.isEmpty()) {
            mMediaAppLabel.setText(R.string.media_no_app);
            return;
        }
        String label = pkg;
        try {
            CharSequence appLabel = getPackageManager().getApplicationLabel(
                    getPackageManager().getApplicationInfo(pkg, 0));
            if (appLabel != null) {
                label = appLabel.toString();
            }
        } catch (PackageManager.NameNotFoundException e) {
            // Fall back to package name.
        }
        mMediaAppLabel.setText(label);
    }

    // ---- End media playback state + current app tracking ----

    @Override
    protected void onResume() {
        super.onResume();
        // Our window is at the front again (initial start, HOME key, or
        // task re-focused by touch). Any freeform window that was covered
        // while we were away now sits behind us — raise the ones that
        // should stay visible back on top.
        restoreEmbeddedWindows();
        mWindowsCovered = false;
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // singleTask: a HOME intent (physical key or hideCloudMusic) is
        // delivered here. If we were already resumed, onResume() will not
        // fire again even though our task was just raised above the
        // freeform windows — restore them here too. Idempotent.
        restoreEmbeddedWindows();
        mWindowsCovered = false;
    }

    @Override
    protected void onStop() {
        super.onStop();
        // A fullscreen activity now covers us; the embedded freeform
        // windows are occluded as well and must be re-raised on return.
        mWindowsCovered = true;
    }

    /**
     * Raise every embedded freeform window that should be visible (map
     * always, music only while toggled on) back above the home window.
     *
     * No-op unless the windows were actually occluded (mWindowsCovered).
     * Calls are made synchronously once the container views are laid out —
     * posting them to the next frame would leave one composed frame where
     * the occluded region shows the wallpaper, i.e. a visible flicker.
     */
    private void restoreEmbeddedWindows() {
        if (!mWindowsCovered) {
            return;
        }
        if (mMapLaunched) {
            final View mapContainer = findViewById(R.id.map_container);
            if (mapContainer != null) {
                if (mapContainer.getWidth() > 0) {
                    launchMapInBounds(mapContainer);
                } else {
                    mapContainer.post(() -> launchMapInBounds(mapContainer));
                }
            }
        }
        if (mMusicLaunched) {
            final View musicOverlay = findViewById(R.id.music_overlay);
            if (musicOverlay != null) {
                if (musicOverlay.getWidth() > 0) {
                    launchMusicInBounds(musicOverlay);
                } else {
                    musicOverlay.post(() -> launchMusicInBounds(musicOverlay));
                }
            }
        }
        if (mXimalayaLaunched) {
            final View ximalayaOverlay = findViewById(R.id.ximalaya_overlay);
            if (ximalayaOverlay != null) {
                if (ximalayaOverlay.getWidth() > 0) {
                    launchXimalayaInBounds(ximalayaOverlay);
                } else {
                    ximalayaOverlay.post(() -> launchXimalayaInBounds(ximalayaOverlay));
                }
            }
        }
        if (mDouyinLaunched) {
            final View douyinOverlay = findViewById(R.id.douyin_overlay);
            if (douyinOverlay != null) {
                if (douyinOverlay.getWidth() > 0) {
                    launchDouyinInBounds(douyinOverlay);
                } else {
                    douyinOverlay.post(() -> launchDouyinInBounds(douyinOverlay));
                }
            }
        }
    }

    private void launchMapInBounds(View container) {
        int[] location = new int[2];
        container.getLocationOnScreen(location);
        int left = location[0];
        int top = location[1];
        int right = left + container.getWidth();
        int bottom = top + container.getHeight();

        Rect bounds = new Rect(left, top, right, bottom);

        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(AMAP_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        ActivityOptions options = ActivityOptions.makeBasic();
        options.setLaunchWindowingMode(5);
        options.setLaunchBounds(bounds);

        startActivity(intent, options.toBundle());
        mMapLaunched = true;
    }

    /**
     * Re-apply bounds and bring an existing freeform task to the front.
     *
     * ActivityOptions.setLaunchBounds() is ignored when launching an
     * existing task with FLAG_ACTIVITY_REORDER_TO_FRONT, so the window
     * falls to the default freeform position (offset to the left). Reuse
     * the task token directly via WindowContainerTransaction instead.
     *
     * @return true if the task was found and re-placed.
     */
    private boolean relaunchTaskInBounds(String packageName, Rect bounds) {
        try {
            List<ActivityManager.RunningTaskInfo> tasks = ActivityTaskManager
                    .getService().getTasks(50, false, false,
                            Display.DEFAULT_DISPLAY);
            if (tasks == null) {
                return false;
            }
            for (ActivityManager.RunningTaskInfo task : tasks) {
                ComponentName name = task.topActivity != null
                        ? task.topActivity : task.baseActivity;
                if (name != null && packageName.equals(name.getPackageName())) {
                    WindowContainerTransaction wct =
                            new WindowContainerTransaction();
                    wct.setBounds(task.token, bounds);
                    wct.reorder(task.token, true /* onTop */);
                    new WindowOrganizer().applyTransaction(wct);
                    return true;
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "relaunchTaskInBounds failed: " + packageName, e);
        }
        return false;
    }

    /**
     * Cold start places the new task at a cascade-offset position when other
     * freeform windows are still in the stack. Once the task exists, apply
     * WCT bounds deterministically to pull it into the sidebar.
     */
    private void reapplyBounds(String packageName, Rect bounds, int attempts) {
        if (attempts <= 0) {
            return;
        }
        if (relaunchTaskInBounds(packageName, bounds)) {
            return;
        }
        getWindow().getDecorView().postDelayed(
                () -> reapplyBounds(packageName, bounds, attempts - 1), 80);
    }

    private void launchMusicInBounds(View container) {
        int[] location = new int[2];
        container.getLocationOnScreen(location);
        int left = location[0];
        int top = location[1];
        int right = left + container.getWidth();
        int bottom = top + container.getHeight();

        Rect bounds = new Rect(left, top, right, bottom);

        if (relaunchTaskInBounds(CLOUDMUSIC_PACKAGE, bounds)) {
            mMusicLaunched = true;
            return;
        }

        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(CLOUDMUSIC_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        ActivityOptions options = ActivityOptions.makeBasic();
        options.setLaunchWindowingMode(5);
        options.setLaunchBounds(bounds);

        startActivity(intent, options.toBundle());
        mMusicLaunched = true;
        reapplyBounds(CLOUDMUSIC_PACKAGE, bounds, 5);
    }

    /**
     * Hide the CloudMusic freeform window without killing the process.
     *
     * Primary path: reorder the music task to the bottom of the display's
     * task stack via a WindowContainerTransaction. The fullscreen home
     * window (treated as opaque by the window manager's occlusion logic)
     * then hides it. The music task stays alive with all playback state —
     * the next click re-launches it with FLAG_ACTIVITY_REORDER_TO_FRONT.
     * The map task's z-order is never touched, so the map does not flicker.
     *
     * Fallback: raise the home task to the front (covers every freeform
     * window), then immediately restore the ones that should stay visible.
     */
    private void hideCloudMusic() {
        mMusicLaunched = false;
        if (!sendMusicTaskToBack()) {
            hideCloudMusicViaHome();
        }
    }

    /**
     * Move the CloudMusic task to the bottom of the display's task stack.
     *
     * @return true if the reorder transaction was applied, false to use
     *         the home-intent fallback instead.
     */
    private boolean sendMusicTaskToBack() {
        try {
            List<ActivityManager.RunningTaskInfo> tasks = ActivityTaskManager
                    .getService().getTasks(50, false, false,
                            Display.DEFAULT_DISPLAY);
            if (tasks == null) {
                Log.w(TAG, "sendMusicTaskToBack: getTasks returned null");
                return false;
            }
            for (ActivityManager.RunningTaskInfo task : tasks) {
                ComponentName name = task.topActivity != null
                        ? task.topActivity : task.baseActivity;
                if (name != null
                        && CLOUDMUSIC_PACKAGE.equals(name.getPackageName())) {
                    WindowContainerTransaction wct =
                            new WindowContainerTransaction();
                    wct.reorder(task.token, false /* onTop */);
                    new WindowOrganizer().applyTransaction(wct);
                    return true;
                }
            }
            Log.w(TAG, "sendMusicTaskToBack: cloudmusic task not found");
        } catch (Exception e) {
            // Hidden API blocked, permission denied, or task lookup
            // failed — caller falls back to the home-intent approach.
            Log.w(TAG, "sendMusicTaskToBack failed, using home-intent"
                    + " fallback", e);
        }
        return false;
    }

    /**
     * Fallback for {@link #hideCloudMusic()}: cover the music window with
     * the fullscreen home window. The HOME intent retargets this singleTask
     * activity, so onNewIntent() always fires after the task has been
     * raised and restores the map — exactly once per hide, with no risk of
     * the map being raised before home (the intent is only delivered after
     * the reorder has been processed).
     */
    private void hideCloudMusicViaHome() {
        // Home is about to occlude every embedded freeform window.
        mWindowsCovered = true;

        Intent home = new Intent(Intent.ACTION_MAIN);
        home.addCategory(Intent.CATEGORY_HOME);
        home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);
        startActivity(home);
    }

    private void launchXimalayaInBounds(View container) {
        int[] location = new int[2];
        container.getLocationOnScreen(location);
        int left = location[0];
        int top = location[1];
        int right = left + container.getWidth();
        int bottom = top + container.getHeight();

        Rect bounds = new Rect(left, top, right, bottom);

        if (relaunchTaskInBounds(XIMALAYA_PACKAGE, bounds)) {
            mXimalayaLaunched = true;
            return;
        }

        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(XIMALAYA_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        ActivityOptions options = ActivityOptions.makeBasic();
        options.setLaunchWindowingMode(5);
        options.setLaunchBounds(bounds);

        startActivity(intent, options.toBundle());
        mXimalayaLaunched = true;
        reapplyBounds(XIMALAYA_PACKAGE, bounds, 5);
    }

    /**
     * Hide the Ximalaya freeform window without killing the process.
     */
    private void hideXimalaya() {
        mXimalayaLaunched = false;
        if (!sendXimalayaTaskToBack()) {
            hideXimalayaViaHome();
        }
    }

    /**
     * Move the Ximalaya task to the bottom of the display's task stack.
     *
     * @return true if the reorder transaction was applied, false to use
     *         the home-intent fallback instead.
     */
    private boolean sendXimalayaTaskToBack() {
        try {
            List<ActivityManager.RunningTaskInfo> tasks = ActivityTaskManager
                    .getService().getTasks(50, false, false,
                            Display.DEFAULT_DISPLAY);
            if (tasks == null) {
                Log.w(TAG, "sendXimalayaTaskToBack: getTasks returned null");
                return false;
            }
            for (ActivityManager.RunningTaskInfo task : tasks) {
                ComponentName name = task.topActivity != null
                        ? task.topActivity : task.baseActivity;
                if (name != null
                        && XIMALAYA_PACKAGE.equals(name.getPackageName())) {
                    WindowContainerTransaction wct =
                            new WindowContainerTransaction();
                    wct.reorder(task.token, false /* onTop */);
                    new WindowOrganizer().applyTransaction(wct);
                    return true;
                }
            }
            Log.w(TAG, "sendXimalayaTaskToBack: ximalaya task not found");
        } catch (Exception e) {
            // Hidden API blocked, permission denied, or task lookup
            // failed — caller falls back to the home-intent approach.
            Log.w(TAG, "sendXimalayaTaskToBack failed, using home-intent"
                    + " fallback", e);
        }
        return false;
    }

    /**
     * Fallback for {@link #hideXimalaya()}: cover the audio window with
     * the fullscreen home window.
     */
    private void hideXimalayaViaHome() {
        // Home is about to occlude every embedded freeform window.
        mWindowsCovered = true;

        Intent home = new Intent(Intent.ACTION_MAIN);
        home.addCategory(Intent.CATEGORY_HOME);
        home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);
        startActivity(home);
    }

    private void launchDouyinInBounds(View container) {
        int[] location = new int[2];
        container.getLocationOnScreen(location);
        int left = location[0];
        int top = location[1];
        int right = left + container.getWidth();
        int bottom = top + container.getHeight();

        Rect bounds = new Rect(left, top, right, bottom);

        if (relaunchTaskInBounds(DOUYIN_PACKAGE, bounds)) {
            mDouyinLaunched = true;
            return;
        }

        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(DOUYIN_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        ActivityOptions options = ActivityOptions.makeBasic();
        options.setLaunchWindowingMode(5);
        options.setLaunchBounds(bounds);

        startActivity(intent, options.toBundle());
        mDouyinLaunched = true;
        reapplyBounds(DOUYIN_PACKAGE, bounds, 5);
    }

    /**
     * Hide the Douyin freeform window without killing the process.
     */
    private void hideDouyin() {
        mDouyinLaunched = false;
        if (!sendDouyinTaskToBack()) {
            hideDouyinViaHome();
        }
    }

    /**
     * Move the Douyin task to the bottom of the display's task stack.
     *
     * @return true if the reorder transaction was applied, false to use
     *         the home-intent fallback instead.
     */
    private boolean sendDouyinTaskToBack() {
        try {
            List<ActivityManager.RunningTaskInfo> tasks = ActivityTaskManager
                    .getService().getTasks(50, false, false,
                            Display.DEFAULT_DISPLAY);
            if (tasks == null) {
                Log.w(TAG, "sendDouyinTaskToBack: getTasks returned null");
                return false;
            }
            for (ActivityManager.RunningTaskInfo task : tasks) {
                ComponentName name = task.topActivity != null
                        ? task.topActivity : task.baseActivity;
                if (name != null
                        && DOUYIN_PACKAGE.equals(name.getPackageName())) {
                    WindowContainerTransaction wct =
                            new WindowContainerTransaction();
                    wct.reorder(task.token, false /* onTop */);
                    new WindowOrganizer().applyTransaction(wct);
                    return true;
                }
            }
            Log.w(TAG, "sendDouyinTaskToBack: douyin task not found");
        } catch (Exception e) {
            // Hidden API blocked, permission denied, or task lookup
            // failed — caller falls back to the home-intent approach.
            Log.w(TAG, "sendDouyinTaskToBack failed, using home-intent"
                    + " fallback", e);
        }
        return false;
    }

    /**
     * Fallback for {@link #hideDouyin()}: cover the video window with
     * the fullscreen home window.
     */
    private void hideDouyinViaHome() {
        // Home is about to occlude every embedded freeform window.
        mWindowsCovered = true;

        Intent home = new Intent(Intent.ACTION_MAIN);
        home.addCategory(Intent.CATEGORY_HOME);
        home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);
        startActivity(home);
    }

    private void launchBilibiliFullscreen() {
        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(BILIBILI_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        startActivity(intent);
    }

    private void launchEmbyFullscreen() {
        Intent intent = getPackageManager()
                .getLaunchIntentForPackage(EMBY_PACKAGE);
        if (intent == null)
            return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        startActivity(intent);
    }

    @Override
    public void onBackPressed() {
    }
}
