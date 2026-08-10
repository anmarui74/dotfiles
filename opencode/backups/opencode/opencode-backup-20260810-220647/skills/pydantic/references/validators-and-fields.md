# Validators and Fields — Pydantic v2 Reference

## Table of Contents
1. [Field Constraints Quick Reference](#field-constraints-quick-reference)
2. [The Annotated Pattern in Depth](#the-annotated-pattern-in-depth)
3. [Validator Modes Explained](#validator-modes-explained)
4. [Validator Ordering](#validator-ordering)
5. [Model Validators](#model-validators)
6. [Validation Context and Info](#validation-context-and-info)
7. [Special Validator Utilities](#special-validator-utilities)
8. [Discriminated Unions](#discriminated-unions)
9. [Computed Fields](#computed-fields)
10. [Field Aliases In Depth](#field-aliases-in-depth)

---

## Field Constraints Quick Reference

| Constraint | Types | Example |
|---|---|---|
| `gt`, `ge`, `lt`, `le` | `int`, `float`, `Decimal` | `Field(gt=0)` |
| `min_length`, `max_length` | `str`, `list`, `set` | `Field(max_length=255)` |
| `pattern` | `str` | `Field(pattern=r'^\w+$')` |
| `max_digits`, `decimal_places` | `Decimal` | `Field(max_digits=10, decimal_places=2)` |
| `multiple_of` | `int`, `float` | `Field(multiple_of=5)` |
| `strict` | any | `Field(strict=True)` |
| `frozen` | any | `Field(frozen=True)` |
| `exclude` | any | `Field(exclude=True)` |
| `deprecated` | any | `Field(deprecated='Use X instead')` |

---

## The Annotated Pattern in Depth

```python
from typing import Annotated
from pydantic import BaseModel, Field, AfterValidator

NonEmptyStr = Annotated[str, Field(min_length=1)]
PositiveFloat = Annotated[float, Field(gt=0)]

def normalize_email(v: str) -> str:
    return v.strip().lower()

Email = Annotated[str, Field(pattern=r'.+@.+\..+'), AfterValidator(normalize_email)]

class User(BaseModel):
    name: NonEmptyStr
    price: PositiveFloat
    email: Email
```

---

## Validator Modes Explained

### after — Post-coercion validation (recommended)

```python
from typing import Annotated
from pydantic import AfterValidator, BaseModel

def ensure_https(url: str) -> str:
    if not url.startswith('https://'):
        raise ValueError('URL must use HTTPS')
    return url

class Config(BaseModel):
    webhook_url: Annotated[str, AfterValidator(ensure_https)]
```

### before — Pre-coercion transformation

```python
from typing import Annotated, Any
from pydantic import BaseModel, BeforeValidator

def coerce_to_list(v: Any) -> Any:
    if isinstance(v, str):
        return v.split(',')
    return v

class Params(BaseModel):
    tags: Annotated[list[str], BeforeValidator(coerce_to_list)]

Params(tags='a,b,c')   # -> tags=['a', 'b', 'c']
```

### plain — Replace Pydantic's validation entirely

```python
from typing import Annotated, Any
from pydantic import BaseModel, PlainValidator

def parse_color(v: Any) -> tuple[int, int, int]:
    if isinstance(v, str) and v.startswith('#'):
        h = v.lstrip('#')
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    if isinstance(v, (list, tuple)) and len(v) == 3:
        return tuple(v)
    raise ValueError(f'Cannot parse color: {v!r}')

class Theme(BaseModel):
    primary: Annotated[tuple[int, int, int], PlainValidator(parse_color)]
```

### wrap — Intercept before and after, handle errors

```python
from typing import Any, Annotated
from pydantic import BaseModel, Field, ValidationError, ValidatorFunctionWrapHandler, WrapValidator

def truncate_on_overflow(v: Any, handler: ValidatorFunctionWrapHandler) -> str:
    try:
        return handler(v)
    except ValidationError as exc:
        if any(e['type'] == 'string_too_long' for e in exc.errors()):
            return str(v)[:50]
        raise

class Post(BaseModel):
    summary: Annotated[str, Field(max_length=50), WrapValidator(truncate_on_overflow)]
```

---

## Model Validators

### mode='after' — Cross-field validation

```python
from typing_extensions import Self
from pydantic import BaseModel, model_validator

class BookingRequest(BaseModel):
    check_in: int
    check_out: int

    @model_validator(mode='after')
    def validate_dates(self) -> Self:
        if self.check_out <= self.check_in:
            raise ValueError('check_out must be after check_in')
        return self
```

### mode='before' — Transform raw input

```python
from typing import Any
from pydantic import BaseModel, model_validator

class StrictPayload(BaseModel):
    amount: float

    @model_validator(mode='before')
    @classmethod
    def reject_sensitive_keys(cls, data: Any) -> Any:
        if isinstance(data, dict) and 'card_number' in data:
            raise ValueError('card_number must not be present')
        return data
```

---

## Discriminated Unions

```python
from typing import Annotated, Literal
from pydantic import BaseModel, Field

class TextBlock(BaseModel):
    type: Literal['text']
    content: str

class ImageBlock(BaseModel):
    type: Literal['image']
    url: str
    alt: str = ''

class Page(BaseModel):
    blocks: list[Annotated[
        TextBlock | ImageBlock,
        Field(discriminator='type'),
    ]]
```

---

## Computed Fields

```python
from pydantic import BaseModel, computed_field

class Rectangle(BaseModel):
    width: float
    height: float

    @computed_field
    @property
    def area(self) -> float:
        return self.width * self.height
```
