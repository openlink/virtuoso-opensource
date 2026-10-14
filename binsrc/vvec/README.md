# VVec — Virtuoso Vector Index Console

A self-contained **Virtuoso Server Pages (VSP)** dashboard for managing the
native vector-index feature visually. It runs entirely inside Virtuoso (no
React, no build step, no external JS/CSS) and is served from a **WebDAV**
collection.

With VVec you can:

- **Browse** every vector index on the instance — relational (SQL) and RDF
  (SPARQL) — with model, dimensions, metric and state at a glance.
- **Create** a vector index on the **SQL side** (`CREATE VECTOR INDEX … ON
  table(col)`) or the **SPARQL side** (`sparql create vector index …`, shorthand
  or general selector), including Matryoshka `reduce=truncate`.
- **Search by meaning** — type natural-language text, tick one or more indexes
  in the picker (*Select all* covers the surface in one click), and get the
  nearest matches ranked by similarity score (`X_SIMILAR` / `VECTOR_DISTANCE`
  for SQL, `bif:vector_search` for SPARQL). Several indexes produce **one merged
  ranking**, not a section per index.
- **Refresh / drop** indexes from the dashboard, or **edit** one: change any
  part of its definition and save, which drops and recreates the index so the
  new definition is rebuilt from the source data.
- **Manage namespace prefixes** — list, add, rebind and remove the instance's
  persistent SPARQL/XML prefixes (`DB.DBA.SYS_XML_PERSISTENT_NS_DECL`), the same
  set the built-in SPARQL query editor lists. The graph and predicate fields on
  the Create and Edit pages accept a **prefixed name** (`schema:name`) as well as
  a full IRI, expanded from this set.
- **Pick a target** without typing IRIs — the Graph IRI field has a *Search
  graphs* picker that lists the instance's named graphs and searches them
  server-side, and the Predicate IRI field has a *List predicates* picker that
  lists the predicates **in that graph** whose objects are string literals, each
  shown as its prefixed name (`schema:name`) with the full IRI beneath it.
- **Manage embedding models** — inspect `DB.DBA.ONNX_MODELS`, register HTTP
  providers (OpenAI / Ollama / LM Studio / OpenAI-compatible) with their API key
  in the same step, **edit** a registered provider in place, reload local ONNX
  models, and test-embed a string.
- **Manage API keys** — a dedicated page lists every provider key: whether a
  value is set, which models reference it, and store / replace / delete for
  each. Nothing about a stored value is read back — not even its length.
- **Run maintenance** — view queue depth and worker state for both surfaces,
  drain queues, start/stop/configure the background workers, and suspend/resume
  the SPARQL queue.

## Layout

VVec ships as a **VAD package** (`vvec_dav.vad`), built like the other
bundled Virtuoso web consoles. The source tree:

