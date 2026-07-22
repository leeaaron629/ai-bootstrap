---
title: Testing Philosophy
harnesses: [claude, cursor]
cursor-always-apply: true
---

## Testing Philosophy

### Test Pyramid

Prefer integration tests as the primary form of testing. Unit tests should be sparse — write them only when logic is complex enough to warrant isolated testing.

```
         [ e2e ]           ← few, cover critical user journeys only
      [ integration ]      ← primary layer; test full flows with real classes
    [ unit ]               ← thin; 2-5 per module for complex isolated logic
```

### Mocking Strategy

Mock only at system boundaries — external APIs, third-party services, payment providers, email/SMS services, cloud storage. Never mock internal classes, repositories, or services you own.

```
# Wrong — mocking internal dependency, reduces confidence
user_repo = Mock()
user_repo.find.return_value = user
service = UserService(user_repo)

# Right — real classes, mock only the external boundary
db = RealDatabase(test_config)
email_client = MockEmailClient()   # external boundary
service = UserService(db, email_client)
result = service.register(user_data)
assert result.success
assert db.find_user(user_data.email) is not None
```

### Test Behavior, Not Implementation

Tests should assert what a function *does*, not how it does it internally. This lets you refactor without rewriting tests.

```
# Tests implementation — breaks on any internal refactor
assert service._cache["aaron"] == user

# Tests behavior — survives refactoring
assert service.get_user("aaron") == expected_user
```

### AAA Structure — Arrange, Act, Assert

Every test follows this shape. One assertion focus per test.

```
def test_registration_sends_welcome_email():
    # Arrange
    email_client = MockEmailClient()
    service = UserService(db, email_client)

    # Act
    service.register({"email": "a@b.com"})

    # Assert
    assert email_client.sent_to == "a@b.com"
```

### Test Independence

No test should depend on another running first, or on shared mutable state between tests. Each test sets up its own world and tears it down. Tests must be runnable in any order.

```
# Fragile — test_two depends on test_one having run first
users = []
def test_one(): users.append(create_user()); assert len(users) == 1
def test_two(): assert users[0].active   # breaks if run alone or reordered

# Independent — each test builds and tears down its own state
def test_user_is_created():
    db = fresh_db()
    user = create_user(db)
    assert db.count() == 1

def test_new_user_is_active():
    db = fresh_db()
    user = create_user(db)
    assert user.active
```

### Test Naming

Test names describe behavior, not method names. A failing test name should tell you exactly what broke.

```
# Vague
test_get_user()

# Descriptive
test_get_user_returns_none_when_user_not_found()
test_registration_fails_when_email_already_exists()
test_order_total_includes_tax_for_us_customers()
```

### Coverage Philosophy

Coverage is a byproduct, not a goal. Don't chase a percentage — chase confidence. 80% meaningful coverage beats 100% trivial coverage. A test that only asserts no exception was raised is not a useful test.

### Skip (no meaningful confidence gain)

- Trivial getters/setters, pure config, feature flags
- Generated code (ORM models, proto, auto-generated clients)
- Framework boilerplate (bare serializers, empty migrations)
- Simple DTOs with no logic
- One-liner library wrappers
- Pure logging/formatting functions

### Always Test

- Business logic and domain rules
- Branching paths and edge cases
- Data transformations
- Error and failure paths
- Auth and authorization logic
- External service integrations (mocked at boundary)
- Public API contracts
