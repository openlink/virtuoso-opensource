
-- MAIN FUNCTIONS

create procedure S3_SAVE_USER (in _user_name varchar)
{
   declare user_id integer;
   declare stmt, txt varchar;
   declare ret, ses any;

   ret := string_output ();
   ses := string_output ();

   if (not exists (select 1 from WA_SYS_USERS where U_NAME = _user_name))
	signal ('23000', 'Invalid user');

   select U_ID into user_id from WA_SYS_USERS where U_NAME = _user_name;

   http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://ods.openlinksw.com/S3/">', ses);

--  seve SQL USER;

   stmt := sprintf ('select * from DB.DBA.SYS_USERS where U_NAME = ''%s''', _user_name);
   S3_GET_TABLE_DATA (stmt, ses);

--   stmt := sprintf ('select * from DB.DBA.WA_USER_INFO where WAUI_U_ID = ''%i''', user_id);
--   S3_GET_TABLE_DATA (stmt, ses);
/*
   stmt := sprintf ('select * from DB.DBA.sn_entity where sne_name = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_entity'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_source where sns_name = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_source'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_person where sne_name = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_person'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_group where sne_name = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_group'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_member where snm_entity = ''%i''', user_id);
   ret := vector_concat (ret, vector ('DB.DBA.sn_group'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_related where snr_url = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_related'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   stmt := sprintf ('select * from DB.DBA.sn_invitation where sni_to = ''%s''', _user_name);
   ret := vector_concat (ret, vector ('DB.DBA.sn_invitation'));
   ret := vector_concat (ret, S3_GET_TABLE_DATA (stmt));

   dbg_obj_print (length (ret));
   dbg_obj_print (length (serialize (ret)));
   dbg_obj_print (length (gz_compress (serialize (ret))));

   return gz_compress (serialize (ret));
*/

   http ('</rdf:RDF>', ses);

   txt := string_output_string (ses);
   dbg_obj_print (xml_tree_doc (txt));
   string_to_file ('rdf_out.xml', txt, -2);
   string_output_gz_compress (ses, ret);
   dbg_obj_print ('OUT LEN = ', length (string_output_string (ret)));
   return string_output_string (ret);
}
;


create procedure S3_RESTORE_USER (in _user_data any)
{
  declare user_id integer;
  declare _un_comp varchar;
  declare user_name integer;

  _un_comp := string_output ();
  gz_uncompress (_user_data, _un_comp);
  _user_data := string_output_string (_un_comp);
  _user_data := xtree_doc (_user_data, 0, '', 'utf-8');

  -- GET USER NAME FIRST

  _user_data := xslt ('file:s3_convert.xsl', _user_data);

  dbg_obj_print ('_user_data ', _user_data);

  user_name :=  S3_GET_DATA_FROM_XML ('DB.DBA.SYS_USERS', 'U_NAME', 0, 182, _user_data);

  dbg_obj_print ('user_name ', user_name);

--  if (exists (select 1 from SYS_USERS where U_NAME = user_name))
--	signal ('23000', 'The resolve conflicts module is not ready yet.');

-- SYS_USERS is special case.
  user_id := S3_UPDATE_USER_TABLE (_user_data);
  select U_NAME into user_name from SYS_USERS where U_ID = user_id;

  dbg_obj_print ('user_name ', user_name);

-- XXX DEBUG
  delete from DB.DBA.WA_USER_INFO where WAUI_U_ID = user_id;
  delete from DB.DBA.sn_entity where sne_name = user_name;
  delete from DB.DBA.sn_source where sns_name = user_name;
  delete from DB.DBA.sn_person where sne_name = user_name;
  delete from DB.DBA.sn_group where sne_name = user_name;
-- XXX DEBUG

  S3_UPDATE_TABLE ('DB.DBA.SYS_USERS', _user_data, 'U_ID = ' || cast (user_id as varchar), vector ('U_NAME', 'U_PASSWORD'));
  commit work;

return;

  insert into DB.DBA.WA_USER_INFO (WAUI_U_ID) values (user_id);
  commit work;

  S3_UPDATE_TABLE ('DB.DBA.WA_USER_INFO', _user_data, 'WAUI_U_ID = ' || cast (user_id as varchar));
  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_entity', _user_data, 'sne_name', user_name);
--  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_source', _user_data, 'sns_name', user_name);
--  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_person', _user_data, 'sne_name', user_name);
--  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_group', _user_data, 'sne_name', user_name);
--  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_alias', _user_data, 'sna_alias', user_name);
--  commit work;

--  S3_INSERT_INTO_TABLE ('DB.DBA.sn_member', _user_data, 'snm_entity', user_name);
--  commit work;

  return user_id;
}
;

-- END MAIN FUNCTIONS




create procedure S3_TRIM_META (in _meta any)
{
  declare _ret any;

  dbg_obj_print (_meta);

  _meta := _meta[0];
  _ret := make_array (length (_meta), 'any');

  for (declare xx any, xx := 0; xx <= length (_meta)-1 ; xx := xx + 1)
     aset (_ret, xx, _meta[xx][0]);

  return _ret;
}
;


