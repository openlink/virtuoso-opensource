--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
yacutia_exec_no_error ('drop view db.dba.xddl_tables')
;

yacutia_exec_no_error ('drop view db.dba.xddl_columns')
;

yacutia_exec_no_error ('drop view db.dba.xddl_pk')
;

yacutia_exec_no_error ('drop view db.dba.xddl_pk_parts')
;

yacutia_exec_no_error ('drop view db.dba.xddl_fk')
;

yacutia_exec_no_error ('drop view db.dba.xddl_fk_ref')
;

yacutia_exec_no_error ('drop view db.dba.xddl_procedures')
;

yacutia_exec_no_error ('drop view db.dba.xddl_views')
;

yacutia_exec_no_error ('drop view db.dba.xddl_constraints')
;

create procedure sql_type(in type integer, in prec integer , in scale integer) returns varchar {
    declare val varchar;
    val := 'any';
    if (type = 189) {
        return 'integer';
    } else if (type = 191) {
        val := 'double precision';
    } else if (type = 219) {
           val := 'numeric';
    } else if (type = 188) {
        val := 'smallint';
    } else if (type = 190) {
        val := 'real';
    } else if (type = 182  or type = 181  or type = 238) {
       val := 'varchar';
--       if (prec <> 0)  val := sprintf('varchar(%d)',prec);
    } else if (type = 125) {
        val := 'long varchar';
    } else if (type = 222) {
       val := 'varbinary';
--      if (prec <> 0)   val := sprintf('varbinary(%d)',prec);
    }  else if (type = 223 or  type = 131 ) {
       val := 'long varbinary';
--       if (prec <> 0)  val := sprintf('long varbinary(%d)',prec);
    } else if (type = 225) {
        val := 'nvarchar';
    } else if (type = 226) {
        val := 'long nvarchar';
    } else if (type = 230) {
       val := 'long xml';
    } else if (type = 183) {
        val := 'string';
--       if (prec <> 0)  val := sprintf('string(%d)',prec);
    } else if (type = 192) {
        val := 'char';
    } else if (type = 125) {
       val := 'any';
    } else if (type = 128) {
       val := 'timestamp';
    }  else if (type = 210) {
       val := 'time';
    } else if (type = 129) {
       val := 'date';
    } else if (type = 211) {
       val := 'datetime';
    }


    return val;
}
;

--   public static final int DV_C_SHORT = 184;
--   public static final int DV_STRING_SESSION = 185;
--   public static final int DV_SHORT_CONT_STRING = 186;
--   public static final int DV_LONG_CONT_STRING = 187;
--   public static final int DV_NUMERIC = 219;
--   public static final int DV_ARRAY_OF_POINTER = 193;
--   public static final int DV_ARRAY_OF_LONG_PACKED = 194;
--   public static final int DV_ARRAY_OF_FLOAT = 202;
--   public static final int DV_ARRAY_OF_DOUBLE = 195;
--   public static final int DV_ARRAY_OF_LONG = 209;
--   public static final int DV_LIST_OF_POINTER = 196;





create procedure is_not_null(in val any) returns varchar {
    if (val is null)
	 return 0; --'xsi:false';
    else return 1; --'xsi:true';
}
;

create procedure is_sequence(in _col_check integer) returns varchar {
  if (_col_check is not null and isstring (_col_check))  {
      --dbg_obj_print (_col_check, length (_col_check));
      if (length(_col_check) >= 1 and aref (_col_check, 0) = 73) -- 'I'
	return '1';
   }
   return '0';

}
;

create procedure is_identified(in _col_check varchar) returns varchar {
  if (_col_check is not null and isstring (_col_check))  {
      --dbg_obj_print (_col_check, length (_col_check));

      if (length(_col_check) >= 2 and aref (_col_check, 1) = 85) -- 'U'
	return sprintf ('%s', trim (subseq (_col_check, 2)));
   }
   return '';
}
;

create procedure get_default(in val varchar) returns varchar {
  if (val is not null)
     return val;
  else return 'null';
}
;

create procedure is_collate(in _col_check varchar) returns varchar {
  if (_col_check is not null and isstring (_col_check))  {
      --dbg_obj_print (_col_check, length (_col_check));
      if ( (length(_col_check) >= 1 and aref (_col_check, 0) = 73) or
         (length(_col_check) >= 2 and aref (_col_check, 1) = 85) ) -- 'U'
	return '';
      else return  _col_check;
   } else
       return  '';
}
;

create procedure int_to_yesno(in val integer) returns integer {
   if (val = 1)
	return 1; --'xsi:true';
   else
	return 0; -- 'xsi:false';
}
;

