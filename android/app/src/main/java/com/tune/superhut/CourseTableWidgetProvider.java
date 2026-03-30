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
import java.util.Calendar;
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
    private static final String STORE_FILE_NAME = "course_widget_store.json";
    private static final String PAYLOAD_FILE_NAME = "course_widget_payload.json";
    private static final String TAG = "CourseTableWidgetProv";

    private static final int COURSE_TABLE_BASE_REQUEST_CODE = 20000;
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

            if (appWidgetIds.length > 0) {
                setupPeriodicUpdate(context);
            }

            if (ACTION_AUTO_UPDATE.equals(action)) {
                Log.d(TAG, "执行定时自动刷新");
            }
        } else if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            Log.d(TAG, "系统启动完成，设置定时刷新");
            if (hasActiveWidgets(context)) {
                setupPeriodicUpdate(context);
            }
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
            views.setTextViewText(R.id.widget_empty_view, buildEmptyStateText(payload));

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
        if (payload.headerTitle != null && !payload.headerTitle.isEmpty()) {
            return payload.headerTitle;
        }
        if (payload.weekIndex > 0) {
            return "第" + payload.weekIndex + "周";
        }
        return "课表";
    }

    private static String buildHeaderSubtitle(CompactPayload payload) {
        if (payload.headerSubtitle != null && !payload.headerSubtitle.isEmpty()) {
            return payload.headerSubtitle;
        }
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
        if (course.meta != null && !course.meta.isEmpty()) {
            return course.meta;
        }
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

    private static String buildEmptyStateText(CompactPayload payload) {
        if (payload.emptyText != null && !payload.emptyText.isEmpty()) {
            return payload.emptyText;
        }
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
        CompactPayload payloadFromStore = loadCompactPayloadFromStore(context);
        if (payloadFromStore != null) {
            return payloadFromStore;
        }

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
            payload.status = jsonObject.optString("status");
            payload.headerTitle = jsonObject.optString("headerTitle");
            payload.headerSubtitle = jsonObject.optString("headerSubtitle");
            payload.emptyText = jsonObject.optString("emptyText", "今日暂无课程");
            payload.isEmpty = jsonObject.optBoolean("isEmpty", true);
            payload.updatedAt = jsonObject.optString("updatedAt");

            JSONArray coursesArray = jsonObject.optJSONArray("courses");
            if (coursesArray != null) {
                for (int i = 0; i < coursesArray.length(); i++) {
                    JSONObject courseObject = coursesArray.getJSONObject(i);
                    CompactCourseInfo course = new CompactCourseInfo();
                    course.name = courseObject.optString("name");
                    course.meta = courseObject.optString("meta");
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

    private static CompactPayload loadCompactPayloadFromStore(Context context) {
        try {
            JSONObject storeObject = loadStoreJsonObject(context);
            if (storeObject == null) {
                return null;
            }
            return buildRelevantPayloadFromStore(storeObject, System.currentTimeMillis());
        } catch (IOException | JSONException e) {
            Log.e(TAG, "读取课程小组件 store 失败: " + e.getMessage(), e);
            return null;
        }
    }

    private static JSONObject loadStoreJsonObject(Context context) throws IOException, JSONException {
        File appDir = context.getFilesDir().getParentFile();
        if (appDir == null) {
            return null;
        }

        File storeFile = new File(appDir, "app_flutter/" + STORE_FILE_NAME);
        if (!storeFile.exists()) {
            storeFile = new File(appDir, "files/" + STORE_FILE_NAME);
        }

        if (!storeFile.exists()) {
            return null;
        }

        StringBuilder stringBuilder = new StringBuilder();
        BufferedReader reader = new BufferedReader(new FileReader(storeFile));
        String line;
        while ((line = reader.readLine()) != null) {
            stringBuilder.append(line);
        }
        reader.close();

        String storeJson = stringBuilder.toString();
        if (storeJson.isEmpty()) {
            return null;
        }

        return new JSONObject(storeJson);
    }

    private static CompactPayload buildRelevantPayloadFromStore(JSONObject storeObject, long nowMillis) {
        JSONObject daysObject = storeObject.optJSONObject("days");
        JSONObject dayCoursesObject = storeObject.optJSONObject("dayCourses");
        String updatedAt = storeObject.optString("updatedAt");
        String todayKey = formatDateKey(nowMillis);
        int todayWeekIndex = weekIndexForDate(daysObject, todayKey);

        List<CompactCourseInfo> todayCourses = filterRemainingCourses(
                todayKey,
                loadActualCoursesForDate(daysObject, dayCoursesObject, todayKey),
                nowMillis
        );
        if (!todayCourses.isEmpty()) {
            return buildPayload(
                    todayKey,
                    weekdayLabelForDate(daysObject, todayKey),
                    todayWeekIndex,
                    "today_courses",
                    "今天课程",
                    composeWeekSubtitle(todayKey, todayWeekIndex, null),
                    "今日暂无课程",
                    updatedAt,
                    todayCourses
            );
        }

        String tomorrowKey = nextDateKey(todayKey);
        List<CompactCourseInfo> tomorrowCourses = loadActualCoursesForDate(
                daysObject,
                dayCoursesObject,
                tomorrowKey
        );

        if (isSunday(todayKey) && !tomorrowCourses.isEmpty()) {
            int mondayWeekIndex = weekIndexForDate(daysObject, tomorrowKey);
            return buildPayload(
                    todayKey,
                    weekdayLabelForDate(daysObject, todayKey),
                    todayWeekIndex,
                    "next_monday",
                    "周一有课",
                    mondayWeekIndex > 0 ? "下周第" + mondayWeekIndex + "周" : "明天上午别睡过",
                    "周一有课",
                    updatedAt,
                    tomorrowCourses
            );
        }

        if (!tomorrowCourses.isEmpty()) {
            int tomorrowWeekIndex = weekIndexForDate(daysObject, tomorrowKey);
            return buildPayload(
                    todayKey,
                    weekdayLabelForDate(daysObject, todayKey),
                    todayWeekIndex,
                    "tomorrow_courses",
                    "明天有课",
                    composeWeekSubtitle(tomorrowKey, tomorrowWeekIndex, null),
                    "明天有课",
                    updatedAt,
                    tomorrowCourses
            );
        }

        String nextCourseDateKey = findNextActualCourseDateAfter(
                todayKey,
                daysObject,
                dayCoursesObject
        );
        if (nextCourseDateKey != null) {
            List<CompactCourseInfo> nextCourses = loadActualCoursesForDate(
                    daysObject,
                    dayCoursesObject,
                    nextCourseDateKey
            );
            int nextWeekIndex = weekIndexForDate(daysObject, nextCourseDateKey);
            String subtitle =
                    isSameWeek(todayKey, nextCourseDateKey)
                            ? composeWeekSubtitle(nextCourseDateKey, nextWeekIndex, null)
                            : composeWeekSubtitle(nextCourseDateKey, nextWeekIndex, "本周无课");
            return buildPayload(
                    todayKey,
                    weekdayLabelForDate(daysObject, todayKey),
                    todayWeekIndex,
                    "next_course",
                    "下次课程",
                    subtitle,
                    "下次课程",
                    updatedAt,
                    nextCourses
            );
        }

        return buildEmptyPayload(todayKey, updatedAt);
    }

    private static CompactPayload buildPayload(
            String dateKey,
            String weekdayLabel,
            int weekIndex,
            String status,
            String headerTitle,
            String headerSubtitle,
            String emptyText,
            String updatedAt,
            List<CompactCourseInfo> courses
    ) {
        CompactPayload payload = CompactPayload.empty();
        payload.date = dateKey;
        payload.weekdayLabel = weekdayLabel;
        payload.weekIndex = weekIndex;
        payload.status = status;
        payload.headerTitle = headerTitle;
        payload.headerSubtitle = headerSubtitle;
        payload.emptyText = emptyText;
        payload.updatedAt = updatedAt;
        payload.courses.addAll(courses.subList(0, Math.min(courses.size(), 2)));
        payload.isEmpty = payload.courses.isEmpty();
        return payload;
    }

    private static CompactPayload buildEmptyPayload(String dateKey, String updatedAt) {
        CompactPayload payload = CompactPayload.empty();
        payload.date = dateKey;
        payload.weekdayLabel = weekdayLabelFromDateKey(dateKey);
        payload.weekIndex = 0;
        payload.status = "empty";
        payload.headerTitle = "当前暂无课表";
        payload.headerSubtitle = "同步或导入后显示课程";
        payload.emptyText = "同步或导入后显示课程";
        payload.updatedAt = updatedAt;
        payload.isEmpty = true;
        return payload;
    }

    private static List<CompactCourseInfo> loadActualCoursesForDate(
            JSONObject daysObject,
            JSONObject dayCoursesObject,
            String dateKey
    ) {
        JSONArray dayCoursesArray =
                dayCoursesObject == null ? null : dayCoursesObject.optJSONArray(dateKey);
        if (dayCoursesArray != null && dayCoursesArray.length() > 0) {
            return parseCompactCourses(dayCoursesArray);
        }

        if (daysObject == null) {
            return new ArrayList<>();
        }

        JSONObject dayPayloadObject = daysObject.optJSONObject(dateKey);
        if (dayPayloadObject == null) {
            return new ArrayList<>();
        }

        if (!"today_courses".equals(dayPayloadObject.optString("status"))) {
            return new ArrayList<>();
        }

        JSONArray coursesArray = dayPayloadObject.optJSONArray("courses");
        if (coursesArray == null || coursesArray.length() == 0) {
            return new ArrayList<>();
        }

        return parseCompactCourses(coursesArray);
    }

    private static List<CompactCourseInfo> parseCompactCourses(JSONArray coursesArray) {
        List<CompactCourseInfo> courses = new ArrayList<>();
        for (int i = 0; i < coursesArray.length(); i++) {
            JSONObject courseObject = coursesArray.optJSONObject(i);
            if (courseObject == null) {
                continue;
            }
            CompactCourseInfo course = new CompactCourseInfo();
            course.name = courseObject.optString("name");
            course.meta = courseObject.optString("meta");
            course.location = courseObject.optString("location");
            course.startSection = courseObject.optInt("startSection", 0);
            course.endSection = courseObject.optInt("endSection", 0);
            course.startTime = courseObject.optString("startTime");
            course.sectionLabel = courseObject.optString("sectionLabel");
            courses.add(course);
        }
        courses.sort((left, right) -> Integer.compare(left.startSection, right.startSection));
        return courses;
    }

    private static List<CompactCourseInfo> filterRemainingCourses(
            String dateKey,
            List<CompactCourseInfo> courses,
            long nowMillis
    ) {
        List<CompactCourseInfo> remaining = new ArrayList<>();
        for (CompactCourseInfo course : courses) {
            Long endAtMillis = courseEndTimeMillis(dateKey, course);
            if (endAtMillis == null || endAtMillis > nowMillis) {
                remaining.add(course);
            }
        }
        remaining.sort((left, right) -> Integer.compare(left.startSection, right.startSection));
        return remaining;
    }

    private static String findNextActualCourseDateAfter(
            String currentDateKey,
            JSONObject daysObject,
            JSONObject dayCoursesObject
    ) {
        List<String> actualDateKeys = new ArrayList<>(actualCourseDateKeys(daysObject, dayCoursesObject));
        actualDateKeys.sort(String::compareTo);
        for (String dateKey : actualDateKeys) {
            if (dateKey.compareTo(currentDateKey) > 0) {
                return dateKey;
            }
        }
        return null;
    }

    private static java.util.Set<String> actualCourseDateKeys(
            JSONObject daysObject,
            JSONObject dayCoursesObject
    ) {
        java.util.Set<String> keys = new java.util.HashSet<>();
        if (dayCoursesObject != null) {
            java.util.Iterator<String> iterator = dayCoursesObject.keys();
            while (iterator.hasNext()) {
                String key = iterator.next();
                JSONArray coursesArray = dayCoursesObject.optJSONArray(key);
                if (coursesArray != null && coursesArray.length() > 0) {
                    keys.add(key);
                }
            }
            if (!keys.isEmpty()) {
                return keys;
            }
        }

        if (daysObject == null) {
            return keys;
        }

        java.util.Iterator<String> iterator = daysObject.keys();
        while (iterator.hasNext()) {
            String key = iterator.next();
            JSONObject dayPayloadObject = daysObject.optJSONObject(key);
            if (dayPayloadObject == null) {
                continue;
            }
            JSONArray coursesArray = dayPayloadObject.optJSONArray("courses");
            if ("today_courses".equals(dayPayloadObject.optString("status"))
                    && coursesArray != null
                    && coursesArray.length() > 0) {
                keys.add(key);
            }
        }
        return keys;
    }

    private static int weekIndexForDate(JSONObject daysObject, String dateKey) {
        if (daysObject == null) {
            return 0;
        }
        JSONObject dayPayloadObject = daysObject.optJSONObject(dateKey);
        if (dayPayloadObject == null) {
            return 0;
        }
        return dayPayloadObject.optInt("weekIndex", 0);
    }

    private static String weekdayLabelForDate(JSONObject daysObject, String dateKey) {
        if (daysObject != null) {
            JSONObject dayPayloadObject = daysObject.optJSONObject(dateKey);
            if (dayPayloadObject != null) {
                String weekdayLabel = dayPayloadObject.optString("weekdayLabel");
                if (!weekdayLabel.isEmpty()) {
                    return weekdayLabel;
                }
            }
        }
        return weekdayLabelFromDateKey(dateKey);
    }

    private static String composeWeekSubtitle(String dateKey, int weekIndex, String prefix) {
        List<String> parts = new ArrayList<>();
        if (prefix != null && !prefix.isEmpty()) {
            parts.add(prefix);
        }
        parts.add(weekdayLabelFromDateKey(dateKey));
        if (weekIndex > 0) {
            parts.add("第" + weekIndex + "周");
        }
        return String.join(" · ", parts);
    }

    private static boolean isSunday(String dateKey) {
        Calendar calendar = calendarFromDateKey(dateKey);
        return calendar != null && calendar.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY;
    }

    private static boolean isSameWeek(String leftDateKey, String rightDateKey) {
        Long leftMonday = startOfMondayMillis(leftDateKey);
        Long rightMonday = startOfMondayMillis(rightDateKey);
        return leftMonday != null && leftMonday.equals(rightMonday);
    }

    private static Long startOfMondayMillis(String dateKey) {
        Calendar calendar = calendarFromDateKey(dateKey);
        if (calendar == null) {
            return null;
        }
        int weekday = calendar.get(Calendar.DAY_OF_WEEK);
        int offset = (weekday + 5) % 7;
        calendar.add(Calendar.DAY_OF_MONTH, -offset);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private static String weekdayLabelFromDateKey(String dateKey) {
        Calendar calendar = calendarFromDateKey(dateKey);
        if (calendar == null) {
            return "";
        }
        switch (calendar.get(Calendar.DAY_OF_WEEK)) {
            case Calendar.MONDAY:
                return "周一";
            case Calendar.TUESDAY:
                return "周二";
            case Calendar.WEDNESDAY:
                return "周三";
            case Calendar.THURSDAY:
                return "周四";
            case Calendar.FRIDAY:
                return "周五";
            case Calendar.SATURDAY:
                return "周六";
            case Calendar.SUNDAY:
                return "周日";
            default:
                return "";
        }
    }

    private static String nextDateKey(String dateKey) {
        Calendar calendar = calendarFromDateKey(dateKey);
        if (calendar == null) {
            return dateKey;
        }
        calendar.add(Calendar.DAY_OF_MONTH, 1);
        return formatDateKey(calendar.getTimeInMillis());
    }

    private static String formatDateKey(long timeMillis) {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(new Date(timeMillis));
    }

    private static Calendar calendarFromDateKey(String dateKey) {
        try {
            Date date = new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(dateKey);
            if (date == null) {
                return null;
            }
            Calendar calendar = Calendar.getInstance();
            calendar.setTime(date);
            return calendar;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Long courseEndTimeMillis(String dateKey, CompactCourseInfo course) {
        int endSection = course.endSection > 0 ? course.endSection : course.startSection;
        String endTime = getSectionEndTime(endSection);
        if (endTime.isEmpty()) {
            return null;
        }

        Calendar calendar = calendarFromDateKey(dateKey);
        if (calendar == null) {
            return null;
        }

        String[] parts = endTime.split(":");
        if (parts.length != 2) {
            return null;
        }

        try {
            calendar.set(Calendar.HOUR_OF_DAY, Integer.parseInt(parts[0]));
            calendar.set(Calendar.MINUTE, Integer.parseInt(parts[1]));
            calendar.set(Calendar.SECOND, 0);
            calendar.set(Calendar.MILLISECOND, 0);
            return calendar.getTimeInMillis();
        } catch (NumberFormatException ignored) {
            return null;
        }
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

    public static String getSectionEndTime(int section) {
        switch (section) {
            case 1:
                return "08:45";
            case 2:
                return "09:40";
            case 3:
                return "10:45";
            case 4:
                return "11:40";
            case 5:
                return "14:45";
            case 6:
                return "15:40";
            case 7:
                return "16:45";
            case 8:
                return "17:40";
            case 9:
                return "19:45";
            case 10:
                return "20:40";
            default:
                return "";
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
        String status = "";
        String headerTitle = "";
        String headerSubtitle = "";
        String emptyText = "今日暂无课程";
        boolean isEmpty = true;
        String updatedAt = "";
        List<CompactCourseInfo> courses = new ArrayList<>();

        static CompactPayload empty() {
            return new CompactPayload();
        }
    }

    private static class CompactCourseInfo {
        String name = "";
        String meta = "";
        String location = "";
        int startSection = 0;
        int endSection = 0;
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
        Log.d(TAG, "设置下一次课表小组件刷新任务");
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
        long firstTrigger = resolveNextRefreshAtMillis(context);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            alarmManager.setExact(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else {
            alarmManager.set(AlarmManager.RTC, firstTrigger, pendingIntent);
        }

        Log.d(TAG, "定时刷新任务设置完成，下次触发时间: " + new Date(firstTrigger));
    }

    private long resolveNextRefreshAtMillis(Context context) {
        long nowMillis = System.currentTimeMillis();
        long nextMidnightMillis = nextMidnightRefreshMillis(nowMillis);

        try {
            JSONObject storeObject = loadStoreJsonObject(context);
            if (storeObject == null) {
                return nextMidnightMillis;
            }

            JSONObject daysObject = storeObject.optJSONObject("days");
            JSONObject dayCoursesObject = storeObject.optJSONObject("dayCourses");
            String todayKey = formatDateKey(nowMillis);
            List<CompactCourseInfo> remainingToday = filterRemainingCourses(
                    todayKey,
                    loadActualCoursesForDate(daysObject, dayCoursesObject, todayKey),
                    nowMillis
            );

            Long nextCourseBoundary = null;
            for (CompactCourseInfo course : remainingToday) {
                Long endAtMillis = courseEndTimeMillis(todayKey, course);
                if (endAtMillis == null || endAtMillis <= nowMillis) {
                    continue;
                }
                if (nextCourseBoundary == null || endAtMillis < nextCourseBoundary) {
                    nextCourseBoundary = endAtMillis;
                }
            }

            if (nextCourseBoundary != null) {
                return Math.max(nextCourseBoundary + 60_000L, nowMillis + 60_000L);
            }
        } catch (IOException | JSONException e) {
            Log.e(TAG, "计算下一次小组件刷新时间失败: " + e.getMessage(), e);
        }

        return nextMidnightMillis;
    }

    private long nextMidnightRefreshMillis(long nowMillis) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(nowMillis);
        calendar.add(Calendar.DAY_OF_MONTH, 1);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 1);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
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

    private boolean hasActiveWidgets(Context context) {
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        ComponentName thisWidget = new ComponentName(context, CourseTableWidgetProvider.class);
        return appWidgetManager.getAppWidgetIds(thisWidget).length > 0;
    }
}