create procedure S3_GET_TABLE_DATA (in stmt any, inout ses any)
{
   declare state, msg, meta, res varchar;

   exec (stmt, state, msg, vector (), 100, meta, res);

dbg_obj_print ('meta 1 ->', meta);

--dbg_obj_print ('res ->', res);

--   res := serialize (res[0]);
--   meta := serialize (meta);
   res := S3_MAKE_RDF (meta, res, ses);

   return res;
}
;


create procedure S3_MAKE_RDF (in meta any, inout data any, inout ses any)
{
   declare table_name varchar;
   declare idx1, idx2 integer;

   table_name := meta[0][1][7] || '.' || meta[0][1][9] || '.' || meta[0][1][10];
   meta := S3_TRIM_META (meta);
   if (data = vector()) data := make_array (length (meta), 'any');

   for (idx1 := 0; idx1 < length (data); idx1 := idx1 + 1)
      {
   	 for (idx2 := 0; idx2 < length (meta); idx2 := idx2 + 1)
            {
		if (data [idx1][idx2] is not NULL)
		  {
		     http ('<rdf:Description', ses);
    --		S3_PRINT_TRIPLE (table_name || '___row' || cast (idx1 as varchar) || '___' || meta[idx2], data [idx1][idx2], ses);
		     S3_PRINT_TRIPLE (replace (encode_base64 (serialize (vector (table_name, meta[idx2], idx1))), '=', '_'),
				data [idx1][idx2], ses);
		     http ('</rdf:Description>', ses);
		  }
            }

      }

   return;
}
;


create procedure S3_PRINT_TRIPLE (in table_column_name any, inout data any, inout ses any)
{
   http (' rdf:about="http://www.w3.org/', ses); http_value (table_column_name, 0, ses); http ('">', ses);

   dbg_obj_print ('S3_PRINT_TRIPLE -> data ', __tag (data));

   http ('<dc:data>n', ses);
	if (isinteger (data) or data is NULL)
	 {
   	  http_value (data, 0, ses);
   dbg_obj_print ('S3_PRINT_TRIPLE 1 -> data ', data);
	 }
	else if (isarray (data) or __tag(data) = 211)
	 {
--     	  http_value (encode_base64 (serialize (data)), 0, ses);
   	  http (encode_base64 (serialize (data)), ses);
   dbg_obj_print ('S3_PRINT_TRIPLE 2 -> data ', encode_base64 (serialize (data)));
	 }
	else
	 {
--   	  http_value (serialize (data), 0, ses);
   	  http (serialize (data), ses);
   dbg_obj_print ('S3_PRINT_TRIPLE 3 -> data ', data);
	 }
   http ('</dc:data>', ses);
}
;


create procedure S3_GET_DATA_FROM_XML (in table_name varchar, in column_name varchar, in _row integer,
	in _tag any, inout data any)
{
   declare temp any;

   temp := replace (encode_base64 (serialize (vector (table_name, column_name, _row))), '=', '_');
--   dbg_obj_print ('S3_GET_DATA_FROM_XML temp -> ', temp);

   temp := xpath_eval ('string (//' || temp || ')', data, 1);
--   dbg_obj_print ('S3_GET_DATA_FROM_XML temp -> ', temp);

   if (temp = '') return NULL;

   temp := trim (temp, 'n');

   if (_tag = 182)
	temp := deserialize (decode_base64 (cast (temp as varchar)));

--   dbg_obj_print ('S3_GET_DATA_FROM_XML temp -> ', temp);

   return (temp);
}
;









create procedure S3_UPDATE_USER_TABLE (inout _user_data any)
{
  declare pos, _user_sql, uid int;
  declare state, msg, mtd, res, _user_name, _user_pass varchar;
  declare stmt any;

  _user_name := S3_GET_DATA_FROM_XML ('DB.DBA.SYS_USERS', 'U_NAME', 0, 182, _user_data);
  _user_pass := S3_GET_DATA_FROM_XML ('DB.DBA.SYS_USERS', 'U_PASSWORD', 0, 182, _user_data);
  _user_pass := pwd_magic_calc (_user_name, _user_pass, 1);
  _user_sql := S3_GET_DATA_FROM_XML ('DB.DBA.SYS_USERS', 'U_SQL_ENABLE', 0, 182, _user_data);

-- XXX DEBUG CODE
  _user_name := _user_name || '_1';
  delete from SYS_USERS where U_NAME = _user_name;
-- XXX DEBUG CODE

  uid :=  DB.DBA.USER_CREATE (_user_name, _user_pass, vector ('SQL_ENABLE', _user_sql));

  dbg_obj_print ('_user_sql ', _user_sql);

/*
  for (declare xx any, xx := 0; xx < length (meta) ; xx := xx + 1)
     {
	if (meta[xx] not in ('U_NAME', 'U_ID', 'U_PASSWORD', 'U_SQL_ENABLE'))
	  {
	    state := '00000';

	    if (__tag (data[xx]) = 189)
	        stmt := sprintf ('update DB.DBA.SYS_USERS set %s=%i where U_ID=%i', meta[xx], data[xx], uid);
	    else
	      {
		declare tmp any;

		tmp := encode_base64 (serialize (data[xx]));
	        stmt := sprintf ('update DB.DBA.SYS_USERS set %s=deserialize (decode_base64 (''%s'')) where U_ID=%i', meta[xx], tmp, uid);
	      }

	     exec (stmt, state, msg, vector (), 100, mtd, res);
		dbg_obj_print (stmt);
		dbg_obj_print (state);
	  }
     }
*/
    exec ('checkpoint');

  return uid;
}
;