create procedure int_to_action(in val integer) returns string {
  if (val = 1)
	return 'set null';
   else if (val = 2)
	return 'cascade';
   else if (val = 3)
	return 'set default';
   return '';
}
;

create procedure get_parent(in table_name varchar ) returns varchar {
  declare id integer;
  declare parent, tmp varchar;
  parent := '';
  tmp := '';
  select KEY_ID into id from SYS_KEYS where  KEY_TABLE = table_name;
  for select SUPER, SUB from SYS_KEY_SUBKEY where SUB = id do {
    select KEY_TABLE into tmp from SYS_KEYS where  KEY_ID = SUPER;
    if (tmp is not null) {
      if (length(parent) > 0 )
         parent := concat(parent,', ');
      parent := concat(parent,tmp);
    }
  }
  if (length(parent) = 0 )
    return 'xsi:nil';
  else
    return parent;
}
;

create view  DB.DBA.XDDL_TABLES (T_NAME, T_PARENT,T_IDENT) as select KEY_TABLE, get_parent(KEY_TABLE),KEY_ID  from sys_keys where __any_grants(KEY_TABLE) and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null  and not exists(select 1 from SYS_VIEWS where V_NAME = KEY_TABLE) order by KEY_TABLE 
;

create view DB.DBA.XDDL_COLUMNS  ( C_TABLE,
                           C_COL,
                           C_TYPE,
			   C_TYPE_TEXT,
			   C_PREC,
			   C_SCALE,
                           C_NOTNULLABLE,
                           C_IDENTITY,
                           C_DEFAULT,
                           C_COLLATION,
                           C_IDENTIFIED_BY) as select \TABLE, \COLUMN, COL_DTP, sql_type(COL_DTP, COL_PREC, COL_SCALE), COL_PREC, COL_SCALE,
is_not_null(COL_NULLABLE), is_sequence(COL_CHECK), get_default(cast(deserialize(COL_DEFAULT) as varchar )), is_collate(COL_CHECK), is_identified(COL_CHECK) from sys_cols order by COL_ID
;

create view  DB.DBA.XDDL_PK  (PK_TABLE, PK_KEY_ID, PK_IS_UNIQUE, PK_IS_CLUSTERED, PK_IS_OID) as select KEY_TABLE, KEY_ID,  int_to_yesno(KEY_IS_UNIQUE), int_to_yesno(KEY_CLUSTER_ON_ID), int_to_yesno(KEY_IS_OBJECT_ID) from sys_keys where KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null
;

create view DB.DBA.XDDL_PK_PARTS  (PKP_KEY_ID, PKP_COL, PKP_ORD)  as select KP_KEY_ID, \COLUMN, KP_NTH from SYS_KEY_PARTS join SYS_COLS on KP_COL =  COL_ID join SYS_KEYS on KP_NTH < KEY_N_SIGNIFICANT AND KEY_ID = KP_KEY_ID
;

create view  DB.DBA.XDDL_FK (FK_TABLE, FK_REF_TABLE, FK_UPDATE_RULE, FK_DELETE_RULE) as select FK_TABLE, PK_TABLE, cast(int_to_action(UPDATE_RULE) as varchar),  cast(int_to_action(DELETE_RULE) as varchar) from SYS_FOREIGN_KEYS group by FK_TABLE, PK_TABLE, UPDATE_RULE,DELETE_RULE
;

create view  DB.DBA.XDDL_FK_REF (FK_TABLE, FK_COL, FK_REF_TABLE, FK_REF_COL) as
select  FK_TABLE, FKCOLUMN_NAME, PK_TABLE, PKCOLUMN_NAME from SYS_FOREIGN_KEYS
;

create view  DB.DBA.XDDL_VIEWS (V_NAME, V_TEXT) as select V_NAME , V_TEXT  from SYS_VIEWS where __any_grants(V_NAME)
;

create view  DB.DBA.XDDL_PROCEDURES (SP_NAME, SP_TEXT) as select P_NAME , blob_to_string(coalesce( coalesce (P_TEXT, P_MORE),''))  from SYS_PROCEDURES where __any_grants(P_NAME)
;

create view  DB.DBA.XDDL_CONSTRAINTS  (C_TABLE, C_NAME, C_CODE) as select C_TABLE, C_TEXT, sql_text(deserialize(C_MODE))  from sys_constraints
;

grant select on  DB.DBA.XDDL_TABLES to public
;

grant select on  DB.DBA.XDDL_VIEWS to public
;

