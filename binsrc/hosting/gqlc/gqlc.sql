-- gqlc.sql — GQL Phase 4 C plugin setup
--
-- This script is for manual testing. The plugin registers BIFs
-- GQL_NORMALIZE and GQL_IS_NORMALIZED at load time via its connect callback.
-- No SQL-side setup is strictly required, but this script verifies
-- the functions are available.

create procedure DB.DBA.GQLC_SELF_TEST ()
{
  declare STATUS, TXT, ERR_STATE, ERR_MESSAGE varchar;
  result_names (STATUS, TXT, ERR_STATE, ERR_MESSAGE);

  result ('START', 'GQL Phase 4 C plugin self-test', '', '');

  -- Test GQL_NORMALIZE with NFC (compose)
  declare nfc_result varchar;
  nfc_result := bif:GQL_NORMALIZE (N'caf' || chr (233));
  if (nfc_result is not null)
    result ('PASS', sprintf ('GQL_NORMALIZE returned %s of length %d', nfc_result, length (nfc_result)), '', '');
  else
    result ('FAIL', 'GQL_NORMALIZE returned NULL', '', '');

  -- Test GQL_IS_NORMALIZED
  declare is_norm integer;
  is_norm := bif:GQL_IS_NORMALIZED ('hello');
  if (is_norm = 1)
    result ('PASS', 'GQL_IS_NORMALIZED: plain ASCII is normalized', '', '');
  else
    result ('FAIL', sprintf ('GQL_IS_NORMALIZED: expected 1, got %d', is_norm), '', '');

  result ('DONE', 'GQL Phase 4 C plugin self-test complete', '', '');
}
;
