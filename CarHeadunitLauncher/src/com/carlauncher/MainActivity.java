package com.carlauncher;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ActivityOptions;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;

public class MainActivity extends Activity {

    private static final String AMAP_PACKAGE = "com.autonavi.amapauto";
    private boolean mMapLaunched = false;

    private boolean isAmapRunning() {
        ActivityManager am = (ActivityManager) getSystemService(ACTIVITY_SERVICE);
        for (ActivityManager.RunningAppProcessInfo info : am.getRunningAppProcesses()) {
            if (AMAP_PACKAGE.equals(info.processName)) return true;
        }
        return false;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Lock system to landscape orientation (persisted across reboots)
        Settings.System.putInt(getContentResolver(),
            Settings.System.ACCELEROMETER_ROTATION, 0);
        Settings.System.putInt(getContentResolver(),
            Settings.System.USER_ROTATION, 0);

        // Enable freeform multi-window support via Settings.Global
        Settings.Global.putInt(getContentResolver(),
            "enable_freeform_support", 1);
        Settings.Global.putInt(getContentResolver(),
            "force_resizable_activities", 1);
        Settings.Global.putInt(getContentResolver(),
            "development_settings_enabled", 1);

        // Kill stale amapauto (first boot only) so the fresh launch
        // with freeform options takes effect.
        try {
            Runtime.getRuntime().exec(new String[]{
                "am", "force-stop", AMAP_PACKAGE
            });
        } catch (Exception e) {
            // non-fatal
        }

        final View mapContainer = findViewById(R.id.map_container);
        mapContainer.post(() -> launchMapInBounds(mapContainer));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // When returning to Launcher from another app, re-embed the map
        // in its freeform bounds.  Only fire when we were actually
        // invisible (first onNewIntent after onStop); spurious HOME
        // intents while Launcher is already visible must be ignored.
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        // Bring amapauto to front without any transition animation.
        // FLAG_ACTIVITY_NO_ANIMATION + REORDER_TO_FRONT ensures the
        // freeform window snaps directly to its bounds with no drag-in
        // artifact that would reveal the Launcher background.
        if (mMapLaunched) {
            final View mapContainer = findViewById(R.id.map_container);
            if (mapContainer != null) {
                mapContainer.post(() -> launchMapInBounds(mapContainer));
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
        if (intent == null) return;

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_NO_ANIMATION);

        // android.app.WindowConfiguration.WINDOWING_MODE_FREEFORM = 5 (@hide)
        ActivityOptions options = ActivityOptions.makeBasic();
        options.setLaunchWindowingMode(5);
        options.setLaunchBounds(bounds);

        startActivity(intent, options.toBundle());
        mMapLaunched = true;
    }

    @Override
    public void onBackPressed() {
        // Launcher is HOME — consume back to prevent
        // the pointless "go home" animation looping on itself.
    }
}
