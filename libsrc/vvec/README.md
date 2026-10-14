# libsrc/vvec — vector-specific algorithm code

Per the VVEC design (specifications_v2 rule 6: "vector-specific algorithm code lives
under `libsrc/vvec/`"), the portable, engine-independent vector algorithm code lives
here, separated from the storage/engine integration in `libsrc/Wi`.

## What lives here

- `vvec_simd.h` — SIMD float32 distance kernels (NEON / AVX2+FMA / scalar fallback),
  used for cosine / L2 / L1 and inner product.
- `vvec_hnsw.h` — the in-memory parallel HNSW builder used by the fast rebuild path
  (build the graph in RAM, then serialize to pages). Uses only the core runtime
  (`dk_alloc`, `dk_mutex_t`, `thread_create` + a completion semaphore) and the SIMD
  kernels above — no buffer manager, no `DPF_VEC` pages, no transaction.

These headers are `#include`d by `libsrc/Wi/vvec.c` via a relative path
(`../vvec/...`); they compile into `libwi` as part of that translation unit, so no
separate library or build wiring is needed here.

## What deliberately stays in libsrc/Wi

`libsrc/Wi/vvec.c` holds the persistent-index implementation: `DPF_VEC` page
format/serialization, buffer-manager access (`it_cursor_t` / `buffer_desc_t` /
`it_new_page` / `page_wait_access`), the epoch/health durability machinery, the
managed hidden-table lifecycle and DML hooks, the optimizer/executor search node, and
BIF registration. That code is page/disk and SQL-engine integration, which
specifications_v2 rule 5 explicitly places in `libsrc/Wi/page.c`, `disk.c` and related
headers. It depends pervasively on Wi internals (hundreds of references), so moving it
under `libsrc/vvec/` would invert the Wi↔vvec dependency; it correctly remains in Wi.
The optimizer recognition/plan-build for the similarity predicate lives in
`libsrc/Wi/sqldf.c`, `sqloby.c` and `sqlgen.c` for the same reason.

The plan's original source map also listed `vvec_math.{h,c}`, `vvec_mt.{h,c}` and
`vvec_cache.{h,c}`; those never existed as separate files in this tree (their
functionality is inline in `vvec.c` where it is storage-coupled, or provided by the
SIMD/HNSW headers here), so there was nothing separate to relocate.
