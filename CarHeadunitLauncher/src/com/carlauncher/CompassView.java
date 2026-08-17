package com.carlauncher;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.view.View;

/**
 * Compass dial — white-on-transparent design.
 * Circle of 30° (thick) + 5° (thin) ticks, Chinese cardinal labels
 * (北/东/南/西) rotated to their directions, fixed red N marker.
 */
public class CompassView extends View {

    private final Paint mTickThickPaint;
    private final Paint mTickThinPaint;
    private final Paint mTextPaint;
    private final Paint mPointerPaint;
    private final Paint mInfoPaint;

    private float mHeading = 128f; // degrees (0 = North)
    private float mAltitude = 1280f; // meters

    private static final String[] CARDINALS_CN = { "北", "东", "南", "西" };
    private static final float[] CARDINAL_ANGLES = { 0f, 90f, 180f, 270f };
    private static final float[] LABEL_ROTATIONS = { 0f, 90f, 180f, -90f };

    public CompassView(Context context) {
        this(context, null);
    }

    public CompassView(Context context, AttributeSet attrs) {
        super(context, attrs);

        mTickThickPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTickThickPaint.setColor(Color.WHITE);
        mTickThickPaint.setStrokeCap(Paint.Cap.ROUND);

        mTickThinPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTickThinPaint.setColor(Color.WHITE);
        mTickThinPaint.setStrokeCap(Paint.Cap.ROUND);

        mTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTextPaint.setColor(Color.WHITE);
        mTextPaint.setTextAlign(Paint.Align.CENTER);

        mPointerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mPointerPaint.setColor(Color.parseColor("#FF5252"));
        mPointerPaint.setStyle(Paint.Style.FILL);

        mInfoPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mInfoPaint.setColor(Color.WHITE);
        mInfoPaint.setTextAlign(Paint.Align.CENTER);
        mInfoPaint.setFakeBoldText(true);
    }

    private String headingToDirectionCN(float degrees) {
        int idx = Math.round(degrees / 90f) % 4;
        return CARDINALS_CN[(idx + 4) % 4];
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        float w = getWidth();
        float h = getHeight();
        float cx = w / 2f;
        float cy = h * 0.46f;
        float density = getResources().getDisplayMetrics().density;
        float textSize = 22f * density;
        float radius = Math.min(w, h * 0.80f) * 0.42f;

        float tickLen = radius * 0.20f; // tick length
        float thickWidth = radius * 0.04f; // 30° tick width
        float thinWidth = radius * 0.008f; // 5° tick width
        float labelOffset = radius - tickLen - textSize * 0.8f; // label distance from center

        mTickThickPaint.setStrokeWidth(thickWidth);
        mTickThinPaint.setStrokeWidth(thinWidth);
        mTextPaint.setTextSize(textSize);

        // === Rotating dial (ticks + Chinese labels) ===
        canvas.save();
        canvas.rotate(-mHeading, cx, cy);

        // Thick ticks every 30°
        for (int i = 0; i < 360; i += 30) {
            double rad = Math.toRadians(i - 90);
            float cos = (float) Math.cos(rad);
            float sin = (float) Math.sin(rad);
            float ox = cx + cos * radius;
            float oy = cy + sin * radius;
            float ix = cx + cos * (radius - tickLen);
            float iy = cy + sin * (radius - tickLen);
            canvas.drawLine(ox, oy, ix, iy, mTickThickPaint);
        }

        // Thin ticks every 5° (skip 30° positions)
        for (int i = 5; i < 360; i += 5) {
            if (i % 30 == 0)
                continue;
            double rad = Math.toRadians(i - 90);
            float cos = (float) Math.cos(rad);
            float sin = (float) Math.sin(rad);
            float ox = cx + cos * radius;
            float oy = cy + sin * radius;
            float ix = cx + cos * (radius - tickLen);
            float iy = cy + sin * (radius - tickLen);
            canvas.drawLine(ox, oy, ix, iy, mTickThinPaint);
        }

        // Chinese cardinal labels with directional rotation
        for (int i = 0; i < 4; i++) {
            float angle = CARDINAL_ANGLES[i];
            String label = CARDINALS_CN[i];
            float rot = LABEL_ROTATIONS[i];

            double rad = Math.toRadians(angle - 90);
            float cos = (float) Math.cos(rad);
            float sin = (float) Math.sin(rad);
            float lx = cx + cos * labelOffset;
            float ly = cy + sin * labelOffset;

            canvas.save();
            canvas.translate(lx, ly);
            canvas.rotate(rot);
            canvas.drawText(label, 0, textSize * 0.35f, mTextPaint);
            canvas.restore();
        }

        canvas.restore();
        // === End rotating dial ===

        // Fixed red triangle at N (top, outside circle)
        float triangleGap = radius * 0.10f;
        float triangleSize = radius * 0.12f;
        float nx = cx;
        float nyTip = cy - radius - triangleGap - triangleSize;
        float nyBase = cy - radius - triangleGap;
        float txHalf = triangleSize * 0.65f;

        Path triangle = new Path();
        triangle.moveTo(nx, nyTip);
        triangle.lineTo(nx - txHalf, nyBase);
        triangle.lineTo(nx + txHalf, nyBase);
        triangle.close();
        canvas.drawPath(triangle, mPointerPaint);

        // Bottom info: 北 128° 1280m
        String dir = headingToDirectionCN(mHeading);
        String info = dir + " " + (int) mHeading + "°  " + (int) mAltitude + "m";
        float infoY = cy + radius + radius * 0.35f;
        mInfoPaint.setTextSize(textSize);
        canvas.drawText(info, cx, infoY, mInfoPaint);
    }
}
