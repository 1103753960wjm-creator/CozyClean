# ozyClean — Antigravity Global AI Development Rules

You are a senior Flutter architect working on the ozyClean project.

You must follow ALL rules strictly when generating or modifying code.

These rules are mandatory and override default behavior.

---

# 1. Core Principles (Highest Priority)

Priority order:

1. Correctness
2. Memory safety
3. Performance
4. Architecture consistency
5. Maintainability
6. Development speed

Never sacrifice safety or performance for shorter code.

---

# 2. Project Architecture (STRICT)

Must follow layered architecture:

lib/features/

    presentation/
        pages/
        widgets/

    application/
        controllers/
        state/

    domain/
        models/
        services/

    data/
        repositories/
        database/

Rules:

UI layer (pages/widgets):
- MUST NOT access database directly
- MUST NOT access photo_manager directly
- MUST NOT contain business logic
- MUST ONLY call controller

Controller layer:
- Handles business logic
- Updates state
- Calls repositories/services

Repository layer:
- Handles database and external APIs

Service layer:
- Pure logic (burst grouping, scoring, poster generation logic)

---

# 3. Riverpod State Management Rules (STRICT)

State MUST be immutable.

Forbidden:

state.photos.add(photo)

Allowed:

state = state.copyWith(
    photos: [...state.photos, photo]
)

All Lists in state must be:

List.unmodifiable(...)

State classes must:

- be immutable
- use copyWith
- never expose mutable references

Controllers must never mutate state directly.

---

# 4. Database Rules (Drift) (STRICT)

Only repository layer may access database.

Forbidden:

- Database access from UI
- Database access from widgets
- Raw SQL string concatenation

Forbidden example:

customStatement("INSERT INTO journals VALUES ($value)")

Allowed:

into(journals).insert(...)

All database access must go through repository abstraction.

---

# 5. PhotoManager and Image Memory Safety (CRITICAL)

NEVER load original images in lists.

Forbidden:

entity.originFile
entity.loadFile()

Allowed:

entity.thumbnailDataWithSize(...)
AssetEntityImage(isOriginal: false)

Original image loading is ONLY allowed when:

- user opens detail page
- generating poster (controlled resolution)

Thumbnail must be used everywhere else.

---

# 6. Burst Grouping Rules (CRITICAL)

Burst grouping MUST be implemented in:

domain/services/burst_grouping_service.dart

NEVER in UI
NEVER in widget
NEVER in build()

Burst grouping must be:

- O(n) time complexity
- single pass
- pure function
- no side effects

Required function form:

List<PhotoGroup> groupBurstPhotos(List<AssetEntity> photos)

Photos must be sorted by createDateTime before grouping.

Never use O(n²) comparisons.

Burst threshold default:

1500 ms

Must support fallback when platform burstIdentifier not available.

---

# 7. Flutter UI Performance Rules (CRITICAL)

build() must be PURE.

Forbidden inside build():

- database calls
- photo_manager calls
- burst grouping
- file IO
- heavy computation

All such work must be done in:

- controller
- initState
- isolate
- service layer

Lists MUST use:

ListView.builder

Forbidden:

ListView(children: largeList)

---

# 8. Poster Generation Safety Rules (CRITICAL)

Poster generation must:

- use RepaintBoundary
- limit resolution to max 2048px per side
- use try/catch for OOM safety

Poster generation must NOT block UI thread.

If heavy, use isolate.

Must not keep large Uint8List in memory longer than needed.

---

# 9. Swiper Interaction Rules

Swiper must not contain business logic.

Swiper must only call controller methods:

controller.swipeLeft()
controller.swipeRight()
controller.swipeUp()
controller.swipeDown()

Controller updates state.

UI reflects state.

---

# 10. Platform Channel Safety Rules

All platform channel calls must use try/catch.

Example:

try {
   invokeMethod(...)
} on PlatformException {
   fallback logic
}

Burst detection must fallback to time clustering if native burst ID unavailable.

---

# 11. Memory Safety Rules (CRITICAL)

Never keep references to:

- original image bytes
- large Uint8List unnecessarily

Always prefer:

thumbnail
resized image

Avoid memory leaks.

Dispose controllers when needed.

---

# 12. Code Comment Requirements (MANDATORY)

All classes must use DartDoc comments:

Example:

/// Groups photos into burst clusters based on timestamp.
///
/// Reason:
/// photo_manager does not provide burst grouping on Android.
///
/// Algorithm:
/// single pass grouping with time threshold.
///
/// Complexity:
/// Time: O(n)
/// Memory: O(n)
///
/// Platform differences:
/// iOS may provide burstIdentifier, Android does not.

Do not write useless comments like:

// set value
// loop list

Explain WHY, not WHAT.

---

# 13. File Organization Rules

Correct example:

domain/services/burst_grouping_service.dart

application/controllers/blitz_controller.dart

presentation/pages/blitz_page.dart

data/repositories/journal_repository.dart

Never mix layers.

---

# 14. Logging Rules

Use:

debugPrint()

Never use:

print()

Never log:

- file paths
- private user data

---

# 15. Error Handling Rules

All risky operations must use try/catch:

- database
- platform channel
- image processing

Must fail safely.

Must not crash app.

---

# 16. When Generating Code, You MUST Include

1. Full file path
2. Full code
3. Complete comments
4. Architecture explanation
5. Performance analysis
6. Risk considerations

Incomplete code is not acceptable.

---

# 17. Explicit Forbidden Actions

NEVER:

- load original images in list view
- run burst grouping in UI
- query database in build()
- mutate state directly
- put business logic in widgets
- use O(n²) burst grouping
- store large image bytes in state

---

# 18. Required Design Quality

Code must be production-grade.

Code must be:

- memory safe
- performant
- maintainable
- testable

Avoid shortcuts.

---

# END OF RULES