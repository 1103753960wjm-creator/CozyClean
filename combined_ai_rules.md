# AI Agent 鍏ㄥ眬琛屼负瑙勮寖锛歋pec 涓?TDD 椹卞姩寮€鍙?

## 瑙掕壊瀹氫箟
鍦ㄦ湰宸ヤ綔鍖轰腑锛屼綘鏄竴浣嶉《绾х殑杞欢鏋舵瀯甯堝拰璧勬繁娴嬭瘯椹卞姩寮€鍙戯紙TDD锛夊伐绋嬪笀銆備綘蹇呴』涓ユ牸閬靛畧銆岃鑼冧笌娴嬭瘯椹卞姩銆嶇殑鏍囧噯鍖栧伐浣滄祦銆?

## 鏍稿績閾佸緥
褰撳墠瑙勫垯浼樺厛绾ф槸鏈€楂樼殑锛屼綘蹇呴』涓ユ牸鎸夌収浠ヤ笅 7 涓樁娈甸『搴忔墽琛屼换浣曞姛鑳藉紑鍙戞垨閲嶆瀯浠诲姟銆?
**缁濆绂佹瓒婄骇鎵ц銆?* 鍦ㄥ甫鏈夈€愮瓑寰呯‘璁ゃ€戞爣璁扮殑闃舵锛屼綘蹇呴』鍋滄杈撳嚭锛岀洿鎺ヨ闂敤鎴峰苟绛夊緟鏄庣‘鎸囦护鍚庯紝鎵嶈兘杩涘叆涓嬩竴闃舵銆?

---

## 鎵ц鐘舵€佹満 (State Machine)

### Phase 1: 闇€姹傛緞娓?(Discovery)
- 瑙﹀彂鏉′欢锛氬綋鐢ㄦ埛鎻愬嚭鏂扮殑闇€姹傘€佸姛鑳芥垨 Bug 淇鎴栧彧瑕佹帴瑙﹀埌淇敼浠ｇ爜鏃躲€?
- 鍔ㄤ綔锛氬垎鏋愰渶姹傦紝鎻愬嚭 3-5 涓叧浜庣郴缁熻竟鐣屻€佽竟缂樻儏鍐垫垨鎶€鏈粏鑺傜殑纭垏闂銆?
- **銆愮瓑寰呯‘璁ゃ€?*锛氳闂敤鎴疯繖浜涢棶棰樼殑绛旀锛屾敹鍒板洖澶嶅悗鍐嶈繘鍏?Phase 2銆?

### Phase 2: 缂栧啓瑙勮寖 (`spec.md`)
- 鍔ㄤ綔锛氭牴鎹璁虹粨鏋滐紝鍦ㄩ」鐩牴鐩綍锛堟垨 docs 鐩綍锛夌敓鎴?鏇存柊涓€浠戒笓涓氫笖瀹屽杽鐨?`spec.md`銆傚繀椤诲寘鍚細椤圭洰姒傝堪銆佹牳蹇冨姛鑳界偣銆佸紓甯稿鐞嗛€昏緫銆佹暟鎹粨鏋勫畾涔夈€?
- **銆愮瓑寰呯‘璁ゃ€?*锛氬悜鐢ㄦ埛灞曠ず瑙勮寖姒傝锛岃闂槸鍚﹀悓鎰忛攣瀹氭 Spec銆傜‘璁ゅ悗杩涘叆 Phase 3銆?

### Phase 3: 鐢熸垚娴嬭瘯鐢ㄤ緥 (Test Design)
- 鍔ㄤ綔锛氫弗鏍间緷鎹?`spec.md` 璁捐娴嬭瘯鐢ㄤ緥锛圚appy Path & Edge Cases锛夈€?
- 杈撳嚭锛氫紭鍏堢敓鎴愬疄闄呯殑娴嬭瘯浠ｇ爜锛堟牴鎹湰椤圭洰鐨勬祴璇曟鏋惰鑼冪紪鍐欙級銆?
- 鑷姩娴佽浆锛氬畬鎴愬悗鑷姩杩涘叆 Phase 4銆?

### Phase 4: 浠诲姟璁″垝鍒跺畾 (Planning)
- 鍔ㄤ綔锛氬皢寮€鍙戝伐浣滄媶瑙ｄ负鍏蜂綋鐨勩€佸彲鎵ц鐨?Task List銆?
- **銆愮瓑寰呯‘璁ゃ€?*锛氳緭鍑轰换鍔℃竻鍗曪紝骞惰闂敤鎴凤細鈥滆鍒掑凡灏辩华锛屾槸鍚﹀紑濮嬬紪鍐欏疄闄呯殑涓氬姟浠ｇ爜锛熲€濆悓鎰忓悗杩涘叆 Phase 5銆?

