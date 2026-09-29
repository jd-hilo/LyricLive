#!/usr/bin/env python3
"""Generates en / zh-Hant Localizable.strings and InfoPlist.strings, then checks Swift sources for gaps.

Edit the dictionaries below, run `python3 scripts/localize.py`. English keys are the source strings.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APP = {
    # Tabs / general
    "Home": "首頁",
    "Library": "資料庫",
    "Settings": "設定",
    "Done": "完成",
    "Cancel": "取消",
    "Close": "關閉",
    "More": "更多",
    "Skip": "略過",
    "Continue": "繼續",
    "Clear": "清除",
    "Stop": "停止",
    "Play": "播放",
    "Pause": "暫停",
    "Listen": "聆聽",
    "Connect": "連接",
    "Allow": "允許",
    "Ready": "就緒",
    "On": "開啟",
    "Not asked": "尚未詢問",
    "Open Settings": "開啟設定",
    "Try again": "再試一次",
    "Share": "分享",
    "Style": "樣式",
    "Format": "格式",
    "Favorite": "加入最愛",
    "Favorites": "最愛",
    "Recent": "最近播放",
    "PRO": "PRO",
    "Go Pro": "升級 Pro",
    # Sources
    "Apple Music": "Apple Music",
    "Spotify": "Spotify",
    "Shazam": "Shazam",
    "Demo": "示範",
    "Sources": "音樂來源",
    "Built-in song with synced lyrics": "內建歌曲，附同步歌詞",
    "Allow access to follow what's playing.": "允許存取，以取得正在播放的歌曲。",
    "Access is off. Enable it in Settings.": "存取已關閉，請到「設定」開啟。",
    "Connected. Play a song in the Music app.": "已連接。請在「音樂」App 播放歌曲。",
    "Connected to Spotify.": "已連接 Spotify。",
    "Connecting…": "連接中…",
    "Tap Connect to authorize in the Spotify app.": "點一下「連接」，在 Spotify App 中授權。",
    "Couldn't connect. Open Spotify and try again.": "無法連接。請開啟 Spotify 後再試一次。",
    "Add your Spotify client ID to enable this.": "請加入你的 Spotify Client ID 以啟用。",
    "Follow songs playing in Spotify.": "跟隨 Spotify 正在播放的歌曲。",
    "Listening for music nearby…": "正在聆聽周圍的音樂…",
    "Couldn't listen. Check microphone access.": "無法聆聽，請檢查麥克風權限。",
    "Identify any song playing around you.": "辨識你周圍正在播放的任何歌曲。",
    "Shazam mode": "Shazam 模式",
    "Apple Music access": "Apple Music 存取權限",
    "Microphone access": "麥克風存取權限",
    # Home
    "Nothing playing": "沒有正在播放的歌曲",
    "Play a song in Apple Music and the lyrics show up here, on your Lock Screen, and in widgets. The built-in demo is in Spanish, with an English translation.":
        "在 Apple Music 播放歌曲，歌詞就會顯示在這裡、鎖定畫面與小工具上。內建示範歌曲是西班牙文，並附英文翻譯。",
    "Play demo song": "播放示範歌曲",
    "Open lyrics": "開啟歌詞",
    "No lyrics found": "找不到歌詞",
    "Instrumental": "純音樂",
    "Finding lyrics…": "正在尋找歌詞…",
    "Lyrics everywhere": "隨處可見的歌詞",
    "Lock Screen & Dynamic Island": "鎖定畫面與動態島",
    "Live lyrics without opening the app.": "無須開啟 App 即可查看即時歌詞。",
    "Live Activities are off in Settings.": "「即時活動」已在設定中關閉。",
    "Live Activity": "即時活動",
    "Widgets": "小工具",
    "Long-press your Home Screen, tap + and add %@.": "長按主畫面，點一下 +，然後加入 %@。",
    "CarPlay": "CarPlay",
    "Lyrics appear in the CarPlay app list while you drive.": "行車時，歌詞會顯示在 CarPlay App 列表中。",
    # Library
    "No favorites yet": "尚無最愛歌曲",
    "Tap the heart on the player to keep a song here.": "點一下播放器上的愛心，即可把歌曲收藏在這裡。",
    "Nothing here yet": "這裡還沒有內容",
    "Songs you play show up here.": "你播放過的歌曲會顯示在這裡。",
    "This song has no lyrics.": "這首歌沒有歌詞。",
    "We couldn't find lyrics for this song.": "找不到這首歌的歌詞。",
    "Couldn't load lyrics": "無法載入歌詞",
    "Check your connection and try again.": "請檢查網路連線後再試一次。",
    # Lyrics screen
    "Start a song and its lyrics will appear here.": "開始播放歌曲，歌詞就會顯示在這裡。",
    "These lyrics aren't time-synced.": "這份歌詞沒有時間同步。",
    "Remove from favorites": "從最愛中移除",
    "Add to favorites": "加入最愛",
    "Lyric options": "歌詞選項",
    "Find other lyrics": "尋找其他歌詞",
    "Share lyrics": "分享歌詞",
    "Translate to": "翻譯為",
    "%lld free translations left today": "今天還可免費翻譯 %lld 首",
    "Translation": "歌詞翻譯",
    "Show translation": "顯示翻譯",
    "Hide translation": "隱藏翻譯",
    "Timing": "時間",
    "Offset for this song": "這首歌的偏移",
    "Positive values show lyrics earlier, negative values later.": "正值讓歌詞提早顯示，負值則延後。",
    "Appearance": "外觀",
    "The lyrics are already in the selected language.": "歌詞已經是所選的語言。",
    "You've used today's free translations.": "你已用完今天的免費翻譯次數。",
    "Translation failed. Make sure the language pack is downloaded.": "翻譯失敗。請確認已下載語言套件。",
    "Font size": "字體大小",
    "Alignment": "對齊方式",
    "Font style": "字體樣式",
    "Background": "背景",
    "No results": "沒有結果",
    "Synced": "已同步",
    "Plain": "純文字",
    "Song and artist": "歌曲與歌手",
    "Previous song": "上一首",
    "Next song": "下一首",
    "Left": "靠左",
    "Center": "置中",
    "Right": "靠右",
    "Animated gradient": "動態漸層",
    "Artwork blur": "封面模糊",
    "Solid color": "純色",
    "Black": "黑色",
    "System": "系統",
    "Rounded": "圓體",
    "Serif": "襯線體",
    "Monospaced": "等寬字體",
    # Share
    "Artwork": "封面",
    "Midnight": "午夜",
    "Sunrise": "日出",
    "Paper": "紙張",
    "Square": "方形",
    "Story": "限時動態",
    "Select up to %lld lines": "最多可選 %lld 行",
    # Onboarding
    "Lyrics for the song that's playing": "正在播放的歌曲歌詞",
    "Synced lyrics for Apple Music and Spotify, on your Lock Screen, Dynamic Island, widgets, and in the car. Songs in other languages translate into English.":
        "Apple Music 與 Spotify 的同步歌詞，顯示在鎖定畫面、動態島、小工具與車上。其他語言的歌曲會翻譯成英文。",
    "Translate songs into English": "把歌曲翻譯成英文",
    "Live lyrics on the Lock Screen": "鎖定畫面上的即時歌詞",
    "Home Screen and Lock Screen widgets": "主畫面與鎖定畫面小工具",
    "Lyrics in CarPlay": "CarPlay 歌詞",
    "Get started": "開始使用",
    "Connect your music": "連接你的音樂",
    "Allow access to Apple Music so we can see which song is playing. Spotify can be connected later from the Home tab.":
        "允許存取 Apple Music，讓我們知道正在播放哪首歌。Spotify 可稍後在「首頁」連接。",
    "Apple Music connected": "已連接 Apple Music",
    "Allow Apple Music": "允許 Apple Music",
    "Identify songs anywhere": "隨處辨識歌曲",
    "Shazam mode listens through the microphone to recognize music playing nearby, from any app, a video or a speaker. Audio is only used to find a match.":
        "Shazam 模式會透過麥克風辨識附近播放的音樂，無論來自任何 App、影片或喇叭。音訊僅用於尋找比對結果。",
    "Microphone allowed": "已允許麥克風",
    "Allow microphone": "允許麥克風",
    "Not now": "暫時不要",
    "Lyrics on your Lock Screen": "鎖定畫面上的歌詞",
    "Live Activities show the current line under the clock and in the Dynamic Island. Turn on notifications so iOS allows them.":
        "「即時活動」會在時鐘下方與動態島顯示目前這一句。請開啟通知，讓 iOS 允許顯示。",
    "Live Activities are turned off for this app in Settings.": "此 App 的「即時活動」已在設定中關閉。",
    "Allow notifications": "允許通知",
    "All set": "設定完成",
    "Start listening": "開始聆聽",
    # Paywall
    "Live Activity and Dynamic Island lyrics": "即時活動與動態島歌詞",
    "Medium, large and Now Playing widgets": "中型、大型與「正在播放」小工具",
    "Unlimited translation into English": "無限次翻譯成英文",
    "Spotify and Shazam mode": "Spotify 與 Shazam 模式",
    "Share cards without watermark": "無浮水印的分享卡片",
    "Artwork backgrounds and font styles": "封面背景與字體樣式",
    "%@ Pro": "%@ Pro",
    "Synced lyrics on your Lock Screen, widgets, and CarPlay. Songs in other languages translate into English.":
        "鎖定畫面、小工具與 CarPlay 上的同步歌詞。其他語言的歌曲會翻譯成英文。",
    "Unlock Lock Screen and Dynamic Island lyrics.": "解鎖鎖定畫面與動態島歌詞。",
    "Unlock lyrics in CarPlay.": "解鎖 CarPlay 歌詞。",
    "You've used today's free translations. Go Pro for unlimited.": "你已用完今天的免費翻譯次數。升級 Pro 即可無限使用。",
    "Unlock Spotify.": "解鎖 Spotify。",
    "Unlock Shazam mode.": "解鎖 Shazam 模式。",
    "Unlock every widget size.": "解鎖所有尺寸的小工具。",
    "Unlock all share card styles without a watermark.": "解鎖所有無浮水印的分享卡片樣式。",
    "Unlock artwork backgrounds and font styles.": "解鎖封面背景與字體樣式。",
    "Couldn't load prices": "無法載入價格",
    "Yearly": "年訂閱",
    "Monthly": "月訂閱",
    "Lifetime": "終身買斷",
    "SAVE %lld%%": "省 %lld%%",
    "BEST VALUE": "最超值",
    "Renews every year. Cancel anytime.": "每年自動續訂，隨時可取消。",
    "Renews every month. Cancel anytime.": "每月自動續訂，隨時可取消。",
    "One payment, yours forever.": "一次付費，永久使用。",
    "Your purchase is waiting for approval.": "你的購買正在等待核准。",
    "The purchase didn't go through. Please try again.": "購買未完成，請再試一次。",
    "Restore purchases": "恢復購買",
    "Terms of use": "使用條款",
    "Privacy policy": "隱私權政策",
    "Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel in your App Store account settings. Lifetime is a one-time purchase.":
        "除非在目前訂閱期結束前至少 24 小時取消，否則訂閱會自動續訂。款項將由你的 Apple ID 扣款。你可在 App Store 帳號設定中管理或取消訂閱。終身買斷為一次性購買。",
    # Settings
    "%@ Pro is active": "%@ Pro 已啟用",
    "Manage subscription": "管理訂閱",
    "Upgrade to Pro": "升級至 Pro",
    "Live Activity, all widgets, CarPlay, Spotify, Shazam and more.": "即時活動、所有小工具、CarPlay、Spotify、Shazam 等功能。",
    "Purchases restored.": "已恢復購買。",
    "No previous purchases were found.": "找不到先前的購買項目。",
    "Lyrics": "歌詞",
    "Reset appearance": "重設外觀",
    "Songs in other languages translate into English on your iPhone (iOS 18 or later). You can pick another language below. Language packs download the first time you use them.":
        "其他語言的歌曲會在你的 iPhone 上翻譯成英文（需要 iOS 18 或以上）。你也可以在下方選擇其他語言。語言套件會在第一次使用時下載。",
    "Global lyric offset": "全域歌詞偏移",
    "Positive values show lyrics earlier. You can also adjust a single song from the lyrics screen.":
        "正值讓歌詞提早顯示。你也可以在歌詞畫面單獨調整某一首歌。",
    "Keep lyrics updating in the background": "在背景持續更新歌詞",
    "iOS suspends apps shortly after you leave them. This option plays inaudible audio, mixed with your music, so the Lock Screen lyrics keep advancing. It uses a little more battery.":
        "離開 App 後，iOS 很快就會暫停它。此選項會與你的音樂混合播放聽不見的音訊，讓鎖定畫面的歌詞持續前進，會多耗一點電力。",
    "Data": "資料",
    "Lyrics cache": "歌詞快取",
    "Clear lyrics cache": "清除歌詞快取",
    "Show welcome tour again": "重新顯示歡迎導覽",
    "Version": "版本",
    "Contact support": "聯絡支援",
    "About": "關於",
    "Lyrics are provided by LRCLIB, a community-run database. Translation happens on your device. %@ has no accounts and no analytics.":
        "歌詞由社群營運的資料庫 LRCLIB 提供。翻譯在你的裝置上進行。%@ 沒有帳號系統，也不做任何分析。",
    "Debug": "除錯",
    "Unlock Pro (debug only)": "解鎖 Pro（僅限除錯）",
    # Runtime messages (String(localized:))
    "Media & Apple Music access is turned off in Settings.": "「媒體與 Apple Music」存取權限已在設定中關閉。",
    "Microphone access is turned off in Settings.": "麥克風存取權限已在設定中關閉。",
    "On-device translation needs iOS 18 or later.": "裝置端翻譯需要 iOS 18 或以上版本。",
    "Add your Spotify client ID in project.yml.": "請在 project.yml 中加入你的 Spotify Client ID。",
    "Spotify SDK is not linked. See the README.": "尚未連結 Spotify SDK，請參閱 README。",
    "No purchase options are available right now.": "目前沒有可用的購買方案。",
    # CarPlay
    "Controls": "控制",
    "LyricLive Pro required": "需要 LyricLive Pro",
    "Open LyricLive on your iPhone to unlock CarPlay lyrics.": "請在 iPhone 上開啟 LyricLive 以解鎖 CarPlay 歌詞。",
    "Start a song in Apple Music or Spotify.": "請在 Apple Music 或 Spotify 播放歌曲。",
    "No synced lyrics for this song": "這首歌沒有同步歌詞",
    # Intents (shared with the widget bundle)
    "Play or Pause": "播放或暫停",
    "Next Song": "下一首",
    "Previous Song": "上一首",
}

WIDGETS = {
    "Lyrics": "歌詞",
    "The current lyric line, updated as the song plays.": "目前的歌詞，會隨歌曲播放更新。",
    "Play a song to see lyrics": "播放歌曲即可查看歌詞",
    "No synced lyrics": "沒有同步歌詞",
    "No song playing": "沒有正在播放的歌曲",
    "Unlock with Pro": "使用 Pro 解鎖",
    "Open the app to upgrade.": "開啟 App 即可升級。",
    "Nothing playing": "沒有正在播放的歌曲",
    "Now Playing": "正在播放",
    "Album art with playback controls.": "專輯封面與播放控制。",
    "Play or Pause": "播放或暫停",
    "Next Song": "下一首",
    "Previous Song": "上一首",
}

INFO_PLIST = {
    "en": {
        "NSAppleMusicUsageDescription": "Lyrics need to know which song is playing in the Music app.",
        "NSMicrophoneUsageDescription": "Shazam mode listens for music playing around you to identify the song. Audio is only used to find a match.",
    },
    "zh-Hant": {
        "NSAppleMusicUsageDescription": "歌詞功能需要知道「音樂」App 正在播放哪一首歌。",
        "NSMicrophoneUsageDescription": "Shazam 模式會聆聽你周圍播放的音樂以辨識歌曲。音訊僅用於尋找比對結果。",
    },
}


def esc(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def write_strings(path, table, header):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(f"/* {header} */\n")
        for key, value in table.items():
            fh.write(f'"{esc(key)}" = "{esc(value)}";\n')


def placeholders(s):
    return sorted(re.findall(r"%(?:lld|@|d|f)", s.replace("%%", "")))


def generate():
    for lang in ("en", "zh-Hant"):
        for folder, table, name in (("App/Resources", APP, "App"), ("Widgets/Resources", WIDGETS, "Widgets")):
            data = {k: (k if lang == "en" else v) for k, v in table.items()}
            write_strings(os.path.join(ROOT, folder, f"{lang}.lproj", "Localizable.strings"), data, f"{name} strings ({lang})")
        write_strings(os.path.join(ROOT, "App/Resources", f"{lang}.lproj", "InfoPlist.strings"), INFO_PLIST[lang], f"Info.plist strings ({lang})")
        write_strings(os.path.join(ROOT, "Widgets/Resources", f"{lang}.lproj", "InfoPlist.strings"), {}, "Widgets Info.plist strings")


def check():
    problems = 0
    for name, table in (("App", APP), ("Widgets", WIDGETS)):
        for key, zh in table.items():
            if placeholders(key) != placeholders(zh):
                print(f"[{name}] placeholder mismatch: {key!r}")
                problems += 1
    # Every literal passed to a localizing API must have an entry.
    patterns = [
        r'Text\("((?:[^"\\]|\\.)*)"\)', r'Label\("((?:[^"\\]|\\.)*)"', r'Button\("((?:[^"\\]|\\.)*)"', r'Toggle\("((?:[^"\\]|\\.)*)"',
        r'Picker\("((?:[^"\\]|\\.)*)"', r'Section\("((?:[^"\\]|\\.)*)"', r'Link\("((?:[^"\\]|\\.)*)"', r'navigationTitle\("((?:[^"\\]|\\.)*)"',
        r'String\(localized: "((?:[^"\\]|\\.)*)"', r'title: "((?:[^"\\]|\\.)*)"', r'message: "((?:[^"\\]|\\.)*)"',
        r'\(\s*"[a-z0-9.]+",\s*"((?:[^"\\]|\\.)*)"\s*\)', r'return "((?:[A-Z][^"\\]|\\.)*)"',
        r'configurationDisplayName\("((?:[^"\\]|\\.)*)"', r'\.description\("((?:[^"\\]|\\.)*)"', r'TextField\("((?:[^"\\]|\\.)*)"',
        r'LocalizedStringResource = "((?:[^"\\]|\\.)*)"', r'prompt: Text\("((?:[^"\\]|\\.)*)"',
    ]
    known = set(APP) | set(WIDGETS)
    files = glob.glob(os.path.join(ROOT, "App/**/*.swift"), recursive=True) + glob.glob(os.path.join(ROOT, "Widgets/*.swift")) + glob.glob(os.path.join(ROOT, "Shared/*.swift"))
    for path in sorted(files):
        source = open(path, encoding="utf-8").read()
        for pattern in patterns:
            for match in re.finditer(pattern, source):
                literal = match.group(1)
                if "\\(" in literal:
                    continue
                if not re.search(r"[A-Za-z]{2}", literal) or re.fullmatch(r"[a-z0-9.]+", literal) or literal.startswith(("#", "http", "mailto")):
                    continue
                if literal in known or literal in ("♪", "-"):
                    continue
                print(f"missing key {literal!r} in {os.path.relpath(path, ROOT)}")
                problems += 1
    return problems


if __name__ == "__main__":
    generate()
    count = check()
    print(f"generated; {len(APP)} app keys, {len(WIDGETS)} widget keys; {count} problem(s)")
    sys.exit(1 if count else 0)