grant select on  DB.DBA.XDDL_PROCEDURES to public
;

grant select on  DB.DBA.XDDL_CONSTRAINTS to public
;

create function xddl_init(in path varchar) returns varchar {
    declare res, tmp  varchar;
    res :='';
-- tmp := xml_load_mapping_schema_decl ( path,  'xddl.xsd',  'UTF-8', 'x-any'  );
--  res := concat(res, tmp);
    tmp := xml_load_mapping_schema_decl ( path, 'xddl_tables.xsd', 'UTF-8', 'x-any'  );
    res := concat(res, tmp);

    tmp:= xml_load_mapping_schema_decl ( path, 'xddl_views.xsd', 'UTF-8', 'x-any'  );
    res := concat(res, tmp);

    tmp:= xml_load_mapping_schema_decl ( path, 'xddl_procs.xsd', 'UTF-8', 'x-any'  );
    return  concat(res, tmp);
}
;

--select xml_load_mapping_schema_decl ('', 'file://xddl.xsd', 'UTF-8', 'x-any');

--select xml_load_mapping_schema_decl ('', 'file://xddl_tables.xsd', 'UTF-8', 'x-any');

--select xml_load_mapping_schema_decl ('', 'file://xddl_views.xsd', 'UTF-8', 'x-any');

--select xml_load_mapping_schema_decl ('', 'file://xddl_procs.xsd', 'UTF-8', 'x-any');


create procedure xddl_get (in path varchar) returns xml_tree {
  declare stmt varchar;
  declare tree xml_tree;
  if (path is null)
    path := '/*';
  stmt := sprintf('<objects>{for \044r in xmlview("xddl")%s return \044r}</objects>', path);
  return xquery_eval(stmt, xtree_doc('<q/>'));
}
;

create procedure xddl_get_tables (in path varchar) returns xml_tree {
  declare stmt varchar;
  declare tree xml_tree;
  if (path is null)
    path := '/*';
  stmt := sprintf('<tables>{for \044r in xmlview("xddl_tables")%s return \044r}</tables>', path);
  return xquery_eval(stmt, xtree_doc('<q/>'));
}
;

create procedure xddl_get_views (in path varchar) returns xml_tree {
  declare stmt varchar;
  declare tree xml_tree;
  if (path is null)
    path := '/*';
  stmt := sprintf('<views>{for \044r in xmlview("xddl_views")%s return \044r}</views>', path);
  return xquery_eval(stmt, xtree_doc('<q/>'));
}
;

create procedure xddl_get_procedures (in path varchar) returns xml_tree {
  declare stmt varchar;
  declare tree xml_tree;
  if (path is null)
    path := '/*';
  stmt := sprintf('<procedures>{for \044r in xmlview("xddl_procs")%s return \044r}</procedures>', path);
  return xquery_eval(stmt, xtree_doc('<q/>'));
}
;

create procedure xddl_diff (in base_path varchar, in fragment xml_tree) returns xml_tree {
    declare src_xslt,res, path, vspx  varchar;
    declare pars, xml_tree_doc, xml_tree_doc2 any;
    xml_tree_doc := fragment;
    xml_tree_doc2 := xpath_eval('/tables',xddl_get_tables(null));
    src_xslt := cast ( xml_uri_resolve_like_get(base_path,'xddl_diff.xsl') as varchar);
    pars  := vector('fragment', xml_tree_doc, 'database', xml_tree_doc2);
    res := xslt (src_xslt, xml_tree_doc,pars);
    return res;
}
;

create procedure xddl_to_ddl (in base_path varchar,in fragment xml_tree)  returns varchar {
   declare  src_xslt varchar;
   declare ses, res  any;

   ses := string_output();
   src_xslt := cast ( xml_uri_resolve_like_get(base_path,'xddl_exec.xsl') as varchar);
   res := xslt (src_xslt, fragment);
--   dbg_obj_print('result', res);
   http_value(res,0,ses);
   return string_output_string(ses);
}
;

