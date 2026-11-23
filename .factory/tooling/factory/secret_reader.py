"""Read one named credential from the configured source."""

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Protocol


class SecretReader(Protocol):
    def read_secret(self, name: str, /) -> str | None:
        """Return None for an absent name. Raise OSError if the provider is unavailable."""
        ...


@dataclass(frozen=True)
class EnvironmentSecretReader:
    values: Mapping[str, str] = field(repr=False)

    def read_secret(self, name: str, /) -> str | None:
        return self.values.get(name)
