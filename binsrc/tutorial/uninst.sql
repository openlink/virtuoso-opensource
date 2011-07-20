create procedure DB.DBA.drop_tut_search_table_safe(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

DB.DBA.drop_tut_search_table_safe('DROP TABLE DB.DBA.TUT_SEARCH');
drop procedure DB.DBA.drop_tut_search_table_safe; 

drop table Demo.demo.XQBids;
drop table Demo.demo.XQItems;
drop table Demo.demo.XQUsers;
