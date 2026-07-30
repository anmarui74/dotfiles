# Serialization and Configuration — Pydantic v2 Reference

## Serialization Methods

### model_dump()

```python
from pydantic import BaseModel, Field

class Order(BaseModel):
    order_id: int
    customer: str
    amount: float = Field(serialization_alias='totalAmount')

o = Order(order_id=1, customer='Alice', amount=99.9)
o.model_dump()
# {'order_id': 1, 'customer': 'Alice', 'amount': 99.9}
o.model_dump(by_alias=True)
# {'order_id': 1, 'customer': 'Alice', 'totalAmount': 99.9}
```

### model_dump_json()

```python
o.model_dump_json()           # compact
o.model_dump_json(indent=2)   # pretty-printed
```

### exclude_unset for PATCH semantics

```python
class UserUpdate(BaseModel):
    name: str = 'default'
    email: str = 'default@example.com'

patch = UserUpdate(name='Alice')
patch.model_dump(exclude_unset=True)
# {'name': 'Alice'}
```

## ConfigDict Reference

| Key | Default | Effect |
|---|---|---|
| `extra` | `'ignore'` | `'forbid'` rejects unknown fields; `'allow'` stores them |
| `strict` | `False` | Disables all type coercion |
| `validate_default` | `False` | Runs validators on defaults |
| `validate_assignment` | `False` | Re-validates on attribute assignment |
| `str_strip_whitespace` | `False` | Strips whitespace from strings |
| `str_to_lower` | `False` | Lowercases all strings |
| `populate_by_name` | `False` | Use field name when alias is set |
| `from_attributes` | `False` | Enable ORM mode |

### Common patterns

```python
class StrictApiModel(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)

class OrmModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)

class ImmutableModel(BaseModel):
    model_config = ConfigDict(frozen=True)
```

## ORM Integration

```python
class UserSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    email: str

orm_obj = UserOrm(id=1, name='Alice', email='alice@example.com')
user = UserSchema.model_validate(orm_obj)
```

## Generic Models

```python
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar('T')

class Paginated(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int

class UserItem(BaseModel):
    id: int
    name: str

response = Paginated[UserItem](
    items=[UserItem(id=1, name='Alice')],
    total=1, page=1, page_size=20,
)
```