| Path | Role |
|------|------|
| `vvec_sticker.xml` | VAD manifest: declares the DAV resources and the install/uninstall SQL hooks. |
| `Makefile.am` | Builds `vvec_dav.vad` with `vadpacker.py`; `EXTRA_DIST` ships the sources. |
| `vad_version` | Package version. |
| `sql/vvec_install.sql` | Install SQL: defines the `DB.DBA.VVEC_*` helper procedures, rebuilds the inline-CSS emitter from the uploaded stylesheet, and maps the `/vvec/` virtual directory. Reads no files from disk. |
| `vsp/index.vsp`   | Overview: stat cards, each linking through to the page that acts on it. |
| `vsp/indexes.vsp` | Manage Indexes: the combined SQL/SPARQL index catalogue and every per-index action. |
| `vsp/create.vsp`  | Create-index form (SQL / SPARQL, Simple / Custom selector; stored as `shorthand` / `general`). |
| `vsp/edit.vsp`    | Edit an existing index: drop + recreate from the edited definition, with restore-on-failure. |
| `vsp/apikeys.vsp` | API-key manager: which provider keys exist, which models use them, store / replace / delete. |
| `vsp/prefixes.vsp`| Namespace-prefix manager (list / add / rebind / remove persistent prefixes). |
| `vsp/labels.vsp`  | Label-property manager: which properties name an entity, kept as the `vvec-labels` inference rule set. |
| `vsp/permissions.vsp` | Permissions: who, beyond a DBA account, holds SQL `EXECUTE` on `DB.DBA.VEC_INDEX_SET_METADATA` and may therefore name and describe the indexes they own. |
| `vsp/search.vsp`  | Similarity-search UI and results. |
| `vsp/models.vsp`  | Embedding-model registry: list, register HTTP provider, store API key, reload, test-embed. |
| `vsp/maintenance.vsp` | SQL + SPARQL queue/worker panels (drain, start/stop/configure, suspend/resume). |
| `vsp/action.vsp`  | POST handler for drop / refresh, then redirects back. |
| `vsp/login.vsp`   | Sign in: the challenge form that opens a session. The only page reachable while signed out. |
| `vsp/logout.vsp`  | Sign out: deletes the session row and expires the cookie. |
| `vsp/ping.vsp`    | Heartbeat endpoint. An open page calls it every 30s; when the calls stop, the session expires. |
| `vsp/graphs.vsp`  | Named-graph lookup (JSON) behind the Graph IRI field's *Search graphs* picker. |
| `vsp/predicates.vsp` | Per-graph predicate lookup (JSON) behind the Predicate IRI field's *List predicates* picker. |
| `css/vvec.css` | Stylesheet: the design tokens and every rule, inlined into each page at deploy time. |
| `test/session_flow.sh` | End-to-end check of the sign-in session: challenge, cookie, CSRF, sign-out, the expiry windows and the IP pin. Run it against any instance with the VAD installed. |

## Prerequisites

- Virtuoso Open Source with the native vector index, the `vonnx` plugin loaded,
  and at least one model registered in `DB.DBA.ONNX_MODELS` (the bundled
  `granite-384-local` is auto-provisioned).

No `DirsAllowed` change is needed: the VAD engine uploads the pages into WebDAV
and the install SQL reads them from there, not from the filesystem.

## Build

The VAD is built when the tree is configured with VAD packages enabled:

```bash
./configure --enable-vvec-vad   # or --with-all-vad
make
```

This produces `binsrc/vvec/vvec_dav.vad`; `make install` places it under
the server's VAD directory (`$datadir/virtuoso/vad`) with the other packages.

## Install

Install it like any Virtuoso VAD — from the Conductor's *System Admin → Packages*
tab, or from **dba** iSQL:

```sql
vad_install ('<path>/vvec_dav.vad', 0);
```

The installer uploads the pages into `/DAV/VAD/vvec/`, runs the install SQL
(no filesystem access, no DAV password), creates the session store
`DB.DBA.VVEC_SESSION`, and maps `/vvec/` behind the DBA-only session guard.
Then open the console and sign in with a **DBA** account:

```
http://<host>:<port>/vvec/
```

## Upgrade / re-run

Re-installing the VAD (or re-loading `sql/vvec_install.sql`) is idempotent: the
helper procedures are redefined and the virtual-directory mapping is removed and
re-defined. To deploy **without** authentication on a trusted localhost instance,
re-map the vhost after install without the `auth_fn`/`sec` arguments (or edit the
`VHOST_DEFINE` call in `sql/vvec_install.sql`).

## How it works

- The pages execute in-process as stored procedures under the `/vvec/`
  virtual directory, mapped to the DAV collection with `vsp_user => 'dba'`.
- All chrome lives in the **sidebar** — navigation, and at its foot the signed-in
  account (`connection_get ('SPARQLUserId')`) with a menu whose one action is
  **Sign out**. There is no top bar.
- Shared chrome (sidebar, top bar), index enumeration, target discovery, and
  input validation live in `DB.DBA.VVEC_*` procedures installed by
  `sql/vvec_install.sql`, keeping the pages thin.
- **SQL indexes** are discovered by scanning `DB.DBA.SYS_KEYS` for keys whose
  `KEY_OPTIONS` carry the vector markers (`sc`, `pk`, `mid`). **SPARQL indexes**
  come from `DB.DBA.SPARQL_VEC_INDEX`.