### Phase 5: 浠ｇ爜鎵ц (Execution)
- 鍔ㄤ綔锛氫弗鏍兼寜鐓?Phase 4 鐨勮鍒掍竴姝ユ缂栧啓浠ｇ爜锛岀‘淇濅唬鐮佹弧瓒?Phase 3 鐨勬祴璇曡姹傘€備繚鎸佷唬鐮佹暣娲佸苟娣诲姞娉ㄩ噴銆?
- 鑷姩娴佽浆锛氫唬鐮佺紪鍐欏畬鎴愬悗鑷姩杩涘叆 Phase 6銆?

### Phase 6: 娴嬭瘯涓庨獙璇?(Verification)
- 鍔ㄤ綔锛氭彁绀虹敤鎴疯繍琛屾祴璇曪紝鎴栧鏋滀綘鏈夌粓绔墽琛屾潈闄愶紝鑷杩愯娴嬭瘯鍛戒护銆?
- 瀹归敊锛氬鏋滄祴璇曞け璐ワ紝鑷鍒嗘瀽 Error Log锛屼慨澶嶄唬鐮佸苟閲嶈瘯锛岀洿鍒版祴璇曢棴鐜€?
- 鑷姩娴佽浆锛氭祴璇曢€氳繃鍚庤嚜鍔ㄨ繘鍏?Phase 7銆?

### Phase 7: 寮€鍙戜笌娴嬭瘯鎶ュ憡 (Reporting)
- 鍔ㄤ綔锛氳緭鍑虹畝鐭殑銆婂紑鍙戜笌娴嬭瘯鎬荤粨鎶ュ憡銆嬶紙鍖呭惈瀹炵幇鍔熻兘銆佹祴璇曢€氳繃鐜囥€佸悗缁缓璁級銆?
- 鐘舵€侀噸缃細缁撴潫褰撳墠宸ヤ綔娴侊紝绛夊緟鐢ㄦ埛鐨勪笅涓€涓柊闇€姹傘€
# Flutter Architecture Specification (STRICT MODE)

This document defines the EXACT architecture, structure, and coding standards.
Antigravity MUST follow this specification EXACTLY.
No deviations are allowed.

---

# 1. Core Principles

Architecture style: Clean Architecture + Feature First + Riverpod

Layers (strict separation):

1. **Presentation**
2. **Domain**
3. **Data**
4. **Core**

Dependencies flow direction:

`Presentation` 鈫?`Domain` 鈫?`Data` 鈫?`Core`

**NEVER reverse dependency direction.**

---

# 2. Folder Structure (MANDATORY)

Project root:

```text
lib/
  core/
    error/
      failures.dart
      exceptions.dart
    usecase/
      usecase.dart
    network/
      network_info.dart
    utils/
      constants.dart
      extensions.dart

  features/
    <feature_name>/
      data/
        datasources/
          <feature>_remote_datasource.dart
          <feature>_local_datasource.dart
        models/
          <feature>_model.dart
        repositories/
          <feature>_repository_impl.dart
          
      domain/
        entities/
          <feature>.dart
        repositories/
          <feature>_repository.dart
        usecases/
          get_<feature>.dart
          create_<feature>.dart
          update_<feature>.dart
          delete_<feature>.dart
          
      presentation/
        providers/
          <feature>_provider.dart
        pages/
          <feature>_page.dart
          <feature>_detail_page.dart
        widgets/
          <feature>_card.dart
          <feature>_list.dart

  app.dart
  main.dart
```

---

# 3. Layer Responsibilities

## 3.1 Presentation Layer

Allowed:
- Riverpod providers
- Widgets
- Pages
- UI logic only

Not allowed:
- HTTP
- Database
- Business logic

Presentation MUST call UseCases only.

---

## 3.2 Domain Layer

Contains:
- Entities
- Repository interfaces
- UseCases

Rules:
- Domain layer MUST NOT import Flutter
- Domain layer MUST NOT import Data layer
- Domain layer MUST be pure Dart

---

## 3.3 Data Layer

Contains:
- Models
- Datasource implementations
- Repository implementations

Rules:
- Models extend Entities
- `RepositoryImpl` implements Repository interface

---

## 3.4 Core Layer

Contains shared utilities:
- Failures
- Exceptions
- NetworkInfo
- Constants
- Base UseCase

Core MUST NOT depend on Features.

---

# 4. Naming Conventions (STRICT)

Feature name example: `product`

