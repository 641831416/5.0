#!/bin/bash

echo "=========================================="
echo "  IPTV Android应用一键生成工具"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 项目变量
PROJECT_NAME="IPTV-Android"
PACKAGE_NAME="com.iptv.mobile"
APP_NAME="IPTV直播源管理器"
VERSION="1.0.0"

# 检查必要工具
check_requirements() {
    echo -e "${YELLOW}检查系统环境...${NC}"
    
    local missing_tools=()
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if ! command -v java &> /dev/null; then
        missing_tools+=("java")
    fi
    
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        missing_tools+=("wget或curl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}错误: 缺少必要的工具: ${missing_tools[*]}${NC}"
        echo "请安装这些工具后重新运行脚本"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 环境检查通过${NC}"
}

# 创建项目结构
create_project_structure() {
    echo -e "${YELLOW}创建项目结构...${NC}"
    
    # 清理旧项目
    if [ -d "$PROJECT_NAME" ]; then
        rm -rf "$PROJECT_NAME"
    fi
    
    # 创建目录结构
    mkdir -p "$PROJECT_NAME/app/src/main/java/com/iptv/mobile"
    mkdir -p "$PROJECT_NAME/app/src/main/res/layout"
    mkdir -p "$PROJECT_NAME/app/src/main/res/drawable"
    mkdir -p "$PROJECT_NAME/app/src/main/res/values"
    mkdir -p "$PROJECT_NAME/app/src/main/assets/iptv-app"
    mkdir -p "$PROJECT_NAME/app/src/main/assets/www"
    mkdir -p "$PROJECT_NAME/gradle/wrapper"
    
    echo -e "${GREEN}✓ 项目结构创建完成${NC}"
}

# 创建Android Manifest
create_android_manifest() {
    cat > "$PROJECT_NAME/app/src/main/AndroidManifest.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.iptv.mobile">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/AppTheme"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:label="@string/app_name"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="http" />
                <data android:scheme="https" />
                <data android:scheme="iptv" />
                <data android:mimeType="audio/*" />
                <data android:mimeType="video/*" />
                <data android:mimeType="application/vnd.apple.mpegurl" />
                <data android:mimeType="application/x-mpegURL" />
            </intent-filter>
        </activity>
        
    </application>

</manifest>
EOF
}

# 创建主Activity
create_main_activity() {
    cat > "$PROJECT_NAME/app/src/main/java/com/iptv/mobile/MainActivity.java" << 'EOF'
package com.iptv.mobile;

import android.annotation.SuppressLint;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewAssetLoader;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends AppCompatActivity {
    
    private WebView webView;
    private ProgressBar progressBar;
    private ProgressDialog progressDialog;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    
    private static final String TAG = "IPTVApp";
    
    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        initializeViews();
        setupWebView();
        loadIPTVApp();
        
        // 处理Intent
        handleIntent(getIntent());
    }
    
    private void initializeViews() {
        webView = findViewById(R.id.webView);
        progressBar = findViewById(R.id.progressBar);
        progressDialog = new ProgressDialog(this);
        progressDialog.setMessage("处理中...");
        progressDialog.setCancelable(false);
    }
    
    @SuppressLint("SetJavaScriptEnabled")
    private void setupWebView() {
        WebSettings webSettings = webView.getSettings();
        
        // 启用JavaScript
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setDatabaseEnabled(true);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowContentAccess(true);
        webSettings.setAllowUniversalAccessFromFileURLs(true);
        webSettings.setAllowFileAccessFromFileURLs(true);
        
        // 缓存设置
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        webSettings.setAppCacheEnabled(true);
        webSettings.setAppCachePath(getCacheDir().getPath());
        
        // 视口设置
        webSettings.setUseWideViewPort(true);
        webSettings.setLoadWithOverviewMode(true);
        webSettings.setSupportZoom(true);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);
        
        // 混合内容
        webSettings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        
        // WebView客户端
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                // 处理特定协议
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    return false; // WebView处理
                } else if (url.startsWith("mailto:") || url.startsWith("tel:") || url.startsWith("sms:")) {
                    // 系统处理
                    Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                    startActivity(intent);
                    return true;
                } else if (url.endsWith(".m3u") || url.endsWith(".m3u8")) {
                    // 处理播放列表
                    openInExternalPlayer(url);
                    return true;
                }
                return false;
            }
            
            @Override
            public void onPageFinished(WebView view, String url) {
                progressBar.setVisibility(View.GONE);
                injectJavaScriptInterface();
            }
        });
        
        // Chrome客户端
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                if (newProgress < 100) {
                    progressBar.setVisibility(View.VISIBLE);
                    progressBar.setProgress(newProgress);
                } else {
                    progressBar.setVisibility(View.GONE);
                }
            }
            
            @Override
            public void onReceivedTitle(WebView view, String title) {
                // 可选：更新Activity标题
            }
        });
        
        // 添加JavaScript接口
        webView.addJavascriptInterface(new WebAppInterface(this), "Android");
    }
    
    private void injectJavaScriptInterface() {
        // 注入额外的JavaScript功能
        String jsCode = """
            window.IPTVApp = {
                showToast: function(message) {
                    Android.showToast(message);
                },
                saveData: function(key, data) {
                    Android.saveData(key, data);
                },
                loadData: function(key, callback) {
                    var data = Android.loadData(key);
                    if (callback && typeof callback === 'function') {
                        callback(data);
                    }
                    return data;
                },
                exportFile: function(filename, content) {
                    Android.exportFile(filename, content);
                },
                getAppInfo: function() {
                    return Android.getAppInfo();
                }
            };
            """;
        webView.evaluateJavascript(jsCode, null);
    }
    
    private void loadIPTVApp() {
        // 加载本地Web应用
        webView.loadUrl("file:///android_asset/www/index.html");
    }
    
    private void handleIntent(Intent intent) {
        if (intent != null && intent.getAction() != null) {
            if (Intent.ACTION_VIEW.equals(intent.getAction())) {
                Uri data = intent.getData();
                if (data != null) {
                    String url = data.toString();
                    Log.d(TAG, "Received URL: " + url);
                    
                    // 传递给Web应用
                    String jsCode = String.format("window.handleExternalUrl && window.handleExternalUrl('%s');", url);
                    webView.evaluateJavascript(jsCode, null);
                }
            }
        }
    }
    
    private void openInExternalPlayer(String url) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(Uri.parse(url), "video/*");
            intent.putExtra(Intent.EXTRA_TITLE, "IPTV直播");
            
            // 添加支持的应用
            Intent chooser = Intent.createChooser(intent, "选择播放器");
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivity(chooser);
            } else {
                Toast.makeText(this, "未找到支持的播放器", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Log.e(TAG, "打开外部播放器失败", e);
            Toast.makeText(this, "打开播放器失败", Toast.LENGTH_SHORT).show();
        }
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }
    
    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        executor.shutdown();
        if (progressDialog != null && progressDialog.isShowing()) {
            progressDialog.dismiss();
        }
    }
    
    // JavaScript接口类
    public class WebAppInterface {
        Context mContext;
        
        WebAppInterface(Context c) {
            mContext = c;
        }
        
        @JavascriptInterface
        public void showToast(String toast) {
            Toast.makeText(mContext, toast, Toast.LENGTH_SHORT).show();
        }
        
        @JavascriptInterface
        public void saveData(String key, String data) {
            try {
                FileOutputStream fos = mContext.openFileOutput(key + ".json", Context.MODE_PRIVATE);
                fos.write(data.getBytes());
                fos.close();
            } catch (IOException e) {
                Log.e(TAG, "保存数据失败", e);
            }
        }
        
        @JavascriptInterface
        public String loadData(String key) {
            try {
                FileInputStream fis = mContext.openFileInput(key + ".json");
                InputStreamReader isr = new InputStreamReader(fis);
                BufferedReader br = new BufferedReader(isr);
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) {
                    sb.append(line);
                }
                br.close();
                return sb.toString();
            } catch (IOException e) {
                Log.e(TAG, "加载数据失败", e);
                return "{}";
            }
        }
        
        @JavascriptInterface
        public void exportFile(String filename, String content) {
            executor.execute(() -> {
                try {
                    File downloadsDir = new File(mContext.getExternalFilesDir(null), "Downloads");
                    if (!downloadsDir.exists()) {
                        downloadsDir.mkdirs();
                    }
                    
                    File file = new File(downloadsDir, filename);
                    FileOutputStream fos = new FileOutputStream(file);
                    fos.write(content.getBytes());
                    fos.close();
                    
                    mainHandler.post(() -> {
                        Toast.makeText(mContext, "文件已保存到: " + file.getAbsolutePath(), Toast.LENGTH_LONG).show();
                    });
                } catch (IOException e) {
                    Log.e(TAG, "导出文件失败", e);
                    mainHandler.post(() -> {
                        Toast.makeText(mContext, "导出失败", Toast.LENGTH_SHORT).show();
                    });
                }
            });
        }
        
        @JavascriptInterface
        public String getAppInfo() {
            try {
                JSONObject info = new JSONObject();
                info.put("version", "1.0.0");
                info.put("name", "IPTV直播源管理器");
                info.put("platform", "Android");
                return info.toString();
            } catch (JSONException e) {
                return "{}";
            }
        }
    }
}
EOF
}

