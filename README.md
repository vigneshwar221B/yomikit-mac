# YomiKit

A native macOS app that captures and recognizes text from your screen using OCR, primarily designed for Japanese.

Select a screen region, and YomiKit captures it periodically, runs OCR via Apple's VisionKit framework, detects text changes, and outputs via clipboard and/or a WebSocket server for external app consumption.

https://github.com/user-attachments/assets/e03896f8-5320-4a0c-9f55-d9ab329e09c3

## Features

- **Region selection** -- drag to select any area of the screen
- **OCR** -- VisionKit framework with support for vertical and horizontal Japanese (also supports English, Korean, and Chinese)
- **Auto-copy** -- recognized text is automatically copied to clipboard on change
- **Quick Scan** -- one-shot capture for a single snapshot without starting continuous capture
- **Text history** -- recognized text blocks are persisted across sessions; right-click any block to copy, resend via WebSocket, or delete
- **WebSocket server** -- broadcasts recognized text on a configurable port for external tools (e.g. popup dictionaries, Anki, translation apps)
- **Change detection** -- only outputs when text actually changes

## Limitations

- Works well for anime, games, YouTube playthroughs, and scanned books. Not ideal for manga -- vertical Japanese text is recognized, but when capturing a full page with multiple speech bubbles, the reading order of the output is not guaranteed.

<img width="1123" height="663" alt="Screenshot 2026-04-26 at 7 52 39 AM" src="https://github.com/user-attachments/assets/6035946e-5cbe-4e64-ad14-8672ac803e3c" />

## Requirements

- macOS 15.0+
- Apple Silicon (M1 or later)
- Screen recording permission

## Install

Download the latest DMG from [Releases](https://github.com/vigneshwar221B/yomikit-mac/releases), open it, and drag YomiKit to Applications.

## Usage

1. Launch YomiKit (requires macOS 15.0+)
2. Grant screen recording permission when prompted
3. Click **Select Region** and drag a rectangle over text you want to capture
4. Click **Start** -- OCR'd text appears in the display area
5. Text auto-copies to clipboard on each change

### WebSocket

Start the WebSocket server from the settings panel, then connect from any client:

```js
ws = new WebSocket("ws://localhost:<port>");
ws.onmessage = e => console.log(e.data);
```

You can also use online texthooker pages like [Renji's Texthooker UI](https://renji-xd.github.io/texthooker-ui/)

Point it at your WebSocket URL and recognized text will appear there automatically, ready for use with popup dictionaries like Yomitan.

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
                     TextRecognizer (Vision OCR)
                            |
                   Change detection (string compare)
                            |
               +------------+-------------+
         NSPasteboard              WebSocketServer
         (auto-copy)              (NWListener broadcast)
```

## License

MIT
