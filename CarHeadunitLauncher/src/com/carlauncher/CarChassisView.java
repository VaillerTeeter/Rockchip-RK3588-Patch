package com.carlauncher;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

/**
 * TPMS chassis diagram with independent ring gauges per wheel.
 * Ring color: green >= 2.2 bar, yellow >= 1.8 bar, red < 1.8 bar.
 * Layout: 4 gauges at corners + chassis body at center.
 */
public class CarChassisView extends View {

    private final Paint mArcBgPaint;
    private final Paint mArcPaint;
    private final Paint mPressurePaint;
    private final Paint mLabelPaint;
    private final Paint mTempPaint;
    private final Paint mChassisPaint;
    private final Paint mChassisStrokePaint;

    private final float[] mPressures = { 2.3f, 2.3f, 2.1f, 2.2f }; // FL, FR, RL, RR
    private final float[] mTemps = { 35f, 36f, 37f, 36f };
    private static final String[] LABELS = { "FL", "FR", "RL", "RR" };

    private static final float ARC_START = 135f; // start angle for 270° arc
    private static final float ARC_SWEEP = 270f;

    public CarChassisView(Context context) {
        this(context, null);
    }

    public CarChassisView(Context context, AttributeSet attrs) {
        super(context, attrs);

        mArcBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mArcBgPaint.setColor(Color.parseColor("#222233"));
        mArcBgPaint.setStyle(Paint.Style.STROKE);
        mArcBgPaint.setStrokeCap(Paint.Cap.ROUND);

        mArcPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mArcPaint.setStyle(Paint.Style.STROKE);
        mArcPaint.setStrokeCap(Paint.Cap.ROUND);

        mPressurePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mPressurePaint.setColor(Color.WHITE);
        mPressurePaint.setTextAlign(Paint.Align.CENTER);
        mPressurePaint.setFakeBoldText(true);

        mLabelPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLabelPaint.setColor(Color.parseColor("#AAAAAA"));
        mLabelPaint.setTextAlign(Paint.Align.CENTER);

        mTempPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTempPaint.setTextAlign(Paint.Align.CENTER);

        mChassisPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mChassisPaint.setColor(Color.parseColor("#1a1a30"));
        mChassisPaint.setStyle(Paint.Style.FILL);

        mChassisStrokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mChassisStrokePaint.setColor(Color.parseColor("#444466"));
        mChassisStrokePaint.setStyle(Paint.Style.STROKE);
        mChassisStrokePaint.setStrokeWidth(3f);
    }

    private int getArcColor(float pressure) {
        if (pressure >= 2.2f)
            return Color.parseColor("#4CAF50");
        if (pressure >= 1.8f)
            return Color.parseColor("#FFA726");
        return Color.parseColor("#FF5252");
    }

    /**
     * Max display pressure for arc scaling (3.5 bar = full arc).
     */
    private float getArcSweep(float pressure) {
        return Math.min(pressure / 3.5f, 1.0f) * ARC_SWEEP;
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        float w = getWidth();
        float h = getHeight();
        float cx = w / 2f;
        float cy = h / 2f;

        // Gauge size: fill each quadrant, leave small padding
        float quadW = w * 0.5f; // half width
        float quadH = h * 0.5f; // half height
        float gaugeRadius = Math.min(quadW, quadH) * 0.40f;
        float arcStroke = gaugeRadius * 0.18f;

        mArcBgPaint.setStrokeWidth(arcStroke);
        mArcPaint.setStrokeWidth(arcStroke);

        float density = getResources().getDisplayMetrics().density;
        mPressurePaint.setTextSize(32f * density);
        mTempPaint.setTextSize(22f * density);

        // Gauge centers: center of each quadrant
        float[][] gaugeCenters = {
                { quadW * 0.5f, quadH * 0.5f }, // FL
                { quadW * 1.5f, quadH * 0.5f }, // FR
                { quadW * 0.5f, quadH * 1.5f }, // RL
                { quadW * 1.5f, quadH * 1.5f }, // RR
        };

        // Draw each ring gauge
        for (int i = 0; i < 4; i++) {
            float gx = gaugeCenters[i][0];
            float gy = gaugeCenters[i][1];

            RectF oval = new RectF(gx - gaugeRadius, gy - gaugeRadius,
                    gx + gaugeRadius, gy + gaugeRadius);

            // Background arc (full 270°)
            canvas.drawArc(oval, ARC_START, ARC_SWEEP, false, mArcBgPaint);

            // Foreground arc
            mArcPaint.setColor(getArcColor(mPressures[i]));
            canvas.drawArc(oval, ARC_START, getArcSweep(mPressures[i]), false, mArcPaint);

            // Pressure value (upper part of ring center)
            canvas.drawText(String.format("%.1f", mPressures[i]), gx, gy - gaugeRadius * 0.05f,
                    mPressurePaint);

            // Temperature in the 90° arc gap at bottom
            mTempPaint.setColor(getArcColor(mPressures[i]));
            canvas.drawText((int) mTemps[i] + "°C", gx,
                    gy + gaugeRadius * 0.62f, mTempPaint);
        }

    }
}
