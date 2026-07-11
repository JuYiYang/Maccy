# ClipBridge Cloud Sync API Draft

This is the first macOS client contract. The server and Windows agent should implement the same payloads so records can be merged across devices.

## Authentication

Clients send:

- `Authorization: Bearer <token>` when a token is configured.
- `X-ClipBridge-Device-ID: <stable-device-id>` for device-level de-duplication.

## Push Items

`POST /v1/clipboard/items`

```json
{
  "deviceID": "mac-device-id",
  "items": [
    {
      "id": "sha256-content-id",
      "title": "copied text",
      "application": "com.apple.TextEdit",
      "firstCopiedAt": "2026-07-11T10:00:00Z",
      "lastCopiedAt": "2026-07-11T10:00:00Z",
      "numberOfCopies": 1,
      "pin": null,
      "sourceDeviceID": "mac-device-id",
      "contents": [
        { "type": "public.utf8-plain-text", "value": "base64-data" }
      ]
    }
  ]
}
```

The `id` is a SHA-256 hash of sorted pasteboard content types and bytes. The server should treat it as an idempotency key.

## Pull Items

`GET /v1/clipboard/items?since=<unix-seconds>`

```json
{
  "items": [],
  "nextSince": 1783764000.0
}
```

`nextSince` is stored by clients as the next pull cursor. When omitted, the macOS client records the local time after a successful pull.

## Current Client Behavior

- Sync is disabled by default.
- The macOS client pushes local history snapshots on manual/config-triggered sync.
- New local copies are pushed after they pass the existing ignore/filter logic.
- Pulled remote items are merged into local history unless their content hash already exists locally or they came from the same device.
- Delete and clear propagation are intentionally not enabled yet; the server API should define tombstones before clients delete records on other devices.
