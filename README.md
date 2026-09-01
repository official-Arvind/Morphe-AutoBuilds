<div align="center">
  <h1>🚀 Morphe AutoBuilds</h1>
  <p align="center">
    <strong>Professional, Fully Automated App Patching Pipeline (Root & Non-Root)</strong><br>
    Built by <strong>Arvind Ji (The New Perfectionist)</strong>
  </p>
  
  [![View Latest Release](https://img.shields.io/badge/View%20Latest%20Release-0A0A0A?style=flat&logo=github&logoColor=white)](https://github.com/official-Arvind/Morphe-AutoBuilds/releases/latest)
</div>

---

## ⚡ Overview

Welcome to **Morphe AutoBuilds**, a sophisticated, 100% automated pipeline that builds ready-to-install Morphe applications for both **Root (Magisk/KernelSU)** and **Non-Root** Android devices. 

This system automatically fetches the latest ReVanced/Morphe tools, interrogates the patches to dynamically find the highest supported app version, downloads the base APKs from multiple sources (APKMirror, APKPure, Uptodown, etc.), applies patches, and publishes optimized APKs & Magisk Modules daily!

### ✨ Key Features

* **🤖 Zero-Maintenance Automation:** GitHub Actions workflow executes flawlessly every day at 06:00 UTC, requiring absolutely zero manual intervention.
* **🧠 Dynamic Version Intelligence:** Never hardcode versions again! The engine dynamically queries the patching CLI for the highest officially supported app version and automatically scrapes it from the internet.
* **📦 Universal Outputs:** Generates both standard `.apk` files for Non-Root users and flashable `.zip` Magisk Modules for Root users.
* **📱 Morphe Manager (Exclusive):** A built-in, on-device Magisk module that provides a local Web UI for seamless 1-click OTA updates and background auto-flashing.
* **⚡ Multi-Source Strategy:** Intelligent fetching from APKMirror, APKPure, GitHub, Aptoide, APKCombo, and Uptodown ensures 100% download reliability.
* **📐 Architecture Optimization:** Builds specific `arm64-v8a`, `armeabi-v7a`, and `universal` architectures to reduce file size.

---

## 📲 How to Install & Use

### 🟢 For Root Users (Highly Recommended)
We have built a completely seamless, on-device OTA update system using the **Morphe Manager**.

1. Go to the [**Latest Release**](https://github.com/official-Arvind/Morphe-AutoBuilds/releases/latest) page.
2. Download the `morphe-manager.zip` file.
3. Flash it in **Magisk** or **KernelSU** and reboot.
4. Open your web browser and go to `http://localhost:8080`.
5. **From the Morphe Manager Web UI**, you can easily select and flash the latest root modules with 1-click. 
6. **Auto-Update Daemon:** Head to the Settings tab in the Web UI to enable Auto-Updates. The background daemon will silently fetch and flash updates overnight at your specified time while you sleep!

*(Alternatively, you can just download the individual app `.zip` files from the Releases page and flash them manually).*

### 🔵 For Non-Root Users
1. Go to the [**Latest Release**](https://github.com/official-Arvind/Morphe-AutoBuilds/releases/latest).
2. Download the standard `.apk` file for the app you want (e.g., YouTube, Spotify).
3. Install the APK normally. 
*(Note: You may need GmsCore/MicroG installed for Google login on non-root YouTube apps).*

---

## 🛠️ Repository Structure

```text
Morphe-AutoBuilds/
├── .github/workflows/      # GitHub Actions automation (Daily cron at 6 AM UTC)
├── apps/                   # Smart configurations for APK sources (APKMirror, Uptodown, etc.)
├── morphe_manager/         # The local Web UI and background daemon for rooted OTA updates
├── patches/                # Patch inclusion/exclusion rules (e.g., +microg-support)
├── scripts/                # Housekeeping, cleaning, and auth validation scripts
├── sources/                # CLI/Patch definition sources
└── src/                    # Core Python intelligent download & build logic
```

---

## ⚙️ Configuration Guide

This builder is highly configurable. The intelligent `src/downloader.py` will automatically parse your configurations.

### 1. App Selection (`patch-config.json`)
Define which applications the pipeline should attempt to build:
```json
{
  "patch_list": [
    { "app_name": "youtube", "source": "morphe" },
    { "app_name": "instagram", "source": "morphe" }
  ]
}
```

### 2. Architecture Matrix (`arch-config.json`)
Specify which CPU architectures to target for each application:
```json
[
  {
    "app_name": "youtube",
    "source": "morphe",
    "arches": ["arm64-v8a", "universal"]
  }
]
```

### 3. Source Configurations (`apps/`)
To add a new app, create a JSON file in the appropriate source folder (e.g., `apps/apkmirror/youtube.json`). 
**Crucial:** Leave `"version": ""` blank to allow the engine to auto-detect the latest supported version dynamically!
```json
{
  "org": "google-inc",
  "name": "youtube",
  "type": "APK",
  "arch": "universal",
  "package": "com.google.android.youtube",
  "version": ""
}
```

---

## 🚀 Local Build Instructions

If you want to test the build engine locally on your machine:

**Prerequisites:** Python 3.11+, Java (JDK 21), `zip`, `apksigner`
```bash
# 1. Clone the repository
git clone https://github.com/official-Arvind/Morphe-AutoBuilds.git
cd Morphe-AutoBuilds

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run the build pipeline for a specific app
export APP_NAME="youtube"
export SOURCE="morphe"
export ARCH="arm64-v8a"
python -m src
```

---

<div align="center">
  <strong>Made with absolute perfection by Arvind Ji.</strong><br>
  <em>Never manually patch or update an app again.</em>
</div>

---

## ⚠️ Disclaimer & Legal Notice

**This repository is strictly for educational and research purposes.** 

Morphe AutoBuilds is an automated build pipeline. **No proprietary APKs, copyrighted applications, or modified binaries are hosted or stored within this repository's source code.** The scripts merely download publicly available tools and unmodified files from third-party hosting sites, process them locally inside temporary GitHub Actions containers, and output the results. We do not own, develop, or hold copyright over any of the third-party applications or patching frameworks utilized.

### Notice to Rights Holders (DMCA / Takedown Requests)
If you are the copyright owner (or represent the owner) of an application and believe that this automated build pipeline infringes upon your rights or violates your Terms of Service, we are fully willing to comply with your request. 

Please **do not issue an immediate DMCA strike to GitHub**. Instead, kindly send a direct removal request to my email, and I will swiftly blacklist your specific application from this build pipeline and delete any related automated releases.

📩 **Contact Email:** `Itz.arvindji@gmail.com`