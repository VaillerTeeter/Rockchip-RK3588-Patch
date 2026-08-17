package com.carlauncher;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

/**
 * Car attitude visualization using beetle PNG images.
 * Left half: side view (beetle_side.png) rotated by pitch angle.
 * Right half: front view (beetle_front.png) rotated by roll angle.
 * Both images are scaled to the same rendered height.
 * Angle values displayed below each image.
 */
public class CarAttitudeView extends View {

    private final Paint mValuePaint;

    private float mPitch = 15f;
    private float mRoll = -12f;

    private Bitmap mSideBitmap;
    private Bitmap mFrontBitmap;
    private boolean mBitmapsReady = false;

    public CarAttitudeView(Context context) {
        this(context, null);
    }

    public CarAttitudeView(Context context, AttributeSet attrs) {
        super(context, attrs);

        mValuePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mValuePaint.setColor(Color.WHITE);
        mValuePaint.setFakeBoldText(true);
        mValuePaint.setTextAlign(Paint.Align.CENTER);

    }

    private void ensureBitmaps(int maxW, int maxH) {
        if (mBitmapsReady)
            return;

        Bitmap sideRaw = BitmapFactory.decodeResource(getResources(), R.drawable.beetle_side);
        Bitmap frontRaw = BitmapFactory.decodeResource(getResources(), R.drawable.beetle_front);
        if (sideRaw == null || frontRaw == null)
            return;

        // Scale side view to fit half width
        float sideScale = (maxW * 0.45f) / sideRaw.getWidth();
        int sideW = (int) (sideRaw.getWidth() * sideScale);
        int sideH = (int) (sideRaw.getHeight() * sideScale);

        // Scale front view to match side view height
        float frontScale = sideH / (float) frontRaw.getHeight();
        int frontW = (int) (frontRaw.getWidth() * frontScale);
        int frontH = (int) (frontRaw.getHeight() * frontScale);

        mSideBitmap = Bitmap.createScaledBitmap(sideRaw, sideW, sideH, true);
        mFrontBitmap = Bitmap.createScaledBitmap(frontRaw, frontW, frontH, true);
        sideRaw.recycle();
        frontRaw.recycle();
        mBitmapsReady = true;
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        float w = getWidth();
        float h = getHeight();
        float halfW = w / 2f;
        float density = getResources().getDisplayMetrics().density;
        float textSize = 22f * density;
        mValuePaint.setTextSize(textSize);

        ensureBitmaps((int) w, (int) h);

        float imageAreaCy = h * 0.38f;
        float valY = h * 0.82f;

        // ===== LEFT HALF: Pitch (side view) =====
        canvas.save();
        canvas.clipRect(0, 0, halfW, h);

        if (mSideBitmap != null && !mSideBitmap.isRecycled()) {
            float cxL = halfW * 0.5f;
            canvas.save();
            canvas.translate(cxL, imageAreaCy);
            canvas.rotate(mPitch, 0, 0);

            Matrix matrix = new Matrix();
            matrix.postTranslate(-mSideBitmap.getWidth() / 2f, -mSideBitmap.getHeight() / 2f);
            canvas.drawBitmap(mSideBitmap, matrix, null);

            canvas.restore();
            canvas.drawText(String.format("%+.0f°", mPitch), cxL, valY, mValuePaint);
        }
        canvas.restore();

        // ===== RIGHT HALF: Roll (front view) =====
        canvas.save();
        canvas.clipRect(halfW, 0, w, h);

        if (mFrontBitmap != null && !mFrontBitmap.isRecycled()) {
            float cxR = halfW * 1.5f;
            canvas.save();
            canvas.translate(cxR, imageAreaCy);
            canvas.rotate(mRoll, 0, 0);

            Matrix matrix = new Matrix();
            matrix.postTranslate(-mFrontBitmap.getWidth() / 2f, -mFrontBitmap.getHeight() / 2f);
            canvas.drawBitmap(mFrontBitmap, matrix, null);

            canvas.restore();
            canvas.drawText(String.format("%+.0f°", mRoll), cxR, valY, mValuePaint);
        }
        canvas.restore();

    }
}
