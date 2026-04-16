# Fix Batches Screen - "إعادة التعيين" Filter Not Showing Batches Without Expiry

**Status:** Plan approved by user ("اه").

## Steps:

### 1. Add fix method in lib/db/db_helper.dart

- Add `Future<int> fixInactiveNoExpiryBatches()` → UPDATE active=1 for batches with no expiry AND remaining_quantity > 0, return count affected.

### 2. Update lib/providers/batch_provider.dart

- Add `Future<void> fixBatchData()` calling DBHelper().fixInactiveNoExpiryBatches().
- Add `Future<Map<String, int>> getBatchStats()` → count total active, no_expiry active.

### 3. Update lib/screens/batches_screen.dart

- Add ElevatedButton row below BatchFilterBar:
  - "إحصائيات" → show dialog with stats.
  - "إصلاح البيانات" → call provider.fixBatchData() → reload + snackbar count.
- Use showDialog for stats.

### 4. Test

- Create batch without expiry, set active=0.
- Run app, check not shows on reset.
- Press "إصلاح" → reloads, shows.

### 5. Cleanup

- Remove admin buttons or hide behind debug flag.

**Followup:** Install dependencies if needed (`flutter pub get`), `flutter run`, test.

Proceed to step 1?
