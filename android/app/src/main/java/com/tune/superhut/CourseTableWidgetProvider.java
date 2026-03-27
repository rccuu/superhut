package com.tune.superhut;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 课程表桌面小组件提供者
 * 实现今日紧凑课表卡片
 */
public class CourseTableWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_REFRESH = "com.tune.superhut.ACTION_REFRESH";
    public static final String ACTION_AUTO_UPDATE = "com.tune.superhut.ACTION_AUTO_UPDATE_WIDGET";
    private static final String EXTRA_WIDGET_ACTION = "widget_action";
    private static final String WIDGET_ACTION_COURSE = "course";
    private static final String PAYLOAD_FILE_NAME = "course_widget_payload.json";
    private static final String TAG = "CourseTableWidgetProv";

    private static final int COURSE_TABLE_BASE_REQUEST_CODE = 20000;
    private static final long UPDATE_INTERVAL_MS = 30 * 60 * 1000;
    private static final int COMPACT_WIDTH_THRESHOLD_DP = 196;
    private static final int COMPACT_HEIGHT_THRESHOLD_DP = 184;
    private static final int MEDIUM_WIDTH_THRESHOLD_DP = 232;
    private static final int MEDIUM_HEIGHT_THRESHOLD_DP = 228;

    private static final int[] COURSE_ROW_IDS = {
            R.id.widget_course_row_1,
            R.id.widget_course_row_2,
            R.id.widget_course_row_3
    };

    private static final int[] COURSE_NAME_IDS = {
            R.id.widget_course_name_1,
            R.id.widget_course_name_2,
            R.id.widget_course_name_3
    };

    private static final int[] COURSE_META_IDS = {
            R.id.widget_course_meta_1,
            R.id.widget_course_meta_2,
            R.id.widget_course_meta_3
    };

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate 被调用，更新小组件");
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }

        setupPeriodicUpdate(context);
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        Log.d(TAG, "onEnabled 被调用，第一次添加小组件");
        setupPeriodicUpdate(context);
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        Log.d(TAG, "onDisabled 被调用，移除所有小组件");
        cancelPeriodicUpdate(context);
    }

    @Override
    public void onAppWidgetOptionsChanged(
            Context context,
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            Bundle newOptions
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions);
        Log.d(TAG, "小组件尺寸变化，重新渲染 ID: " + appWidgetId);
        updateAppWidget(context, appWidgetManager, appWidgetId);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        String action = intent.getAction();
        Log.d(TAG, "接收到广播: " + action);

        if (ACTION_REFRESH.equals(action) || ACTION_AUTO_UPDATE.equals(action)) {
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            ComponentName thisWidget = new ComponentName(context, CourseTableWidgetProvider.class);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget);

            for (int appWidgetId : appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId);
            }

            if (ACTION_AUTO_UPDATE.equals(action)) {
                Log.d(TAG, "执行定时自动刷新");
            }
        } else if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            Log.d(TAG, "系统启动完成，设置定时刷新");
            setupPeriodicUpdate(context);
        }
    }

    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "更新小组件 ID: " + appWidgetId);
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.coursetable_widget);
            CompactPayload payload = loadCompactPayload(context);
            WidgetLayoutConfig layoutConfig = resolveLayoutConfig(appWidgetManager, appWidgetId);

            views.setTextViewText(R.id.widget_title, buildHeaderTitle(payload));
            String subtitle = buildHeaderSubtitle(payload);
            if (layoutConfig.showSubtitle && !subtitle.isEmpty()) {
                views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE);
                views.setTextViewText(R.id.widget_subtitle, subtitle);
            } else {
                views.setViewVisibility(R.id.widget_subtitle, View.GONE);
            }
            views.setTextViewText(R.id.widget_empty_view, buildEmptyStateText());

            Intent refreshIntent = new Intent(context, CourseTableWidgetProvider.class);
            refreshIntent.setAction(ACTION_REFRESH);
            refreshIntent.putExtra("widget_id", appWidgetId);
            refreshIntent.putExtra("timestamp", System.currentTimeMillis());
            PendingIntent refreshPendingIntent = createPendingIntent(
                    context,
                    refreshIntent,
                    COURSE_TABLE_BASE_REQUEST_CODE + 1,
                    true
            );
            views.setOnClickPendingIntent(R.id.widget_title, refreshPendingIntent);

            PendingIntent openCoursePendingIntent = buildOpenCoursePendingIntent(context);
            if (openCoursePendingIntent != null) {
                views.setOnClickPendingIntent(R.id.widget_card_root, openCoursePendingIntent);
                views.setOnClickPendingIntent(R.id.widget_empty_view, openCoursePendingIntent);
            }

            if (payload.courses.isEmpty()) {
                showEmptyState(views);
            } else {
                bindCourses(views, payload.courses, layoutConfig);
            }

            appWidgetManager.updateAppWidget(appWidgetId, views);
            Log.d(TAG, "小组件更新完成");
        } catch (Exception e) {
            Log.e(TAG, "更新小组件视图时出错: " + e.getMessage(), e);
        }
    }

    private static PendingIntent buildOpenCoursePendingIntent(Context context) {
        Intent openAppIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (openAppIntent == null) {
            return null;
        }
        openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        openAppIntent.putExtra(EXTRA_WIDGET_ACTION, WIDGET_ACTION_COURSE);
        return createPendingIntent(context, openAppIntent, COURSE_TABLE_BASE_REQUEST_CODE + 2, false);
    }

    private static void showEmptyState(RemoteViews views) {
        for (int rowId : COURSE_ROW_IDS) {
            views.setViewVisibility(rowId, View.GONE);
        }
        views.setViewVisibility(R.id.widget_empty_view, View.VISIBLE);
    }

    private static void bindCourses(
            RemoteViews views,
            List<CompactCourseInfo> courses,
            WidgetLayoutConfig layoutConfig
    ) {
        views.setViewVisibility(R.id.widget_empty_view, View.GONE);
        int visibleCourseCount = Math.min(courses.size(), layoutConfig.maxCourseCount);

        for (int i = 0; i < COURSE_ROW_IDS.length; i++) {
            if (i < visibleCourseCount) {
                CompactCourseInfo course = courses.get(i);
                views.setViewVisibility(COURSE_ROW_IDS[i], View.VISIBLE);
                views.setTextViewText(COURSE_NAME_IDS[i], course.name);
                views.setTextViewText(COURSE_META_IDS[i], buildCourseMeta(course, layoutConfig));
            } else {
                views.setViewVisibility(COURSE_ROW_IDS[i], View.GONE);
            }
        }
    }

    private static String buildHeaderTitle(CompactPayload payload) {
        if (payload.weekIndex > 0) {
            return "第" + payload.weekIndex + "周";
        }
        return "课表";
    }

    private static String buildHeaderSubtitle(CompactPayload payload) {
        StringBuilder builder = new StringBuilder();
        if (!payload.weekdayLabel.isEmpty()) {
            builder.append(payload.weekdayLabel);
        }
        String shortDate = formatShortDate(payload.date);
        if (!shortDate.isEmpty()) {
            if (builder.length() > 0) {
                builder.append(" · ");
            }
            builder.append(shortDate);
        }
        if (builder.length() == 0) {
            return new SimpleDateFormat("MM/dd", Locale.getDefault()).format(new Date());
        }
        return builder.toString();
    }

    private static String buildCourseMeta(
            CompactCourseInfo course,
            WidgetLayoutConfig layoutConfig
    ) {
        StringBuilder builder = new StringBuilder();
        if (!course.startTime.isEmpty()) {
            builder.append(course.startTime);
        }
        if (!course.sectionLabel.isEmpty()) {
            if (builder.length() > 0) {
                builder.append(" · ");
            }
            builder.append(course.sectionLabel);
        }
        if (layoutConfig.showLocation && !course.location.isEmpty()) {
            if (builder.length() > 0) {
                builder.append(" · ");
            }
            builder.append(course.location);
        }
        if (builder.length() == 0) {
            return "时间待定";
        }
        return builder.toString();
    }

    private static String buildEmptyStateText() {
        return "今日暂无课程";
    }

    private static WidgetLayoutConfig resolveLayoutConfig(
            AppWidgetManager appWidgetManager,
            int appWidgetId
    ) {
        Bundle options = appWidgetManager.getAppWidgetOptions(appWidgetId);
        int minWidth = options == null ? 0 : options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0);
        int minHeight = options == null ? 0 : options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0);

        if ((minWidth > 0 && minWidth < COMPACT_WIDTH_THRESHOLD_DP)
                || (minHeight > 0 && minHeight < COMPACT_HEIGHT_THRESHOLD_DP)) {
            return new WidgetLayoutConfig(minWidth, minHeight, 2, false, false);
        }

        if ((minWidth > 0 && minWidth < MEDIUM_WIDTH_THRESHOLD_DP)
                || (minHeight > 0 && minHeight < MEDIUM_HEIGHT_THRESHOLD_DP)) {
            return new WidgetLayoutConfig(minWidth, minHeight, 2, false, true);
        }

        return new WidgetLayoutConfig(minWidth, minHeight, 3, true, true);
    }

    private static String formatShortDate(String date) {
        if (date == null || date.length() < 10) {
            return "";
        }
        return date.substring(5).replace("-", "/");
    }

    private static CompactPayload loadCompactPayload(Context context) {
        CompactPayload payload = CompactPayload.empty();

        try {
            File appDir = context.getFilesDir().getParentFile();
            if (appDir == null) {
                Log.e(TAG, "无法获取应用目录");
                return payload;
            }

            File payloadFile = new File(appDir, "app_flutter/" + PAYLOAD_FILE_NAME);
            if (!payloadFile.exists()) {
                payloadFile = new File(appDir, "files/" + PAYLOAD_FILE_NAME);
            }

            if (!payloadFile.exists()) {
                Log.d(TAG, "紧凑课表 payload 不存在，显示空态");
                return payload;
            }

            StringBuilder stringBuilder = new StringBuilder();
            BufferedReader reader = new BufferedReader(new FileReader(payloadFile));
            String line;
            while ((line = reader.readLine()) != null) {
                stringBuilder.append(line);
            }
            reader.close();

            String payloadJson = stringBuilder.toString();
            if (payloadJson.isEmpty()) {
                return payload;
            }

            JSONObject jsonObject = new JSONObject(payloadJson);
            payload.date = jsonObject.optString("date");
            payload.weekdayLabel = jsonObject.optString("weekdayLabel");
            payload.weekIndex = jsonObject.optInt("weekIndex", 0);
            payload.isEmpty = jsonObject.optBoolean("isEmpty", true);
            payload.updatedAt = jsonObject.optString("updatedAt");

            JSONArray coursesArray = jsonObject.optJSONArray("courses");
            if (coursesArray != null) {
                for (int i = 0; i < coursesArray.length(); i++) {
                    JSONObject courseObject = coursesArray.getJSONObject(i);
                    CompactCourseInfo course = new CompactCourseInfo();
                    course.name = courseObject.optString("name");
                    course.location = courseObject.optString("location");
                    course.startTime = courseObject.optString("startTime");
                    course.sectionLabel = courseObject.optString("sectionLabel");
                    payload.courses.add(course);
                }
            }
        } catch (IOException | JSONException e) {
            Log.e(TAG, "读取紧凑课表 payload 失败: " + e.getMessage(), e);
        }

        if (!payload.courses.isEmpty()) {
            payload.isEmpty = false;
        }
        return payload;
    }

    private static PendingIntent createPendingIntent(Context context, Intent intent, int requestCode,
            boolean isBroadcast) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        if (isBroadcast) {
            return PendingIntent.getBroadcast(context, requestCode, intent, flags);
        } else {
            return PendingIntent.getActivity(context, requestCode, intent, flags);
        }
    }

    /**
     * 兼容旧服务类保留的节次开始时间映射
     */
    public static String getSectionStartTime(int section) {
        switch (section) {
            case 1:
                return "08:00";
            case 2:
                return "08:55";
            case 3:
                return "10:00";
            case 4:
                return "10:55";
            case 5:
                return "14:00";
            case 6:
                return "14:55";
            case 7:
                return "16:00";
            case 8:
                return "16:55";
            case 9:
                return "19:00";
            case 10:
                return "19:55";
            case 11:
                return "21:00";
            default:
                return "00:00";
        }
    }

    /**
     * 兼容旧服务类保留的数据结构
     */
    public static class CourseInfo {
        public String name;
        public String location;
        public int startSection;
        public int duration;
        public String timeStart;
        public String sectionText;
    }

    private static class CompactPayload {
        String date = "";
        String weekdayLabel = "";
        int weekIndex = 0;
        boolean isEmpty = true;
        String updatedAt = "";
        List<CompactCourseInfo> courses = new ArrayList<>();

        static CompactPayload empty() {
            return new CompactPayload();
        }
    }

    private static class CompactCourseInfo {
        String name = "";
        String location = "";
        String startTime = "";
        String sectionLabel = "";
    }

    private static class WidgetLayoutConfig {
        final int minWidthDp;
        final int minHeightDp;
        final int maxCourseCount;
        final boolean showSubtitle;
        final boolean showLocation;

        WidgetLayoutConfig(
                int minWidthDp,
                int minHeightDp,
                int maxCourseCount,
                boolean showSubtitle,
                boolean showLocation
        ) {
            this.minWidthDp = minWidthDp;
            this.minHeightDp = minHeightDp;
            this.maxCourseCount = maxCourseCount;
            this.showSubtitle = showSubtitle;
            this.showLocation = showLocation;
        }
    }

    private void setupPeriodicUpdate(Context context) {
        Log.d(TAG, "设置定时刷新任务，间隔: " + (UPDATE_INTERVAL_MS / 1000 / 60) + "分钟");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            Log.e(TAG, "获取AlarmManager失败");
            return;
        }

        Intent intent = new Intent(context, CourseTableWidgetProvider.class);
        intent.setAction(ACTION_AUTO_UPDATE);
        intent.putExtra("alarm_type", "auto_update");

        PendingIntent pendingIntent = createPendingIntent(
                context,
                intent,
                COURSE_TABLE_BASE_REQUEST_CODE + 4,
                true
        );

        alarmManager.cancel(pendingIntent);

        long firstTrigger = System.currentTimeMillis() + UPDATE_INTERVAL_MS;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            alarmManager.setExact(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else {
            alarmManager.set(AlarmManager.RTC, firstTrigger, pendingIntent);
        }

        Log.d(TAG, "定时刷新任务设置完成");
    }

    private void cancelPeriodicUpdate(Context context) {
        Log.d(TAG, "取消定时刷新任务");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }

        Intent intent = new Intent(context, CourseTableWidgetProvider.class);
        intent.setAction(ACTION_AUTO_UPDATE);
        intent.putExtra("alarm_type", "auto_update");

        PendingIntent pendingIntent = createPendingIntent(
                context,
                intent,
                COURSE_TABLE_BASE_REQUEST_CODE + 4,
                true
        );

        alarmManager.cancel(pendingIntent);
        Log.d(TAG, "定时刷新任务已取消");
    }
}