create procedure xddl_attach_pk_xml_tree (in primary_key any, in current_table xml_tree, in key_is_unique varchar, in key_is_clustered varchar, in key_is_oid varchar ) 
 returns xml_tree {
  declare len, i  integer;
  declare cols, objs any;
  declare path, tmp_pk  varchar;
  declare pk_tree xml_tree;
  
    len :=  length(primary_key);
    objs := xpath_eval('/table',xml_tree_doc(current_table));
    path := '/table/pk/field';
    cols:= xpath_eval(path,objs,0);

    if (len > 0) { -- update pk
      declare  field xml_tree;			       
      pk_tree := xml_tree_doc(sprintf('<pk is_unique="%s" is_clustered="%s" is_oid="%s"/>', 
                          key_is_unique, key_is_clustered, key_is_oid )); 
      pk_tree := xpath_eval('/pk',pk_tree);
      i :=0;
      while (i < len) {
        tmp_pk := aref(primary_key,i);
        field := xml_tree_doc(sprintf('<field ord="%d" col="%s"/>',i,tmp_pk));
        XMLAppendChildren ( pk_tree, field);
        i:= i +1;
      }
      dbg_obj_print ('Constructed PK ', pk_tree ,'Flag', cols , 'Table ', objs);
      if (length( cols) = 0 ) {
         XMLAppendChildren (objs,   pk_tree);
	    return  objs;
      } else {
        path := sprintf('/table/pk');
        return XMLUpdate(objs,path, pk_tree);	     
     }
   } else if  (length(cols) > 0 ) { -- remove pk
      return XMLUpdate(objs,'/table/pk', NULL);	     
   }
   return current_table;
}
;

create procedure   xddl_attach_fk_xml_tree (in fk_columns any, in cur_table xml_tree) returns xml_tree {
   declare path, table_name, column_name,  pk_name, tmp_pk  varchar;
   declare tmp_array, cols, fk_array, foreign_key_columns  any;
   declare i, len, i2, len2,  is_found integer;
   declare current_table xml_tree;
   
  foreign_key_columns := fk_columns;
  current_table :=  cur_table;
  
  fk_array  := vector();
  len := length( foreign_key_columns);
  while (len > 0) {
    table_name  := null;
    i := 0;
    tmp_array :=  vector();
    cols :=  vector();
    while ( i < len) {
       if (table_name  is  null) {
           table_name  :=  aref(foreign_key_columns, i+2);
           cols := vector(aref(foreign_key_columns, i), aref(foreign_key_columns, i+1));
           i := i +3;
       } else {
         if (table_name  =  aref(foreign_key_columns, i+2))  {
            cols := vector_concat(cols  , vector(aref(foreign_key_columns, i), aref(foreign_key_columns, i+1)) );
         } else
            tmp_array :=  vector_concat(tmp_array , vector( aref(foreign_key_columns,i), aref(foreign_key_columns,i +1), aref(foreign_key_columns,i +2)) );
	    
         i := i +3;
       }
    }
    if (table_name is not null and length(cols) > 0) {
        fk_array  := vector_concat(fk_array  , vector( table_name , cols) );
    }
    foreign_key_columns :=  tmp_array;
    len := length( foreign_key_columns);
  }
  
  current_table := XMLUpdate(xml_tree_doc(current_table),'/table/fk', NULL);	     
  len :=  length(fk_array);

  if (len > 0 ) {
     i := 0;
     while (i < len) {
       path :=  sprintf('<fk ref_table="%s">', aref(fk_array,i) );
       cols := aref(fk_array,i +1);
       i2 :=0;
       len2 := length(cols);
       dbg_obj_print ('VEC', cols, len2);
       while  (i2 < len2) {
         path := concat (path, sprintf('<reference col="%s" ref_col="%s"/>',   aref(cols, i2), aref(cols, i2+1)  ));
         i2 := i2 +2;
       }
       path := concat (path, '</fk>');
       XMLAppendChildren(xpath_eval('/table',current_table), xpath_eval('/fk',  xml_tree_doc (path) ));
       i := i +2;
     }
     dbg_obj_print ('FK_ARRAY',  current_table);
   }
   return current_table;
}
;
   
create procedure xddl_execute_statements (in current_table varchar, out statement_out varchar ) returns any {
   declare err_sqlstate, err_msg, rel_path, statement varchar;
   declare m_dta, exec_errors any;
   declare statements varchar;
   declare  xq_res any;
   declare difference xml_tree;
   declare  pos, flag integer;

   difference := xddl_diff(xddl_get_base(), current_table);
   dbg_obj_print('Original',current_table,  'Difference', difference);
   statements := xddl_to_ddl(xddl_get_base(), xml_tree_doc(difference));
   dbg_obj_print('Exec', statements);
   statement_out := statements;
    err_sqlstate := '00000';
   if (statements is not null and length(statements) > 0) {
      flag := 1;
      exec_errors := vector();
      while(flag = 1 and length(statements) > 0) {
        pos := locate(';',statements);
        dbg_obj_print('POsition is ', pos, length(statements));
        if (pos > 0) {
          statement := substring(statements, 1,  pos -1);
          if (locate(';', substring(statements, pos + 1, length(statements) - pos)) = 0 ) 
	       flag := 0;
	  else 
	        statements := substring(statements, pos + 1, length(statements) - pos);				
	} else {
	     statement := statements;
	     flag := 0;
	} 
	declare exit handler for sqlstate '*' {
	  dbg_obj_print ('Error', __SQL_MESSAGE);
	  err_msg := sprintf(' Execution Error: %s', __SQL_MESSAGE);
	  exec_errors := vector_concat( exec_errors, vector(statement, err_msg));
	};
	exec (statement, err_sqlstate, err_msg, vector(),100, m_dta, xq_res);
	if ('00000' <> err_sqlstate)    {
	        err_msg := sprintf(' Execution Error: %s', err_msg);
	        exec_errors := vector_concat( exec_errors, vector(statement, err_msg));
	}
      } -- while		
      return exec_errors;
    }
    return null;
}
;

