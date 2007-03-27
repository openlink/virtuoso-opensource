set_user_id('dba', 1, 'dba');
DB.DBA.exec_no_error('drop user petshop');
delete from DB.DBA.SYS_REPL_ACCOUNTS;