- **Prefixed names** typed into a Graph IRI / Predicate IRI field are expanded
  against `SYS_XML_PERSISTENT_NS_DECL` by `VVEC_EXPAND_QNAME` *before* the DDL
  is built. This is not cosmetic: those values are written into the statement
  inside angle brackets, and `<schema:name>` is not a qname to SPARQL — it is an
  absolute IRI whose scheme happens to be `schema`, so the index would be
  created, go `active`, and silently match nothing. Expanding first also stores
  the real IRI in `SVI_SELECTOR_GRAPH` / `SVI_SELECTOR_PRED`, which is what
  refresh, search and the async triggers compare against. A value is left exactly
  as typed unless it really is a declared prefixed name (a full IRI, a `urn:`, or
  an undeclared prefix all pass through untouched).
- **Listing named graphs** goes through `DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS`,
  which walks the `G` index only — a skip-scan over distinct graph ids, plus the
  explicitly created empty graphs — so its cost tracks the number of *graphs*,
  not the number of quads. It is also what the SPARQL compiler rewrites
  `select distinct ?g where { graph ?g { ?s ?p ?o } }` into, so calling it
  directly saves a SPARQL compilation per keystroke. Note that adding a `FILTER`
  inside that group **defeats** the rewrite — the plan reverts to a full
  `RDF_QUAD` scan with a `DISTINCT` on top — which is why the substring search is
  applied in PL rather than in the query.
- **Listing a graph's predicates** offers only those with **string** objects —
  a plain literal, an `xsd:string`, or a language-tagged one — because those are
  what a shorthand index can embed; `isLiteral()` alone would also return the
  numeric and dateTime predicates. There is no `(G, P)` index on `RDF_QUAD` (the
  keys are `PSOG`, `POGS`, `SP`, `OP`, `GS`), so an exact answer has to look at
  the graph's quads; the query bounds that scan with an inner `LIMIT` so a very
  large graph cannot hang the picker, and the list is fetched once per open and
  filtered client-side rather than re-scanning per keystroke. Each predicate is
  paired with its prefixed-name form (`VVEC_QNAME_OF` against the longest
  matching namespace in `SYS_XML_PERSISTENT_NS_DECL`, built once per request by
  `VVEC_NS_MAP`); the filter matches either spelling, and clicking a row
  inserts the full IRI.
- **Nothing is searched by default.** A search with no index ticked is refused
  rather than quietly widened to the whole instance; *Select all* in the picker
  is how you cover a surface, so the scope is always something that was chosen.
  The page does open on whichever surface actually has indexes.
- **Searching several indexes at once** queries each for its own top *k*
  (`VVEC_SEARCH_ONE`) and then keeps the best *k* of everything returned
  (`VVEC_TOP_HITS`, a partial selection sort — *k* passes over the merged
  set). An index that fails is reported on its own without losing the results
  from the others. The surface control in the picker is what keeps a search on
  one surface; the page also refuses a hand-built URL that mixes `sql:` and
  `sparql:` entries rather than silently searching half of it. Selections travel
  as a `|`-joined `idx` parameter — `|` is safe as a separator because
  `VVEC_IRI_OK` rejects it inside an IRI.
- **Ordering a cross-model merge.** Raw cosine is not calibrated between models,
  so a merged ranking by score favours whichever model scores high by default.
  Measured on the same eight rows on one instance: `all-MiniLM-L6` scores a
  nonsense query at **0.47–0.53** and `text-embedding-3-small` scores the same
  query at **0.56–0.61** — the second model's *noise floor* sits above the first
  model's *mid-range*. So the results are ordered by each hit's **rank within
  its own index** when the chosen indexes do not all share a model and metric,
  and by raw score when they do; the *Order by* control on the results card
  flips between the two client-side, and every row shows its index, model and
  rank so the difference is inspectable. Filter chips narrow the ranking to
  particular indexes without re-running the search.
- **An empty index is reported, not hidden.** After the first backfill the Create
  and Edit pages count the rows the selector produced
  (`VVEC_SPARQL_INDEX_ROWS`) and show the count on success — or an amber
  warning when it is zero, which is otherwise indistinguishable from a healthy
  `active` index until every search comes back empty.
