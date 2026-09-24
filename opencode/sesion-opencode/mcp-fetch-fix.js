#!/usr/bin/env node
// mcp-fetch-fix.js — Proxy stdio para el MCP `mcp-fetch-server`.
//
// Problema: el servidor upstream (zcaceres/fetch v1.1.2) declara la capability
// "resources" en el handshake de initialize pero NO implementa resources/list
// ni resources/templates/list: responde -32601 (Method not found). OpenCode lo
// registra como "failed to get resources" en cada arranque.
//
// Solución: este proxy arranca `npx -y mcp-fetch-server`, reenvía todo el
// protocolo tal cual y elimina únicamente la clave "resources" del mensaje
// initialize. Así OpenCode no consulta resources y desaparece el warning,
// conservando las 6 tools (fetch_html, fetch_markdown, fetch_txt, fetch_json,
// fetch_readable, fetch_youtube_transcript).
//
// Se usa desde la config MCP: command = ["node", ".../mcp-fetch-fix.js"]

const { spawn } = require("node:child_process");

const child = spawn("npx", ["-y", "mcp-fetch-server"], {
  stdio: ["pipe", "pipe", "inherit"],
});

process.stdin.pipe(child.stdin);

let buffer = "";
child.stdout.setEncoding("utf8");
child.stdout.on("data", (chunk) => {
  buffer += chunk;
  let nl;
  while ((nl = buffer.indexOf("\n")) !== -1) {
    const line = buffer.slice(0, nl);
    buffer = buffer.slice(nl + 1);
    let out = line;
    if (line.trim()) {
      try {
        const msg = JSON.parse(line);
        if (msg && msg.result && msg.result.capabilities && "resources" in msg.result.capabilities) {
          delete msg.result.capabilities.resources;
          out = JSON.stringify(msg);
        }
      } catch {
        // Si no es JSON válido, se reenvía sin tocar.
      }
    }
    process.stdout.write(out + "\n");
  }
});

for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(sig, () => child.kill(sig));
}
child.on("exit", (code) => process.exit(code ?? 0));
child.on("error", (err) => {
  process.stderr.write(String(err) + "\n");
  process.exit(1);
});
