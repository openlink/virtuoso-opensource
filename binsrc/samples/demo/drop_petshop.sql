set_user_id('dba', 1, DB.DBA.GET_PWD_FOR_VAD('dba'))
;
DB.DBA.exec_no_error('drop user petshop')
;
delete from DB.DBA.SYS_REPL_ACCOUNTS
;
drop procedure DB.DBA.GET_PWD_FOR_VAD
;
