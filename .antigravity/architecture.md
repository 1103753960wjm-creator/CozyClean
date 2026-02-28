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

`Presentation` → `Domain` → `Data` → `Core`

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
Pages MUST use: `Provider` → `UseCase` → `Repository`

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