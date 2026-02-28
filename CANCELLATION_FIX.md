# Request Cancellation Fix - Flutter SDK

## Problem
The Flutter SDK HTTP client did not properly support request cancellation. Specifically:
1. No public exception type for distinguishing cancellation from other errors
2. The disposal check only happened before initial request attempts, not between retry attempts
3. If `close()` was called during a retry backoff delay, the retry loop would continue

## Solution
Implemented proper request cancellation with the following changes:

### 1. Public Exception Type (`TolinkuCancelledException`)

**File:** `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/lib/src/exceptions.dart`

Added a new public exception class:
```dart
/// Exception thrown when a request is attempted after the client has been
/// disposed or when an in-flight request is cancelled.
///
/// This allows callers to distinguish request cancellation from other errors.
class TolinkuCancelledException implements Exception {
  const TolinkuCancelledException();

  @override
  String toString() => 'TolinkuCancelledException: HTTP client has been disposed';
}
```

This allows SDK users to handle cancellation separately:
```dart
try {
  await tolinku.track('event');
} on TolinkuCancelledException {
  // Client was disposed, handle gracefully
} on TolinkuException catch (e) {
  // Handle API errors
}
```

### 2. Disposal Check in Retry Loop

**File:** `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/lib/src/http_client.dart`

Added disposal check at the start of the retry loop (line 144):
```dart
Future<Map<String, dynamic>> _requestWithRetry(
  Future<Map<String, dynamic>> Function() request,
) async {
  for (var attempt = 0; attempt <= _maxRetries; attempt++) {
    // Check disposed flag before each retry attempt.
    _checkDisposed();  // <-- NEW: stops retry loop immediately if disposed

    try {
      return await request();
    } on TolinkuException catch (e) {
      // ... retry logic ...
      await Future<void>.delayed(delay);  // If close() called here, next iteration catches it
    }
  }
}
```

**Before:** If `close()` was called during the `Future.delayed()` backoff, the next retry would still execute.

**After:** The disposal check at the start of each iteration catches this immediately and throws `TolinkuCancelledException`.

### 3. Updated Exception Handling

Changed from private `_DisposedException` to public `TolinkuCancelledException`:

**In retry loop (line 180):**
```dart
} on TolinkuCancelledException {
  rethrow;
}
```

**In `_checkDisposed()` method (line 198-202):**
```dart
void _checkDisposed() {
  if (_disposed) {
    throw const TolinkuCancelledException();
  }
}
```

**Removed private class:**
```dart
// DELETED: class _DisposedException implements Exception { ... }
```

### 4. Updated Documentation

**In `close()` method (line 273-279):**
```dart
/// Closes the underlying HTTP client and marks this instance as disposed.
///
/// Any in-flight requests will fail with a [TolinkuCancelledException].
void close() {
  _disposed = true;
  _client.close();
}
```

## How It Works

### Cancellation Points

Request cancellation now happens at multiple checkpoints:

1. **Before initial request:**
   - Each `get()`, `post()`, `postBatch()` method calls `_checkDisposed()` before making the HTTP call

2. **Before each retry attempt:**
   - `_requestWithRetry()` calls `_checkDisposed()` at the start of each loop iteration
   - This catches disposal that happens during backoff delays

3. **During in-flight requests:**
   - `_client.close()` cancels all active HTTP requests at the socket level

### Disposal Flow

```
User calls Tolinku.instance.dispose()
  ↓
Calls _httpClient.close()
  ↓
Sets _disposed = true
  ↓
Calls _client.close() (http.Client)
  ↓
All in-flight HTTP requests are cancelled
  ↓
Any subsequent request attempts throw TolinkuCancelledException
```

### Example Scenario

```dart
// Start a request that will retry
final future = tolinku.track('event');

// Request fails, enters retry backoff (500ms delay)
await Future.delayed(Duration(milliseconds: 250));

// Dispose the client during the backoff
await tolinku.dispose();

// After backoff completes, retry loop checks _disposed and throws
// TolinkuCancelledException instead of attempting another request
```

## Testing

While the Dart SDK is not available in this environment to run `dart test`, the implementation follows Dart best practices:

1. Uses `http.Client.close()` for native cancellation
2. Checks disposal flag at all critical points
3. Provides distinguishable exception type
4. Properly handles async cancellation during delays

The existing test suite in `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/test/tolinku_test.dart` validates the dispose flow and should continue to pass.

## Files Modified

1. `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/lib/src/exceptions.dart`
   - Added `TolinkuCancelledException` class

2. `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/lib/src/http_client.dart`
   - Added disposal check at start of retry loop
   - Changed exception handling from `_DisposedException` to `TolinkuCancelledException`
   - Updated `_checkDisposed()` to throw public exception
   - Removed private `_DisposedException` class
   - Updated `close()` documentation

3. `/home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk/lib/tolinku.dart`
   - No changes needed (exceptions.dart already exported)

## Verification

To verify the fix works correctly when Dart SDK is available:

```bash
cd /home/ryon-whyte/Documents/GitHub/tolinku/flutter-sdk
dart test
```

Expected: All tests pass with no errors.
