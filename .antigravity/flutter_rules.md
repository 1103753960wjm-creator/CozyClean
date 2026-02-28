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