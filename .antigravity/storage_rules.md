# Storage Rules (STRICT MODE)

All persistence must follow:

`UI` → `Controller` → `Repository` → `DataSource` → `Storage`

## Storage Access Rules

Never allow **UI** or **Controller** to directly access:
- `SharedPreferences`
- `SecureStorage`
- `Database`
- `File system`

**Repository is the mandatory abstraction layer.**