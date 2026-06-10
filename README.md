# ⭕ Osu! Shadow Launcher

![Platform](https://img.shields.io/badge/OS-Windows-blue?style=flat-square)
![Language](https://img.shields.io/badge/Language-PowerShell%20%7C%20Batch%20%7C%20C%23-green?style=flat-square)
![osu!](https://img.shields.io/badge/Game-osu!-pink?style=flat-square)

A lightweight, modular, and fully automated multi-tool launcher for **osu!**. 

If you are tired of manually starting osu!, opening web dashboards (like Tosu), and switching your Wooting keyboard profiles every time you want to play, this launcher does it all for you in a single click, completely in the background.

## ✨ Features

- **All-in-One Startup:** Launches osu! alongside companion apps (Tosu, GosuMemory).
- **Automated Wooting Profile Switcher:** Automatically switches your Wooting keyboard to your osu! profile (e.g., Rapid Trigger on) when you launch the game, and reverts to your typing profile when you close it.
- **Auto-Downloader & Configurator:** Don't have Tosu installed? The script fetches the latest Windows release directly from GitHub, extracts it, and applies optimal configuration automatically.
- **Native C# Wrapper:** Compiles a clean `.exe` launcher on your machine using the built-in Windows C# compiler. No heavy dependencies, no external bloatware.
- **Dynamic Icon Support:** Drop your favorite `.ico` files into the resources folder, and the setup will let you choose your launcher icon dynamically.
- Native support for both English and Czech languages.

---

## 📂 Directory Structure

Before running the setup, ensure your folder structure looks like this:

```
Osu! Shadow Launcher/
├── setup.bat                 <-- Run this first!
├── README.md
└── resources/
    ├── icons/                <-- Drop custom .ico files here
    └── local/
        └── scripts/
            ├── launcher_EN.ps1
            └── launcher_CS.ps1
```


---


🚀 Installation & Setup
1. Build the Launcher
Extract the .zip archive to your desired location.

Run setup.bat.

Choose your preferred language (English or Czech).

Select an icon for your launcher from the dynamically generated list.

The script will compile OsuShadowLauncher.exe in the root folder.

(Optional) You can now safely delete setup.bat to keep the folder clean.

2. First Run (Configuration)
Double-click the newly created OsuShadowLauncher.exe.

A console window will appear guiding you through the initial setup.

The script will locate your osu!.exe. If it is not in the default %localappdata%\osu! folder, a file picker dialog will prompt you to find it.

You will be asked if you want to import/download Tosu and configure the Wooting Profile Switcher. Follow the on-screen prompts.

All settings are saved securely in resources/config.json.

3. Daily Usage
Once configured, simply run OsuShadowLauncher.exe. It will present a clean CLI menu allowing you to launch osu! alone, or alongside your chosen companion apps.

To edit your configuration later, press C in the main menu. To reconfigure Tosu, press T.

---

🛠️ Troubleshooting & FAQ
Q: I built a new .exe with a different icon, but Windows still shows the old one!

This is a known Windows feature, not a bug in the script. Windows aggressively caches icons in IconCache.db. If you generate an executable with the same name in the same folder, Windows Explorer will display the old cached icon.
Fix: Simply rename the .exe file or move it to your Desktop, and the new icon will magically appear.

Q: The setup fails to download Tosu and returns a (404) Not Found error.

Make sure you are using the latest version of the script. The Tosu GitHub repository recently migrated. This launcher is updated to pull from tosuapp/tosu.

Q: My antivirus / Windows Defender flagged the .exe file.

Because setup.bat compiles a C# executable that wraps and executes a PowerShell script silently in the background, heuristic scanners (like Windows Defender) might flag it as suspicious. This is a false positive. You can inspect the source code in setup.bat to see exactly how the C# wrapper is built. Sometimes it helps to delete the built OsuShadowLauncher.exe and rebuild it again.

---

📜 Requirements
Windows 10 / 11
PowerShell 5.1+
.NET Framework (Pre-installed on modern Windows machines)

---

## 🤝 Acknowledgments & Credits

This launcher automates and downloads third-party tools created by the community. Huge thanks to the original developers:

*   **[Tosu](https://github.com/tosuapp/tosu)** - An open-source, web-based overlay for osu!.
*   **[Wooting Profile Switcher](https://github.com/ShayBox/Wooting-Profile-Switcher)** by ShayBox - A CLI tool to automatically switch analog keyboard profiles.
