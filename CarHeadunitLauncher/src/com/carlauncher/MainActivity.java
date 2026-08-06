package com.carlauncher;

import android.app.Activity;
import android.os.Bundle;
import android.provider.Settings;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Lock system to landscape orientation (persisted across reboots)
        // RK3588 car headunit: ROTATION_0 is the natural landscape orientation
        Settings.System.putInt(getContentResolver(),
            Settings.System.ACCELEROMETER_ROTATION, 0);
        Settings.System.putInt(getContentResolver(),
            Settings.System.USER_ROTATION, 0);
    }
}