- **Editing** an index is a drop + create: a vector index definition is immutable
  in the engine, so `edit.vsp` reads the current definition back out of the
  catalog (`VVEC_SQL_INDEX_FULL` / `VVEC_SPARQL_INDEX_FULL`), builds the DDL
  for both the edited *and* the original definition (`VVEC_SQL_VEC_DDL` /
  `VVEC_SPARQL_VEC_DDL`), drops the index, and creates it again. If the edited
  definition fails to create after the drop has gone through, the original DDL is
  replayed so the instance is not left without the index, and the page says so.
  Properties the form does not expose — a general selector's captured `PREFIX`
  preamble, `source_kind = 'vector'`, and an index's **Name** and
  **Description** — are carried through from the catalog into the regenerated
  DDL, restore replay included, because an option this builder does not carry
  is one a failed edit drops on the floor.
- **Name and description are edited without a rebuild.** They describe the index
  rather than define it, so `edit.vsp` gives them their own card, their own
  Save and their own `do=meta` handler, which calls
  `DB.DBA.VEC_INDEX_SET_METADATA` — two catalogue columns, no DROP, no refresh,
  no window in which searches fail. Making a label a field of the definition
  form would have meant re-embedding a corpus to fix a typo.

## Design

The console is drawn as the instrument's own printout rather than an
application skin — ruled, annotated, measured — on three rules that the
stylesheet header states in full:

1. **Colour is spent only where it carries data.** State (`ready` / `creating` /
   `error`) and measured quantities get colour; navigation, panels, buttons and
   headings are ink on paper. If something is coloured, the colour *is* the
   information.
2. **One family, monospaced, throughout.** A vector index is described in
   identifiers, dimensions, metrics and DDL. Tabular figures keep every column
   of numbers aligned, and the executed statement is set in the same face as
   everything else because it is not an afterthought.
3. **Size and spacing are fluid, not stepped.** Type and gutters interpolate
   with `clamp()`, and the grids use `auto-fit`/`minmax`, so the layout adapts
   continuously. One breakpoint survives, for the one thing that cannot
   interpolate: below `46rem` the sidebar stops being a column and becomes a
   band above the content.

Motion is reserved for waits that are real. Creating or rebuilding an index
embeds every source row, so those forms carry `data-working` and report what
they are doing while they do it (`VVEC_WORK_JS`). Similarity search
deliberately gets none: it is fast, the answer is the feedback, and an
indicator on a sub-second action only makes it feel slower. Everything is
disabled under `prefers-reduced-motion`.

