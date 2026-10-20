-- Deterministic OpenAI-compatible provider coverage.  The fixture listens only on localhost.

echo BOTH "STARTED: VVEC HTTP provider tests\n";

select case when DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE ('lm_studio') = 'lmstudio'
                  and DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE ('openai-compatible') = 'openai_compatible'
                  and DB.DBA.ONNX_HTTP_PROVIDER_DEFAULT_ENDPOINT ('ollama') like '%/v1/embeddings'
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": HTTP provider normalization/default endpoint\n";

select DB.DBA.ONNX_API_KEY_SET ('ONNX_API_KEY_MOCK', 'test-provider-key');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-http-4', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/custom/v1/embeddings', 'ONNX_API_KEY_MOCK', 5, 'local mock provider');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

select case when provider_endpoint = 'http://127.0.0.1:19481/custom/v1/embeddings'
                  and provider_dimensions = 4 and provider_timeout = 5
            then 1 else 0 end
  from DB.DBA.ONNX_MODELS where model_name = 'mock-http-4';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": per-model provider endpoint override persisted\n";

select length (DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-http-4', 'alpha document'));
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": OpenAI-compatible response parsed and dimensions validated\n";

create table DB.DBA.VVEC_HTTP_DOCS (id integer not null primary key, content varchar);
insert into DB.DBA.VVEC_HTTP_DOCS values (1, 'alpha document');
insert into DB.DBA.VVEC_HTTP_DOCS values (2, 'beta document');
create vector index VVEC_HTTP_IDX on DB.DBA.VVEC_HTTP_DOCS (content)
using 'mock-http-4' with (dimensions = 4, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";

select count (*) from (select top 1 id from DB.DBA.VVEC_HTTP_DOCS where X_SIMILAR (content, 'alpha document', 4) > 0.99) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": provider dispatch indexes and searches through the relational queue\n";

select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-http-wrong-dim', 'openai_compatible', 'mock-embed-4', 5,
  'http://127.0.0.1:19481/custom/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
select DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-http-wrong-dim', 'alpha document');
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": provider dimension mismatch rejected\n";

-- ===========================================================================
-- Provider hardening (prompt 11).
-- ===========================================================================

-- Issue 6: a plain-http endpoint to a PUBLIC host is refused at registration
-- (the API key must not go out in cleartext); loopback http stays allowed.
select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-http-public', 'openai_compatible', 'mock-embed-4', 4,
  'http://8.8.8.8/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": plain-http endpoint to a public host rejected at registration\n";

-- Issue 1: a redirect (302) is NOT followed, so the Authorization bearer token
-- is never resent to the redirect target on a different host/port.
select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-redirect', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/redirect/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
select DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-redirect', 'alpha document');
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": redirect not followed (embed fails rather than chasing the 302)\n";

select case when cast (http_get ('http://127.0.0.1:19481/stats') as varchar) like '%"leak_auth_seen": false%'
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Authorization header never reached the redirect target (no token leak)\n";

-- Issue 3: a 429 (with Retry-After) followed by a 200 succeeds transparently.
select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-flaky', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/flaky/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
select length (DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-flaky', 'alpha document'));
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": 429-then-200 retried and succeeded\n";

-- Issue 3: three consecutive 500s exhaust the retry cap and fail terminally with
-- the generic (redacted) error; the provider body is not echoed to the caller.
select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-500', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/fail500/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
select DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-500', 'alpha document');
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": three 500s fail with a clear terminal error\n";
select case when cast (http_get ('http://127.0.0.1:19481/stats') as varchar) like '%/fail500/v1/embeddings": 3%'
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": retryable 5xx attempted exactly 3 times (cap honoured)\n";

-- Issue 3: a terminal 401 is NOT retried (exactly one request reaches the mock).
select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-401', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/unauth/v1/embeddings', 'ONNX_API_KEY_MOCK', 5);
select DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('mock-401', 'alpha document');
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": 401 fails terminally\n";
select case when cast (http_get ('http://127.0.0.1:19481/stats') as varchar) like '%/unauth/v1/embeddings": 1%'
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": terminal 401 was not retried (single request)\n";

-- Issue 5: a degraded provider is recorded per model (consecutive failures > 0)
-- so VVec Console can surface it; a healthy provider stays at 0.
select case when (select coalesce (provider_consecutive_failures, 0) from DB.DBA.ONNX_MODELS where model_name = 'mock-500') >= 1
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": provider failure state recorded for VVec Console\n";

-- ===========================================================================
-- The SQL backfill sends one request per batch, not one per row
-- ===========================================================================
--  CREATE VECTOR INDEX over a table that has rows embedded each row with a
--  call of its own -- for an HTTP provider, a request per row.  70 rows at the
--  default batch of 32 need 3.  The model points at the mock's
--  /batch/v1/embeddings, which nothing else uses, so its count is this
--  backfill's alone.  Guards, on both sides: every row is embedded, keeps the
--  hash of its text, and is found by a search.
create function DB.DBA.VVEC_HTTP_REQUESTS (in _path varchar) returns integer
{
  declare _js varchar;
  declare _p integer;
  _js := cast (http_get ('http://127.0.0.1:19481/stats') as varchar);
  _p := strstr (_js, sprintf ('"%s": ', _path));
  if (_p is null)
    return 0;
  return atoi (subseq (_js, _p + length (_path) + 4));
};

select DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  'mock-http-batch', 'openai_compatible', 'mock-embed-4', 4,
  'http://127.0.0.1:19481/batch/v1/embeddings', 'ONNX_API_KEY_MOCK', 5, 'local mock provider, batch endpoint');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": register a model on the mock's batch endpoint\n";

create table DB.DBA.VVEC_HTTP_BULK (id integer not null primary key, content varchar);
create procedure DB.DBA.VVEC_HTTP_BULK_FILL ()
{
  declare i integer;
  for (i := 1; i <= 70; i := i + 1)
    insert into DB.DBA.VVEC_HTTP_BULK values (i,
      sprintf ('%s document %d', case when mod (i, 2) = 0 then 'alpha' else 'beta' end, i));
  commit work;
};
DB.DBA.VVEC_HTTP_BULK_FILL ();
create vector index VVEC_HTTP_BULK_IDX on DB.DBA.VVEC_HTTP_BULK (content)
using 'mock-http-batch' with (dimensions = 4, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create an index over 70 rows on the HTTP provider STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_HTTP_REQUESTS ('/batch/v1/embeddings');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": the backfill of 70 rows sent 3 requests, one per batch of 32 (got " $LAST[1] ")\n";

select count (*) from DB.DBA.VVEC_HTTP_BULK_IDX_vec_embeddings where SOURCE_HASH is not null;
ECHO BOTH $IF $EQU $LAST[1] 70 "PASSED" "***FAILED";
ECHO BOTH ": every row embedded, with the hash of its text=" $LAST[1] "\n";

select count (*) from (select top 1 id from DB.DBA.VVEC_HTTP_BULK where X_SIMILAR (content, 'alpha document 2', 4) > 0.99) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the backfilled index is searched\n";

drop index VVEC_HTTP_BULK_IDX;
drop table DB.DBA.VVEC_HTTP_BULK;
drop procedure DB.DBA.VVEC_HTTP_BULK_FILL;
drop function DB.DBA.VVEC_HTTP_REQUESTS;
delete from DB.DBA.ONNX_MODELS where model_name = 'mock-http-batch';

create user VVEC_HTTP_NON_DBA;
grant execute on DB.DBA.ONNX_API_KEY_SET to VVEC_HTTP_NON_DBA;

echo BOTH "COMPLETED: VVEC HTTP provider tests\n";
