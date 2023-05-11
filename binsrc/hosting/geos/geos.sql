create procedure DB.DBA.GEOS_SELF_TEST_RESULT (in status varchar, in txt varchar, in err_state varchar, in err_message varchar)
{
  dbg_obj_princ ('DB.DBA.GEOS_SELF_TEST:\t', status, '\t', txt, '\t', err_state, '\t', err_messsage);
  result (status, txt, err_state, err_message);
}
;

create procedure DB.DBA.GEOS_SELF_TEST ()
{
  declare STATUS, TXT, ERR_STATE, ERR_MESSAGE varchar;
  result_names (STATUS, TXT, ERR_STATE, ERR_MESSAGE);
  DB.DBA.GEOS_SELF_TEST_RESULT ('', 'Starting tests...', '', '');
  DB.DBA.GEOS_SELF_TEST_RESULT ('', 'Tests complete.', '', '');
}
;
