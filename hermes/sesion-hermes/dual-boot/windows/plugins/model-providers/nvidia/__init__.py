"""Perfil NVIDIA NIM con el catálogo limitado al whitelist de OpenCode.

Equivalente en Hermes del plugin ``nvidia-filter`` de OpenCode: el catálogo vivo
de NVIDIA se filtra con ``providers.nvidia.whitelist`` del perfil de OpenCode
(``opencode.json`` en Linux; ``opencode.jsonc`` en Windows, que es la config activa
allí), así que ``/model`` y los selectores (CLI, TUI, escritorio) solo ofrecen los
modelos que Antonio mantiene operativos.

El whitelist se **relee en cada consulta**: cuando ``check-nvidia-whitelist.sh``
(timer quincenal, días 1 y 16) retira un modelo o añade candidatos, la lista de
Hermes se recompone sola — sin reiniciar y sin tocar ``config.yaml``.

Sin whitelist legible no se filtra (mejor el catálogo completo que un selector
vacío). Los atajos cortos de esos mismos modelos los mantiene
``hermes-nvidia-aliases``.
"""

from __future__ import annotations

import importlib.util
import json
import logging
import re
from pathlib import Path
from typing import Any

from hermes_constants import get_hermes_home
from providers import register_provider
from providers.base import ProviderProfile

logger = logging.getLogger(__name__)

# Perfiles de OpenCode, en orden de búsqueda: manda el primero que traiga whitelist.
# Linux: opencode.json. Windows: opencode.jsonc (config activa, con comentarios JSONC).
_WHITELIST_FILES = (
    "~/.config/opencode/opencode.json",
    "~/.config/opencode/opencode.jsonc",
    "~/.config/opencode/opencode-local.json",
    "~/.config/opencode/opencode-cloud.json",
)

_COMA_FINAL = re.compile(r",(\s*[}\]])")


def _sin_comentarios(texto: str) -> str:
    """JSONC → JSON: fuera comentarios ``//`` y ``/* */`` (respetando las cadenas) y comas finales.

    No vale hacerlo a lo bruto con expresiones regulares: los perfiles llevan URLs
    (``https://…``, ``http://localhost:4001/v1``) y ese ``//`` es parte del dato, no un
    comentario. De ahí el recorrido carácter a carácter.
    """
    trozos: list[str] = []
    i, n = 0, len(texto)
    en_cadena = False
    while i < n:
        ch = texto[i]
        if en_cadena:
            trozos.append(ch)
            if ch == "\\" and i + 1 < n:
                trozos.append(texto[i + 1])
                i += 2
                continue
            if ch == '"':
                en_cadena = False
            i += 1
            continue
        if ch == '"':
            en_cadena = True
            trozos.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and texto[i + 1] == "/":
            i += 2
            while i < n and texto[i] not in "\r\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and texto[i + 1] == "*":
            i += 2
            while i + 1 < n and not (texto[i] == "*" and texto[i + 1] == "/"):
                i += 1
            i += 2
            continue
        trozos.append(ch)
        i += 1
    return _COMA_FINAL.sub(r"\1", "".join(trozos))


def _leer_perfil(ruta: Path) -> dict[str, Any] | None:
    """Lee un perfil de OpenCode tolerando JSONC (comentarios y comas finales)."""
    try:
        texto = ruta.read_text(encoding="utf-8-sig")
    except OSError:
        return None
    for candidato in (texto, _sin_comentarios(texto)):
        try:
            data = json.loads(candidato)
        except ValueError:
            continue
        if isinstance(data, dict):
            return data
    return None


def nvidia_whitelist() -> list[str]:
    """Ids NVIDIA (con su organización) del whitelist de OpenCode; ``[]`` si no hay."""
    for raw in _WHITELIST_FILES:
        data = _leer_perfil(Path(raw).expanduser())
        if data is None:
            continue
        for key in ("providers", "provider"):  # V2 `providers`, V1 `provider`
            block = data.get(key)
            if not isinstance(block, dict):
                continue
            nvidia = block.get("nvidia")
            if not isinstance(nvidia, dict):
                continue
            ids = nvidia.get("whitelist")
            if isinstance(ids, list):
                clean = [str(item).strip() for item in ids if str(item).strip()]
                if clean:
                    return clean
    return []