# 创建布局文件
create_layout_files() {
    # 主布局
    cat > "$PROJECT_NAME/app/src/main/res/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#f5f5f5">

    <WebView
        android:id="@+id/webView"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <ProgressBar
        android:id="@+id/progressBar"
        style="?android:attr/progressBarStyleHorizontal"
        android:layout_width="match_parent"
        android:layout_height="4dp"
        android:layout_alignParentTop="true"
        android:progressTint="#007bff"
        android:visibility="gone" />

</RelativeLayout>
EOF

    # 字符串资源
    cat > "$PROJECT_NAME/app/src/main/res/values/strings.xml" << EOF
<resources>
    <string name="app_name">$APP_NAME</string>
    <string name="loading">加载中...</string>
    <string name="error_loading">加载失败</string>
</resources>
EOF

    # 颜色资源
    cat > "$PROJECT_NAME/app/src/main/res/values/colors.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="colorPrimary">#2196F3</color>
    <color name="colorPrimaryDark">#1976D2</color>
    <color name="colorAccent">#FF4081</color>
</resources>
EOF

    # 样式资源
    cat > "$PROJECT_NAME/app/src/main/res/values/styles.xml" << 'EOF'
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.Light.DarkActionBar">
        <item name="colorPrimary">@color/colorPrimary</item>
        <item name="colorPrimaryDark">@color/colorPrimaryDark</item>
        <item name="colorAccent">@color/colorAccent</item>
    </style>
</resources>
EOF
}

