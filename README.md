# YomiKit

A native macOS app that captures and recognizes text from your screen using OCR, primarily designed for reading Japanese.

Under 5 MB. No Electron. No runtime dependencies.

## How it works

Pick a region anywhere on your screen. YomiKit captures it at 2 fps using SCStream, runs OCR via Apple VisionKit, and emits text only when it changes.

https://github.com/user-attachments/assets/3d0cfc2a-8d5a-4ef9-b820-abe4f9bfadab

## Features

- Region capture - select any area across screens, including external monitors
- OCR (VisionKit) - Japanese (vertical + horizontal) plus English, Korean, Chinese
- Quick scan - one-shot capture
- Filters - ustom text filters using regex
- Clipboard sync - auto-copy on change with built-in deduplication
- WebSocket - real-time text stream for external tools

## Limitations

Works best for anime, games, scanned text and Youtube.

Manga is hit or miss. Vertical text is recognized, but full-page captures with multiple bubbles can mess up reading order.

<img width="1255" height="718" alt="Screenshot 2026-04-26 at 11 20 34 AM" src="https://github.com/user-attachments/assets/3b03d95c-9b5e-440a-9184-b13bf9d7ea81" />

## Requirements

- macOS 15.0 or later (macOS 26 recommended for the Liquid Glass UI)
- Apple Silicon (M1 or later)
- Screen recording permission

## Install

Download the latest DMG from [Releases](https://github.com/vigneshwar221B/yomikit-mac/releases), open it, and drag YomiKit to Applications.

## Usage

1. Launch YomiKit and grant screen recording permission when prompted
2. Click **Select Region** and drag a rectangle over the text you want to capture
3. Click **Start Capture** and OCR'd text will start appearing in the panel
4. Text is automatically sent to your clipboard on each change

### WebSocket

Start the WebSocket server from the settings panel and connect from any client:

```js
ws = new WebSocket("ws://localhost:<port>");
ws.onmessage = e => console.log(e.data);
```

Works great with online texthooker pages like [Renji's Texthooker UI](https://renji-xd.github.io/texthooker-ui/). Point it at your WebSocket URL and recognized text will show up there automatically, ready for popup dictionaries like [Yomitan](https://github.com/yomidevs/yomitan).

## Architecture

```
User selects region -> OverlayWindow (drag rect)
                            |
                     CaptureManager (coordinator)
                            |
               SCStream (2fps, sourceRect = region)
                            |
               CapturedFrame -> CGImage extraction
                            |
                     TextRecognizer (VisionKit OCR)
                            |
                   Change detection (string compare)
                            |
               +------------+-------------+
         NSPasteboard              WebSocketServer
         (auto-copy)              (NWListener broadcast)
```

## License

MIT