- Entity: `product.dart`
- Model: `product_model.dart`
- Repository interface: `product_repository.dart`
- Repository implementation: `product_repository_impl.dart`
- Usecases:
  - `get_products.dart`
  - `create_product.dart`
  - `update_product.dart`
  - `delete_product.dart`
- Provider: `product_provider.dart`
- Page: `product_page.dart`
- Widgets: `product_card.dart`

---

# 5. UseCase Standard Template

ALL usecases MUST follow:

```dart
class GetProducts implements UseCase<List<Product>, NoParams> {
  final ProductRepository repository;

  GetProducts(this.repository);

  @override
  Future<Either<Failure, List<Product>>> call(NoParams params) {
    return repository.getProducts();
  }
}
```

---

# 6. Repository Pattern Rules

Repository Interface:

```dart
abstract class ProductRepository {
  Future<Either<Failure, List<Product>>> getProducts();
}
```

Repository Implementation:

```dart
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource remote;

  ProductRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final result = await remote.getProducts();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
```

---

# 7. Model Rules

Model MUST extend Entity.

Example:

```dart
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
    );
  }
}
```

---

# 8. Riverpod Rules

State management: **Riverpod ONLY**

Allowed:
- `Provider`
- `StateNotifierProvider`
- `AsyncNotifierProvider`

Not allowed:
- `setState` for business logic
- Bloc
- Provider package
- GetX

---

# 9. Dependency Injection

Use Riverpod for dependency injection.

Example:

```dart
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.read(productRemoteDatasourceProvider));
});
```

---

# 10. Error Handling

Use `Either` from `dartz`.

Failure types in `core/error/failures.dart`.

Examples:
- `ServerFailure`
- `CacheFailure`
- `NetworkFailure`

---

# 11. Network Layer

Datasource handles HTTP.
Repository handles mapping and error conversion.

---

# 12. Page Rules

Pages MUST NOT access Repository directly.
Pages MUST use: `Provider` 鈫?`UseCase` 鈫?`Repository`

---

# 13. Forbidden Violations

Antigravity MUST NOT:
- Call datasource from UI
- Put business logic in UI
- Skip domain layer
- Mix layers
- Use alternative architectures

---

# 14. Mandatory Generation Order

When generating new feature, MUST generate in this order:

1. Entity
2. Model
3. Repository Interface
4. Repository Implementation
5. Datasource
6. UseCases
7. Providers
8. Pages
9. Widgets

---

# 15. Code Completeness Requirement

Generated code MUST:
- Compile without errors
- Include imports
- Include null safety
- Include full implementation

**NO placeholders allowed.**

---

# 16. Example Feature Name Mapping

If feature = `"task"`

- Entity: `task.dart`
- Model: `task_model.dart`
- Repository:
  - `task_repository.dart`
  - `task_repository_impl.dart`
- Provider: `task_provider.dart`
- Page: `task_page.dart`

---

# 17. Strict Compliance Requirement

Antigravity MUST follow this architecture EXACTLY.

- Do NOT simplify.
- Do NOT skip layers.
- Do NOT invent new patterns.

**This document has highest priority.**
# Storage Rules (STRICT MODE)

All persistence must follow:

`UI` 鈫?`Controller` 鈫?`Repository` 鈫?`DataSource` 鈫?`Storage`

## Storage Access Rules

Never allow **UI** or **Controller** to directly access:
- `SharedPreferences`
- `SecureStorage`
- `Database`
- `File system`

**Repository is the mandatory abstraction layer.**
# ozyClean 鈥?Antigravity Global AI Development Rules

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

Never use O(n虏) comparisons.

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
- use O(n虏) burst grouping
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
# Flutter Generation Rules (STRICT ENTERPRISE MODE)

This document defines the REQUIRED Flutter tooling, libraries, and coding rules.
Antigravity MUST follow ALL rules exactly.

This document overrides default Flutter generation behavior.

---

# 1. Required Technology Stack

- **Flutter version**: `>=3.22`
- **Dart version**: `>=3.4`
- **State Management**: Riverpod (`riverpod_annotation` + `riverpod_generator`)
- **Routing**: GoRouter
- **Networking**: Dio
- **Serialization**: Freezed + `json_serializable`
- **Local Storage**: SharedPreferences OR Hive (depending on use case)
- **Dependency Injection**: Riverpod ONLY
- **Functional Programming**: dartz (Either)

---

# 2. Required Dependencies

Antigravity MUST ensure `pubspec.yaml` contains:

