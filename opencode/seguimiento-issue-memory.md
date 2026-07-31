# Seguimiento: Issue MCP memory - outputSchema draft-07

## Issue
- URL: https://github.com/anomalyco/opencode/issues/39908
- Título: [MCP] memory server tools fail to load: outputSchema uses JSON Schema draft-07, validator only supports 2020-12
- Repo: anomalyco/opencode
- Reportado por: anmarui74 (Antonio)
- Fecha creación: 31/07/2026

## Problema
Las herramientas del servidor MCP memory (`@modelcontextprotocol/server-memory`)
no cargan en OpenCode 1.18.8:

```
Tool 'search_nodes' has an invalid outputSchema: JSON Schema declares an unsupported
dialect ("$schema": "http://json-schema.org/draft-07/schema#"). The default validator
supports JSON Schema 2020-12 only; pass a pre-configured Ajv instance to AjvJs
```

Causa: el servidor genera esquemas con draft-07 (zod-to-json-schema por defecto)
y OpenCode solo valida 2020-12. El SDK oficial de MCP ya tiene el fix.

## Estado
- [ ] Creado (31/07/2026)
- [ ] Respuesta de mantenedores
- [ ] Arreglado
- [ ] Verificado tras arreglo
