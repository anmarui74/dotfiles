# Pydantic v2 Performance Reference

## JSON Parsing: Prefer model_validate_json

```python
# Slow — Python parses JSON to dict, then Pydantic validates
user = User.model_validate(json.loads(raw_json))

# Fast — Pydantic-core parses and validates in one Rust pass
user = User.model_validate_json(raw_json)
```

## TypeAdapter: Instantiate Once at Module Level

```python
from pydantic import TypeAdapter
from typing import Annotated
from pydantic import Field

# Bad — compiled on every call
def validate_price(v: float) -> float:
    adapter = TypeAdapter(Annotated[float, Field(gt=0)])
    return adapter.validate_python(v)

# Good — compiled once at import time
PriceAdapter = TypeAdapter(Annotated[float, Field(gt=0)])

def validate_price(v: float) -> float:
    return PriceAdapter.validate_python(v)
```

## TypedDict Over Nested BaseModel for Hot Paths

TypedDict models validate ~2.5x faster than nested BaseModel.

```python
from typing import TypedDict
from pydantic import TypeAdapter

class AddressDict(TypedDict):
    street: str
    city: str

class UserDict(TypedDict):
    id: int
    address: AddressDict

UserDictAdapter = TypeAdapter(UserDict)
user = UserDictAdapter.validate_python(raw_data)
```

## Discriminated Unions

```python
# Slow — tries each member in order
Pet = Union[Cat, Dog]

# Fast — O(1) dispatch via discriminator
TaggedPet = Annotated[Union[Cat, Dog], Field(discriminator='pet_type')]
```

## model_construct for Pre-Validated Data

```python
# Bypasses all validation — only for trusted data
user = User.model_construct(id=1, name='Alice')
```

## Summary Table

| Technique | When to Apply |
|-----------|---------------|
| `model_validate_json` over `json.loads` + `model_validate` | Any JSON input |
| Module-level `TypeAdapter` | Hot paths with non-BaseModel types |
| `TypedDict` over nested `BaseModel` | Internal data, not rich objects |
| Discriminated unions | Unions with a literal field |
| `model_construct` | Pre-validated trusted data only |
| `list[X]` over `Sequence[X]` | Any list-typed field |