create procedure S3_UPDATE_TABLE (in table_name varchar, inout all_data any, in pk any := null, in not_in any := null)
{
  declare stmt, meta, data, pos any;
  declare state, msg, mtd, res varchar;

  for (select "COLUMN", COL_DTP, COL_CHECK from SYS_COLS where "TABLE" = table_name) do
    {
	dbg_obj_print ('"COLUMN" ', "COLUMN");
	stmt := NULL;

	if (COL_CHECK = 'I') goto _next;

	data := S3_GET_DATA_FROM_XML (table_name, "COLUMN", 0, COL_DTP, all_data);

	if (data is NULL) goto _next;

	if (position ("COLUMN", not_in)) goto _next;

	data := encode_base64 (serialize (data));

	if (COL_DTP in (182))
	  {
	      stmt := sprintf ('update %s set %s=deserialize (decode_base64 (''%s'')) where %s', table_name, "COLUMN", data, pk);
	  }

	if (stmt is not NULL)
	  {
	  dbg_obj_print ('stmt ', stmt);
	     exec (stmt, state, msg, vector (), 100, mtd, res);
		dbg_obj_print (stmt);
		dbg_obj_print (state);
	  }

_next:;
    }



  return;

  for (declare xx any, xx := 0; xx < length (meta) ; xx := xx + 1)
     {
	if (meta[xx] not in ('U_NAME', 'U_ID', 'WAUI_U_ID'))
	  {
		dbg_obj_print (meta[xx]);
		dbg_obj_print (data[xx]);
		dbg_obj_print (__tag (data[xx]));
		dbg_obj_print (pk[0]);
		dbg_obj_print (pk[1]);
	    if (__tag (data[xx]) = 189)
	        stmt := sprintf ('update %s set %s=%i where %s', table_name, meta[xx], data[xx], pk);
	    else
	      {
		declare tmp any;

		tmp := encode_base64 (serialize (data[xx]));
	        stmt := sprintf ('update %s set %s=deserialize (decode_base64 (''%s'')) where %s', table_name, meta[xx], tmp, pk);
	      }

	     exec (stmt, state, msg, vector (), 100, mtd, res);
		dbg_obj_print (stmt);
		dbg_obj_print (state);
	  }
     }

    exec ('checkpoint');

  return 1;
}
;

create procedure S3_INSERT_INTO_TABLE (in table_name varchar, inout all_data any, in pk varchar, in pk_val any)
{
  declare stmt, meta, data, pos any;
  declare state, msg, mtd, res, val_st, tbl2 varchar;

  pos := position (table_name, all_data);
  meta := deserialize (all_data[pos]);
  data := deserialize (all_data[pos+1]);

  if (isinteger (data)) return;

  tbl2 := table_name;

  if (tbl2 = 'DB.DBA.sn_person') tbl2 := 'DB.DBA.sn_entity';
  if (tbl2 = 'DB.DBA.sn_group') tbl2 := 'DB.DBA.sn_entity';

  stmt := 'insert into ' || table_name || ' (';

  val_st := '(';

	dbg_obj_print ('data ->', data);

  for (declare xx any, xx := 0; xx < length (meta) ; xx := xx + 1)
    {
        declare tmp any;

        if (DB.DBA.S3_COL_CHECK (tbl2, meta[xx]))
	  {
--	dbg_obj_print ('(DB.DBA.col_check (table_name, meta[xx] -> ', DB.DBA.col_check (table_name, meta[xx]));
	     tmp := data[xx];

	     if (meta[xx] = pk) tmp := pk_val;

	     tmp := '''' || encode_base64 (serialize (tmp)) || '''';
	     stmt := stmt || meta[xx] || ', ';
	     val_st := val_st || 'deserialize (decode_base64 (' || tmp || ')), ';
          }
    }

   stmt := trim (stmt);
   stmt := trim (stmt, ',');
   stmt := stmt || ')';

   val_st := trim (val_st);
   val_st := trim (val_st, ',');
   val_st := val_st || ')';

   stmt := stmt || ' values ' ||val_st;

	dbg_obj_print ('val_st ->', val_st);
	dbg_obj_print ('stmt ->', stmt);

   exec (stmt);
}
;

create procedure DB.DBA.S3_COL_CHECK (in tbl any, in col any)
{
    if (exists (select 1 from DB.DBA.SYS_COLS where "TABLE" = tbl and "COLUMN" = col and COL_CHECK ='I'))
      return 0;

    return 1;
}
;