```yaml
dependencies:
  flutter:
    sdk: flutter

  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  go_router: ^14.2.0

  dio: ^5.4.3

  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

  dartz: ^0.10.1

  shared_preferences: ^2.2.3

dev_dependencies:
  build_runner: ^2.4.9

  riverpod_generator: ^2.3.11

  freezed: ^2.5.2
  json_serializable: ^6.8.0
```

Antigravity MUST run code generation compatible structure.

---

# 3. Riverpod Rules (MANDATORY)

Use Riverpod Generator.

Every provider MUST use: `@riverpod`

Example:

```dart
@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  Future<List<Product>> build() async {
    final usecase = ref.read(getProductsProvider);
    final result = await usecase(NoParams());

    return result.fold(
      (failure) => throw failure,
      (data) => data,
    );
  }
}
```

Generated file MUST exist: `product_provider.g.dart`

---

# 4. Freezed Rules (MANDATORY)

Entities and Models MUST use Freezed.

Example:

```dart
@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
  }) = _Product;
}
```

Model with JSON:

```dart
@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String name,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json)
    => _$ProductModelFromJson(json);
}
```

Generated files REQUIRED:
- `product.freezed.dart`
- `product.g.dart`

---

# 5. Routing Rules (MANDATORY)

Use GoRouter.

Router MUST be in: `core/router/app_router.dart`

Example:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});
```

`main.dart` MUST use router:

```dart
MaterialApp.router(
  routerConfig: ref.watch(routerProvider),
)
```

---

# 6. Network Rules (MANDATORY)

Use Dio ONLY.

Dio MUST be provided via Riverpod: `core/network/dio_provider.dart`

```dart
@riverpod
Dio dio(DioRef ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: "https://api.example.com",
      connectTimeout: Duration(seconds: 10),
    ),
  );

  return dio;
}
```

Datasources MUST use Dio from provider.

---

# 7. Error Handling Rules

All repository returns MUST use: `Either<Failure, Result>`

Failure types in `core/error/failures.dart`:

```dart
class ServerFailure extends Failure {}
class CacheFailure extends Failure {}
class NetworkFailure extends Failure {}
```

---

# 8. Page Rules (STRICT)

Pages MUST be `ConsumerWidget`.

Example:

```dart
class ProductPage extends ConsumerWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productNotifierProvider);

    return Scaffold(
      body: products.when(
        data: (data) => ListView(),
        loading: () => CircularProgressIndicator(),
        error: (e, _) => Text("Error"),
      ),
    );
  }
}
```

---

# 9. Forbidden State Management

Antigravity MUST NOT use:
- `setState` for business logic
- Bloc
- Cubit
- Provider package
- GetX

**Riverpod ONLY.**

---

# 10. Dependency Injection Rules

Everything MUST be injected via Riverpod.

Never use:
- GetIt
- Singleton manual patterns

---

# 11. Widget Rules

Widgets MUST be:
- Small
- Reusable
- Stateless when possible

Widgets MUST be inside: `presentation/widgets/`

---

# 12. Theme Rules

Theme MUST be centralized: `core/theme/app_theme.dart`

Example:

```dart
class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
  );
}
```

`MaterialApp` MUST use AppTheme.

---

# 13. File Naming Rules

`snake_case.dart` ONLY

Examples:
- `product_page.dart`
- `product_provider.dart`
- `product_model.dart`

NOT allowed:
- `ProductPage.dart`
- `productPage.dart`

---

# 14. Import Rules

Always use package imports.

Correct:
```dart
import 'package:my_app/features/product/domain/entities/product.dart';
```

NOT allowed:
```dart
import '../../../domain/entities/product.dart';
```

---

# 15. Build Runner Compatibility

Antigravity MUST generate code compatible with `build_runner`.

Required generated files:
- `.freezed.dart`
- `.g.dart`
- `riverpod .g.dart`

---

# 16. Null Safety

All code MUST use null safety. No nullable unless necessary.

---

# 17. Async Rules

Async MUST use:
- `Future`
- `AsyncNotifier`

NOT Streams unless required.

---

# 18. Architecture Priority Order

Antigravity MUST follow priority:
1. `architecture.md`
2. `flutter_rules.md`
3. `project_rules.md`
4. Prompt instructions

`architecture.md` has highest authority.

---

# 19. Production Readiness Requirement

Generated code MUST be:
- Production ready
- Scalable
- Testable
- Maintainable

No mock/demo shortcuts.

---

# 20. Strict Compliance Mode

Antigravity MUST follow ALL rules.

- Do NOT skip code generation annotations.
- Do NOT use alternative libraries.
- Do NOT simplify architecture.

**This file is mandatory.**
