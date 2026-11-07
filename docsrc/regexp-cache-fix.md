# Regexp cache and query-cost fixes

## Regexp ownership and study

Retain compiled regexp objects while holding the cache lock on both cache-hit
paths. Return the retained object instead of dereferencing a hash slot after
unlocking, since eviction or rehashing can invalidate that slot. Check reference
counts under the same lock when releasing shared objects.

Pass zero options to `pcre_study`. Compile flags such as UTF-8 and case folding
remain in the compiled pattern and are not valid study options.

## Cardinality sampling

Include column identities, comparison operators, and the boundary between index
conditions and residual filters in sample cache keys. Samples with different
scan ranges no longer share cached cardinalities solely because their parameter
values match.

Apply residual filters during column-store sampling when the index prefix ends
with an equality condition, as well as for range conditions.

## Regression coverage and runtime utilities

Add deterministic, sanitizer-enabled tests for cache-hit ownership, duplicate
compilation, study options, and sample cache key separation. Add SQL coverage
for residual-filter selectivity and query results, plus a concurrent regexp
cache stress driver with result validation.

Add runtime packaging and startup utilities that preserve the source
installation, bundle the required loader and shared libraries, generate
relocatable launchers, include licenses and checksums, and resolve database
paths relative to the selected configuration file.
