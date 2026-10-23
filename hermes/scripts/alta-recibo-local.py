"""Alta del recibo local que falta a una conversacion local importada del otro sistema.

Uso: alta-recibo-local.py <ruta state.db> <session_id>
Requisito: la sesion debe existir en `sessions` con su session_key/chat_id/origin_json
(asi llega por el trasvase). El identificador local-<sha256> no se puede recalcular aqui
porque se acuño con el perfil y el principal del otro sistema, asi que el recibo se da de
alta con `legacy_session_id` + la fila `gateway.local_legacy.v1:` que exige el gateway.
"""
import sys, json, sqlite3, datetime, copy, uuid

REPO = '/home/antonio/.hermes/hermes-agent'
sys.path.insert(0, REPO)
DB = sys.argv[1]
SID = sys.argv[2] if len(sys.argv) > 2 else (
    'local-99ecd8ee06b52baace2d0cbc16442e9da678897c545e581cd4f86d5f30e2f98d')
TEMPLATE = 'gateway.local_policy.v1:local-fa682800326d5695c5f585b22857128f4be5f1a4e3382af232da9c088786e5ca'
POLICY_PREFIX = 'gateway.local_policy.v1:'
LEGACY_PREFIX = 'gateway.local_legacy.v1:'

con = sqlite3.connect(DB, timeout=10)
con.row_factory = sqlite3.Row
row = dict(con.execute('SELECT * FROM sessions WHERE id=?', (SID,)).fetchone())
tmpl = json.loads(con.execute('SELECT value FROM state_meta WHERE key=?', (TEMPLATE,)).fetchone()[0])

rec = copy.deepcopy(tmpl)
rec['session_id'] = SID
rec['legacy_session_id'] = SID
rec['route'] = 'agent:main:local:dm:' + SID
rec['principal_id'] = row['user_id']
rec['request_id'] = str(uuid.uuid4())
rec['lineage'] = [SID]
entry = rec['entry']
entry['session_id'] = SID
entry['session_key'] = row['session_key']
entry['origin'] = json.loads(row['origin_json'])
entry['chat_type'] = 'dm'
entry['platform'] = 'local'
created = datetime.datetime.fromtimestamp(row['started_at']).isoformat()
entry['created_at'] = created
entry['updated_at'] = created

legacy = {k: rec[k] for k in ('session_id', 'profile_id', 'principal_id', 'legacy_session_id')}

with con:  # una sola transaccion
    con.execute('INSERT OR REPLACE INTO state_meta(key,value) VALUES(?,?)',
                (POLICY_PREFIX + SID, json.dumps(rec, ensure_ascii=False)))
    con.execute('INSERT OR REPLACE INTO state_meta(key,value) VALUES(?,?)',
                (LEGACY_PREFIX + SID, json.dumps(legacy, ensure_ascii=False)))

print('escrito en', DB)
print('  ', POLICY_PREFIX + SID)
print('  ', LEGACY_PREFIX + SID)
con.close()

# --- verificacion con el codigo real del gateway ---
from gateway.session import SessionEntry, SessionSource
from gateway.config import Platform
from gateway.session_policy import restore_policy
from hermes_state_local_lineage import validate_local_lineage
from hermes_state_local import local_receipt

con = sqlite3.connect(DB, timeout=10)
con.row_factory = sqlite3.Row


class FakeDb:
    def _read_ctx(self):
        import contextlib
        return contextlib.nullcontext(con)


stored = local_receipt(FakeDb(), SID)
print('recibo leido:', stored['session_id'][:22] + '...', 'legacy=', stored['legacy_session_id'][:22] + '...')
e = SessionEntry.from_dict(stored['entry'])
src = SessionSource(platform=Platform.LOCAL, chat_id=SID, user_id=stored['principal_id'], chat_type='dm')
assert e.origin.to_dict() == src.to_dict(), 'origin no coincide'
assert stored['route'] == e.session_key == row['session_key'], 'ruta no coincide'
pol = restore_policy(stored['policy'])
validate_local_lineage(con, stored)
print('policy:', pol.source, pol.platform, pol.cwd, pol.model)
print('OK: recibo valido y reanudable (todas las comprobaciones del gateway pasan)')
