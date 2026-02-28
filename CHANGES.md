# Changes to HTTP Client Request Cancellation

## Summary
Fixed the request cancellation issue in the Flutter SDK HTTP client by implementing proper disposal checking and introducing a public exception type for cancellation.

## Changes Made

### 1. Added `TolinkuCancelledException` (lib/src/exceptions.dart)
- New public exception class that is thrown when requests are attempted after the client is disposed
- Allows callers to distinguish cancellation from other errors
- Replaces the private `_DisposedException` class

### 2. Enhanced `_requestWithRetry` loop (lib/src/http_client.dart)
- Added `_checkDisposed()` call at the start of each retry attempt (line 144)
- This ensures that if `close()` is called during a backoff delay, the retry loop stops immediately
- Previously only checked disposal at the start of each request, not between retries

### 3. Updated exception handling
- Changed catch block from `on _DisposedException` to `on TolinkuCancelledException` (line 180)
- Updated `_checkDisposed()` to throw `TolinkuCancelledException` instead of `_DisposedException` (line 200)
- Removed private `_DisposedException` class

### 4. Updated documentation
- Updated `close()` method documentation to reference `TolinkuCancelledException` instead of `_DisposedException`

## How It Works

1. When `close()` is called on the HTTP client:
   - Sets `_disposed = true`
   - Calls `_client.close()` on the underlying `http.Client`, which cancels all in-flight HTTP requests

2. Request cancellation happens at multiple points:
   - Before each request attempt (via `_checkDisposed()` in GET/POST methods)
   - Before each retry attempt (via `_checkDisposed()` at the start of retry loop)
   - During request execution (when underlying client is closed)

3. The `TolinkuCancelledException` is public and can be caught by SDK users:
   ```dart
   try {
     await tolinku.track('event');
   } on TolinkuCancelledException {
     // Handle cancellation (client was disposed)
   } on TolinkuException catch (e) {
     // Handle other API errors
   }
   ```

## Testing
While `dart test` cannot be run in this environment (Dart SDK not available), the implementation follows the proper pattern for Dart HTTP request cancellation:
- Uses the `http.Client.close()` method to cancel in-flight requests
- Checks disposal flag before and during retry attempts
- Provides a distinguishable exception type for cancellation scenarios
