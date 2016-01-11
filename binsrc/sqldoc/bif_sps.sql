--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

create procedure
DB.DBA.HELP_BIF_CATEGORIES()
{
  declare categories any;
  declare idx integer;
  declare state, msg, CATEGORY varchar;

  state := '00000';
  exec ('SELECT DISTINCT CATEGORY FROM DB.DBA.REFENTRY ORDER BY CATEGORY',
        state, msg, NULL, 0, NULL, categories);
  if (state <> '00000')
    signal (state, msg);
  idx := 0;
  result_names(CATEGORY);
  WHILE (idx < length(categories)) {
    CATEGORY := AREF(AREF(categories, idx),0);
    result( CATEGORY );
    idx := idx + 1;
  }
  end_result ();
};
grant execute on DB.DBA.HELP_BIF_CATEGORIES to public;

create procedure
DB.DBA.HELP_BIF_FUNCTIONS( IN category_mask VARCHAR := NULL, IN function_mask VARCHAR := NULL )
{
  declare functions any;
  declare idx, IS_BIF integer;
  declare state, msg varchar;
  declare cmd varchar;
  declare CATEGORY, FUNCTIONNAME, TITLE, PURPOSE, DESCRIPTION, RETURN_TYPE, RETURN_DESC varchar;

  cmd := 'SELECT CATEGORY, FUNCTIONNAME, TITLE, PURPOSE, DESCRIPTION, RETURN_TYPE, RETURN_DESC
          FROM DB.DBA.REFENTRY INNER JOIN DB.DBA.FUNCTIONS ON DB.DBA.REFENTRY.ID = DB.DBA.FUNCTIONS.REFENTRYID';
  if( (not isnull(category_mask)) OR (not isnull(function_mask)) ) {
    cmd := concat( cmd, ' WHERE' );
    if( not isnull(category_mask) ) 
      cmd := concat( cmd, ' CATEGORY LIKE ''', category_mask, '''');

    if( not isnull(function_mask) ) {
      if( not isnull(category_mask) )
        cmd := concat( cmd, ' AND' );
      cmd := concat( cmd, ' FUNCTIONNAME LIKE ''', function_mask, '''');
    }
  }
  cmd := concat( cmd, ' ORDER BY CATEGORY, FUNCTIONNAME');

  state := '00000';
--dbg_obj_print(cmd);
  exec (cmd, state, msg, NULL, 0, NULL, functions);
  if (state <> '00000')
    signal (state, msg);
  idx := 0;
  result_names(CATEGORY, IS_BIF, FUNCTIONNAME, TITLE, PURPOSE, DESCRIPTION, RETURN_TYPE, RETURN_DESC);
  WHILE (idx < length(functions)) {
    CATEGORY := AREF(AREF(functions, idx),0);
    FUNCTIONNAME := AREF(AREF(functions, idx),1);
    TITLE := replace( AREF(AREF(functions, idx),2), '@', '''');
    PURPOSE := replace( AREF(AREF(functions, idx),3), '@', '''');
    DESCRIPTION := replace( AREF(AREF(functions, idx),4), '@', '''');
    RETURN_TYPE := AREF(AREF(functions, idx),5);
    RETURN_DESC := replace( AREF(AREF(functions, idx),6), '@', '''');
--    IS_BIF := case when strchr(FUNCTIONNAME, '.') IS NULL then 1 else 0 end;
    IS_BIF := case when strchr(RETURN_TYPE, '.') IS NULL then 1 else 0 end; --temporary

    result( CATEGORY, IS_BIF, FUNCTIONNAME, TITLE, PURPOSE, DESCRIPTION, RETURN_TYPE, RETURN_DESC );
    idx := idx + 1;
  }
  end_result ();
};
grant execute on DB.DBA.HELP_BIF_FUNCTIONS to public;

create procedure
DB.DBA.HELP_BIF_PARAMETERS( IN function_mask VARCHAR := NULL )
{
  declare parameters any;
  declare idx, OPTIONAL integer;
  declare state, msg varchar;
  declare cmd varchar;
  declare FUNCTIONNAME, DIRECTION, PARAMETER, TYPE varchar;
  declare DESCRIPTION varchar;

  cmd := 'SELECT FUNCTIONNAME, DIRECTION, PARAMETER, TYPE, OPTIONAL, DESCRIPTION FROM DB.DBA.PARAMETER';
  if( not isnull(function_mask) )
    cmd := concat( cmd, ' WHERE FUNCTIONNAME LIKE ''', function_mask, '''' );
  cmd := concat( cmd, ' ORDER BY FUNCTIONNAME, ID');

  state := '00000';
  exec (cmd, state, msg, NULL, 0, NULL, parameters);
  if (state <> '00000')
    signal (state, msg);
  idx := 0;
  result_names(FUNCTIONNAME, DIRECTION, PARAMETER, TYPE, OPTIONAL, DESCRIPTION);
  WHILE (idx < length(parameters)) {
    FUNCTIONNAME := AREF(AREF(parameters, idx),0);
    DIRECTION := AREF(AREF(parameters, idx),1);
    PARAMETER := AREF(AREF(parameters, idx),2);
    TYPE := AREF(AREF(parameters, idx),3);
    OPTIONAL := AREF(AREF(parameters, idx),4);
    DESCRIPTION := replace( AREF(AREF(parameters, idx),5), '@', '''');

    result(FUNCTIONNAME, DIRECTION, PARAMETER, TYPE, OPTIONAL, DESCRIPTION);
    idx := idx + 1;
  }
  end_result ();
};
grant execute on DB.DBA.HELP_BIF_PARAMETERS to public;