create procedure xddl_attach_table_xml_tree( in current_table xml_tree, in kind varchar, in objects xml_tree) returns xml_tree {	  
 declare objs xml_tree;
 declare path varchar;
  
  if ( kind ='create' ) {
     objs := xpath_eval('/tables',objects);
     XMLAppendChildren(objs, current_table);
     return   objs;
  } else if ( kind ='edit' ) {
       path := sprintf('/tables/table[@name=\'%s\']',xpath_eval('/table/@name',current_table) );
       return  XMLUpdate(objects, path,  xml_tree_doc(current_table) );
  }
   return objects;
}
;

create procedure xddl_exec (in stmt varchar, out exec_error varchar) returns integer {
   declare m_dta any;
   declare err_sqlstate, err_msg varchar;
   declare xq_res any;
	 err_msg := '';
    err_sqlstate := '00000';
	 
	 dbg_obj_print ('---------------------------Execute the following statement', stmt);
	 
	declare exit handler for sqlstate '*' {
	  err_msg := sprintf('Check creation Error: %s', cast(__SQL_MESSAGE as varchar) );
	  exec_error :=  err_msg;
		return -1;
	};
	exec (stmt, err_sqlstate, err_msg, vector(),100, m_dta, xq_res);
	if ('00000' <> err_sqlstate)    {
	   dbg_obj_print('Creation ==============================  Error: %s', err_msg);
	   exec_error :=  err_msg;
		 return -1;
	}						
	return 0;	
}
;

create procedure xddl_check_constraints_validation (in current_table xml_tree, in sid varchar,  inout errors any) returns integer {
    declare objs xml_tree;
		declare path, code , err_msg, name, stmt, table_name  varchar;
		declare cols, err_list any;
		declare i, len, result integer;
 	
		table_name := 	sprintf('db.dba.check_consttraint_%s',sid);
		stmt := sprintf('create table %s (', table_name);
    objs := xpath_eval('/table',xml_tree_doc(current_table));

    path := '/table/constraint';
    cols:= xpath_eval(path,objs,0);
		if (length (cols) = 0 ) {
		  errors := vector();
		  return 0;
		}
		
		result := xddl_exec(sprintf('drop table %s',table_name), err_msg);		

			
		path := '/table/column';
    cols:= xpath_eval(path,objs,0);
    i := 0;
		len := length(cols);
		while(i < len) {
		   name := xpath_eval('@name',aref(cols,i));
			 code := xpath_eval('@type-text',aref(cols,i));		    
			 stmt := concat(stmt, sprintf ('%s %s', name, code) );
		   i := i + 1;
			 if (i < len ) {
			   stmt := concat(stmt, ', ');
			 }
		}
    stmt := concat(stmt, ')');
		
    result := xddl_exec(stmt, err_msg);
		if (result < 0) {
		 errors := vector('Cannot create temporary table', err_msg);
		 return -1;
		}
		
		err_list := vector();		
    path := '/table/constraint';
    cols:= xpath_eval(path,objs,0);
    i := 0;
		len := length(cols);
		while(i < len) {
		   name := xpath_eval('@name',aref(cols,i));
			 code := cast ( xpath_eval('code/text()',aref(cols,i)) as varchar);
			 stmt := sprintf('select 1 from %s where %s', table_name,  code);
			 result := xddl_exec(stmt, err_msg);			 
			 if (result < 0)
		       err_list := vector_concat( err_list, vector(code, err_msg));
		   i := i + 1;
		}
		errors := err_list;
		
		result := xddl_exec(sprintf('drop table %s',table_name), err_msg);		
		
		if (length (err_list) > 0) {
		  return -1;
		}
		return 0;
}
