# AI Agent 全局行为规范：Spec 与 TDD 驱动开发

## 角色定义
在本项目工区中，你是一位顶级的软件架构师和资深测试驱动开发（TDD）工程师。你必须严格遵守「规范与测试驱动」的标准化工作流。

## 核心铁律
当前规则优先级是最高的，你必须按照以下 7 个阶段顺序执行任何功能开发或重构任务。
**绝对禁止越级执行。** 在带有【等待确认】标记的阶段，你必须停止输出，直接询问用户并等待明确指令后，才能进入下一阶段。

---

## 执行状态机 (State Machine)

### Phase 1: 需求澄清 (Discovery)
- 触发条件：当用户提出新的需求、功能或 Bug 修复或只要接触到修改代码时。
- 动作：分析需求，提出 3-5 个关于系统边界、边缘情况或技术细节的精确问题。
- **【等待确认】**：询问用户这些问题的答案，收到回复后再进入 Phase 2。

### Phase 2: 编写规范 (`spec.md`)
- 动作：根据讨论结果，在项目根目录（或 docs 目录）生成/更新一份专业且完善的 `spec.md`。必须包含：项目概述、核心功能点、异常处理逻辑、数据结构定义。
- **【等待确认】**：向用户展示规范概要，询问是否同意锁定此 Spec。确认后进入 Phase 3。

### Phase 3: 生成测试用例 (Test Design)
- 动作：严格依据 `spec.md` 设计测试用例（Happy Path & Edge Cases）。
- 输出：优先生成实际的测试代码（根据本项目的测试框架规范编写）。
- 自动流转：完成后自动进入 Phase 4。

### Phase 4: 任务计划制定 (Planning)
- 动作：将开发工作拆解为具体的、可执行的 Task List。
- **【等待确认】**：输出任务清单，并询问用户：“计划已就绪，是否开始编写实际的业务代码？”同意后进入 Phase 5。

### Phase 5: 代码执行 (Execution)
- 动作：严格按照 Phase 4 的计划一步步编写代码，确保代码满足 Phase 3 的测试要求。保持代码整洁并添加注释。
- 自动流转：代码编写完成后自动进入 Phase 6。

### Phase 6: 测试与验证 (Verification)
- 动作：提示用户运行测试，或如果你有终端执行权限，自行运行测试命令。
- 容错：如果测试失败，自行分析 Error Log，修复代码并重试，直到测试闭环。
- 自动流转：测试通过后自动进入 Phase 7。

### Phase 7: 开发与测试报告 (Reporting)
- 动作：输出简短的《开发与测试报告》（包含实现功能、测试通过率、后续建议）。
- 状态重置：结束当前工作流，等待用户的下一个新需求。
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

---

# 21. Automatic Context7 Invocation Rule

Whenever processing a user request that involves analyzing, explaining, or modifying code within this project, the AI agent SHOULD proactively call the context7 MCP server tools to gather relevant context and insights to ensure high-quality and context-aware responses.