def _sync_static_catalog(allowed: list[str]) -> None:
    """Alinea el catálogo curado del repo con el whitelist.

    ``merge_profile_catalog()`` da prioridad a ``_PROVIDER_MODELS['nvidia']`` sobre
    ``fallback_models``, y la lista curada del repo incluye modelos NVIDIA ya retirados
    (glm-5.3, kimi-k2.6, minimax-m3, glm-5.2): sin esto el selector los seguiría ofreciendo
    aunque ``fetch_models()`` los filtre. Con el whitelist ilegible no se toca (mejor la
    lista del repo que una vacía).
    """
    if not allowed:
        return
    try:
        from hermes_cli import models as _models
    except Exception as exc:  # pragma: no cover - defensivo
        logger.debug("nvidia: no pude importar el catálogo de modelos (%s)", exc)
        return
    static = getattr(_models, "_PROVIDER_MODELS", None)
    try:
        if isinstance(static, dict) and static.get("nvidia") != list(allowed):
            static["nvidia"] = list(allowed)
    except Exception as exc:  # pragma: no cover - renombrado aguas arriba: no rompe, no filtra
        logger.debug("nvidia: no pude alinear el catálogo curado (%s)", exc)


def _bundled_profile() -> ProviderProfile | None:
    """Perfil nvidia de serie, para heredar su trato de mensajes ``tool``.

    NVIDIA NIM rechaza los campos ``name``/``tool_name`` en mensajes de herramienta
    y el perfil de serie los limpia; se hereda en vez de reimplementarlo.
    """
    path = (
        get_hermes_home()
        / "hermes-agent"
        / "plugins"
        / "model-providers"
        / "nvidia"
        / "__init__.py"
    )
    if not path.is_file():
        return None
    try:
        spec = importlib.util.spec_from_file_location("_hermes_bundled_nvidia", path)
        if spec is None or spec.loader is None:
            return None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)  # vuelve a registrar el de serie; el nuestro gana
        profile = getattr(module, "nvidia", None)
    except Exception as exc:  # pragma: no cover - defensivo ante cambios de layout
        logger.warning("nvidia: no pude cargar el perfil de serie (%s)", exc)
        return None
    return profile if isinstance(profile, ProviderProfile) else None


_BUNDLED = _bundled_profile()
_Base = type(_BUNDLED) if _BUNDLED is not None else ProviderProfile


class NvidiaWhitelistProfile(_Base):
    """NVIDIA NIM cuyo catálogo son los modelos del whitelist de OpenCode."""

    if _BUNDLED is None:  # copia del comportamiento de serie, solo si no se pudo heredar
        @staticmethod
        def _needs_strip(msg: Any) -> bool:
            return isinstance(msg, dict) and msg.get("role") == "tool" and (
                "name" in msg or "tool_name" in msg
            )

        def prepare_messages(self, messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
            if not any(self._needs_strip(msg) for msg in messages):
                return messages
            return [
                {k: v for k, v in msg.items() if k not in ("name", "tool_name")}
                if self._needs_strip(msg)
                else msg
                for msg in messages
            ]

    def fetch_models(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: float = 8.0,
    ) -> list[str] | None:
        allowed = nvidia_whitelist()
        _sync_static_catalog(allowed)
        models = super().fetch_models(api_key=api_key, base_url=base_url, timeout=timeout)
        if not models or not allowed:
            return models
        keep = set(allowed)
        filtered = [model for model in models if model in keep]
        logger.debug(
            "nvidia: catálogo de %s modelos → %s del whitelist (%s ocultos)",
            len(models),
            len(filtered),
            len(models) - len(filtered),
        )
        return filtered


def _kwargs() -> dict[str, Any]:
    """Identidad y endpoint iguales que el perfil de serie (o sus valores por defecto)."""
    source = _BUNDLED
    whitelist = nvidia_whitelist()
    fallback = tuple(whitelist) or tuple(
        getattr(source, "fallback_models", ()) or () if source is not None else ()
    )
    return {
        "name": "nvidia",
        "aliases": tuple(
            getattr(source, "aliases", ()) or ("nvidia-nim", "nim", "build-nvidia", "nemotron")
        ),
        "env_vars": tuple(getattr(source, "env_vars", ()) or ("NVIDIA_API_KEY",)),
        "display_name": getattr(source, "display_name", "") or "NVIDIA NIM",
        "description": getattr(source, "description", "") or "NVIDIA NIM — accelerated inference",
        "signup_url": getattr(source, "signup_url", "") or "https://build.nvidia.com/",
        "base_url": getattr(source, "base_url", "") or "https://integrate.api.nvidia.com/v1",
        "default_max_tokens": getattr(source, "default_max_tokens", None) or 16384,
        "fallback_models": fallback,
    }


register_provider(NvidiaWhitelistProfile(**_kwargs()))

# Aunque nadie consulte el catálogo en vivo (por ejemplo, una lectura servida desde
# provider_models_cache.json), el curado del repo no debe seguir ofreciendo retirados.
_sync_static_catalog(nvidia_whitelist())