Two structural details worth knowing before editing the CSS: a catalogue row is
one line per record (cells do not wrap — the table scrolls inside
`.table-wrap`, and long identifiers clip to `.truncate` with the full value on
the cell's `title`), and the action column is `position: sticky` against the
right edge so a record's controls never scroll away from it.

## Security notes

- **The Permissions page administers one grant and says what it means.** SQL
  `EXECUTE` on `DB.DBA.VEC_INDEX_SET_METADATA` lets a non-DBA account set the
  Name and Description of the indexes *it created* — the procedure's own
  owner-or-DBA check is the second gate, and the page states that rule rather
  than leaving the reader to infer it. A fresh install grants it to no one. DBA
  accounts are listed as permanently allowed with no Revoke button, because
  they hold the right by being DBA. The grant list is read from
  `DB.DBA.SYS_GRANTS`, so a grant made from `isql` — to an SQL role or to
  `PUBLIC` included — shows there too, and the account to grant is picked from a
  `<select>`, never typed: `nobody` is a real account, so a typo can land
  somewhere much worse than nowhere.
- This is a **DBA tool**: the pages run with `vsp_user => 'dba'`. `/vvec/` is
  guarded by `auth_fn => 'DB.DBA.VVEC_AUTH'`, which validates a **server-side
  session** and authorizes **DBA accounts only** — a valid but non-DBA sign-in
  is refused. Do not grant application users execute rights on the
  `VEC_INDEX_*` management procedures.
- **Signing in** does not put the password on the wire. Each render of
  `login.vsp` mints a single-use nonce; the browser submits
  `MD5(nonce || password)` and blanks the field it typed into; the server
  recomputes the digest from the stored credential and redeems the nonce, which
  is deleted on use so a captured sign-in POST cannot be replayed. This is the
  same challenge the Virtuoso Conductor uses
  (`binsrc/conductor/adm_login.vspx` with `y_sql_user_password_check`). With
  JavaScript off the form can only submit the password in clear, which is
  accepted over **HTTPS only**.
- **The session** is a row in `DB.DBA.VVEC_SESSION`, addressed by a cookie that
  is `HttpOnly`, `SameSite=Strict`, `Secure` over HTTPS, and carries no
  `Expires` (so the browser drops it on exit). It is pinned to the client IP,
  and three windows must all hold for it to stay valid:

  | window | default | meaning |
  |---|---|---|
  | `VVEC_SES_BEAT_S` | 150 s | the page is still open (heartbeat) |
  | `VVEC_SES_IDLE_MIN` | 30 min | somebody is still using it (page requests only) |
  | `VVEC_SES_MAX_H` | 12 h | absolute cap |

  Each is a one-line function in the install SQL, so an operator can redefine
  one without touching the procedures that read it.
- **Closing the page signs you out.** Every open console page calls `ping.vsp`
  every 30 seconds; the session dies once the beats stop for `VVEC_SES_BEAT_S`
  — tab closed, browser quit, machine asleep, network gone. HTTP has no close
  event, and a `pagehide` beacon cannot do this job here because the console
  navigates page to page, so it would fire on every link click and never fire
  at all on a crash. Only a heartbeat covers every way a page can stop
  existing. A heartbeat advances the page-open clock but deliberately **not**
  the idle clock, so a forgotten open tab still times out.
- **Signing out really ends the session**: `logout.vsp` deletes the row, so the
  id the browser still holds matches nothing. This is the practical difference
  from the HTTP Digest authentication the console used previously — digest keeps
  no server-side state, so nothing could be revoked, and a sign-in survived even
  deleting and rebuilding the database, because the only check was
  `MD5(user:realm:password)` recomputed per request against whatever credential
  the fresh database happened to have.
- The session is not encrypted in transit — put the instance behind **HTTPS**
  for any non-localhost use. To run without auth on a trusted localhost
  instance, re-map the vhost after install without the `auth_fn` argument.
- All user-influenced HTML is emitted through `http_value()` / `<?= ?>`, and all
  URL parameters through `http_url()` / `<?/ ?>`. That covers indexed *content*
  too: a document whose text contains `<script>` renders escaped.
- **Values read back out of the catalog are re-checked before they are
  re-emitted.** The Create and Edit pages gate what a user types, but an index
  can also be created from `isql` or its catalogue row edited by hand, so the
  read paths that interpolate stored values into a statement — the similarity
  search, and the Edit page's restore-on-failure replay — re-validate the graph
  and predicate IRIs, the key/embedding variable names, the `WHERE` pattern, the
  dataset clause and the `PREFIX` preamble, and refuse rather than interpolate
  something they cannot reproduce verbatim. Every index created through the
  console passes by construction.
- Identifiers used in DDL are validated before being placed in a statement:
  table/column/model must exist in the catalog; index names and IRIs pass strict
  character checks (`VVEC_IDENT_OK` / `VVEC_IRI_OK`); `distance` / `reduce`
  / `maintenance` are allow-listed; the model name is escaped for the target
  context (SQL literal in the SQL branch, SPARQL literal in the SPARQL branch).
  Query text is bound as a parameter (SQL) or escaped into the SPARQL string
  literal. Model management and maintenance actions call the documented
  `DB.DBA.ONNX_*` / `VEC_*` procedures directly with bound arguments — no SQL is
  string-built from those inputs.
- The one free-form input is the **general-selector `WHERE` pattern** on the
  Create and Edit pages, which is SPARQL syntax and cannot be a bound parameter, so it is
  interpolated into the `CREATE VECTOR INDEX … WHERE { … }` DDL. It is
  structurally validated first by `DB.DBA.VVEC_SPARQL_PATTERN_OK` — balanced
  `{ }` that never go negative (so the pattern cannot close the group and append
  statements), no `#` comments or control characters, balanced string/IRI
  delimiters, and none of the update/DDL keywords (`INSERT`/`DELETE`/`LOAD`/
  `CLEAR`/`DROP`/`CREATE`/`COPY`/`MOVE`/`ADD`/`WITH`/`USING`) or `define` pragmas.
  This is not a full SPARQL parser; it is a structural gate. The page is DBA-only
  regardless, and a DBA can already run arbitrary SPARQL, so the residual risk of
  a crafted pattern is low — the gate exists so that the general selector is not
  a lever for turning a lesser flaw (e.g. a CSRF gap) into arbitrary DDL.
  The Edit page carries two more catalog-sourced fragments into the regenerated
  DDL, and gates both the same way: a general selector's **dataset clause**
  (`VVEC_DATASET_OK` — only `FROM <iri>` / `FROM NAMED <iri>` terms) and its
  stored **`PREFIX` preamble** (`VVEC_PREFIX_PREAMBLE_OK` — only
  `PREFIX name: <iri>` declarations). An index whose stored preamble does not
  pass cannot be edited from the console at all.
- **Namespace prefixes** are written with the documented
  `DB.DBA.XML_SET_NS_DECL` / `XML_REMOVE_NS_BY_PREFIX` procedures with bound
  arguments; the prefix name and namespace IRI are validated first
  (`VVEC_PREFIX_OK` / `VVEC_IRI_OK`).
- **API keys**: the API key field on the register, edit and API-key forms POSTs
  the key once to `DB.DBA.ONNX_API_KEY_SET`; it is never echoed back. When the
  console is not on HTTPS, submitting a form with a **non-empty** password field
  is interrupted first by a modal spelling out that the value crosses the network
  in the clear, pointing at `isql`, ODBC or JDBC — each of which can be
  TLS-encrypted — as ways to avoid the browser, and requiring an explicit
  *I understand, continue*. The test is `window.isSecureContext`, the browser's
  own answer to the question: it stays true behind a TLS-terminating proxy where
  the server only sees plain HTTP, and treats loopback as secure, since nothing
  typed into `http://localhost` leaves the machine. The guard is emitted for
  every page by `VVEC_FOOT` and keys off the presence of a *filled* password
  field, so a secret-bearing form added later is covered without being wired up,
  and a form submitted with the key box left blank is not interrupted.
  *Do not warn me again in this browser* records the acknowledgement in
  `localStorage` — per browser and per origin, never on the server, so one
  operator dismissing it does not silence the warning for anyone else. It sticks
  only when the risk is actually taken on: ticking the box and then cancelling
  does not remember. The API Keys page shows a notice while the warning is
  suppressed, with a control to turn it back on, so the checkbox is not a
  one-way door. Supplying a key while leaving the registry name blank stores it
  under the provider's conventional name (`ONNX_PROVIDER_API_KEY_NAME`) — the
  same one `ONNX_REGISTER_HTTP_EMBED_MODEL` would have referenced — so the model
  and its key cannot end up pointing at different names. Editing a provider with
  the key field blank leaves the stored key untouched. Only use it over HTTPS or a
  trusted network so the value is not exposed in transit.
- **CSRF**: every state-changing form carries a hidden `csrf` token and every
  POST handler calls `DB.DBA.VVEC_CSRF_CHECK()` as its first statement — a
  missing or wrong token, or a non-`POST` method, returns **403** and performs
  no action. The token is the synchroniser pattern: one unguessable value minted
  with the session and kept in its row, which a cross-site page can neither
  forge nor read out of our same-origin form. It is worthless the moment the
  session ends. As defence in depth, when the browser sends an `Origin` or
  `Referer` its host must match the request `Host`. (The `SameSite=Strict`
  cookie means a cross-site request carries no session at all, so this is
  belt and braces.)

## Uninstall

Uninstall the VAD from the Conductor's *Packages* tab, or from **dba** iSQL:

```sql
vad_uninstall ('vvec');
```

The VAD's pre-uninstall hook removes the `/vvec/` virtual-directory mapping and
the engine removes the DAV resources.
