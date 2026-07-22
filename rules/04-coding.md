---
title: Coding Rules (Functional Style)
harnesses: [claude, cursor]
cursor-always-apply: true
---

## Coding Rules (Functional Style)

These rules apply across all languages. Adopt them where possible; document explicitly when deviating and why.

### 1. Return Values
Always return something meaningful. Prefer a typed result object or DataClass that carries outcome and context. `True`/`False` is the floor, not the ceiling. Raise exceptions with context when the *reason* for failure matters more than the boolean outcome.

```
# Minimum
def save_user(user) → True / False

# Preferred
def save_user(user) → Result(success=True, data=saved_user)
                       Result(success=False, error="email already exists")
```

### 2. Immutability
Prefer creating new values over mutating existing ones. Exception: large collections in performance-sensitive data processing — iterate and mutate in place rather than copying.

```
# Avoid
user.name = "Aaron"
user.role = "admin"

# Prefer
updated_user = User(**user, name="Aaron", role="admin")
```

### 3. Declarative over Imperative
Express *what* you want, not *how* to get it.

```
# Imperative
results = []
for user in users:
    if user.active:
        results.append(user.email)

# Declarative
results = [u.email for u in users if u.active]
```

### 4. Pure Functions
Same inputs → same outputs. No hidden side effects, no globals read or written, no external state mutated inside the function.

```
# Impure — depends on hidden global
def get_discount(user):
    return user.balance * CURRENT_RATE

# Pure — everything explicit
def get_discount(user, rate):
    return user.balance * rate
```

### 5. Fail Fast / Early Returns
Guard clauses at the top. Return early on invalid state — don't nest the happy path.

```
# Avoid
def process(order):
    if order:
        if order.items:
            if order.paid:
                # happy path buried here

# Prefer
def process(order):
    if not order:       return Result(False, "no order")
    if not order.items: return Result(False, "empty order")
    if not order.paid:  return Result(False, "unpaid")
    # happy path at top level
```

### 6. No Shared Mutable State
Pass data explicitly as parameters. No module-level or global mutable variables that functions silently read or write.

```
# Avoid
cache = {}
def get_user(id):
    cache[id] = fetch(id)  # mutates hidden global

# Prefer
def get_user(id, cache):
    return {**cache, id: fetch(id)}  # returns new state
```

### 7. One Level of Abstraction per Function
A function either coordinates other functions *or* does low-level work — not both.

```
# Mixed levels
def handle_checkout(cart):
    total = sum(i.price * i.qty for i in cart.items)  # low-level
    charge_card(total)                                  # high-level

# Clean
def handle_checkout(cart):
    total = calculate_total(cart)
    return charge_card(total)
```

### 8. Explicit over Implicit
Dependencies and outputs must be visible in the function signature. No action-at-a-distance, no hidden I/O.

```
# Implicit
def send_report():
    data = self.data       # hidden
    email = config.EMAIL   # hidden

# Explicit
def send_report(data, recipient): ...
```

### 9. Idempotency over State Management
Design operations so calling them multiple times produces the same result as calling them once. Prefer upserts over inserts, and operations that check-then-act over blind mutations.

```
# Not idempotent — duplicate calls = duplicate records
def create_subscription(user_id): INSERT ...

# Idempotent — safe to retry
def ensure_subscription(user_id): UPSERT ... WHERE user_id = ?
```

### 10. Command Query Separation (CQS)
A function either changes state (command) *or* returns data (query) — never both.

```
# Violates CQS — reading AND mutating
def get_next_id():
    self.counter += 1
    return self.counter

# Clean
def increment_counter(): ...  # command
def current_id(): ...         # query
```

### 11. Avoid Boolean Parameters
A boolean argument usually means the function is doing two things. Split it into two functions.

```
# Unclear at call site
send_email(user, True)

# Explicit
send_welcome_email(user)
send_reset_email(user)
```

### 12. Single Source of Truth
Data should have one canonical source. Derive everything else from it — don't keep multiple copies in sync.

```
# Fragile — two fields to keep in sync
user.full_name = "Aaron Lee"
user.display_name = "Aaron Lee"

# Derive from one source
user.first = "Aaron"
user.last = "Lee"
user.full_name → f"{first} {last}"
```

### 13. Make Illegal States Unrepresentable
Design data structures so invalid combinations cannot be constructed. If a state can't exist, it can't cause a bug.

```
# Fragile — nothing prevents both or neither being set
user.verified_email = "a@b.com"
user.unverified_email = "a@b.com"

# Better — structure enforces valid states
class UnverifiedUser: email: str
class VerifiedUser:   email: str, verified_at: datetime
```

### 14. Composition over Inheritance
Build behavior by composing small focused pieces rather than deep inheritance chains. Inheritance creates tight coupling — a change to a parent breaks all children.

```
# Inheritance — deep chain; changing Animal risks breaking everything below
class Animal:        def eat(): ...
class Dog(Animal):   def bark(): ...
class GuideDog(Dog): def guide(): ...   # tightly bound to two parents

# Composition — assemble from small, focused behaviors
class Eater:    def eat(): ...
class Barker:   def bark(): ...
class Guider:   def guide(): ...
class GuideDog: eater = Eater(); barker = Barker(); guider = Guider()
```

### 15. Dependency Injection over Hardcoded Dependencies
Pass dependencies in rather than instantiating them inside functions. Makes code testable, swappable, and explicit about what it needs.

```
# Hardcoded — untestable
def send_alert():
    client = SlackClient()
    client.send(...)

# Injected — testable
def send_alert(client):
    client.send(...)
```

### 16. Prefer Data over Code for Rules and Config
When behavior is driven by rules that change, represent those rules as data rather than branching code. Adding a new case then requires no code change.

```
# Branching — adding a role = code change
if role == "admin":  permissions = [...]
elif role == "viewer": permissions = [...]

# Data-driven — adding a role = data change
PERMISSIONS = {"admin": [...], "viewer": [...]}
permissions = PERMISSIONS[role]
```