# 创建Web应用界面
create_web_interface() {
    # 主HTML文件
    cat > "$PROJECT_NAME/app/src/main/assets/www/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IPTV直播源管理器</title>
    <style>
        :root {
            --primary-color: #2196F3;
            --primary-dark: #1976D2;
            --accent-color: #FF4081;
            --text-primary: #212121;
            --text-secondary: #757575;
            --background: #f5f5f5;
            --surface: #ffffff;
            --error: #f44336;
            --success: #4caf50;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--background);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 0;
            margin: 0;
        }
        
        .container {
            max-width: 100%;
            padding: 16px;
        }
        
        .header {
            background: linear-gradient(135deg, var(--primary-color), var(--primary-dark));
            color: white;
            padding: 20px 16px;
            text-align: center;
            margin-bottom: 16px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 1.5em;
            font-weight: 500;
            margin-bottom: 4px;
        }
        
        .header .subtitle {
            font-size: 0.9em;
            opacity: 0.9;
        }
        
        .card {
            background: var(--surface);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .card:active {
            transform: translateY(2px);
            box-shadow: 0 1px 4px rgba(0,0,0,0.1);
        }
        
        .card h3 {
            color: var(--primary-color);
            margin-bottom: 12px;
            font-size: 1.2em;
            font-weight: 500;
        }
        
        .input-group {
            margin-bottom: 16px;
        }
        
        .input {
            width: 100%;
            padding: 14px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
            background: var(--surface);
        }
        
        .input:focus {
            outline: none;
            border-color: var(--primary-color);
        }
        
        .btn {
            background: var(--primary-color);
            color: white;
            border: none;
            padding: 14px 20px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s;
            text-align: center;
            display: block;
            width: 100%;
            margin: 8px 0;
        }
        
        .btn:hover {
            background: var(--primary-dark);
        }
        
        .btn:active {
            transform: translateY(1px);
        }
        
        .btn-secondary {
            background: #757575;
        }
        
        .btn-success {
            background: var(--success);
        }
        
        .btn-danger {
            background: var(--error);
        }
        
        .nav {
            display: flex;
            background: var(--surface);
            border-radius: 12px;
            margin-bottom: 16px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .nav-item {
            flex: 1;
            padding: 14px;
            text-align: center;
            background: var(--surface);
            border: none;
            font-size: 14px;
            font-weight: 500;
            color: var(--text-secondary);
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .nav-item.active {
            background: var(--primary-color);
            color: white;
        }
        
        .tab {
            display: none;
            animation: fadeIn 0.3s ease-in;
        }
        
        .tab.active {
            display: block;
        }
        
        .source-item, .channel-item {
            background: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 12px;
            margin: 8px 0;
            display: flex;
            justify-content: between;
            align-items: center;
        }
        
        .source-info {
            flex: 1;
        }
        
        .source-title {
            font-weight: 500;
            margin-bottom: 4px;
        }
        
        .source-url {
            font-size: 0.9em;
            color: var(--text-secondary);
            word-break: break-all;
        }
        
        .action-buttons {
            display: flex;
            gap: 8px;
        }
        
        .icon-btn {
            background: none;
            border: none;
            padding: 6px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 1.2em;
        }
        
        .delete-btn {
            color: var(--error);
        }
        
        .edit-btn {
            color: var(--primary-color);
        }
        
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-online {
            background: var(--success);
        }
        
        .status-offline {
            background: var(--error);
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: var(--text-secondary);
        }
        
        .hidden {
            display: none;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        /* 响应式设计 */
        @media (min-width: 768px) {
            .container {
                max-width: 600px;
                margin: 0 auto;
            }
            
            .btn {
                width: auto;
                display: inline-block;
                margin: 4px;
            }
            
            .action-buttons {
                flex-direction: row;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>IPTV直播源管理器</h1>
        <div class="subtitle">全功能电视直播源更新工具</div>
    </div>

    <div class="container">
        <div class="nav">
            <button class="nav-item active" onclick="showTab('sources')">源管理</button>
            <button class="nav-item" onclick="showTab('channels')">频道</button>
            <button class="nav-item" onclick="showTab('epg')">EPG</button>
            <button class="nav-item" onclick="showTab('export')">导出</button>
            <button class="nav-item" onclick="showTab('settings')">设置</button>
        </div>

        <!-- 源管理标签 -->
        <div id="sources" class="tab active">
            <div class="card">
                <h3>添加直播源</h3>
                <div class="input-group">
                    <input type="text" class="input" id="sourceUrl" placeholder="输入直播源URL (支持.m3u, .m3u8, .txt)">
                </div>
                <div class="input-group">
                    <input type="text" class="input" id="sourceName" placeholder="源名称 (可选)">
                </div>
                <button class="btn" onclick="addSource()">添加源</button>
                <button class="btn btn-secondary" onclick="addDefaultSources()">添加默认源</button>
            </div>

            <div class="card">
                <h3>源列表</h3>
                <div id="sourceList" class="loading">
                    加载中...
                </div>
            </div>
        </div>

        <!-- 频道管理标签 -->
        <div id="channels" class="tab">
            <div class="card">
                <h3>频道管理</h3>
                <button class="btn" onclick="updateAllChannels()">更新所有频道</button>
                <button class="btn btn-secondary" onclick="scanChannels()">扫描可用频道</button>
                <button class="btn btn-success" onclick="testAllChannels()">测试频道状态</button>
            </div>

            <div class="card">
                <h3>频道列表</h3>
                <div class="input-group">
                    <input type="text" class="input" id="channelSearch" placeholder="搜索频道..." onkeyup="filterChannels()">
                </div>
                <div id="channelList" class="loading">
                    加载中...
                </div>
            </div>
        </div>

        <!-- EPG管理标签 -->
        <div id="epg" class="tab">
            <div class="card">
                <h3>EPG电子节目指南</h3>
                <div class="input-group">
                    <input type="text" class="input" id="epgUrl" placeholder="EPG源URL">
                </div>
                <button class="btn" onclick="addEpgSource()">添加EPG源</button>
                <button class="btn btn-secondary" onclick="updateEpg()">更新EP
