# YomiKit

A native macOS screen text hooker, primarily designed for Japanese.

Select a screen region, and YomiKit captures it periodically, runs OCR via Apple's Vision framework, detects text changes, and outputs via clipboard and/or a WebSocket server for external app consumption.

https://github.com/user-attachments/assets/e03896f8-5320-4a0c-9f55-d9ab329e09c3

## Features

- **Region selection** -- drag to select any area of the screen
- **OCR** -- Vision framework with `.accurate` recognition, primarily for Japanese (also supports English, Chinese, and other Vision-supported languages)
- **Auto-copy** -- recognized text is automatically copied to clipboard on change
- **WebSocket server** -- broadcasts recognized text on a configurable port for external tools (e.g. popup dictionaries, Anki, translation apps)
- **Change detection** -- only outputs when text actually changes

## Usage

1. Build and run in Xcode (requires macOS 15.0+)
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
- Xcode 16+
- Screen recording permission

## License

MIT
