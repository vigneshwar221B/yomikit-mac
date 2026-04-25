# YomiKit

A macOS screen text hooker for Japanese, English, and Chinese.

Select a screen region, and YomiKit captures it periodically, runs OCR via Apple's Vision framework, detects text changes, and outputs via clipboard and/or a WebSocket server for external app consumption.

## Features

- **Region selection** -- drag to select any area of the screen
- **OCR** -- Vision framework with `.accurate` recognition for Japanese, English, Simplified Chinese, and Traditional Chinese
- **Auto-copy** -- recognized text is automatically copied to clipboard on change
- **WebSocket server** -- broadcasts recognized text on port 8765 for external tools (e.g. popup dictionaries, Anki, translation apps)
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
ws = new WebSocket("ws://localhost:8765");
ws.onmessage = e => console.log(e.data);
```

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
