# YomiKit

A native macOS screen text hooker, primarily designed for Japanese.

Select a screen region, and YomiKit captures it periodically, runs OCR via Apple's VisionKit framework, detects text changes, and outputs via clipboard and/or a WebSocket server for external app consumption.

https://github.com/user-attachments/assets/e03896f8-5320-4a0c-9f55-d9ab329e09c3

## Features

- **Region selection** -- drag to select any area of the screen
- **OCR** -- VisionKit framework with support for vertical and horizontal Japanese (also supports English, Korean, and Chinese)
- **Auto-copy** -- recognized text is automatically copied to clipboard on change
- **WebSocket server** -- broadcasts recognized text on a configurable port for external tools (e.g. popup dictionaries, Anki, translation apps)
- **Change detection** -- only outputs when text actually changes

## Limitations

- Vertical Japanese text is recognized, but when capturing a full manga page with multiple speech bubbles, the reading order of the output is not guaranteed.

<img width="1028" height="713" alt="Screenshot 2026-04-25 at 5 24 28 PM" src="https://github.com/user-attachments/assets/3f897825-dfaa-4378-89eb-bdaf7cf6bc45" />

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

## Requirements

- macOS 15.0+
- Screen recording permission

## License

MIT
