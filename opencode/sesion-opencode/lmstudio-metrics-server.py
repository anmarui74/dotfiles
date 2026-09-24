#!/usr/bin/env python3
"""Dashboard de métricas LM Studio (tokens/s).
Sirve en http://localhost:4200 una página HTML que lee metrics.json
(escrito por lmstudio-proxy.py) y muestra velocidad, tokens e histórico.
"""
import json
import os
import sys
import time
import http.server

CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4200
METRICS_PATH = os.environ.get("METRICS_EXPORT_PATH") or os.path.join(CONFIG_DIR, "data", "metrics.json")

PAGE = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LM Studio · Tokens/s</title>
<style>
:root{--bg:#0f1115;--card:#171a21;--border:#262b36;--text:#e6e8ee;--muted:#9aa3b2;
--accent:#4cc2ff;--green:#3ecf8e;--yellow:#f5c542;--red:#f2645f;--mono:"JetBrains Mono","Fira Code",monospace}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);
font-family:-apple-system,"Segoe UI",system-ui,sans-serif;padding:24px}
h1{font-size:18px;margin:0 0 4px}h2{font-size:13px;color:var(--muted);font-weight:600;
text-transform:uppercase;letter-spacing:.05em;margin:0 0 12px}
.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px}
.card .label{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;margin-bottom:8px}
.card .value{font-family:var(--mono);font-size:28px;font-weight:700}
.big{color:var(--accent)}.ok{color:var(--green)}.warn{color:var(--yellow)}.bad{color:var(--red)}
table{width:100%;border-collapse:collapse;font-family:var(--mono);font-size:12px;margin-top:14px}
th{color:var(--muted);text-align:left;padding:6px 10px;border-bottom:1px solid var(--border);
text-transform:uppercase;font-size:10px;letter-spacing:.05em}
td{padding:6px 10px;border-bottom:1px solid var(--border)}
tr:hover td{background:#1b1f28}
.section{margin-top:28px}.refresh{color:var(--muted);font-size:12px;margin-top:8px}
@media(max-width:600px){body{padding:14px}}
</style>
</head>
<body>
<header><h1>⚡ LM Studio · Tokens por segundo</h1><div class="muted" id="updated">cargando…</div></header>
<section class="grid" style="margin-top:16px">
  <div class="card"><div class="label">Última velocidad</div><div class="value big" id="last-tps">–</div></div>
  <div class="card"><div class="label">Media (histórico)</div><div class="value ok" id="avg-tps">–</div></div>
  <div class="card"><div class="label">Peticiones</div><div class="value" id="count">–</div></div>
  <div class="card"><div class="label">Tokens generados</div><div class="value" id="tokens-out">–</div></div>
</section>
<section class="section"><h2>Últimas peticiones</h2>
<div class="card" style="padding:4px 16px">
  <table>
    <thead><tr><th>Hora</th><th>Modelo</th><th>Tipo</th><th>Tok/s</th><th>Salida</th><th>Entrada</th><th>Tiempo</th></tr></thead>
    <tbody id="rows"><tr><td colspan="7" class="muted">Sin datos todavía</td></tr></tbody>
  </table>
</div>
</section>
<div class="refresh">Auto-refresco cada 5 s · <a href="/api/metrics" target="_blank">JSON crudo</a></div>
<script>
async function load(){
  try{
    const r=await fetch("/api/metrics");
    if(!r.ok) throw new Error(r.status);
    const d=await r.json();
    const recs=d.records||[];
    document.getElementById("updated").textContent="actualizado: "+d.updated_at;
    document.getElementById("count").textContent=d.count??recs.length;
    if(recs.length){
      const last=recs[recs.length-1];
      const tps=last.tokens_per_second;
      const el=document.getElementById("last-tps");
      el.textContent=(tps==null?"–":tps.toFixed(1));
      el.className="value "+(tps>=30?"big":tps>=10?"ok":tps>0?"warn":"bad");
      let sum=0,n=0;
      for(const r of recs){if(r.tokens_per_second){sum+=r.tokens_per_second;n++}}
      document.getElementById("avg-tps").textContent=n?(sum/n).toFixed(1):"–";
      const tot=recs.reduce((a,r)=>a+(r.completion_tokens||0),0);
      document.getElementById("tokens-out").textContent=tot>=1000?(tot/1000).toFixed(1)+"k":tot;
      const rows=document.getElementById("rows");
      rows.innerHTML="";
      for(const r of recs.slice(-15).reverse()){
        const tr=document.createElement("tr");
        tr.innerHTML=`<td>${r.time||""}</td><td>${escapeHtml(r.model||"")}</td>
          <td>${r.stream?"stream":"normal"}</td>
          <td class="${r.tokens_per_second>=30?"ok":r.tokens_per_second>=10?"":"warn"}">${(r.tokens_per_second??"–")}</td>
          <td>${r.completion_tokens||0}</td><td>${r.prompt_tokens||0}</td>
          <td>${r.elapsed_s!=null?r.elapsed_s.toFixed(1)+"s":""}</td>`;
        rows.appendChild(tr);
      }
    }
  }catch(e){document.getElementById("updated").textContent="sin datos de métricas";}
}
function escapeHtml(s){return String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]))}
load();setInterval(load,5000);
</script>
</body>
</html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/metrics":
            try:
                with open(METRICS_PATH) as f:
                    data = json.load(f)
            except (OSError, ValueError):
                data = {"updated_at": time.strftime("%d/%m/%Y %H:%M:%S"), "count": 0, "records": []}
            body = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
