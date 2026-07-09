-- gqlc.sql — GQL Phase 4 C plugin setup
--
-- This script is for manual testing. The plugin registers BIFs
-- GQL_NORMALIZE, GQL_IS_NORMALIZED, GQL_PERCENTILE_CONT, and
-- GQL_PERCENTILE_DISC at load time via its connect callback.
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

  -- Test GQL_PERCENTILE_CONT (continuous percentile with interpolation)
  declare pctc_result double;
  pctc_result := bif:GQL_PERCENTILE_CONT (vector (10, 20, 30, 40, 50), 0.5);
  if (pctc_result = 30.0)
    result ('PASS', sprintf ('GQL_PERCENTILE_CONT median = %f', pctc_result), '', '');
  else
    result ('FAIL', sprintf ('GQL_PERCENTILE_CONT: expected 30.0, got %f', pctc_result), '', '');

  -- Test GQL_PERCENTILE_DISC (discrete percentile, nearest rank)
  declare pctd_result double;
  pctd_result := bif:GQL_PERCENTILE_DISC (vector (10, 20, 30, 40, 50), 0.5);
  if (pctd_result = 30.0)
    result ('PASS', sprintf ('GQL_PERCENTILE_DISC median = %f', pctd_result), '', '');
  else
    result ('FAIL', sprintf ('GQL_PERCENTILE_DISC: expected 30.0, got %f', pctd_result), '', '');

  result ('DONE', 'GQL Phase 4 C plugin self-test complete', '', '');
}
;
