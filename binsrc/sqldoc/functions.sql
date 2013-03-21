--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

DROP TABLE DB.DBA.PARAMETER;
DROP TABLE DB.DBA.FUNCTIONS;
DROP TABLE DB.DBA.REFENTRY;

CREATE TABLE DB.DBA.REFENTRY (
 ID VARCHAR(50) NOT NULL,
 TITLE VARCHAR(100),
 CATEGORY VARCHAR(50),
 PURPOSE VARCHAR(255),
 DESCRIPTION LONG VARCHAR,
 CONSTRAINT pk_refentry PRIMARY KEY (ID)
 )
;

CREATE INDEX idx_refentry_cats on DB.DBA.REFENTRY(CATEGORY)
;

CREATE TABLE DB.DBA.FUNCTIONS (
 FUNCTIONNAME VARCHAR(100) NOT NULL,
 REFENTRYID VARCHAR(50) NOT NULL,
 RETURN_TYPE VARCHAR(50),
 RETURN_DESC VARCHAR(255),
 CONSTRAINT pk_function PRIMARY KEY (FUNCTIONNAME),
 CONSTRAINT fk_func_refentry FOREIGN KEY (REFENTRYID) REFERENCES DB.DBA.REFENTRY(ID)
 )
;

CREATE TABLE DB.DBA.PARAMETER (
 ID INTEGER IDENTITY,
 PARAMETER VARCHAR(50) NOT NULL,
 FUNCTIONNAME VARCHAR(100) NOT NULL,
 TYPE VARCHAR(50),
 DIRECTION VARCHAR(50),
 DESCRIPTION LONG VARCHAR,
 OPTIONAL INTEGER,
 CONSTRAINT pk_parameter PRIMARY KEY (ID, PARAMETER),
 CONSTRAINT fk_param_func FOREIGN KEY (FUNCTIONNAME) REFERENCES DB.DBA.FUNCTIONS(FUNCTIONNAME)
 )
;

GRANT SELECT ON DB.DBA.REFENTRY TO PUBLIC
;

GRANT SELECT ON DB.DBA.FUNCTIONS TO PUBLIC
;

GRANT SELECT ON DB.DBA.PARAMETER TO PUBLIC
;


INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn__row',
'_ROW',
'sql',
'Special column consisting of a copy of the row@s internal representation.',
'
There is a special column _ROW that can be selected from any table.
The value of this column is a special string that contains all the column
values; i.e., a copy of the row@s internal representation.
This string can then be decomposed into the table and columns with the
row_table() and row_column() functions.

If the user does not have table-wide select privileges to the table
mentioned in the FROM clause of the SELECT that is accessing
_ROW, the code Diagnostics
42000 is returned as the SQL STATE for all operations
involving _ROW.  Separate privileges on all columns
do not suffice.

The _ROW is not updatable.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'_ROW',
'fn__row',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_mts_get_timeout',
'mts_get_timeout',
'2pc',
' returns timeout of distributed transaction in milliseconds.
     ',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'mts_get_timeout',
'fn_mts_get_timeout',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_mts_set_timeout',
'mts_set_timeout',
'2pc',
' sets timeout of distributed transaction. ',
' sets distributed transactions timeout. @timeout@ parameter 
	indicates amount of timoute in milliseconds. If it equals -1 then 
	default timeout of Virtuoso transaction is used (SQL_QUERY_TIMEOUT). 
	This function must be called directly after "SET MTS_2PC=1". The time
	 countdown begins at moment of changing first branch.  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'mts_set_timeout',
'fn_mts_set_timeout',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'timeout',
'mts_set_timeout',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_mts_status',
'mts_status',
'2pc',
' checks status of current transaction or server. ',
' Checks status of subject. Subject can be  either @MTS@ or 
	@TRANSACTION@. In the first case this checks if  the server is 
	connected to MTS. In the second case, checks if  2pc control is 
	enabled for the current transaction. This function returns status 
	string. For @MTS@ it could be either @connected@ or @disconnected@. 
	For @TRANSACTION@ - either @2pc enabled@ or @2pc disabled@. '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'mts_status',
'fn_mts_status',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'subject',
'mts_status',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_abs',
'abs',
'number',
'Return the absolute value of a number',
'abs returns the absolute value of its argument.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'abs',
'fn_abs',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'abs',
  'any/variable','in',
'Numeric value whose absolute value is to be
      returned'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn___any_grants',
'__any_grants',
'sql',
'Checks a table for grants.',
'The __any_grants() can be used to test whether there 
    are any rights granted (for insert/update/delete) to a table for 
    current SQL account.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'__any_grants',
'fn___any_grants',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tablename',
'__any_grants',
  'varchar','in',
'The table name to be tested.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_aref',
'aref',
'array',
'returns specific element of an array or string',
'aref returns the nth element of an array, string or string session, where nth is a zero-
    based index. If the first argument is a string or string session, the integer ASCII value of the
    nth character is returned. If the first argument is an
    array of any, then the corresponding element is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'aref',
'fn_aref',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'aref',
  'any/variable','',
'
        array, vector or string.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'nth',
'aref',
  'integer','',
'integer zero-based index.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ascii',
'ascii',
'string',
'Get ASCII value of a character',
'ascii returns the ASCII value of the first character of a string.  If an empty string is given, then zero is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ascii',
'fn_ascii',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'ascii',
  'any/variable','',
'A string '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_aset',
'aset',
'array',
'set array element',
'aset sets the nth element of a string, array or vector where nth
      is a zero-based index. If the first argument is a string, the nth
      character of string is replaced with the ASCII value given in the third
      argument elem.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'aset',
'fn_aset',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'aset',
  'any/variable','in',
'A string, array or vector.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'nth',
'aset',
  'integer','in',
'Zero-based element index.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_elem',
'aset',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_atof',
'atof',
'number',
'Convert a string to single precision float',
'atof returns its argument as a single precision floating point.
      If the string cannot be parsed and converted to a valid
      float, a value 0.0 is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'atof',
'fn_atof',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'atof',
  'varchar','in',
'A string input parameter'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_atoi',
'atoi',
'string',
'Convert a string to an integer',
'atoi returns its argument as an integer.
      If the string cannot be parsed and converted to a valid
      integer, a value 0 is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'atoi',
'fn_atoi',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'atoi',
  'varchar','in',
'A string input parameter'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_att_local_name',
'att_local_name',
'rmt',
'Compose a fully qualified table name based on DSN and remote table name.',
'The utility function, att_local_name(), can 
    be used to make a fully 
    qualified table name from non-qualified or qualified one, i.e. the qualifier 
    and owner will be added if they are missing.  The schema name will be 
    replaced with current qualifier on execuation, owner will be replaced 
    or added with name of supplied DSN name.  All non-alphanumeric characters 
    in the name will be replaced with undersore symbol.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'att_local_name',
'fn_att_local_name',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'att_local_name',
  'varchar','in',
'The name of remote data source.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table',
'att_local_name',
  'varchar','in',
'The name of remote table.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_backup',
'backup',
'backup',
'facilitate backup operations',
'All backup files, whether complete (created with
    backup) or partial (created with
    backup_prepare and backup_row
    of selected rows), begin with the complete schema that was effective at
    the time of the backup.Backup and log files contain assumptions about the schema and row
    layout of the database. Hence it is not possible to use these for
    transferring data between databases. Attempt to do so will result in
    unpredictable results.  Thus a log or backup may only be replayed on
    the same database, an empty database or a copy of the database which
    has had no schema changed since it was made.The backup function takes a file name as
      argument. The file produced will be in the log format and will recreate
      the database as it was at the time of the last checkpoint when replayed
      on an empty database. Such a file cannot be replayed on anything except
      an empty database. Logs made after the backup can be replayed over the
      database resulting from the backup file@s replay.  No schema operations
      are allowed between replays.The backup_prepare,
      backup_row and backup_close
      operations allow making specific partial backups.backup_prepare initiates the backup. This
        must be the first statement to execute in its transaction.  The
        rest of the transaction will be a read only snapshot view of the state
        as of the last checkpoint.  Checkpointing is disabled until
				backup_close is called.Checkpoints are disabled for the time between
      backup_prepare and
      backup_close.  The backup transaction being
      lock-free, it cannot die of deadlock and hence will stay open for the
      duration of the backup.backup_row writes the row given as
        parameter into the backup file that was associated to the current
        transaction by a prior backup_prepare. The row
        must be obtained obtained by selecting the pseudo column
        _ROW from any table.The backup_flush function will insert a
        transaction boundary into the backup log.  All rows backed up between
        two backup_flush calls will be replayed as a
        single transaction by replay.  Having long intervals between
        backup_flush calls will cause significant memory
        consumption at replay time for undo logs.The backup_close function terminates the
        backup and closes the file.  The transaction remains a read only
        snapshot of the last checkpoint but checkpoints are now re-enabled.
        The transaction should be committed or rolled back after
        backup_close.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'backup',
'fn_backup',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'file',
'backup',
  'varchar','in',
'varchar file filename for
      the generated log.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'backup_close',
'fn_backup',
'',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'backup_flush',
'fn_backup',
'',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'backup_prepare',
'fn_backup',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'file',
'backup_prepare',
  'varchar','in',
'varchar file filename for
      the generated log.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'backup_row',
'fn_backup',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row',
'backup_row',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_blob_to_string',
'blob_to_string',
'string',
'Convert a blob to string',
'Although primarily used for converting blobs (long varbinary, long varchar) to string, blob_to_string may also be used to convert from wide string, persistent XML (XPER) and string_output streams. If the data being converted is longer than maximum length of a string, blob_to_string will signal an error.This function is equivalent to cast (x as varchar).
      Using cast is preferred.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'blob_to_string',
'fn_blob_to_string',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'blob',
'blob_to_string',
  'blob','in',
'blob handle (long varbinary or long varchar), string_output or XPER (persistent XML)'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_blob_to_string_output',
'blob_to_string_output',
'string',
'Convert a blob to string session',
'Although primarily used for converting blobs (long varbinary, long varchar) to string output object, blob_to_string_output may also be used to convert from wide string, persistent XML (XPER) and string_output streams.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'blob_to_string_output',
'fn_blob_to_string_output',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'blob',
'blob_to_string_output',
  'blob','in',
'blob handle (long varbinary or long varchar), string_output or XPER (persistent XML)'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_bookmark',
'bookmark',
'cursors',
'Return the bookmark for current row of a scrollable cursor',
'bookmark returns a bookmark for the current row
    of an open scrollable cursor. Given an invalid argument, i.e. no cursor,
    no current row or non-open cursor, it signals an error. The returned
    value can be used in subsequent FETCH .. BOOKMARK over the same
    cursor.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'bookmark',
'fn_bookmark',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor',
'bookmark',
  'cursor handle','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ceiling',
'ceiling',
'number',
'Round a number to positive infinity.',
'ceiling calculates the smallest integer greater than or equal to x.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ceiling',
'fn_ceiling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'ceiling',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_item_count',
'cfg_item_count',
'admin',
'return number of items in a section in configuration file',
'Return the number of items that exist
    in the specified section of the INI file.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_item_count',
'fn_cfg_item_count',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_item_count',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'section',
'cfg_item_count',
  'varchar','in',
'Name of the section in the INI file.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_item_name',
'cfg_item_name',
'admin',
'get nth item name from ini file',
'Returns the name of the item specified by item_index
    (begins from zero). If the index and secion name do not point
    to a valid item, then zero is returned, otherwise on success the
    function returns the item name.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_item_name',
'fn_cfg_item_name',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_item_name',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'section',
'cfg_item_name',
  'varchar','in',
'Name of the section in the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item_index',
'cfg_item_name',
  'integer','in',
'Zero based index to the item within the section to be listed.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_item_value',
'cfg_item_value',
'admin',
'returns the value of an item from the ini file',
'Return the value of an item identified
    by item_name and section
    paramaters from the specified INI file.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_item_value',
'fn_cfg_item_value',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_item_value',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'section',
'cfg_item_value',
  'varchar','in',
'Name of the section in the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item_name',
'cfg_item_value',
  'varchar','in',
'Name of the item in the section.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_section_count',
'cfg_section_count',
'admin',
'get number of sections in an INI file',
'Returns the number of sections in an INI file.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_section_count',
'fn_cfg_section_count',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_section_count',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_section_name',
'cfg_section_name',
'admin',
'returns INI file section name',
'Returns the name of section specified by the index
    (begins from zero). If the index can reference a section, the that
    section name is returned, otherwise returns zero on error.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_section_name',
'fn_cfg_section_name',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_section_name',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'index',
'cfg_section_name',
  'integer','in',
'Zero based index that references a section.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_cfg_write',
'cfg_write',
'admin',
'Writes the item=value to an INI file',
'This function allows modification of existing entries, or update
    updating existing items in an INI file.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cfg_write',
'fn_cfg_write',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'cfg_write',
  'varchar','in',
'Name of the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'section',
'cfg_write',
  'varchar','in',
'Name of the section in the INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item_name',
'cfg_write',
  'varchar','in',
'Name of item that will be assigned the item_value.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item_value',
'cfg_write',
  'varchar','in',
'Value to be assigned to the item_name.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_charset_define',
'charset_define',
'localization',
'Define a character set.',
'This function creates a new narrow
    language-specific character set, or redefines an existing one.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'charset_define',
'fn_charset_define',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'name',
'charset_define',
  'varchar','in',
'The name of the character set to define.  This becomes the "preferred" name of the character set.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'charset_string',
'charset_define',
  'varchar','in',
'Wide string with the character codes for each given character
from 1 to 255.  That is, a 255-byte long NCHAR defining the Unicode
codes for narrow chars 1-255.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'aliases',
'charset_define',
  'any/variable','in',
'Vector of character set names that are to be aliases of the character set being defined. Use NULL if there are to be no aliases.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_charset_recode',
'charset_recode',
'localization',
'Translate a string to another character set',
'This function translates a string from a given source charset to a destination charset.  It provides a generic way of recoding string entities.The src_charset may be a narrow or a wide string. If it@s a narrow string (VARCHAR) then the src_charset is taken into account and defines the current encoding of the src_string.  In any other case src_charset is ignored.src_charset and dst_charset are names of system-defined 8 bit charset tables. Use charsets_list to obtain a list of currently defined character sets and aliases. If either of these is null, then the charset in effect is used. There are two special character set names - "UTF-8" and "_WIDE_" - that are recognized by this function. These represent UTF-8 encoding of characters and wide string (NVARCHAR).'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'charset_recode',
'fn_charset_recode',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'src_string',
'charset_recode',
  'varchar','in',
'The input data to be converted. String or wide string.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'src_charset',
'charset_recode',
  'varchar','in',
'Input data character set, string.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dst_charset',
'charset_recode',
  'varchar','in',
'The charset to convert to, string.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_charsets_list',
'charsets_list',
'localization',
'List known character set names and aliases.',
'This function produces a list of all character set names and aliases
      known to Virtuoso. The returned value is an array
      of strings with a character set name as each element.
      If the gen_res_set flag is 1, the function also
      produces a result set in which each row contains one varchar column with
      a name of a character set or alias.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'charsets_list',
'fn_charsets_list',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gen_res_set',
'charsets_list',
  'integer','in',
'Integer flag to determine whether to produce a result set: 0 means no, 1 means yes.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_checkpoint_interval',
'checkpoint_interval',
'admin',
'Configure database checkpointing',
'This function changes the database checkpointing interval to the given
      value in minutes. It may also be used to disable checkpointing in two
      ways: By setting checkpoint interval to 0, the checkpoint will only be
      performed after roll forward upon database startup. A setting of -1
      will disable all checkpointing. Main use for this function is to
      ensure a clean online backup of the database slices. Copying of the
      database may take long and checkpointing would modify those files in
      mid-copy, thus rendering the resulting copy unusable. In case the
      system should, for some reason or another, become unstable, it is
      sometimes better to disable checkpointing after a database restart
      to resume backing up from where it was left prior to a system crash.
      Disabling all checkpointing by giving checkpoint_interval the value
      of -1 will do just that.The interval setting will be saved in the server configuration
      file as value of CheckpointInterval in section [Parameters], thus it
      will persist over consecutive server shutdown/restart cycles. A
      long checkpoint_interval setting will produce longer transaction
      logs, which in turn prolongs the time it takes for the database to
      perform a roll forward upon restart in case it was shut down without
      making a checkpoint.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'checkpoint_interval',
'fn_checkpoint_interval',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'minutes',
'checkpoint_interval',
  'integer','in',
'integer number of minutes between checkpoints.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_chr',
'chr',
'string',
'Convert a long character code to a character or wide character',
'chr returns a new one character long string
    containing the character with character code given as parameter.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'chr',
'fn_chr',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'chr_code',
'chr',
  'long','in',
'The LONG character code value for the character or wide character to be produced.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_complete_table_name',
'complete_table_name',
'sql',
'Returns a fully qualified table name.',
'The complete_table_name() can be used to make a 
    fully qualified table name from non-qualified one, i.e. the qualifier and 
    owner will be added if they are missing.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'complete_table_name',
'fn_complete_table_name',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tablename',
'complete_table_name',
  'varchar','in',
'The table name to be retrieved.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'complete_table_name',
  'integer','in',
'If this mode parameter is set to 1 this function will first look-up 
      the supplied tablename for a match in the system tables.  If a match is found 
      the full name will be returned, if the table is not found the function 
      will continue as if the mode were set to 0.When the mode parameter is 0 the result will be generated using 
      the current qualifier and current SQL user account names.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_composite',
'composite',
'misc',
'create a composite object',
'Create a composite objectReturns a composite object containing the serialization of each argument.
      The total serialized length of the arguments may not exceed 255.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'composite',
'fn_composite',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'composite',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'composite',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_composite_ref',
'composite_ref',
'misc',
'get member of a composite object',
'composite_ref returns the nth
      element of the composite. The index is 0 based.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'composite_ref',
'fn_composite_ref',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'c',
'composite_ref',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'nth',
'composite_ref',
  'integer','in',
'integer'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_concat',
'concat',
'array',
'Concatenate strings',
'concat returns a new string,
    concatenated from a variable number of strings given as
    arguments. NULL arguments are handled as empty strings.concat (str) returns a copy of
    str. concat () returns an empty
    string.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'concat',
'fn_concat',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str1',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str2',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'concat',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strn',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_concatenate',
'concatenate',
'array',
'concatenate strings',
'Concatenate is an alias of
      concat.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'concatenate',
'fn_concatenate',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg_1',
'concatenate',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'concatenate',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_get',
'connection_get',
'ws',
'Get connection variable',
'connection_get is used to retrieve values
    stored within the current connection context. See
    connection_set
    for a more detailed discussion of connection variables.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_get',
'fn_connection_get',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'name',
'connection_get',
  'varchar','in',
'Name of the connection variable'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_id',
'connection_id',
'misc',
'get connection identifier',
'This function returns a string uniquely identifying the connection
    in this server instance. It is usually a combination of server@s
    port number and a serial number of the client.The value returned is usually not useful in HTTP invocation
    context (VSP or SOAP), since consecutive requests by the same client will
    typically not be on the same connection the way the server sees
    it.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_id',
'fn_connection_id',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_is_dirty',
'connection_is_dirty',
'ws',
'check if current session connection variables have been altered',
'This function is used to determine if the session variables
    have changed between a call to
    connection_vars_set and current point of execution. A call to
    connection_vars_set
    will cause subsequent calls to connection_is_dirty
    to return true.The function is useful in postprocessing functions
    for making conditional storage of session variables in a database
    table.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_is_dirty',
'fn_connection_is_dirty',
'integer',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_set',
'connection_set',
'misc',
'Associates a value to the name in the context of the present connection',
'This associates a value to the name in the context of present
    connection. The name should be a string and the value can be any
    data type except blob, open cursor or an XML entity.
    If the value is an array it may not contain the restricted types.Connection variable setting is not logged and information
    stored will be lost when the connection is closed.
    The value can be retrieved by any future statement executing within
    the same connection. Connection variables can
    be used as a global variable mechanism for stored procedures, the
    scope being the client connection.In the case of VSP or SOAP this mechanism cannot be used to
    pass information between requests by the same client. It will however,
    be useful for having @global variables@ between procedures called
    within the same HTTP request.
Note that this mechanism is used to provide persistent HTTP session variables in some cases but this works through special before and after code which stores the values set with this function into an external session structure.  In this sense this function itself has nothing to do with web session management although it can be used as a component for such.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_set',
'fn_connection_set',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'name',
'connection_set',
  'varchar','in',
'VARCHAR name to associate the value with.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'value',
'connection_set',
  'any/variable','in',
'value to be stored. May be any data type
      except LOB, open cursor or XML entity.  If the value is an
      array, it may not contain the restricted types.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_vars',
'connection_vars',
'ws',
'Retrieve all connection variables',
'
This function returns all stored session variables in an array with
name/value pairs.

Connection variables do not persist across sessions, one
may maintain persistence of variables by storing them in a database table:
see the Session Variables Section.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_vars',
'fn_connection_vars',
'any',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_connection_vars_set',
'connection_vars_set',
'misc',
'set all connection variables',
'This function clears all connection variables for current
    session and sets new ones defined in the array passed as parameter.
    Connection variables do not persist across sessions, one
    may maintain persistence of variables by storing them in a database
    table, as discussed in Session Variables
    -section.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'connection_vars_set',
'fn_connection_vars_set',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'var_array',
'connection_vars_set',
  'array','in',
'An array of even number of elements, containing
      name-value pairs. NULL, will cause all connection variables for current
      connection to be erased.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_contains',
'contains',
'ft',
'A text contains predicate',
' This is a SQL predicate that specifies a condition on a column
      on which a free text index exists.  The expression is a
      string matching the grammar of a text search expression.
      This is computed for each evaluation of the contains predicate and
      does not have to be a constant. For example a parameter or variable
      of a containing score (e.g. procedure) is accepted. The score_limit is optional. If
      specified, it should be a numeric expression determining the minimum score
      required to produce a hit.A virtual column named @SCORE@ is available in queries
      involving a contains predicate. This can for
      example be returned in a result set or used for sorting.
      Note that the name is in upper case and is case sensitive in all
      case modes.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'contains',
'fn_contains',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'column',
'contains',
  'varchar','',
'The table column whose contents are free text indexed'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'expression',
'contains',
  'varchar','',
'A string matching the grammar of a text search
      expression.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'opt_or_value',
'contains',
  'integer','',
'May be one or more of the following:
        
	  
	    DESCENDING
	    
	      specifies that the search will produce the hit with the
	      greatest id first, as defined by integer or
	      composite collation.
	    
	  
	  
	    START_ID @,@
	    scalar_exp
	    
	      the first allowed document id to be selected by the
	      expression in its traversal order, e.g. least or equal for
	      ascending and greatest or equal for descending.
	    
	  
	  
	    END_ID @,@
	    scalar_exp
	    
	      the last allowed id in the traversal order.  For
	      descending order the START_ID must be >=
	      END_ID for hits to
	      be able to exist. For ascending order the
	      START_ID must be <=
	      END_ID for hits to be able to
	      exist.
	    
	  
	  
	    SCORE_LIMIT @,@
	    scalar_exp
	    
	      Minimum score that hits must have or exceed to be
	      considered matches of the predicate.
	    
	  
	  
	    RANGES @,@
	    scalar_exp
	    
	      specifies that the query variable following the
	      RANGES keyword will be bound to the word
	      position ranges of the hits of the expression inside the
	      document.  The variable is in scope inside the enclosing
	      SELECT statement.
	    
	  
	  
	    OFFBAND @,@column
	    
	      Specifies that the following column will be
	      retrieved from the free text index instead of the
	      actual table.  For this to be possible the column must have
	      been declared as offband with the CLUSTERED WITH
	       option of the CREATE TEXT INDEX statement.
	    
	  
	
      specifies that the search will produce the hit with the
	      greatest id first, as defined by integer or
	      composite collation.the first allowed document id to be selected by the
	      expression in its traversal order, e.g. least or equal for
	      ascending and greatest or equal for descending.the last allowed id in the traversal order.  For
	      descending order the START_ID must be >=
	      END_ID for hits to
	      be able to exist. For ascending order the
	      START_ID must be <=
	      END_ID for hits to be able to
	      exist.Minimum score that hits must have or exceed to be
	      considered matches of the predicate.specifies that the query variable following the
	      RANGES keyword will be bound to the word
	      position ranges of the hits of the expression inside the
	      document.  The variable is in scope inside the enclosing
	      SELECT statement.Specifies that the following column will be
	      retrieved from the free text index instead of the
	      actual table.  For this to be possible the column must have
	      been declared as offband with the CLUSTERED WITH
	       option of the CREATE TEXT INDEX statement.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_curdate',
'curdate',
'time',
'get current date and time',
'These functions return the current date or time as a date,
    time or datetime, respectively. Internally they all return the
    same value but data type reported to client differs.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'curdate',
'fn_curdate',
'date',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'curdatetime',
'fn_curdate',
'datetime',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'curtime',
'fn_curdate',
'time',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_current_charset',
'current_charset',
'i18n',
'Get name of current charset.',
'This function returns the "preferred" name of the current charset as a string.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'current_charset',
'fn_current_charset',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dateadd',
'dateadd',
'time',
'arithmetic add to a date',
'dateadd adds a positive or negative quantity of units to a date
    (in the internal date time format), and returns a new date so formed.
    The unit is specified as a string and can be one of the following:
    @second@, @minute@, @hour@, @day@, @month@, or @year@.
    Use datestring to convert the result to a human-readable string.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dateadd',
'fn_dateadd',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'unit',
'dateadd',
  'varchar','in',
'String value denoting the unit to use in the addition.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'number',
'dateadd',
  'integer','in',
'Integer number of unit units to be added.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'date',
'dateadd',
  'datetime','in',
'Datetime value to which the number
      of units is to be added'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_datediff',
'datediff',
'time',
'get difference of 2 dates',
'datediff subtracts date1 from date2 and returns the difference as
    an integer in the specified units.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'datediff',
'fn_datediff',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'unit',
'datediff',
  'varchar','in',
'The resulting unit name as a string. May be @second@, @minute@, @hour@, @day@,
      @month@, or @year@'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'date1',
'datediff',
  'datetime','in',
'The datetime value that will be subtracted from
      date2'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'date2',
'datediff',
  'datetime','in',
'The datetime value date1
      is subtracted from'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_datestring',
'
      datestring,
      datestring_GMT,
    ',
'time',
'convert a timestamp from internal to external
    date-time representation',
'datestring and datestring_gmt convert
    timestamps or datetimes
    from internal to external date-time representation.  The internal
    representation is an 8 byte binary string
    of the special type TIMESTAMP_OBJ, documented elsewhere
    and the external representation is a human-readable ASCII string of
    up to 30 characters. The external format is:
    YYYY-MM-DD hh:mm:ss uuuuuu
    where uuuuuu represents
    microseconds.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'datestring',
'fn_datestring',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'date',
'datestring',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_datestring_gmt',
'datestring_GMT',
'time',
'convert a timestamp to external format string in GMT',
'Converts the local datetime to GMT and returns its
    external representation as a string.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'datestring_GMT',
'fn_datestring_gmt',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'datestring_GMT',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dav_api_add',
'DAV add & update functions',
'ws',
'functions for adding, updating, deleting of DAV collections or resources',
'DAV_COL_CREATE creates a new collection on path, with supplied security permissions,
  returning a collection id (COL_ID) upon success.DAV_RES_UPLOAD creates or replaces an existing resource on path with content, mime type and supplied security permissions. Returns a resource id (RES_ID) on success.DAV_DELETE Removes an existing collection/resource.
    If silent is set to a nonzero value,  no errors codes will be returned.
  returns 1 on success.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_COL_CREATE',
'fn_dav_api_add',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_COL_CREATE',
  'varchar','in',
'Collection (directory) path and name of destination of upload.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'permissions',
'DAV_COL_CREATE',
  'varchar','in',
'Access permission string of Dav collection or resource.
      Defaults to @110100000R@ if not supplied.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uname',
'DAV_COL_CREATE',
  'varchar','in',
'Owner user name. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gname',
'DAV_COL_CREATE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_COL_CREATE',
  'varchar','in',
'Name of administration user capable of performing the operation.
      default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_COL_CREATE',
  'varchar','in',
'Administrator password. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_DELETE',
'fn_dav_api_add',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_DELETE',
  'varchar','in',
'Collection (directory) path and name of destination of upload.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'silent',
'DAV_DELETE',
  'integer','in',
'If non-zero, no errors will be returned.
      Default is 0, meaning errors are returned.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_DELETE',
  'varchar','in',
'Name of administration user capable of performing the operation.
      default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_DELETE',
  'varchar','in',
'Administrator password. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_RES_UPLOAD',
'fn_dav_api_add',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_RES_UPLOAD',
  'varchar','in',
'Collection (directory) path and name of destination of upload.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content',
'DAV_RES_UPLOAD',
  'any/variable','in',
'The resource data to upload.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'type',
'DAV_RES_UPLOAD',
  'varchar','in',
'Mime type of the uploaded resource.
      Defaults to @@ if not supplied.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'permissions',
'DAV_RES_UPLOAD',
  'varchar','in',
'Access permission string of Dav collection or resource.
      Defaults to @110100000R@ if not supplied.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uname',
'DAV_RES_UPLOAD',
  'varchar','in',
'Owner user name. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gname',
'DAV_RES_UPLOAD',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_RES_UPLOAD',
  'varchar','in',
'Name of administration user capable of performing the operation.
      default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_RES_UPLOAD',
  'varchar','in',
'Administrator password. Default is null.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dav_api_change',
'DAV manipulation functions',
'ws',
'Functions for manipulating an existing DAV
    collection or resource',
'DAV_COPY copies the resource or collection taken from path to the destination.
  returns COL_ID or RES_ID on success.DAV_MOVE moves the collection or resource to the destination path
  returns 1 on success.DAV_PROP_SET defines or updates the property with name @propname@
    with propvalue. Returns PROP_ID on success.DAV_PROP_REMOVE removal of the existing property on target path.
    If silent supplied then no error will be returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_COPY',
'fn_dav_api_change',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_COPY',
  'varchar','in',
'Directory and name of source to be operated on.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'destination',
'DAV_COPY',
  'varchar','in',
'Directory and name of destination.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'overwrite',
'DAV_COPY',
  'integer','in',
'If non zero then overwrite is enabled. Default is 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'permissions',
'DAV_COPY',
  'varchar','in',
'Access permission of Dav collection or resource.
      Defaults to @110100000R@ if not supplied.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uname',
'DAV_COPY',
  'varchar','in',
'User identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gname',
'DAV_COPY',
  'varchar','in',
'Group identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_COPY',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_COPY',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_MOVE',
'fn_dav_api_change',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_MOVE',
  'varchar','in',
'Directory and name of source to be operated on.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'destination',
'DAV_MOVE',
  'varchar','in',
'Directory and name of destination.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'overwrite',
'DAV_MOVE',
  'integer','in',
'If non zero then overwrite is enabled. Default is 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_MOVE',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_MOVE',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_PROP_REMOVE',
'fn_dav_api_change',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_PROP_REMOVE',
  'varchar','in',
'Directory and name of source to be operated on.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'propname',
'DAV_PROP_REMOVE',
  'varchar','in',
'Property name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'silent',
'DAV_PROP_REMOVE',
  'integer','in',
'If specified as non zero, then no error will be returned.
      Default is 0, so errors are returned.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_PROP_REMOVE',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_PROP_REMOVE',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_PROP_SET',
'fn_dav_api_change',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_PROP_SET',
  'varchar','in',
'Directory and name of source to be operated on.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'propname',
'DAV_PROP_SET',
  'varchar','in',
'Property name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'propvalue',
'DAV_PROP_SET',
  'any/variable','in',
'Property value.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uname',
'DAV_PROP_SET',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_PROP_SET',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dav_api_search',
'DAV search functions',
'ws',
'Functions for searching a DAV collection or resource',
'DAV_SEARCH_ID() returns the RES_ID or COL_ID, depending on the
    @what@ parameter passed. (@R@esource or @C@ollection
    or @P@arent collection).DAV_SEARCH_PATH() returns full path string of resource or collection,
    depending on parameter passed. (@R@esource or @C@ollection or
    @P@arent collection).DAV_DIR_LIST() returns an array of arrays that contains the
    following information about the requested path:'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_DIR_LIST',
'fn_dav_api_search',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_DIR_LIST',
  'varchar','in',
'Name of DAV location to search.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'recursive',
'DAV_DIR_LIST',
  'integer','in',
'If non zero then recurse into subdirectories during the search.
      Default is 0 which causes a search in current path only.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uid',
'DAV_DIR_LIST',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_DIR_LIST',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_SEARCH_ID',
'fn_dav_api_search',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'DAV_SEARCH_ID',
  'varchar','in',
'Name of DAV location to search.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'what',
'DAV_SEARCH_ID',
  'char(1)','in',
'The type of DAV item to search for: @R@ for resource,
      @C@ for collection or @P@ for parent collection.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_SEARCH_PATH',
'fn_dav_api_search',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'id',
'DAV_SEARCH_PATH',
  'integer','in',
'Identifier of resource or collection, for example
      from DAV_SEARCH_ID().'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'what',
'DAV_SEARCH_PATH',
  'char(1)','in',
'The type of DAV item to search for: @R@ for resource,
      @C@ for collection or @P@ for parent collection.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dav_api_user',
'WebDAV Users & Groups administration',
'ws',
'Functions for manipulating an existing DAV
    collection or resource',
'DAV_ADD_USER() create a new WebDAV user with login name @uid@
    and password @pwd@. User will belong to the group named @gid@.
     @perms@ are the default user permissions for creation of new
     resources. Additional user info supplied is @home@ directory,
     @full name@ and @e-mail@.DAV_DELETE_USER() remove the existing webDAV user named @uid@.DAV_HOME_DIR() returns the home folder for specified WebDAV user
    named @uid@.DAV_ADD_GROUP() create a new webDAV group named @gid@.DAV_DELETE_GROUP() remove the existing webDAV group named @gid@.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_ADD_GROUP',
'fn_dav_api_user',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gid',
'DAV_ADD_GROUP',
  'varchar','in',
'Group identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uid',
'DAV_ADD_GROUP',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_ADD_GROUP',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_ADD_USER',
'fn_dav_api_user',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uid',
'DAV_ADD_USER',
  'varchar','in',
'User identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'pwd',
'DAV_ADD_USER',
  'varchar','in',
'Password'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gid',
'DAV_ADD_USER',
  'varchar','in',
'Group identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'permis',
'DAV_ADD_USER',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'disable',
'DAV_ADD_USER',
  'integer','in',
'Disable flag'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'home',
'DAV_ADD_USER',
  'varchar','in',
'The User@s home directory path'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'full_name',
'DAV_ADD_USER',
  'varchar','in',
'Full name of user'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'email',
'DAV_ADD_USER',
  'varchar','in',
'User@s email'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uid',
'DAV_ADD_USER',
  'varchar','in',
'User identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uid',
'DAV_ADD_USER',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_ADD_USER',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_DELETE_GROUP',
'fn_dav_api_user',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'gid',
'DAV_DELETE_GROUP',
  'varchar','in',
'Group identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uid',
'DAV_DELETE_GROUP',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_DELETE_GROUP',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_DELETE_USER',
'fn_dav_api_user',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uid',
'DAV_DELETE_USER',
  'varchar','in',
'User identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_uid',
'DAV_DELETE_USER',
  'varchar','in',
'Administration user capable of performing the operation.
      Default is null.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_pwd',
'DAV_DELETE_USER',
  'varchar','in',
'Password of Administrator. Default is null.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_HOME_DIR',
'fn_dav_api_user',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uid',
'DAV_HOME_DIR',
  'varchar','in',
'User identifier. Default is @dav@.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dav_exp',
'DAV_EXP',
'ws',
'Export a retrieved Web site to another WebDAV enabled server',
'This function is used to export local content retrieved from a Web Robot Copy
to the local file system.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'DAV_EXP',
'fn_dav_exp',
'WS.WS.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'host',
'DAV_EXP',
  'varchar','in',
'The target host name'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'url',
'DAV_EXP',
  'varchar','in',
'start path on target'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root',
'DAV_EXP',
  'varchar','in',
'local WebDAV collection that contains the retrieved content'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dst',
'DAV_EXP',
  'varchar','in',
'absolute URL to the WebDAV folder to export content to'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dayname',
'dayname',
'time',
'decompose a datetime to its components',
'These functions decompose a datetime to its components.  These can be used on timestamps, datetimes, dates and times, all being the same internal data type.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayname',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayname',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofmonth',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofmonth',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofweek',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofweek',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofyear',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofyear',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'hour',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'hour',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'minute',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'minute',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'month',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'month',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'monthname',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'monthname',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'quarter',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'quarter',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'second',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'second',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'timezone',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'timezone',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'week',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'week',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'year',
'fn_dayname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'year',
  'datetime','in',
'A datetime value.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dayofmonth',
'dayofmonth',
'date',
'get day of month from a datetime',
'dayofmonth takes a datetime and returns 
    an integer containing day of the month represented by the datetime'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofmonth',
'fn_dayofmonth',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofmonth',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dayofweek',
'dayofweek',
'date',
'get day of week from a datetime',
'dayofweek takes a datetime and returns 
    an integer containing a number representing the day of week of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofweek',
'fn_dayofweek',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofweek',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dayofyear',
'dayofyear',
'date',
'get day of year from a datetime',
'dayofyear takes a datetime and returns 
    an integer containing a number representing the day of year of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dayofyear',
'fn_dayofyear',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dayofyear',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dbg_obj_print',
'dbg_obj_print',
'debug',
'print to the Virtuoso system console',
'dbg_obj_print prints a variable number of
    arguments onto the system console (stdout) of Virtuoso server, each
    argument in its own native format, on the same line, which is followed
    by one newline. '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dbg_obj_print',
'fn_dbg_obj_print',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'dbg_obj_print',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'dbg_obj_print',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dbg_printf',
'dbg_printf',
'debug',
'print formatted output onto the system console',
'dbg_printf prints a variable number
      (max. eight) of arguments to the system console of Virtuoso server,
      each argument formatted in C printf style,
      according to the format string specified in the first argument.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dbg_printf',
'fn_dbg_printf',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'format',
'dbg_printf',
  'varchar','in',
'a C sprintf -style format string'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'dbg_printf',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'dbg_printf',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'argn',
'dbg_printf',
  'any/variable','in',
'The arguments to format and print in any type'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dbname',
'dbname',
'misc',
'get current catalog',
'Returns the current qualifier as set by the USE statement or default.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dbname',
'fn_dbname',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_delay',
'delay',
'sql',
'sleep for n seconds',
'This will halt calling procedure execution for specified 
    interval in seconds.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'delay',
'fn_delay',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'n_seconds',
'delay',
  'integer','in',
'INTEGER number of seconds to sleep.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_disconnect_user',
'disconnect_user',
'admin',
'Disconnect client connections of a given user',
'disconnect_user disconnects clients whose
      username matches the username_pattern string given as an argument, and
      returns an integer value giving the number of clients disconnected.
      This can be used after DELETE USER or REVOKE statement to make sure that
      the affected user has no open connections.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'disconnect_user',
'fn_disconnect_user',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'username_pattern',
'disconnect_user',
  'varchar','in',
'A string pattern to match users to be disconnected. SQL wildcards
      including Virtuoso extensions may be used.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dt_set_tz',
'dt_set_tz',
'time',
'modifies the timezone component of a datetime',
'This modifies the timezone component of a datetime.
    The value remains equal for purposes of comparison but will look
    different when converted to a string.  The  timezone component is an
    offset from UTC in minutes. It can be retrieved with the timezone
    function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dt_set_tz',
'fn_dt_set_tz',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'dt_set_tz',
  'datetime','in',
'The original DATETIME.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tz',
'dt_set_tz',
  'integer','in',
'INTEGER new timezone offset.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_dvector',
'dvector',
'array',
'return an array of either long, float or double',
'
These functions are like vector but return an array of either long, float or double whereas
vector returns a generic, untyped array.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'dvector',
'fn_dvector',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt1',
'dvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'....',
'dvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt-n',
'dvector',
  '','',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'fvector',
'fn_dvector',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt1',
'fvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'....',
'fvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt-n',
'fvector',
  '','',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lvector',
'fn_dvector',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt1',
'lvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'....',
'lvector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elt-n',
'lvector',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_end_result',
'end_result',
'sql',
'End the current result set.',
'The result_names()
predefines variables to be used in a result set to follow.  The variables must 
be previously declared, from which the column data types are ascertained.  
This assigns the meta data but does not send any results.  The 
result() function sends its parameters as a single row 
of results.  These parameters should be compatible with those in the previous 
result_names().  The end_end_results() 
function can be used to separate multiple result sets.  The 
result_names() can then be used to alter the result 
set structure.The result_names() call can be omitted if 
the application already knows what columns and their types are to be returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'result',
'fn_end_result',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_either',
'either',
'misc',
'conditionally return one of specified parameters',
'either returns a copy of arg1 if cond is something
      else than integer 0 (zero). Otherwise, a copy of arg2 is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'either',
'fn_either',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cond',
'either',
  'any/variable','in',
'Anything'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'either',
  'any/variable','in',
'Anything'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'either',
  'any/variable','in',
'Anything'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_elh_get_handler',
'elh_get_handler',
'Virtuoso C API - localization',
'get localization function handler',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'elh_get_handler',
'fn_elh_get_handler',
'encodedlang_handler_t *',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'encoding',
'elh_get_handler',
  '_handler_t * encoding','',
'Name of the encoding to be used.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'language',
'elh_get_handler',
  '_handler_t * language','',
'Name of the text language'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_elh_load_handler',
'elh_load_handler',
'localization',
'load encoding handler into system',
'
Loads given handler in table of handlers bound to encoding specified in the
handler, using ISO 639 and RFC 1766 language IDs of the handler as keys for future table lookups.
If another handler was already specified for given RFC 1766 id, table entry
will be updated and will refer to new handler. If another handler was already
specified for given ISO 639 id, it will be replaced only if new handler has
ISO 639 language ID equal to its RFC 1766 ID.
Please do not load custom versions of @x-any@ and @x-ftq-x-any@ handlers.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'elh_load_handler',
'fn_elh_load_handler',
'int',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_handler',
'elh_load_handler',
  '','encodedlang_handler_t *',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_encode_base64',
'encode_base64',
'ws',
'base64-encode/decode a string',
'These functions convert strings from/to base64-encoding.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'decode_base64',
'fn_encode_base64',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'decode_base64',
  'varchar','in',
'A varchar value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'encode_base64',
'fn_encode_base64',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'encode_base64',
  'varchar','in',
'A varchar value.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_equ',
'equ',
'number',
'comparison functions',
'These functions return 1 if their first argument is less than (lt),
    less than or equivalent (lte), greater than (gt), greater than or
    equivalent (gte), equivalent (equ), or not equivalent (neq) to the
    second argument, respectively. If the arguments are not of the same type,
    then an appropriate type coercion is done for them before
    comparison. These functions correspond to SQL query operators <, <=, >,
    >=, = and <> and are needed because the SQL syntax does not
    allow these operators to be used on the left side of
    FROM keyword in a SELECT
    statement.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'equ',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'equ',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'equ',
  'any/variable','',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'gt',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'gt',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'gt',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'gte',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'gte',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'gte',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lt',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'lt',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'lt',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lte',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'lte',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'lte',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'neq',
'fn_equ',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'neq',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'neq',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_exec',
'exec',
'sql',
'dynamic execution of SQL returning state and result set',
'This function provides dynamic SQL capabilities in Virtuoso PL.
    The first argument is an arbitrary SQL statement, which may contain
    parameter placeholders. The function returns as output parameters a
    SQL state, error message, column metadata and result set rows if
    the statement is a select.A stored procedure can be invoked by exec but a procedure@s
    result set will not be received in the rows output parameter but rather
    sent to the client.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'exec',
'fn_exec',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'exec',
  'varchar','in',
'A varchar containing arbitrary SQL using ?@s for parameter markers.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'state',
'exec',
  'varchar','out',
'An output parameter of type varchar set to the 5 character SQL state if the exec resulted an error. Not set if an error is not present.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'message',
'exec',
  'varchar','out',
'An output parameter of type varchar set to SQL error message associated with the error. Not set if an error is not present.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'params',
'exec',
  'any/variable','in',
'A vector containing the parameters for the SQL being executed. Element 0 corresponding to first ?, etc.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'maxrows',
'exec',
  'integer','in',
'The integer maximum number of rows to retrieve in case of a statement returning a result set.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'metadata',
'exec',
  'vector','out',
'An output parameter of type vector returning the metadata of the statement and its result.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'rows',
'exec',
  'vector','out',
'An output array with one element per result row containing an array with the leftmost column as element 0 and so forth.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'exec',
  'cursor handle','out',
'The cursor handle for use with related functions.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_exec_close',
'close',
'sql',
'Closes cursor created by exec()',
'Closes the cursor opened by the exec() function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'exec_close',
'fn_exec_close',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'exec_close',
  'cursor handle','in',
'The cursor handle used.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_exec_next',
'exec_next',
'sql',
'Get next result from a result set',
'Use exec_next() to
    iterate over a result set produced by a statement run 
    with exec.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'exec_next',
'fn_exec_next',
'integer retcode',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'exec_next',
  'cursor handle','in',
'The long cursor handle as obtained from exec().'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row_array',
'exec_next',
  'array','out',
'An output vector that will contain the result 
      columns.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_state',
'exec_next',
  'varchar','out',
'Optional varchar output parameter for SQL state.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_error',
'exec_next',
  'varchar','out',
'Optional varchar output parameter for any error 
      message.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_exp',
'exp',
'number',
'calculate exponent',
'The function raises e to the power of x, it
    works with double precision floating point numbers, converts its argument
    to an IEEE 64-bit float and returns a result of that type.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'exp',
'fn_exp',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'exp',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_explain',
'explain',
'debug',
'describe SQL statement compilation',
'The explain function compiles a SQL statement and returns
      a description of the compilation as a result set. The set consists
      of one column, a varchar, which corresponds to each line of the
      description but may be long, several hundred characters.The output is not a complete disassembly of the query graph but
      is detailed enough to show the join order, subquery structure and the
      order of evaluation of predicates as well as the splitting of a
      distributed VDB query over different data sources.The optional cursor type can be one of the SQL_CURSOR_<xx>
      constants. The default is 0, for forward only. If the statement is a
      SELECT and the cursor type is not forward only, the auxiliary SQL
      statements used by the cursor implementation are shown.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'explain',
'fn_explain',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'text',
'explain',
  'varchar','in',
'varchar SQL statement'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'cursor_type',
'explain',
  'integer','in',
'integer cursor type',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_file_to_string',
'file_to_string',
'string',
'returns the contents of a file as a varchar',
'Returns the contents of a file as a varchar value. The file@s
    length is limited to 16 MB. The path is relative to the working directory
    of the database server.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'file_to_string',
'fn_file_to_string',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'file_to_string',
  'varchar','in',
'Path name of the file to read.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_file_to_string_output',
'file_to_string_output',
'stream',
'get contents of a file as a string output stream',
'This function returns a   string output stream
    initialized to contain the text of the file or its segment, on local file system path
    relative to the server@s working directory.file_to_string_output can handle longer
    files than
    file_to_string
    and the resulting string output, if too long to be converted into
    a varchar, can be stored inside a blob.Access controls in the server configuration file apply. An attempt
    to access a file in a directory where access is not explicitly allowed will signal an error.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'file_to_string_output',
'fn_file_to_string_output',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'file',
'file_to_string_output',
  'varchar','in',
'a varchar path relative to server@s working directory.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'from',
'file_to_string_output',
  'integer','in',
'an optional integer byte offset of the start of the segment to
      extract. Defaults to 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'to',
'file_to_string_output',
  'integer','in',
'an optional integer byte offset of the end of the requested segment.
      Defaults to file length.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_fk_check_input_values',
'fk_check_input_values',
'',
'alter default foreign key checking behavior',
'
Enforcing foreign key constraints is enabled by default.
This function allows globally disabling it without however disabling all triggers.
This may be useful for large data imports or other special circumstances.
The return value is the previous state of this setting, 0 for off, 1, for on.  The effect of this function is persistent and survives server restart.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'fk_check_input_values',
'fn_fk_check_input_values',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'fk_check_input_values',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_floor',
'floor',
'number',
'Round a number to negative infinity.',
'floor calculates the largest integer smaller than or equal to x.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'floor',
'fn_floor',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'floor',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_get_certificate_info',
'get_certificate_info',
'ws',
'Returns information about the current client X509 certificate',
'
This BIF will return information about the current client X509 certificate
(if successfully verified).  If there is no valid X509 certificate or the requested
information is not available it will return NULL.

If the optional cert_pem_string is supplied it should contain
a PEM encoded certificate. The certificate info is read from the first certificate in
that string.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'get_certificate_info',
'fn_get_certificate_info',
'integer or string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'type',
'get_certificate_info',
  'integer','in',
'type must be an integer.  It can be one of the following values:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cert_pem_string',
'get_certificate_info',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_get_keyword',
'get_keyword',
'array',
'Find a value in keyword vector',
'get_keyword performs a case sensitive seek
    for the occurance of
    keyword from each even position of
    searched_array. If found,this   returns the
 element following the occurrence of the keyword.
    If the keyword is not found this returns the default argument or NULL if the default is
    not supplied.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'get_keyword',
'fn_get_keyword',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'keyword',
'get_keyword',
  'any/variable','',
'String key value to be searched in the searched_array at
      even positions.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'searched_array',
'get_keyword',
  'array','',
'An array of even length to be searched.
      Each even position is a string to search. Each odd position
      can be any value that may then be returned.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'default',
'get_keyword',
  'any/variable','',
'Any data to be returned if keyword is not matched in
      the searched_array.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'no_copy',
'get_keyword',
  'integer','',
'By default no_copy is false (0). If passed as true (non-zero integer)
      then the element to return is the original content of the array and the place
      in the array from which the element came gets set to 0.
This must in some cases  be true, for example when the data being retrieved is
not copiable, as in the case of a string output.  While the default behavior is to
return a copy of the element get_keyword will return the element itself and then
set the place from which the element was retrieved to 0 if this argument is true.
',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_get_keyword_ucase',
'get_keyword_ucase',
'array',
'Find a value in keyword vector (search uppercase)',
'Identical to
    get_keyword
    except all comparisons  are performed case insensitively.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'get_keyword_ucase',
'fn_get_keyword_ucase',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'keyword',
'get_keyword_ucase',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'searched_array',
'get_keyword_ucase',
  'array','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'default',
'get_keyword_ucase',
  'any/variable','',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'no_copy',
'get_keyword_ucase',
  'integer','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_get_timestamp',
'get_timestamp',
'time',
'returns the timestamp of the current transaction',
'get_timestamp is merely an alias for now and
    is provided for backward compatibility.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'get_timestamp',
'fn_get_timestamp',
'timestamp',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_getdate',
'getdate',
'time',
'returns the date part of the current time',
'getdate returns the current date as apposed to 
    now which returns a complete timestamp.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'getdate',
'fn_getdate',
'date',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_gz_compress',
'gz_compress',
'misc',
'Compress data using gzip algorithm',
'
The gz_compress returns its argument compressed with the gzip
algorithm. The argument and return values are arbitrary strings,
possibly including any 8 bit characters.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'gz_compress',
'fn_gz_compress',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'gz_compress',
  'varchar','in',
'The string containing data to be compressed.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_gz_uncompress',
'gz_uncompress',
'misc',
'Uncompress a string using gzip algorithm',
'gz_uncompress takes a string argument, 
    uncompresses it using the gzip algorithm, writing it to a string_output
    given as the second argument.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'gz_uncompress',
'fn_gz_uncompress',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'gz_uncompress',
  'varchar','in',
'A string to be uncompressed.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str_out',
'gz_uncompress',
  'varchar','out',
'A string_output where the uncompressed 
      output should be written.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_hour',
'hour',
'date',
'get hour from a datetime',
'hour takes a datetime and returns 
    an integer containing a number representing the hour of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'hour',
'fn_hour',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'hour',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http',
'http',
'ws',
'write to HTTP client or a string output stream',
'http writes val_expr
    to HTTP client or, if parameter stream is given,
    to the given string output stream.val_expr may be any scalar object, i.e.
    string, date or number and will
    automatically be cast to varchar before further processing.
    http will print out the string without escapes.
    http_value
    uses HTML escapes and
    http_url URL
    escapes.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http',
'fn_http',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val_expr',
'http',
  'any/variable','in',
'A value expression. May be any scalar expression.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'stream',
'http',
  'any/variable','in',
'Optional parameter. If omitted or is 0 and the function is
      executed within a VSP context, the val_expr will
      be written to the HTTP client. If present and non-zero,
      val_expr will be written to the specified stream.
      If non-zero, the value must be a valid stream obtained
      from function
      string_output
      ',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_body_read',
'http_body_read',
'soap',
'Reads the HTTP body from the client HTTP connection and returns it as a string.',
'
This function reads the HTTP body from the client HTTP connection and returns it as a string output.
This is suitable for processing POST requests with bodies encoded differently than multipart/* and
application/x-www-form-urlencoded as in SOAP requests where the POST body is encoded as text/xml).
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_body_read',
'fn_http_body_read',
'string',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_client_ip',
'http_client_ip',
'ws',
'Returns the IP address of the calling client.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_client_ip',
'fn_http_client_ip',
'varchar',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_debug_log',
'http_debug_log',
'ws',
'set WebDAV HTTP request logging',
'When an valid path string is supplied and it is allowed in file ACL list, 
    the WebDAV HTTP requests and responces will be logged in append mode in to that file.
    When an open logging session is encountered the second call will produce an error.
    Specifying a NULL instead of file_path string stops the logging.The log file consists of lines with following fields:The request and response are marked by <<< and 
      >>> signsClient IP addressDate and time of request/responseTimestamp (milliseconds)Request/response line'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_debug_log',
'fn_http_debug_log',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'file_path',
'http_debug_log',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_enable_gz',
'http_enable_gz',
'ws',
'Enable / Disable "Content-Encoding: gzip" for HTTP server',
'
Enable (1)/ Disable (0) "Content-Encoding: gzip" for HTTP server.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_enable_gz',
'fn_http_enable_gz',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'http_enable_gz',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_file',
'http_file',
'ws',
'Send a file to the HTTP client',
'
This function causes the contents of the file specified by
path to be sent as the response of the calling request.
The file is not sent until the code calling this returns.
Content types etc. are defaulted based on the file@s extension.
If this function is called, other output to the HTTP client
by the caller is discarded.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_file',
'fn_http_file',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'http_file',
  'varchar','in',
'Path to the file to send'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_flush',
'http_flush',
'ws',
'Flush internal HTTP stream and disconnect client.',
'
This flushes the internal buffer where output of a VSP page is stored pending the execution of the page@s code.
This sends the content of the page output buffer along with headers and disconnects the client.  The status is 200 OK by default, unless overridden by http_status.
The purpose of this function is to allow a page to send output before terminating, thus the page can continue processing for an indefinite time without requiring the client to wait.  This is useful for starting long running background tasks from HTTP clients.

VSP pages that use this function must be sure to supply appropriate content
(or response headers) if needed before calling this function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_flush',
'fn_http_flush',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_get',
'http_get',
'ws',
'returns a varchar containing the body of the request uri',
'http_get returns a varchar containing the body of the
requested target_uri or NULL if the body is not received.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_get',
'fn_http_get',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'target_uri',
'http_get',
  'varchar','in',
'HTTP target in form http://<target_host>:<target_port>/<path>
(if <target_port> is not given then 80 will be used by default)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'return_header',
'http_get',
  'any/variable','out',
'This output parameter is set to the array of HTTP
response header lines from the target server, if the parameter is a  constant it will be ignored.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'http_method',
'http_get',
  'varchar','in',
'This parameter will be used to specify the HTTP request method.
Possible values are: GET, POST, PUT, OPTIONS or see RFC2616[5.1.1] for
details. ',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'request_header',
'http_get',
  'varchar','in',
'This string will be sent to the target server together with other
header fields. If more than one header field should be sent then header fields must be separated
with CR/LF pair. (Warning: this string must not be terminated with CR/LF pair!).',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'request_body',
'http_get',
  'varchar','in',
'This string will be sent to the target server as the request body.
The  "Content-Length" header field is set to the length of this string.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'proxy',
'http_get',
  'varchar','in',
'If this parameter is supplied  the request will be passed through this HTTP proxy. The format is  <proxy_host>:<proxy_port> .',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_header',
'http_header',
'ws',
' Specifies non-default HTTP response headers',
'
This function is used to add additional HTTP  header lines to the server response.
The http_header parameter MUST finish with <CR><LF> characters.
Warning: Each call of this function cancels the effect of the previous call.
In order to add to previously set header lines, use
the http_header_get function to retrieve the current headers.

A Content-Type or Media-Type header specified as a part of the headers given with
this function will override the default.  Otherwise the header lines set using this function add to but do  not replace  the default response headers.
Note that this function cannot set the status line.  Use http_request_status for that.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_header',
'fn_http_header',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'head',
'http_header',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_header_get',
'http_header_get',
'ws',
'returns header of current HTTP request',
'
Returns the response header associated with the current HTTP request.  This will not return the default header lines, only those explicitly set with http_header.

This is useful for incrementally modifying response headers during processing
of a URL.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_header_get',
'fn_http_header_get',
'varchar',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_kill',
'http_kill',
'ws',
'Kill VSP process whose details match parameter inputs',
'
This function is used to kill the process whose details match that of the input parameters.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_kill',
'fn_http_kill',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'client_IP_address',
'http_kill',
  'varchar','in',
'Clients IP as per the output of http_pending_req()'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'URL',
'http_kill',
  'varchar','in',
'Process URL as per the output of http_pending_req()'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'process_request_id',
'http_kill',
  'integer','in',
'The task ID of the request.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_listen_host',
'http_listen_host',
'ws',
'Starts, stops and retrieves the state of a user-defined HTTP listener',
'This function is used to start, stop or lookup the state of user-defined HTTP and HTTPS listeners.
  The return value is 0 or 1 and indicates state of the listener, 1 for started and 0 for stopped. 
  This function is permitted for DBA group only. 
IP addres of interface to be 
    started, stopped or queried for its current state.Can only take one of the following integer values:An array of name-value pairs for 
    setting up a HTTPS listeners.  This parameter only used for starting HTTPS 
    listeners, and nothing more.  The avalable options are:The certificate and key are mandatory for HTTPS listeners, but the 
    others are optional.  They are similar to the SSLCertificate, SSLPrivateKey, 
    X509ClientVerifyCAFile, X509ClientVerifyDepth Virtuoso INI file settings.
    The return type is integer, and will be either 0 or 1 to indicate the 
  state of the listener, 1 for started and 0 for stopped.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_listen_host',
'fn_http_listen_host',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'interface_address',
'http_listen_host',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'action',
'http_listen_host',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'options',
'http_listen_host',
  'vector','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_map_table',
'http_map_table',
'ws',
'Update internal HTTP mapping table',
'This function inserts an entry defining a virtual directory into the HTTP maps table.Only the DBA can run http_map_table'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_map_table',
'fn_http_map_table',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'logical_path',
'http_map_table',
  'varchar','in',
'The absolute path string which the user agent will pass to the server in path part of URI'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'physical_path',
'http_map_table',
  'varchar','in',
'The absolute path of the real content.  For directories or WebDAV collections physical_path MUST end
with a slash @/@ character, otherwise the point will be treated as a file (or resource).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vhost',
'http_map_table',
  'varchar','in',
'The host name that will be sent to the user-agent in HTTP request.  This MUST be valid
fully-qualified host name or alias and port separated with semi-column @:@ character.  This parameter
accept special value @*ini*@ which will be replaced with hostname and port from INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'listen_host',
'http_map_table',
  'varchar','in',
'The fully-qualified host name or IP address and port which will be listened on.  Warning: This
is only used to make an in-memory mapping, and will not start listening (for starting and stopping a
listener see http_listen_host).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'stored_in_dav',
'http_map_table',
  'integer','in',
'Determine if the physical location is a WebDAV resource or collection.  Can
      accept zero or one (1) integer values.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'is_browseable',
'http_map_table',
  'integer','in',
'Determine if directory browsing is allowed for this location.  Accepts integer
      values 0 or 1, treated as false and true respectively.  If true (1) enabled and a default
      page is not specified, a GET request of an URL pointing to this location will generate a
      directory listing as a response to the user-agent.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'default_page',
'http_map_table',
  'varchar','in',
'File name of default page that will be sent to the user-agent if
      physical_path is a directory.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'security_restriction',
'http_map_table',
  'varchar','in',
'A keyword that denotes security type controlling access to the location.  Can
      be @Digest@, @SSL@ or NULL.  This value can be used in the auth_function
      hook using http_map_get.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'authentication',
'http_map_table',
  'varchar','in',
'A string value that will be passed as a parameter to the auth_function
      hook',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'auth_function',
'http_map_table',
  'varchar','in',
'Fully qualified name of a PL procedure that will perform HTTP authentication.
      The function must accept one input parameter of type VARCHAR and MUST return
      integer 0 or 1 as false or true, respectively.  A zero return value from the authentication
      function will cause the HTTP request to be rejected.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'postprocess_function',
'http_map_table',
  'varchar','in',
'Fully qualified name of a PL procedure that will be called every time after page processing.
      Usual purpose is to store session variables in a session table.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'execute_vsp_as',
'http_map_table',
  'varchar','in',
'The name of DB user, as whom VSP pages will be executed.  If the
      user is not specified (is null), execution is forbidden.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'execute_soap_as',
'http_map_table',
  'varchar','in',
'The name of DB user, as whom SOAP calls will be executed.  If null,
      execution of SOAP calls is forbidden.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'have_persistent_session_variables',
'http_map_table',
  'integer','in',
'Flag that determines if the location has persistent session variables.
      The value of this flag can be retrieved with
      http_map_get.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'soap_options',
'http_map_table',
  'any/variable','in',
'A vector with keyword/value pairs. Currently, valid keywords are @Namespace@
      and @ServiceName@. Namespace is a string defining the namespace for the SOAP service.
      ServiceName is a string containing name of the SOAP service. See example.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'auth_options',
'http_map_table',
  'any/variable','in',
'The value of this parameter can be used in the authentication hook.
      In practice an array of keyword/value pairs would be the input but a single
      string could be supplied.  The user-specific authentication hook can retrieve
      the options by calling the http_map_get(@auth_opts@)
      function.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_map_get',
'http_map_get',
'ws',
'get values from HTTP virtual host path mapping table',
'
    Retrieves information associated with the virtual host / HTTP path mapping in
    effect for the VSP page being processed.
    Values valid
    in current connection or URL context may be retrieved by element_name.Calling http_map_get has no use outside of http context. In this case an
    error will be signalled.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_map_get',
'fn_http_map_get',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'element_name',
'http_map_get',
  'varchar','in',
'The possible values for element_name are: @vsp_uid@, @soap_uid@, @persist_ses_vars@,
      @default_page@, @browseable@, @security_level@ , @auth_opts@, @soap_opts@, @domain@,
      @mounted@.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_path',
'http_path',
'ws',
'returns the absolute path to the logical path location of the current http request',
'
This function returns the absolute path to the logical path location
of current HTTP request.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_path',
'fn_http_path',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_pending_req',
'http_pending_req',
'ws',
'return array describing running  VSP threads',
'
http_pending_req returns an array of running  VSP requests in the form
of an array of their associated Client IP Address, URL, and Process Request ID.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_pending_req',
'fn_http_pending_req',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_physical_path',
'http_physical_path',
'ws',
'returns the physical path location of the requested URL',
'
This function returns the absolute path to the physical path location of
current HTTP request'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_physical_path',
'fn_http_physical_path',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_proxy',
'http_proxy',
'ws',
'proxy request to another host and return content to calling client',
'
This function is used to retrieve content from a foreign host and send
the response to the HTTP client of the page calling this.  This is useful for re-routing a request to another server in the middle of a VSP page.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_proxy',
'fn_http_proxy',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'host',
'http_proxy',
  'varchar','in',
'The fully-qualified host name or alias.  If a target port is specified the
semi-column @:@ character MUST be used as the separator. (@www.foo.com:8080@)
'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'header',
'http_proxy',
  'any/variable','in',
'
an array consisting of the HTTP request header lines.  Warning: Each line
MUST finish with <CR><LF> characters.  This header lines will be
sent to the target server without any conversion.
'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content',
'http_proxy',
  'varchar','in',
'
In the case of posting of forms this parameter can contain the form data
as specified in HTML standards.
'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_request_header',
'http_request_header',
'ws',
'returns array of HTTP request header lines',
'
This function provides access to the HTTP request header lines.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_request_header',
'fn_http_request_header',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'array',
'http_request_header',
  'array','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'field_name',
'http_request_header',
  'varchar','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'attr-name',
'http_request_header',
  'varchar','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'default_value',
'http_request_header',
  'varchar','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_request_status',
'http_request_status',
'ws',
'set the status sent to the client in an HTTP response',
'
This allows a VSP page to control the status sent to the client in the HTTP response.
The argument will be presented as the first line of the reply instead of the default
"HTTP/1.1 200 OK".  The string should not contain a CR or LF at the end.
  This allows a page to issue redirects, authentication challenges etc.Use it with http_headers to control the content of the HTTP reply headers.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_request_status',
'fn_http_request_status',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'status_line',
'http_request_status',
  'varchar','in',
'String conforming to HTTP/1.1 (see RFC2616).   Examples of possible status lines are: @HTTP/1.1 200 OK@, @HTTP/1.1 500 Internal Server Error@,
@HTTP/1.1 401 Not found@ or @HTTP/1.1 400 Bad request@ etc.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_rewrite',
'http_rewrite',
'ws',
'Clears output written to  a string output or to an HTTP    ',
'
This clears any previous output to the stream. If the stream is omitted or 0 the stream
is the HTTP client stream of the calling procedure.
All output from VSP page procedures is buffered into a local string stream
before being sent out.  This is done so as to support the HTTP/1.1 required
content length and to allow recovery from errors.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_rewrite',
'fn_http_rewrite',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'stream',
'http_rewrite',
  'any/variable','in',
'Optional stream to clear.  Null or zero (0) implies the default HTTP client stream.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_root',
'http_root',
'ws',
'Returns the absolute path of the server root directory.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_root',
'fn_http_root',
'varchar',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_value',
'http_value',
'ws',
'write to HTTP client or string output stream with HTML
    escapes',
'The http_value is used to write to an HTTP
    client (when in a VSP context) or a specified string output stream.
    http_value uses HTML-escapes for characters that
    should be escaped according to the HTML spec.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_value',
'fn_http_value',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val_expr',
'http_value',
  'any/variable','in',
'A value expression. May be any string expression. If
      val_expr is an XML entity, a serialization of
      the entity is written to the stream. This is not
      the string value of the XML fragment, but a serialization of the XML
      fragment as text including all the markup, i.e. elements, attributes,
      namespaces, text nodes, etc. To get the string value of an XML entity,
      convert it to a varchat using cast. Casting as
      varchar will only produce a concatenation of the text nodes in the
      XML fragment, leaving out elements, attributes, name spaces, etc.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'tag',
'http_value',
  'varchar','in',
'Optional. If present and is a string, the output will be enclosed
      in tags named as the string content of tag.
      If the expression evaluates to 0 or null, it will be ignored.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'stream',
'http_value',
  'any/variable','in',
'Optional parameter. If omitted or is 0 and the function is
      executed within a VSP context, the val_expr will
      be written to the HTTP client. If present and non-zero,
      val_expr will be written to the specified stream.
      If non-zero, the value must be a valid stream obtained
      from function
      string_output
      ',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_url',
'http_url',
'ws',
'write to HTTP client or string output stream with URL escapes',
'The http_url is used to write to an HTTP
    client (when in a VSP context) or a specified string output stream.
    http_url uses URL escapes for special
    characters.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_url',
'fn_http_url',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val_expr',
'http_url',
  'any/variable','in',
'A value expression. May be any scalar expression. If
      val_expr is an XML entity, a serialization of
      the entity is written to the stream. This is not
      the XML as a text string, but a serialization of the internal
      representation of parsed XML data.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'tag',
'http_url',
  'varchar','in',
'Optional. If present and is a string, the output will be enclosed
      in tags named by the string content of tag.
      If the expression evaluates to 0 or null, it will be ignored.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'stream',
'http_url',
  'any/variable','in',
'Optional parameter. If omitted or is 0 and the function is
      executed within VSP context, the val_expr will
      be written to the HTTP client. If present and non-zero,
      val_expr will be written to the specified stream.
      If non-zero, the value must be a valid stream obtained
      from function
      string_output
      ',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_http_xslt',
'http_xslt',
'ws',
'applies an XSLT stylesheet to the output of a VSP page',
'
This function can be called inside a VSP page to apply an XSLT
stylesheet to the output of the page once the page is complete.  This
function will return immediately and the stylesheet will not be
applied until the page is successfully formed.  Any errors arising in
the stylesheet processing will be reported to the web client.

The stylesheet does not have to be previously defined.  The URI
supplied will be used to locate the stylesheet.  This can be a file,
an HTTP URL or a virt:// URI for a stylesheet stored in a local table.
Virtuoso will cache the stylesheet after first use.  You can clear the
cache entry with the xslt_stale() function.

For this to work the text generated by the VSP page should be well-formed XML.

This function is only valid in a VSP context.  The
xsl:output element will control the
Content-Type sent to the user agent.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'http_xslt',
'fn_http_xslt',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xslt_uri',
'http_xslt',
  'varchar','in',
'Absolute URI of the XSL stylesheet'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'params',
'http_xslt',
  'any/variable','in',
'Even length array of name/value pairs.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_initcap',
'initcap',
'string',
'returns its argument with the first letter capitalized',
'initcap returns a copy of string str with the first character, if it is a
    lowercase letter, converted to the corresponding uppercase letter.
    Otherwise, an identical copy of the string is returned. Notes about ucase
    apply also here.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'initcap',
'fn_initcap',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'initcap',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_internal_to_sql_type',
'internal_to_sql_type',
'type',
'returns the integer standard SQL type of its argument',
'internal_to_sql_type returns an integer value representing the standard
    SQL type converted from internal_type given as its argument.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'internal_to_sql_type',
'fn_internal_to_sql_type',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'internal_type',
'internal_to_sql_type',
  'integer','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_internal_type',
'internal_type',
'type',
'returns internal integer datatype of its argument',
'internal_type returns an integer value representing the internal type of
    its argument. These values are the same as what Virtuoso uses in the
    column COL_DTP of the system table SYS_COLS for keeping the track of the
    default types of each column of each table.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'internal_type',
'fn_internal_type',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'internal_type',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_internal_type_name',
'internal_type_name',
'type',
'returns the internal type name of the argument',
'internal_type_name returns a string which is a human-readable name for an
    internal_type integer given as its argument.  The function 
    dv_type_title() is an alias of 
    internal_type_name().'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'internal_type_name',
'fn_internal_type_name',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'internal_type',
'internal_type_name',
  'integer','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isarray',
'isarray',
'array',
'Check for a valid array',
'isarray is true if the argument is a valid argument to aref.
    This is the case for any string or vector.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isarray',
'fn_isarray',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'isarray',
  'any/variable','in',
'The variable to be checked.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isblob',
'isblob',
'string',
'returns true if its argument is of type long varchar',
'isblob returns one if its argument as a handle to an object of the type
    LONG VARCHAR, zero otherwise.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isblob',
'fn_isblob',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isblob',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isdouble',
'isdouble',
'number',
'returns true is argument is a double',
'    isdouble returns one if its argument is of type double precision float,
    zero otherwise.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isdouble',
'fn_isdouble',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isdouble',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isentity',
'isentity',
'type',
'returns true if its argument is an XML entity',
'isentity is true if the argument is an XML
    entity object, such as that returned from XPATH expressions etc.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isentity',
'fn_isentity',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'isentity',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isfloat',
'isfloat',
'type',
'returns true if its argument is a float',
'isfloat returns one if its argument is of type
    single float, zero otherwise.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isfloat',
'fn_isfloat',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isfloat',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isinteger',
'isinteger',
'type',
'returns true if its argument is of type integer',
'isinteger returns one if its argument is of type
  integer, zero otherwise.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isinteger',
'fn_isinteger',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isinteger',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isnull',
'isnull',
'type',
'returns true if its argument is NULL',
'isnull returns one if its argument is NULL, zero otherwise.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isnull',
'fn_isnull',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isnull',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isnumeric',
'isnumeric',
'type',
'returns true if argument is of numeric type',
'isnumeric returns one if its argument is of type integer, single float or
    double precision floating point number, zero otherwise.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isnumeric',
'fn_isnumeric',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isnumeric',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_isstring',
'isstring',
'type',
'returns true if its argument is of type varchar',
'isstring returns one if its argument is of type VARCHAR, zero otherwise.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'isstring',
'fn_isstring',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'isstring',
  'any/variable','',
'Some variable to be assessed.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_iszero',
'iszero',
'type',
'returns true if argument is numeric zero',
'    iszero returns one if its argument is an integer 0, a float 0.0 or a
    double 0.0 For any other arguments, of whatever type, it will return zero.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'iszero',
'fn_iszero',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'iszero',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_lcase',
'lcase',
'string',
'Converts string argument to lower case',
'lcase returns a copy of string str with all the uppercase alphabetical
    characters converted to corresponding lowercase letters. This includes
    also the diacritic letters present in the ISO 8859/1 standard in range
    192 - 222 decimal, excluding the character 223, German double-s which
    stays the same.lower is an alias for lcase.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lcase',
'fn_lcase',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'lcase',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ldap_search',
'ldap_search',
'ldap',
'Search in an LDAP server.',
'
This function performs a search in the LDAP server.  It returns control to
the PL/SQL environment only after all of the search results have been sent by the server
or if the search request is timed out by the server.  The result of the search
(attributes, names of the attributes, etc.) will be returned as an array result.  Options
to the LDAP search can be passed as an array.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ldap_search',
'fn_ldap_search',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_url ',
'ldap_search',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'try_tls ',
'ldap_search',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base ',
'ldap_search',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'filter ',
'ldap_search',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'username ',
'ldap_search',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password ',
'ldap_search',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ldap_delete',
'ldap_delete',
'ldap',
'Remove a leaf entry in the LDAP Directory Information Tree.',
'
This function removes a leaf entry in the LDAP Directory Information Tree.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ldap_delete',
'fn_ldap_delete',
'int',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_url ',
'ldap_delete',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'try_tls ',
'ldap_delete',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'entrydn ',
'ldap_delete',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'username ',
'ldap_delete',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password ',
'ldap_delete',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ldap_add',
'ldap_add',
'ldap',
'Adds a new entry to an LDAP directory.',
'This function adds a new entry to the LDAP directory.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ldap_add',
'fn_ldap_add',
'int',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_url ',
'ldap_add',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'try_tls ',
'ldap_add',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'data ',
'ldap_add',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'username ',
'ldap_add',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password ',
'ldap_add',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ldap_modify',
'ldap_modify',
'ldap',
'Modifies an existing LDAP directory.',
'This function modifies an existing LDAP directory entry.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ldap_modify',
'fn_ldap_modify',
'int',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_url ',
'ldap_modify',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'try_tls ',
'ldap_modify',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'data ',
'ldap_modify',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'username ',
'ldap_modify',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password ',
'ldap_modify',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_left',
'left',
'string',
'returns substring taken from left of string argument',
'left returns a subsequence of string str, taking count characters from the
    beginning of the string.

    If count is zero an empty string @@ is returned.

    If length of str is less than count then a copy of the whole str is
    returned.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'left',
'fn_left',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'left',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'count',
'left',
  'integer','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_length',
'length',
'string',
'Get length of argument',
'Returns the length of its argument.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'length',
'fn_length',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg',
'length',
  'any/variable','in',
'Any type that can be tested for length.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_lfs_exp',
'LFS_EXP',
'ws',
'Export retrieved web site to the local file system',
'This function is used to export local content retrieved from a Web Robot Copy
to the local file system.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'LFS_EXP',
'fn_lfs_exp',
'WS.WS.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'host',
'LFS_EXP',
  'varchar','in',
'The target host name'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'url',
'LFS_EXP',
  'varchar','in',
'start path on target'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root',
'LFS_EXP',
  'varchar','in',
'local WebDAV collection that contains the retrieved content'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dst',
'LFS_EXP',
  'varchar','in',
'absolute path to the file system directory to export content to'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_lh_get_handler',
'lh_get_handler',
'localization',
'Returns language handler',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lh_get_handler',
'fn_lh_get_handler',
'lang_handler_t *',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'language_name',
'lh_get_handler',
  '','const char *',
'Name of language handler.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_lh_load_handler',
'lh_load_handler',
'localization',
'Loads given handler in global table of the server',
'
Loads given handler in global table of the server, using ISO 639 and
RFC 1766 language IDs of the handler as keys for future table lookups.
If another handler was already specified for given RFC 1766 id, table entry
will be updated and will refer to new handler. If another handler was already
specified for given ISO 639 id, it will be replaced only if new handler has
ISO 639 language ID equal to its RFC 1766 ID.
Please do not load custom versions of @x-any@ and @x-ftq-x-any@ handlers.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lh_load_handler',
'fn_lh_load_handler',
'int',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_handler',
'lh_load_handler',
  '','lang_handler_t *',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_locate',
'locate',
'string',
'returns the starting position of the first occurrence of an substring in a string',
'
Returns the starting position of the first occurrence of
string_exp1 within string_exp2. The search for the first occurrence
of string_exp1 begins with the first character position in string_exp2
unless the optional argument, start, is specified.
If start is specified, the search begins with the character
position indicated by the value of start.
The first character position in string_exp2 is indicated by the value 1.
If string_exp1 is not found within string_exp2, the value 0 is returned.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'LOCATE',
'fn_locate',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string_exp1',
'LOCATE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string_exp2',
'LOCATE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'start',
'LOCATE',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_log',
'log',
'number',
'calculate natural logarithm of an expression',
'log calculates the natural logarithm of its
    argument and returns it as a IEEE 64-bit float.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'log',
'fn_log',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'log',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_log10',
'log10',
'number',
'Calculate 10-based logarithms',
'log10 calculates the 10-based logarithm of its
    argument and returns it as a IEEE 64-bit float.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'log',
'fn_log10',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'log',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_log_enable',
'log_enable',
'misc',
'controls transaction logging',
'The log_enable function allows turning regular
    transaction logging off or on.
    A value of 0 terminates logging of DML statements inside the calling
    transaction.  A value of 1 resumes logging of DML statements. Using
    this function one can create situations where a transaction@s outcome
    would be different from the outcome of doing a roll forward of the
    transaction log.There are rare cases where it is more efficient to log an action in
    the form of a procedure call instead of logging the effects of the procedure on
    a row by row basis.  This is similar in concept to replicating procedure
    calls but applies to roll forward instead.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'log_enable',
'fn_log_enable',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'flag',
'log_enable',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_log_text',
'log_text',
'misc',
'inserts statements into the roll forward log',
'The log_text function can be used to insert a SQL statement
    into the roll forward log.The log_text function causes the SQL text given as first argument to
    be executed at roll forward time with the following arguments as parameters,
    bound from left to right to the parameter markers in the statement (@?@).
    There can be a maximum of 8 parameters but these can be arrays.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'log_text',
'fn_log_text',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'text',
'log_text',
  'varchar','in',
'VARCHARSQL statement to be added in the
      transaction log.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'arg_1',
'log_text',
  'any/variable','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'...',
'log_text',
  '','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_lower',
'lower',
'number',
'returns a lower case version of its argument',
'
    lcase returns a copy of string str with all the uppercase alphabetical
    characters converted to corresponding lowercase letters. This includes
    also the diacritic letters present in the ISO 8859/1 standard in range
    192 - 222 decimal, excluding the character 223, German double-s which
    stays the same.

    lower is just an alias for lcase.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lower',
'fn_lower',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'lower',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ltrim',
'ltrim',
'string',
'removes specific characters from a string',
'ltrim returns a copy of subsequence of string str with all the characters
    present in trimchars trimmed off from the beginning. If the second
    argument is omitted, it is a space @ @ by default.

    rtrim is similar except that it trims from the right.

    trim trims from both ends.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ltrim',
'fn_ltrim',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'ltrim',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'trimchars',
'ltrim',
  'varchar','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_make_array',
'make_array',
'array',
'returns a new array',
'This returns an array of length elements with the content element
    type. The initial content of the array is undefined.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'make_array',
'fn_make_array',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'length',
'make_array',
  'integer','in',
'Number of elements to be allocated in the resultant array.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content',
'make_array',
  'varchar','in',
'String that specifies the data type of the array to make.
      Valid strings are @float@, @double@, @long@ or @any@.
      These correspond respectively to the C types long (32 bit signed),
      float (IEEE 32-bit), double (IEEE 64-bit) and untyped. The untyped array
      may hold a heterogeneous collection of any Virtuoso data types,
      including other arrays. The initial content of the array is undefined.
      '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_make_string',
'make_string',
'string',
'make a string',
'make_string returns a new string of length count, filled with
    binary zeros.If count is zero, an empty string @@ is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'make_string',
'fn_make_string',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'count',
'make_string',
  'integer','in',
'Length of the string to be generated.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_md5',
'md5',
'misc',
'returns the md5 checksum of its argument',
'md5 calculates the MD5 checksum of its argument.
    The md5 message digest algorithm is defined in
    RFC1321.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'md5',
'fn_md5',
'checksum',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'md5',
  'varchar','in',
'A string or string_output containing the data
      for calculating the message digest.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_md5_init',
'md5_init',
'misc',
'returns the string serialization of a new md5 context',
'
This functions initializes an MD5_CTX, converts it into varchar form and returns
this representation. Should be used with md5_update/md5_finit.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'md5_init',
'fn_md5_init',
'new md5 checksum context',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_md5_update',
'md5_update',
'misc',
'returns the updated md5 context serialized as varchar',
'
This functions updates MD5_CTX with data parameter and returns the (deserialized from ctx parameter) updated context.
   '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'md5_update',
'fn_md5_update',
'md5 context update',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ctx',
'md5_update',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'data',
'md5_update',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_md5_finit',
'md5_finit',
'misc',
'returns the md5 checksum given an initialized md5 context',
'This function finalizes the MD5_CTX and returns the final checksum.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'md5_finit',
'fn_md5_finit',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ctx',
'md5_finit',
  'varchar','in',
'A MD5_CTX'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_mime_tree',
'mime_tree',
'mail',
'parses MIME messages into an array structure',
'
This function is intended to parse MIME (RFC2045) messages (coming from a RFC822 or HTTP sources).
It parses the text and produces an array structure representing the structure of the MIME message.
It copies into the structure MIME headers, but for the MIME bodies it only stores start and end offsets,
thus optimizing space usage.

The parameters to mime_tree are:

If flag is 1, the "root" message follows RFC822. This means mime_tree will unfold the attributes,
will scan for MIME registered header fields and will take their attributes. or it@s a MIME message
(needs no unfolding and has attributes separated with semicolon).

If flag is 2, the "root" message follows RFC2045. This means mime_tree will scan for MIME attributes.

In either cases mime_tree will look for the Content-Type header field and will parse
the "message/rfc822" and "multipart/digest" MIME bodies as nested messages.

mime_tree will return an array of 3 elements (message descriptor) with the following structure:
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'mime_tree',
'fn_mime_tree',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'message_text',
'mime_tree',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'flag',
'mime_tree',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_minute',
'minute',
'date',
'get minute from a datetime',
'minute takes a datetime and returns 
    an integer containing a number representing the minute of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'minute',
'fn_minute',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'minute',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_mod',
'mod',
'number',
'returns the modulus of its arguments',
'mod returns the modulus (i.e. remainder) of the division dividend/divisor.
    If the divisor is zero the SQL error 22012 "Division by zero" is generated.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'mod',
'fn_mod',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dividend',
'mod',
  'integer','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'divisor',
'mod',
  'integer','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_month',
'month',
'date',
'get number of month from a datetime',
'month takes a datetime and returns 
    an integer containing a number representing the month of year of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'month',
'fn_month',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'month',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_monthname',
'monthname',
'date',
'get name of month from a datetime',
'monthname takes a datetime and returns 
    a string containing name of the month represented by the datetime'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'monthname',
'fn_monthname',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'monthname',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_msec_time',
'msec_time',
'time',
'Get number of milliseconds from system epoch',
'msec_time returns the number of milliseconds since system epoch. It is useful for benchmarking purposes, timing operations, etc.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'msec_time',
'fn_msec_time',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_name_part',
'name_part',
'sql',
'Returns portion of dotted name such as a fully qualified table name.',
'The name_part() can be used to disecting parts of a three part names (string 
    where items are divided by dots ".") such as table names or columns names.  The table 
    name "DB"."DBA"."SYS_USERS" contains three parts which can be extracted individually 
    using this function providing the correct index from a 0 base: 0 would return "DB", 
    1 would return "DBA", 2 would return "SYS_USERS".'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'name_part',
'fn_name_part',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string',
'name_part',
  'varchar','in',
'The string to be disected.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'idx',
'name_part',
  'integer','in',
'The part index starting from 0.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_nntp_auth_get',
'nntp_auth_get',
'mail',
'returns information about an NNTP server with authorization',
'The nntp_auth_get() is used to retrieve messages from a 
server requiring authorization.  See nntp_get for more information.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'nntp_auth_get',
'fn_nntp_auth_get',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server',
'nntp_auth_get',
  'varchar','in',
'The host to connect with. IP address or hostname:port.  There is no default for 
      port, so to connect to the standard port for NNTP, use <hostname/IP address>:119'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'user',
'nntp_auth_get',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'nntp_auth_get',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'command',
'nntp_auth_get',
  'varchar','in',
'The username.
      The user password.
      Command string. Valid values are @article@, @body@, @head@, @stat@, @list@, @group@ or @xover@. 
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'group',
'nntp_auth_get',
  'varchar','in',
'A string containing name of the news group.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'first_message',
'nntp_auth_get',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'last_message',
'nntp_auth_get',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_nntp_auth_post',
'nntp_auth_post',
'mail',
'Post message to NNTP server with authorization',
'
Nntp_auth_post is used to post a message to the server require authorization.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'nntp_auth_post',
'fn_nntp_auth_post',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server',
'nntp_auth_post',
  'varchar','in',
'The host to connect with. IP address or hostname:port.  There is 
      no default for port, so to connect to the standard port for NNTP, 
      use <hostname/IP address>:119'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'user',
'nntp_auth_post',
  'varchar','in',
'The username.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'nntp_auth_post',
  'varchar','in',
'The user password.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'body',
'nntp_auth_post',
  'varchar','in',
'The body stringThe structure of the message must comply 
      with RFC 850 (Standard for Interchange of USENET Messages).
      '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_nntp_get',
'nntp_get',
'mail',
'Returns information about an NNTP server.',
'
nntp_get() is used to retrieve messages from a server running
the Network News Transfer Protocol (NNTP) as defined in RFC977. It returns an array
whose structure depends on the command parameter,
thus:
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'nntp_get',
'fn_nntp_get',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server ',
'nntp_get',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'command ',
'nntp_get',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'group ',
'nntp_get',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'first_message ',
'nntp_get',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'last_message ',
'nntp_get',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_nntp_post',
'nntp_post',
'mail',
'Post message to NNTP server',
'
Nntp_post is used to post a message to the server running 
the Network News Transfer Protocol as defined in the rfc977. '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'nntp_post',
'fn_nntp_post',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server',
'nntp_post',
  'varchar','in',
'The host to connect with. IP address or hostname:port. There is no default for port, so to connect to the standard port for NNTP, use <hostname/IP address>:119'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'body',
'nntp_post',
  'varchar','in',
'The body stringThe structure of the message must comply with RFC 850 (Standard for Interchange of USENET Messages).
      '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_now',
'now',
'time',
'returns the current transaction timestamp',
'
      Now returns the timestamp associated with current transaction as a DATETIME.
      This value is guaranteed to differ from the timestamp of any other transaction.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'now',
'fn_now',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_pem_certificates_to_array',
'pem_certificates_to_array',
'mail',
'converts a PEM file to an array of PEM strings',
'This gets a PEM file with (possibly) many X509 certificates among others and
    constructs an array containing each X509 certificate as a separate PEM
    string. This can serve for splitting a PEM file containing multiple
    certificates (for example CA file) to single certificate entries so it can
    be examined with get_certificate_info function.  Note that the array can
    contain NULL elements in places where in the PEM file there are blocks other
    than X509 PEM certificates.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'pem_certificates_to_array',
'fn_pem_certificates_to_array',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'pem_string',
'pem_certificates_to_array',
  'varchar','in',
'text of the PEM file'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_pop3_get',
'pop3_get',
'mail',
'get messages from a POP3 server',
'Pop3_get is used to retrieve and delete messages from a server
    running the Post Office Protocol version 3 as defined in rfc1725. In its default form it
    returns a vector of vectors containing messages retrieved from the POP3 server.
    Each vector within the vector contains a pair of VARCHAR UIDL and
    VARCHAR Message body, i.e. to get the message body of the second message retrieved,
    one would use aref (aref (msg_vec, 1), 1).
    Total length of messages retrieved will not exceed the value of buffer_size
    parameter in bytes.The optional parameter command can be used to control output
    or delete messages. When command
    is passed a VARCHAR @uidl@, pop3_get outputs single
    vector containing VARCHAR UIDLs. The buffer_size constraint
    is effective here. Thus, the vector will only contain UIDLs of messages whose total message text
    length does not exceed buffer_size bytes. These message lengths are
    cumulated in the order returned by the POP3 server.Command @delete@ will cause retrieved messages to be deleted from the server
    after retrieval.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'pop3_get',
'fn_pop3_get',
'array',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'host',
'pop3_get',
  'varchar','in',
'The host to connect with. IP address or hostname:port. There is no default for port, so to connect to the standard port for POP3, use <hostname/IP address>:110'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'user',
'pop3_get',
  'varchar','in',
'string user id in remote host.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'pop3_get',
  'varchar','in',
'string password in remote host.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'buffer_size',
'pop3_get',
  'integer','in',
'integer maximum total length of message text for
      messages/uidls to be retrieved.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'command',
'pop3_get',
  'varchar','in',
'Command string. Valid values are empty, @uidl@
      or @delete@',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'exclude_uidl_list',
'pop3_get',
  'vector','in',
'A vector containing UIDLs. A message whose UIDL appears in this
      list will not be retrieved or deleted.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_power',
'power',
'number',
'return value of expression raised to specified
    power.',
'power raises x to the yth power and returns
    the value as a IEEE 64-bit float.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'power',
'fn_power',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'power',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'y',
'power',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_prof_enable',
'prof_enable',
'misc',
'Control virtuoso profiling',
'prof_enable is used to enable or disable 
    profiling of execution times, SQL statements and web requests.  
    Passing flag value 1, enables profiling, causing times of statement 
    executions, which begin and end while profiling is on, to be 
    accumulated.When called with a flag of 0, the accumulation is stopped and 
    results gathered so far are written into file named virtprof.out in 
    the server@s working directory.  For a description of the file, see 
    section about SQL Execution Profiling 
    in Performance tuning part of 
    Virtuoso documentation.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'prof_enable',
'fn_prof_enable',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'flag',
'prof_enable',
  'integer','in',
'An INTEGER. Valid values are 1 or 0.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_quarter',
'quarter',
'date',
'get number of quarter of year from a datetime',
'quarter takes a datetime and returns 
    an integer containing a number representing the quarter of year of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'quarter',
'fn_quarter',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'quarter',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_quote_dotted',
'quote_dotted',
'rmt',
'Returns an quoted identifier.',
'The quote_dotted() function will return the 
    identifier (table name or column name) appropriately quoted for the remote 
    data source.  This function will obtain the apropriate quote characters  
    from the remote data source.  This function can be used in conjuction with 
    rexecute function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'quote_dotted',
'fn_quote_dotted',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'quote_dotted',
  'varchar','in',
'The remote DSN name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'identifier',
'quote_dotted',
  'varchar','in',
'The string containing the identifier.  The identifier can be a one, 
      two or three part name, separated with the dot, @.@, character.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_randomize',
'randomize',
'number',
'initializes the random number generator',
'
The rnd function returns a random number between zero and n - 1, inclusive.
	
randomize initializes the random number generator.
	
The random number generator is initialized after the clock at first usage, so the
produced sequences will be different each time unless
specifically initialized.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'randomize',
'fn_randomize',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seed',
'randomize',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rclose',
'rclose',
'rmt',
'Closes cursor created by rexecute()',
'Closes the cursor opened to a remote DSN by the rexecute() function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rclose',
'fn_rclose',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'rclose',
  'cursor handle','in',
'The cursor handle used.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_regexp_match',
'regexp_match',
'string',
'returns substring matching the regular expression to the supplied string',
'
The regexp_match function returns a copy of substring of string target_str which matches the regular expression pattern.
The first characters of target_str are cut until end of matched substring. In this way target_str could be passed to
this function again to find the next occurrence of substring which matches the regular expression.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'regexp_match',
'fn_regexp_match',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'pattern',
'regexp_match',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'target_string',
'regexp_match',
  'varchar','out',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_regexp_parse',
'regexp_parse',
'string',
'returns substrings that match the regular expression in supplied string after an offset',
'
The regexp_parse function is more efficient than regexp_match and regexp_substr. It applies regular expression to target_str
with offset. This function returns a vector containing 2 elements for each match. The first (even numbered) element of each pair is the start index and the second (odd numbered) is the end index of the match.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'regexp_parse',
'fn_regexp_parse',
'index_vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'pattern',
'regexp_parse',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'target_string',
'regexp_parse',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'offset',
'regexp_parse',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_regexp_substr',
'regexp_substr',
'string',
'returns a single captured substring from matched substring',
'
The regexp_substr function  returns a single captured substring from matched substring. The matched substring
could be obtained from regexp_match function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'regexp_substr',
'fn_regexp_substr',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'pattern',
'regexp_substr',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'matched_string',
'regexp_substr',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'index',
'regexp_substr',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repeat',
'repeat',
'string',
'returns a new string consisting of its string argument repeated a given number of times',
'
    repeat returns a new string, composed of the string str repeated count
    times. If count is zero, an empty string @@ is returned.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repeat',
'fn_repeat',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'repeat',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'count',
'repeat',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_replace',
'replace',
'string',
'This replaces every occurrence of the second argument in the first argument
with the third argument.',
'
This replaces every occurrence of the second argument in the first argument
with the third argument.  The arguments can be narrow or wide strings.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'replace',
'fn_replace',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string',
'replace',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'what',
'replace',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'repl_with',
'replace',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_replay',
'replay',
'backup',
'starts the roll forward of the given log',
'This starts a roll forward of the given log.  The log may have been
    produced by normal transaction logging, backup or crash dump.  Logs
    may not be transferred between databases and thus cannot be rolled forward
    anywhere except on the database that generated them.This function is for example useful after restoring a backup.
    It should be called for each archived transaction log produced since the
    backup, including and starting with the one that was current when the
    backup was made.The operation blocks until the roll forward is complete.
    Other clients are not affected.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'replay',
'fn_replay',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'log_file',
'replay',
  'varchar','in',
'Full pathname of file containing the transactions to be replayed.
      The file must be produced by backup.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_disconnect',
'repl_disconnect',
'repl',
'terminates communication with a replication publisher',
'
This terminates any communication with the publisher. Any
pending synchronization communication is disconnected and all subscribed publications
are marked as @OFF@.  The effect is reversed on a subscription by subscription
basis by calling repl_sync for each.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_disconnect',
'fn_repl_disconnect',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publisher',
'repl_disconnect',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_grant',
'REPL_GRANT',
'repl',
'grant privileges for subscription to a publication',
'publication publication account name.grantee valid DB account name to be granted subscription rights.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_GRANT',
'fn_repl_grant',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_GRANT',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'grantee',
'REPL_GRANT',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_init_copy',
'REPL_INIT_COPY',
'repl',
'create initial subscription state',
'server_name target publisher server name.account publication account name.
This function is called on the subscriber to copy the current state of the
elements of the publication from the publishing server.  Copied data can
include DAV collections, tables, procedures etc.  Syncing the
subscription using repl_sync will synchronize the subscription
once it has been initialized with this function.  The state copied
corresponds to the state of the published data as of the last checkpoint
completed on the publisher.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_INIT_COPY',
'fn_repl_init_copy',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_name',
'REPL_INIT_COPY',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_INIT_COPY',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_new_log',
'repl_new_log',
'repl',
'create new publication log',
'
This function switches to a new file for logging data for the publication.
If the file is NULL a new file name will be generated based on the previous file name by appending
or replacing a datetime field in the file name.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_new_log',
'fn_repl_new_log',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'repl_new_log',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'file',
'repl_new_log',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_publish',
'REPL_PUBLISH',
'repl',
'create publication on publisher',
'
This function starts a publication and associates a file system file to it.   The file
will be used to log transaction records associated to the publication.  The server will
periodically start new files, so that replication log files do not grow indefinitely.
New files will go to the same directory as the initial one and will have names suffixed with
the date and time of their creation.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_PUBLISH',
'fn_repl_publish',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_PUBLISH',
  'varchar','in',
'Publication name (must not contain spaces or special symbols).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'log_path',
'REPL_PUBLISH',
  'varchar','in',
'Full path and filename to the file where transactions to this account will be stored.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_pub_add',
'REPL_PUB_ADD',
'repl',
'add item to a publication',
'
This function is used to add items to a pre-existing  publication and to set replication options for the published items.  Operations concerning the added item will henceforth be logged into the publication@s log. Performing this operation will copy the items and definition on the existing connected subscribtions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_PUB_ADD',
'fn_repl_pub_add',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_PUB_ADD',
  'varchar','in',
'publication account name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item',
'REPL_PUB_ADD',
  'varchar','in',
'dependent on type should be:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'type',
'REPL_PUB_ADD',
  'integer','in',
'type of item, can accept following types:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'REPL_PUB_ADD',
  'integer','in',
'mode of remote copy:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'procedure_replication_options',
'REPL_PUB_ADD',
  'integer','in',
'valid only in case of Virtuoso/PL procedure:'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_pub_init_image',
'REPL_PUB_INIT_IMAGE',
'repl',
'create initial image of publication on publisher',
'publication publication account name.image_file_path full path to the image file
    where to store the initial image of publication.bytes_per_file at which bytes count to split
    file into next sliceThe image creation process MUST be done after server checkpoint.
Otherwise, the replication data resides in the transaction log file, and you
will get an error stating that the Publication does not exist.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_PUB_INIT_IMAGE',
'fn_repl_pub_init_image',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_PUB_INIT_IMAGE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'image_file_path',
'REPL_PUB_INIT_IMAGE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'bytes_per_file',
'REPL_PUB_INIT_IMAGE',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_pub_remove',
'REPL_PUB_REMOVE',
'repl',
'remove item from publication.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_PUB_REMOVE',
'fn_repl_pub_remove',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_PUB_REMOVE',
  'varchar','in',
'publication account name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item',
'REPL_PUB_REMOVE',
  'varchar','in',
'dependent on type should be:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'type',
'REPL_PUB_REMOVE',
  'integer','in',
'type of item, can accept following types:'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'flag',
'REPL_PUB_REMOVE',
  'integer','in',
'Behavior on the subscriber side'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_revoke',
'REPL_REVOKE',
'repl',
'revoke privileges for subscription',
'Revokes Privileges for Subscription.  This is called on the publisher to revoke access to the publication from the user account on publisher.  The subscriber will no longer get access to the publication with this account.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_REVOKE',
'fn_repl_revoke',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_REVOKE',
  'varchar','in',
'publication  name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'grantee',
'REPL_REVOKE',
  'varchar','in',
'valid DB account name to be revoked subscription rights.The DBA account is granted subscription rights by default,
      this cannot be revoked.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_sched_init',
'REPL_SCHED_INIT',
'repl',
'adds scheduled job to synchronize subscriptions',
'Adds scheduled job to synchronize all subscriptions.  The server will attempt to start synchronization of all non-synchronized subscriptions at a 1 minute interval.  The action can be reversed by deleting the corresponding row from the SYS_SCHEDULED_EVENTS table.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_SCHED_INIT',
'fn_repl_sched_init',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_server',
'REPL_SERVER',
'repl',
'defines a server that will participate in replication',
'server_name unique replication server name of publisher
(specified in [Replication] -> [ServerName] section in ini file of publisher).dsn data source name of publisher.replication_address host:port pair of publishing server where this subscriber will connect to.
This function defines a server that will participate in replication.
The name is a symbolic name that should match the name specified
as the ServerName configuration parameter in
the replication section of the virtuoso.ini file of the server being defined.  The address is the <host:port> where the
server designated by the name is listening. The DSN is an ODBC data source name referring to the server, so that the subscriber can retrieve schema and other information.  Note that replication communication itself does not take place through ODBC but that ODBC access to the publisher is required to initiate the subscription. In order to subscribe to
publications from a server the server must first be declared
with this function.  If this function is called to define the local server, i.e. the given server name is the ServerName in the Replication section of the local ini file,  an error is signalled and the function has no effect.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_SERVER',
'fn_repl_server',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_name',
'REPL_SERVER',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'REPL_SERVER',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'replication_address',
'REPL_SERVER',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_server_rename',
'REPL_SERVER_RENAME',
'repl',
'rename the publishing server instance',
'
    This function is useful to rename the publishing servers data (that stored in to the replication tables) after renaming the server in virtuoso.ini file. The call of the procedure will associate the all data belong to the old server name to the current server name. It will also set the appropriate transaction levels. In case of duplicate publications (publications with the same name exists in old and new server definitions) it will reject the operation.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_SERVER_RENAME',
'fn_repl_server_rename',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'old_name',
'REPL_SERVER_RENAME',
  'varchar','in',
'The old name of the publishing server.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_name',
'REPL_SERVER_RENAME',
  'varchar','in',
'The new name of the publishing server (must be the same as ServerName from Replication section of INI file).'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_stat',
'REPL_STAT',
'repl',
'retrieve status of all subscriptions and publications',
'Retrieves status of all subscriptions and publications. This function is for interactive use (via ISQL tool).'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_STAT',
'fn_repl_stat',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'',
'REPL_STAT',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_status',
'repl_status',
'repl',
'returns status of a published or subscribed publication',
'
Given a publisher and publication name this returns the status of the publication
on the local server.  If the publisher is the name of the local server this
 returns the next transaction number to be assigned to a transaction as the level output parameter.

If the publisher is other than the local server this returns the transaction number
of the last transaction of that publication that has successfully been replicated to
the local database as the level output parameter.  The stat output parameter
reflects the current state of the subscription.  If the publisher is the local
server the stat is always 0.  Otherwise it has the following possible values:
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_status',
'fn_repl_status',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publisher',
'repl_status',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'repl_status',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'level',
'repl_status',
  'integer','out',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'stat',
'repl_status',
  'integer','out',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_subscribe',
'REPL_SUBSCRIBE',
'repl',
'add a subscription',
'This function is used to subscribe to an existing publication, 
      and to specify the local WebDAV owner (for replicated WebDAV content).  
      Before making a subscription the repl_server() must be called in order 
      to define the publisher server.  After making a subscription it becomes 
      off-line until it syncronized from scheduled task or with repl_sync() function.  
      Also the initial data of the subscription will be not loaded until 
      repl_init_copy() called or initial image loaded.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_SUBSCRIBE',
'fn_repl_subscribe',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_name',
'REPL_SUBSCRIBE',
  'varchar','in',
'target publisher server name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_SUBSCRIBE',
  'varchar','in',
'publication account name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dav_user',
'REPL_SUBSCRIBE',
  'varchar','in',
'valid local  WebDAV user account name which is used to own local 
    copy (if null @REPLICATION@ account will be created, disabled  by 
    default).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dav_group',
'REPL_SUBSCRIBE',
  'varchar','in',
'valid local WebDAV group name witch is used to own local copy.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'replication_user',
'REPL_SUBSCRIBE',
  'varchar','in',
'used to authenticate on 
publisher (should be valid DB account on publisher).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'replication_password',
'REPL_SUBSCRIBE',
  'varchar','in',
'used to authenticate on publisher (should be valid password 
      for replication_user on publisher).'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_sync',
'repl_sync',
'repl',
'starts the syncing process against an existing subscription',
'
This starts the syncing process against an existing subscription. The function
returns as soon as the request has been successfully sent. The synchronization will
take place in the background.  If the syncing process is already underway or if
the subscriber is already in sync and connected to the publisher this function has no effect.
If there is no connection to the publisher at the time of calling this function and the connection
fails an error is immediately signalled.
To initiate a syncronization the valid SQL account must be specified. Also the account must have rights to the publication unless publisher DBA@s account is used to connect.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_sync',
'fn_repl_sync',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publisher',
'repl_sync',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'repl_sync',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uid',
'repl_sync',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'repl_sync',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_sync_all',
'repl_syc_all',
'repl',
'synchronize all subscriptions',
'
This function is used to syncronize all subscriptions. It make a syncronization requests to the all publisher and will return immediately after that. The status of subscriptions can be tested with repl_stat() function. 
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_sync_all',
'fn_repl_sync_all',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'',
'repl_sync_all',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_text',
'repl_text',
'repl',
'adds a SQL statement to the log of the replication',
'
This SQL function adds the SQL statement to the log of the publication.  The statement will
typically be a procedure call but can be any SQL statement.  There can be
a parameters, which are bound to ?@s in the statement@s text from left to right.
No restriction for number of parameters.
The parameters are input only since the actual call will take place on
a remote server at an unknown future time.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_text',
'fn_repl_text',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'repl_text',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sqltext',
'repl_text',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'a-1',
'repl_text',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'repl_text',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_this_server',
'repl_this_server',
'repl',
'returns calling servers name',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'repl_this_server',
'fn_repl_this_server',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_unpublish',
'REPL_UNPUBLISH',
'repl',
'drop publication on publisher',
'
    This function is used to remove from current replication set an existing publication.
    The replication messages for all existing items will be stopped, so the last replication message will
    instruct the subscribers that this publication is dropped.
    On subscriber side depending of the copy mode of items they can be removed or not, but the
    description entry for that publication will be removed explicitly.
    Any existing grants to the publication being dropped will be revoked.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_UNPUBLISH',
'fn_repl_unpublish',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_UNPUBLISH',
  'varchar','in',
'publication account name.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_repl_unsubscribe',
'REPL_UNSUBSCRIBE',
'repl',
'drop subscription',
'server_name target publisher server name.publication publication account name.item item to be removed, NULL to remove all items.
This function is used to stop receiving a replication messages from a publisher server for a item or whole subscription. It will be invoked automatically when publication is dropped. Anyway the subscriber also can invoke it that means no more replcation messages to be received.
The existing items can be dropped or not depending of the copy mode flag.
The description entries for that subscription will be removed and reversal operation cannot be done. To stop temproraly the replication messages you can use repl_disconnect().
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'REPL_UNSUBSCRIBE',
'fn_repl_unsubscribe',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_name',
'REPL_UNSUBSCRIBE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'REPL_UNSUBSCRIBE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'item',
'REPL_UNSUBSCRIBE',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_result',
'result',
'sql',
'Sends one row of results to the calling client.',
'The result_names()
predefines variables to be used in a result set to follow.  The variables must 
be previously declared, from which the column data types are ascertained.  
This assigns the meta data but does not send any results.  The 
result() function sends its parameters as a single row 
of results.  These parameters should be compatible with those in the previous 
result_names().  The end_results() 
function can be used to separate multiple result sets.  The 
result_names() can then be used to alter 
the structure of the next result set.The result_names() call can be omitted if 
the application already knows what columns and their types are to be returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'result',
'fn_result',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'col_1',
'result',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'..',
'result',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'col_n',
'result',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_result_names',
'result_names',
'sql',
'',
'The result_names()
predefines variables to be used in a result set to follow.  The variables must 
be previously declared, from which the column data types are ascertained.  
This assigns the meta data but does not send any results.  The 
result() function sends its parameters as a single row 
of results.  These parameters should be compatible with those in the previous 
result_names().  The end_results() 
function can be used to separate multiple result sets.  The 
result_names() can then be used to alter 
the structure of the next result set.The result_names() call can be omitted if 
the application already knows what columns and their types are to be returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'result_names',
'fn_result_names',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'var_1',
'result_names',
  '','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'result_names',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'var_n',
'result_names',
  '','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rexecute',
'rexecute',
'rmt',
'execute a SQL statement on a remote DSN',
'The result_set param is useful to obtain a result set quickly and
    easily. However, if the result set is going to be large, this comes with
    a cost in time and resources such as memory, since Virtuoso would have to
    obtain all results from the statement and build the result-set arrays in
    memory before returning.A more efficient way is to obtain a cursor handle and iterate
    through the result set one row at a time:To keep Virtuoso from obtaining the whole result set from the
    remote, pass NULL as the result_set parameter
    when calling rexecute.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rexecute',
'fn_rexecute',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'rexecute',
  'varchar','in',
'The data source where the SQL statement should be executed.
      You must make sure that you have already defined the data source
      using the 
      vd_remote_data_source function or by attaching tables from it.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_stmt',
'rexecute',
  'varchar','in',
'the SQL statement to execute.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_state',
'rexecute',
  'varchar','out',
'A varchar containing the SQL State returned from the
      remote data source.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'error_message',
'rexecute',
  'varchar','out',
'A varchar containing any error message returned from
      the remote.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'in_params',
'rexecute',
  'vector','in',
'A vector of input parameters to the statement if the
      executed statement has parameters.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num_cols',
'rexecute',
  'integer','out',
'Number of columns in the result set if the statement returned
      one.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'stmt_meta',
'rexecute',
  'vector','out',
'A vector containing  result metadata, etc.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'result_set',
'rexecute',
  'vector','out',
'A vector of vectors containing each row in the
      result set.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'rexecute',
  'cursor handle','out',
'The cursor handle (long).'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_right',
'right',
'string',
'get n rightmost characters of a string',
'right returns the count rightmost characters of string str.If count is zero an empty string @@ is returned.If length of str is less than count then a copy of the whole
    str is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'right',
'fn_right',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'right',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'count',
'right',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rmoreresults',
'rmoreresults',
'rmt',
'move to next result set of rexecute()',
'This function moves to the next result set when handling
    result sets returned by statement executed with rexecute.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rmoreresults',
'fn_rmoreresults',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'rmoreresults',
  'cursor handle','in',
'The cursor handle obtained from
      rexecute'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_state',
'rmoreresults',
  'varchar','out',
'Output parameter for returning SQL state.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_error',
'rmoreresults',
  'varchar','out',
'Output parameter for returning an error message.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num_cols',
'rmoreresults',
  'integer','out',
'Output parameter for returning number of columns in a result
      row.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'stmt_meta',
'rmoreresults',
  'vector','out',
'The metadata vector as described in documentation for
      rexecute.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rnd',
'rnd',
'number',
'returns a random number between 0 and n - 1 inclusive',
'
The rnd function returns a random number between zero and n - 1, inclusive.
    randomize initializes the random number generator.
The random number generator is initialized after the clock at first usage, so the
produced sequences will be different each time unless
specifically initialized.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rnd',
'fn_rnd',
'number',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'n',
'rnd',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rnext',
'rnext',
'rmt',
'Get next result from a remote result set',
'Use rnext in combination with
    rmoreresults to
    iterate over a result set produced by a statement run in a remote data source
    with rexecute.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rnext',
'fn_rnext',
'integer retcode',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'cursor_handle',
'rnext',
  'cursor handle','in',
'The long cursor handle as obtained from rexecute.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row_array',
'rnext',
  'array','out',
'An output vector that will contain the result
      columns.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_state',
'rnext',
  'varchar','out',
'Optional varchar output parameter for SQL state.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_error',
'rnext',
  'varchar','out',
'Optional varchar output parameter for any error
      message.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_row_column',
'row_column',
'sql',
'Retrieves a column value from a row string given the name of
the table and column.',
'
This function retrieves a column value from a row string given the name of
the table and column if such a column existed in the row.  If not, NULL is
returned.

row is a row string obtained by selecting _ROW from
some table, or a row identity string returned by
row_identity().  In this case
the column being retrieved must be part of the primary key of the table
the row identity string references.

Table_name is the name of the table that defines the column being retrieved.

Col_name is the name of the column.

The output parameter exists is optional.  If a
variable is specified here,
it is set to 1 if the table contains a column of the name requested.

If table_name and col_name specify a column that is not in the row,
NULL is returned. This can happen if the row comes from a table other than
the one specified in table_name.

is identical to

The direct column reference is faster, naturally.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'row_column',
'fn_row_column',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row ',
'row_column',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name ',
'row_column',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'col_name ',
'row_column',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'exists ',
'row_column',
  'integer','out',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_row_count',
'row_count',
'sql',
'returns number of rows affected by the previous DML statement in a procedure body',
'
This function returns the count of rows affected by the previous DML statement
in a procedure body.  The scope is local to the procedure.  Calling
this from ODBC will always return 0.  This is the PL equivalent of the
SQLRowCount ODBC function.  The count is set after any in-line searched or positioned update, insert or delete.  This is also set by the exec function.  The count stays set until overwritten by the next DML operation. This is not set by rexecute.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'row_count',
'fn_row_count',
'integer',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_row_identity',
'row_identity',
'sql',
'Retrieves the row identity string from a row string.',
'This function retrieves the row identity string from a row
string. The identity string contains the name of the table and primary key
of the row, allowing the row to be retrieved.

row is a row string obtained by selecting _ROW from some table.
The row identity string is a regular varchar value that can appear as a
column value. This is a sort of @universal foreign key@ with which a
reference can be made to any part of the database.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'row_identity',
'fn_row_identity',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row ',
'row_identity',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_row_table',
'row_table',
'sql',
'Given a row string, returns the name of the table the row came from as a string.',
'
row is a row string obtained by selecting _ROW from
some table, or a row identity string returned by row_identity().

Given a row string, this function returns the name of the table the row
came from as a string.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'row_table',
'fn_row_table',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'row ',
'row_table',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_rtrim',
'rtrim',
'string',
'trims given characters from right of given string',
'    ltrim returns a copy of subsequence of string str with all the characters
    present in trimchars trimmed off from the beginning. If the second
    argument is omitted, it is a space @ @ by default.

    rtrim is similar except that it trims from the right.

    trim trims from both ends.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'rtrim',
'fn_rtrim',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'rtrim',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'trimchars',
'rtrim',
  'varchar','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_second',
'second',
'date',
'get second from a datetime',
'second takes a datetime and returns 
    an integer containing a number representing the second of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'second',
'fn_second',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'second',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_serialize',
'serialize',
'misc',
'convert any heterogeneous array or tree of arrays into a binary string and back',
'
These functions will convert any heterogeneous
array or tree of arrays into a binary string and back.  The format
is platform independent.
	
is the identity function.
	
These functions are useful for persisting heterogeneous arrays.
	The serialization can be stored as a blob, so that there is no practical
length limit.  The string length is however limited to 16 MB.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'deserialize',
'fn_serialize',
'binary string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'deserialize',
  'varchar','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'serialize',
'fn_serialize',
'binary string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tree',
'serialize',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_serv_queue_top',
'SERV_QUEUE_TOP',
'ws',
'Retrieve target website and store within Virtuoso',
'Web Robot site retrieval can be performed with the WS.WS.SERV_QUEUE_TOP PL function
integrated in to the Virtuoso server.
To run multiple walking robots all you simply need to do is kick them off from
separate ODBC/SQL connections and all robots will walk together without overlapping.

>From a VSP interface, after calling the retrieval function you may
call http_flush to keep running tasks
in the server and allowing the user agent to continue with other tasks.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'SERV_QUEUE_TOP',
'fn_serv_queue_top',
'WS.WS.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'target',
'SERV_QUEUE_TOP',
  'varchar','in',
'URI to target site.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'WebDAV_collection',
'SERV_QUEUE_TOP',
  'varchar','in',
'Local WebDAV collection to copy the content to.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'update',
'SERV_QUEUE_TOP',
  'integer','in',
'Flag to set updatable, can be 1 or 0 for on or off respectably.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'debug',
'SERV_QUEUE_TOP',
  'integer','in',
'Debug flag, must be set to 0'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'function_hook',
'SERV_QUEUE_TOP',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'data',
'SERV_QUEUE_TOP',
  'any/variable','in',
'application dependent data, usually an array, is passed to the PL function
hook to perform next queue entry extraction.  In our example we use an array with
names of non-desired sites.
'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_set_identity_column',
'set_identity_column',
'sql',
'sets the sequence starting value for an identity column',
'This function takes the table name, the column name and the new 
		sequence value as parameters.  It checks for the existence of the identity column, 
		and then sets the sequence value (using the sequence_set) and returns the 
		old sequence value.  The table and column names must be properly qualified to 
		ensure the correct resource is located.  The effect of calling this function 
		is immediate.  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'set_identity_column',
'fn_set_identity_column',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'set_identity_column',
  'varchar','in',
'the fully qualified table name in the correct case exactly as it 
		  appears in the DB.DBA.SYS_KEYS table.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'column_name',
'set_identity_column',
  'varchar','in',
'the exact column name as it appears in the DB.DBA.SYS_COLS table.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_value',
'set_identity_column',
  'integer','in',
'the new sequence value.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sign',
'sign',
'type',
'returns -1, 0, or 1 depending on the sign of its numerical',
'    sign returns either -1, 0 or 1 depending whether its numeric argument is
    negative, zero or positive.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sign',
'fn_sign',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'sign',
  'numeric','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_signal',
'signal',
'sql',
'Signal an exception   in the calling procedure',
'
This signals the given SQLSTATE with the message.  The calling procedure will transfer control to the most appropriate local handler. In the absence of a local handler the procedure terminates and signals the exception in the scope where it was called from, until there either is a handler or there are no more calling procedures.  If there is no handler in the entire stack of call contexts the error is signalled to the client.
Handlers can be declared with whenever .. goto and the declare handler for construct.
See the Virtuoso/PL documentation.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'signal',
'fn_signal',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sqlstate',
'signal',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'message',
'signal',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_smime_sign',
'smime_sign',
'mail',
'Converts a MIME message to a signed S/MIME message',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'smime_sign',
'fn_smime_sign',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'msg_text',
'smime_sign',
  'varchar','in',
'The text of the message'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'signer_cert',
'smime_sign',
  'varchar','in',
'Signer certificate.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'private_key',
'smime_sign',
  'varchar','in',
'Private Key',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'private_key_pass',
'smime_sign',
  'varchar','in',
'Private Key Pass',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'signer_CA_certs',
'smime_sign',
  'any/variable','in',
'Array of strings of CA Certificates',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'flags',
'smime_sign',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_smime_verify',
'smime_verify',
'mail',
'Verifies signature of signed MIME message',
'
	This function takes the RFC822 text of an e-mail containing an S/MIME signed
	message and verifies it@s signature using the CA certificates in certs, which
	is an array of strings containing single or multiple PEM-encoded certificates.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'smime_verify',
'fn_smime_verify',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'msg_text',
'smime_verify',
  'varchar','in',
'The text of the message'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'certs',
'smime_verify',
  'any/variable','in',
'array of strings containing CA certificates'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'signer_certs',
'smime_verify',
  'any/variable','out',
'for receipt of PEM encoded certificates',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'flags',
'smime_verify',
  'integer','in',
'A bitmask. See table below for valid mask values. Default is 0.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_smtp_send',
'smtp_send',
'mail',
'send message to SMTP server',
'Virtuoso can act as an SMTP client.  This means that Virtuoso is able to send emails directly
to a mail SMTP server.  Virtuoso has a simple function to facilitate this which means that it can
be achieved by any means such as from stored procedures, VSP pages, or part of a tables trigger.

The sender and recipient email addresses must be enclosed with <..> and separated by comma
i.e. string @<support@openlinksw.co.uk>,<sales@openlinksw.co.uk>@

The message Body contains headers such as Subject, From, To, Cc, Bcc and then continues with
the actual message text itself.  New lines can be added using @\r\n@

Virtuoso will pick up Subject and other headers from the body content.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'smtp_send',
'fn_smtp_send',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server',
'smtp_send',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sender',
'smtp_send',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'recipient',
'smtp_send',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'body',
'smtp_send',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_box_xml_entity',
'soap_box_xml_entity',
'soap',
'Converts an XML entity to an SQL value based on the type of the entity and the desired type.',
'
This function converts an XML entity to an SQL value based on the type of the entity and the desired SQL type.
This function is called internally to convert a SOAP request parameter to a PL procedure parameter when a SOAP
request is being processed by the SOAP server.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_box_xml_entity',
'fn_soap_box_xml_entity',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'entity',
'soap_box_xml_entity',
  'any/variable','in',
'The XML fragment as a vector (as returned from
xml_tree() or a subpart of it).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'try_typed_as',
'soap_box_xml_entity',
  'any/variable','in',
'A sample value, whose type is taken as a desired type for conversion.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'soap_version',
'soap_box_xml_entity',
  'integer','in',
'Optional (default 1).  The soap version (1 for SOAP 1.0, 11 for SOAP 1.1).',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_dt_define',
'soap_dt_define',
'soap',
'define re-define or erase the complex datatype definition for SOAP calls',
'This defines a new complex SOAP datatype (usualy array of structure) named @name@.   


The schema_string string represents definition as complexType element from XML Schema.
The only complexContent, all and sequence elements can be used within the complexType. This means that 
optional elements in the defined datattype are not supported as a variant of the SOAP paramter datatype.
If the schema descritopns contains an unsuported element , the SQL error will be signalled and error message 
will explain what element is wrong.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_dt_define',
'fn_soap_dt_define',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'name',
'soap_dt_define',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'schema_string',
'soap_dt_define',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_call',
'soap_call',
'soap',
'calls a function from a SOAP server and returns the result. value',
'
This calls a function from a SOAP server and returns the result as a return value.
Params is an array of (Parameter name, Value) pairs representing the parameters
passed in the SOAP call.  Each of these pairs become an XML sub-entity
of the procedure entity.  The return value of the function is the entity
inside the SOAP body of the response.  In debug mode the return value is an
array of 3 elements; the non-debug return value (if any) as element 0, the XML
text of the request as element 1 and the XML text of the server response
as element 2.  This function does not use any XML types when creating the
XML.  It represents types as a cast to varchar would, with one
exception - dates and times according to ISO8061.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_call',
'fn_soap_call',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'host',
'soap_call',
  'varchar','in',
'DNS name or IP address of the SOAP server'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'soap_call',
  'varchar','in',
'path into the HTTP server containing the SOAP server page'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'methodURI',
'soap_call',
  'varchar','in',
'URI of the SOAP method being called'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'methodName',
'soap_call',
  'varchar','in',
'Name of the SOAP method being called'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'params',
'soap_call',
  'array','in',
'array of parameters to the SOAP call; array of (ParamName, Value)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'version',
'soap_call',
  'integer','in',
'the SOAP version used in call (SOAP 1.0 = 1, SOAP 1.1 = 11).  Default value = SOAP 1.0.
If the value is negated : i.e. -1 or -11 then the soap_call procedure enters "debug" mode
    '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'certificate',
'soap_call',
  'varchar','in',
'If this parameter is specified (string or null) the HTTPS operation will be performed.
      Path to the HTTPS client certificate in PKCS#12 format, if this parameter is set to NULL
      then client will do only encrypted connection.
    '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'soap_call',
  'varchar','in',
'If certificate is supplied this parameter must contain password for opening the certificate file.
    '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_make_error',
'soap_make_error',
'soap',
'Creates a SOAP error reply XML message based on its parameters.',
'
This function creates a SOAP error reply based on the given parameters.  It returns the generated XML
as a varchar value.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_make_error',
'fn_soap_make_error',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'soap_code',
'soap_make_error',
  'varchar','in',
'Required.  The fault code according to the SOAP specification.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_state',
'soap_make_error',
  'varchar','in',
'Required.  The error@s SQL state.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'error_message',
'soap_make_error',
  'varchar','in',
'Required.  The error text.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'soap_version',
'soap_make_error',
  'integer','in',
'Optional (default 11).  The SOAP version used to encode the SOAP error reply.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'do_uddi',
'soap_make_error',
  'integer','in',
'Optional (default 0).  1 = produce UDDI error format; 0 = SOAP error format.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_print_box',
'soap_print_box',
'soap',
'Formats an SQL value and returns it as a generated XML fragment.',
'
This function formats an SQL value as an XML fragment and returns it.
This is used internally by the SOAP server to encode the output parameter values and return values when
processing a SOAP request.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_print_box',
'fn_soap_print_box',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'value',
'soap_print_box',
  'any/variable','in',
'Required. Any SQL value to be represented as an XML fragment.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'enclosing_tag',
'soap_print_box',
  'varchar','in',
'Required. The XML tag to place the value into.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'date_encoding_type|soap_version',
'soap_print_box',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_sdl',
'soap_sdl',
'soap',
'Generate SDL document for a PL module and return it as a varchar.',
'This function generates a SDL for the procedures in a PL module the same way as
    /SOAP/services.xml is generated for the procedures in WS.SOAP.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_sdl',
'fn_soap_sdl',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'module_name',
'soap_sdl',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'URL',
'soap_sdl',
  'varchar','in',
'Optional (default is the current VSP path if in VSP context. Otherwise error).
      The URL to include in the SDL file',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_server',
'soap_server',
'soap',
'Execute SOAP request and return XML reply as a varchar.',
'
This function executes the SOAP request in the same way as it it was
directed to the /SOAP physical path.
It returns the XML SOAP reply as a varchar value.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_server',
'fn_soap_server',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'req_xml',
'soap_server',
  'any/variable','in',
'Required. The XML entity of the SOAP request to execute.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'soap_method',
'soap_server',
  'varchar','in',
'Optional(default ""). The "SOAPAction" header field value',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'lines',
'soap_server',
  'any/variable','in',
'Optional(default NULL). The Request header fields (the lines parameter to the VSPs for HTTP)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'soap_version',
'soap_server',
  'long','in',
'Optional(default 11). The SOAP version (11 for SOAP 1.1 and 1 for SOAP 1.0)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'procedure_mappings',
'soap_server',
  'any/variable','in',
'Optional(default NULL). A vector of pairs (<SOAP_method>, <PL procedure>)
mapping the SOAP call request to the corresponding PL function name.
If empty, then the mapping proceeds by taking the local name of the SOAP
method and finding a procedure with the same name in the executing
user@s current qualifier and owner.If a string is supplied then this string is considered as a PL module name.
      Mapping takes place from the local name of the SOAP call to a PL procedure inside
      the module. Virtuoso matches procedure names in case-sensitive fashion.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_soap_wsdl',
'soap_wsdl',
'soap',
'Generate WSDL document for a PL module and return it as a varchar.',
'
   This  function generates WSDL for the procedures in a PL module the same way as /SOAP/services.wsdl
   is generated for the procedures in WS.SOAP.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'soap_wsdl',
'fn_soap_wsdl',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'module_name',
'soap_wsdl',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'URL',
'soap_wsdl',
  'varchar','in',
'Optional(default the current VSP path if in VSP context. Otherwise
error). The URL to include in the WSDL file',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_space',
'space',
'string',
'returns a new string of count spaces',
'space returns a new string, composed of count spaces.
If count is zero, an empty string @@ is returned.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'space',
'fn_space',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'count',
'space',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_split_and_decode',
'split_and_decode',
'misc',
'converts escaped var=val pairs to a vector of strings',
'
   split_and_decode converts the escaped var=val pair inputs text to a
   corresponding vector of string elements. If the optional third
   argument is a string of less than three characters, then does only
   the decoding (but no splitting) and returns back a string.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'split_and_decode',
'fn_split_and_decode',
'vector or string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'coded_str',
'split_and_decode',
  'varchar','in',
'Input string to be converted.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'case_mode',
'split_and_decode',
  'integer','in',
'This optional second argument, if present should be an integer
   either 0, 1 or 2, which tells whether "variable name"-parts
   (those at the left side of the fourth character given in
   third argument (or = if using the default URL-decoding))
   are converted to UPPERCASE (1), lowercase (2) or left intact
   (0 or when the second argument is not given).This avoids all hard-coded limits for the length
   of elements, by scanning the inputs string three times.
   First for the total number of elements (the length of vector
   to allocate), then calculating the length of each string element
   to be allocated, and finally transferring the characters of elements
   to the allocated string elements.
	',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'str',
'split_and_decode',
  'varchar','in',
'If this argument is a string of less than three characters then
      this function will only decode without splitting and will return a string.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sprintf',
'sprintf',
'string',
'returns a formatted string',
'sprintf returns a new string formed by "printing" a variable number
    of arguments arg_1 - arg_x according to the format string format,
    that is, exactly the same way as with the sprintf function of C language.
    However the sprintf function enforces some additional limitations over the sprintf C function.
    It does not allow for single value output to take more than 2000 characters.
    It does support the following additional format characters:

    diouxXeEfgcs - as in the C language printf

    S - as @s@ but escapes the single quotes by doubling them (as per SQL/92). This is suitable for
    constructing dynamic SQL statements with string literals inline.

    I - as @s@ but escapes the string value to form a valid identifier name (will double the double
      quotes).  This is suitable for constructing dynamic SQL statements with identifiers inline.

    U - as @s@ but escapes the string value as an HTTP URL (same as http_url() BIF). Useful for making
      dynamic VSP content

    V - as @s@ but escapes the string value as an HTTP Value (same as http_value). Useful for making
      dynamic VSP content

    Note that the sprintf format length and precision modifiers do not apply to the extension format characters
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sprintf',
'fn_sprintf',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'format',
'sprintf',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg_1',
'sprintf',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'sprintf',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg_x',
'sprintf',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_columns',
'sql_columns',
'rmt',
'get column information from table on a remote DSN',
'This function corresponds to the ODBC catalog call of similar name.
    It and related functions are used by the virtual database to query
    remote data dictionaries.The dsn argument must refer to a dsn previously defined by
    vd_remote_data_source or ATTACH TABLE.For instance, the qualifier argument corresponds to the
    szTableQualifier and cbTableQualifier arguments of an ODBC catalog
    function.  The SQL NULL value corresponds to the C NULL value.
    The arguments can contain % signs, which are interpreted as in LIKE.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_columns',
'fn_sql_columns',
'vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'sql_columns',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'qualifier',
'sql_columns',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'owner',
'sql_columns',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sql_columns',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'column',
'sql_columns',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_data_sources',
'sql_data_sources',
'rmt',
'get list of available DSNs',
'sql_data_sources is used to get the list of datasources
    available to the dsn. It returns a vector of 2 element vectors containing Data
    source name and type pairs.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_data_sources',
'fn_sql_data_sources',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_gettypeinfo',
'sql_gettypeinfo',
'rmt',
'return type information from a remote DSN',
'You can use the functions described here to find out information about the
remote datasources that you are using.  These could be especially useful in Virtuoso PL
later on if you are not able to know everything about the remote tables ahead of time for
the ATTACH TABLE statement.
statement
These SQL functions correspond to the ODBC catalog calls of similar name.

The dsn argument must refer to a dsn previously defined by
vd_remote_data_source or ATTACH TABLE.

By default information for all the data types supported by the remote is returned.
The optional type argument (defaults to SQL_ALL_TYPES) limits the information
returned to cover only the ODBC type number supplied.

These functions return an array, with one element for each row of the result set.
Each row is represented as an array with one element for each column.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_gettypeinfo',
'fn_sql_gettypeinfo',
'vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'sql_gettypeinfo',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'type',
'sql_gettypeinfo',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_primary_keys',
'sql_primary_keys',
'rmt',
'get primary key information about a table on a remote DSN',
'You can use the functions described here to find out information about the
    remote datasources that you are using.  These could be especially useful in Virtuoso PL
    later on if you are not able to know everything about the remote tables ahead of time for
    the ATTACH TABLE statement.
    statementThese SQL functions correspond to the ODBC catalog calls of similar name.
    These are used to access the data dictionary of remote data sources inside the
    ATTACH TABLE process.The dsn argument must refer to a dsn previously defined by
    vd_remote_data_source or ATTACH TABLE.For instance, the qualifier argument corresponds to the szTableQualifier and
    cbTableQualifier arguments of an ODBC catalog function.  A SQL NULL value
    corresponds to the C NULL value.  The arguments can contain % signs, which
    are interpreted as in LIKE.These functions return an array, with one element for each row of the result set.
    Each row is represented as an array with one element for each column.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_primary_keys',
'fn_sql_primary_keys',
'vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'sql_primary_keys',
  'varchar','in',
'The data source name string'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'qualifier',
'sql_primary_keys',
  'varchar','in',
'Qualifier string. May contain wildcards as in @De%@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'owner',
'sql_primary_keys',
  'varchar','in',
'Table owner string. May contain wildcard characters in @Dem%@.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sql_primary_keys',
  'varchar','in',
'Table name string. May contain wildcard characters in @Cust%@.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_statistics',
'sql_statistics',
'rmt',
'retrieve statistics information on remote DSN',
'This SQL function corresponds to the ODBC catalog call of similar name.
    It is used to access the data dictionary of remote data sources inside the
    ATTACH TABLE process.The dsn argument must refer to a dsn previously defined by
    vd_remote_data_source or ATTACH TABLE.The qualifier argument corresponds to the szTableQualifier and
    cbTableQualifier arguments of an ODBC catalog function.  A SQL NULL value
    corresponds to the C NULL value.  The arguments can contain % signs, which
    are interpreted as in LIKE.These functions return an array, with one element for each row of the result set.
    Each row is represented as an array with one element for each column.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_statistics',
'fn_sql_statistics',
'vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'sql_statistics',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'qualifier',
'sql_statistics',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'owner',
'sql_statistics',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sql_statistics',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_unique',
'sql_statistics',
  'integer','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'detail',
'sql_statistics',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sql_tables',
'sql_tables',
'rmt',
'get list of tables from remote DSN',
'This function corresponds to the ODBC catalog call of similar name.
    It and related functions are used by the virtual database to query
    remote data dictionaries.The dsn argument must refer to a dsn previously defined by
    vd_remote_data_source or ATTACH TABLE.The qualifier argument corresponds to the szTableQualifier and
    cbTableQualifier arguments of an ODBC catalog function.  A SQL NULL value
    corresponds to the C NULL value.  The arguments can contain % signs, which
    are interpreted as in LIKE.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sql_tables',
'fn_sql_tables',
'vector',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'sql_tables',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'qualifier',
'sql_tables',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'owner',
'sql_tables',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sql_tables',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tabletype',
'sql_tables',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sqrt',
'sqrt',
'number',
'calculate square root',
'sqrt calculates the square root of its
    argument and returns it as a IEEE 64-bit float.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sqrt',
'fn_sqrt',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'sqrt',
  'double precision','in',
'double precision'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_strcasestr',
'strcasestr',
'string',
'case-insensitive substring search',
'strcasestr performs a case-insensitive
    substring search, returning a zero-based index pointing to
    beginning of first occurrence of sub or
    NULL if not found.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'strcasestr',
'fn_strcasestr',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'strcasestr',
  'varchar','in',
'String to search from.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sub',
'strcasestr',
  'varchar','in',
'Substring to search for.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_strchr',
'strchr',
'string',
'strchr returns a zero-based index to the first occurrence of the character.',
'
    strchr returns a zero-based index to the first occurrence of char. If char is not found
    NULL is returned. char can be given either as an integer ASCII value or a
    string, in which case the first character of that string is searched fo.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'strchr',
'fn_strchr',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'strchr',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'char',
'strchr',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_stringdate',
'stringdate',
'time',
' Convert a string to a datetime',
'stringdate converts dates and timestamps from text to the internal
    DATETIME type.The external format is: YYYY.MM.DD  hh:mm.ss uuuuuu
    where uuuuuu represents number of microseconds.If trailing parts are omitted from the string given to stringdate,
    they are assumed to be zero. The three first parts are mandatory.
    Note that use of cast (x as datetime) is preferred
    over this function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'stringdate',
'fn_stringdate',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'stringdate',
  'varchar','in',
'A varchar date in human-readable (external)
      format.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_stringtime',
'stringtime',
'time',
'converts string to a time',
'Converts the argument to a time. Same as'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'stringtime',
'fn_stringtime',
'time',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'stringtime',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_string_output',
'string_output',
'string',
'make a string output stream',
'A string output stream is a special object that may be used to
    buffer arbitrarily long streams of data. They are useful for handling data
    that would not otherwise fit within normal varchar size
    limitations. The HTTP output functions optionally take a string output
    stream handle as a parameter and then output to said stream instead of
    the HTTP client. A string output stream can be assigned to a database column in insert or update, causing the characters written to the stream to be assigned to the column as a narrow string.
    The function
    string_output_string
    
     can be used to produce a varchar out of a string output stream. It may
     be called repeatedly to obtain several copies of the data.
    http_rewrite
    can be used to flush a string output stream.If a string output stream is passed to the function
    result the
    data stored in it is sent to the client.The string output object cannot be copied. It cannot therefore be
    assigned between two variables or passed by value (as an IN parameter.)
    It can be passed by reference (OUT, INOUT parameter.)'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string_output',
'fn_string_output',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_string_output_flush',
'string_output_flush',
'string',
'resets the state of the string_output object',
'
This function resets the state of the string output object. 
The string associated with the string output is dropped and is of 0 characters 
after this call.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string_output_flush',
'fn_string_output_flush',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'stream',
'string_output_flush',
  'any/variable','out',
'stream to clear, must have been created by the string_output function.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_string_output_gz_compress',
'string_output_gz_compress',
'misc',
'compress a string_output with gzip algorithm',
'The string_output_gz_compress compresses its string_output argument using the gzip
    algorithm and writes the result to another string_output given as an argument.
    When successful, the number of bytes written to str_out_out
    is returned.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string_output_gz_compress',
'fn_string_output_gz_compress',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str_out_in',
'string_output_gz_compress',
  'varchar','in',
'A string session as returned by string_output function.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str_out_out',
'string_output_gz_compress',
  'varchar','out',
'A string session as returned by string_output function.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_string_output_string',
'string_output_string',
'string',
'produce a string out of a string output stream',
'This function is used to produce a string from contents of a
    string output stream. See
    string_output
    for more information about string output streams.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string_output_string',
'fn_string_output_string',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string_out',
'string_output_string',
  'varchar','in',
'The string output stream'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_string_to_file',
'string_to_file',
'string',
'writes a varchar to a file',
'string_to_file writes a varchar
    value or string session to a file. The path is relative to the server@s
    working directory. The mode is an integer value interpreted as a
    position. A mode of 0 writes the content starting at offset 0.
    A mode of -1 appends to the end of the file. The append option is
    probably the most useful for producing application level logs,
    etc.The string argument can also be a string output object. In this
    case the content is used as the string.If the mode is -2, the new content supersedes the old.  This is
    different from 0 in that the file will be truncated if the new content
    is shorter than the old.The DirsAllowed and DirsDenied lists in Parameters section of the
    virtuoso configuration file (virtuoso.ini by default) are used to control
    disk access. An error 42000/FA024 is signalled if an attempt is made to
    write to a file in a directory to which disk access is not explicitly
    allowed.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string_to_file',
'fn_string_to_file',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'string_to_file',
  'varchar','in',
'varchar relative path.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'string',
'string_to_file',
  'varchar','in',
'varchar or string session to write to
      the file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'string_to_file',
  'integer','in',
'integer mode.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_strrchr',
'strrchr',
'string',
'returns a zero-based index to the last occurrence of the char in str.',
'
    strchr returns a zero-based index to the last occurrence of  char in string. If char is not found
    NULL is returned. char can be given either as an integer ASCII value or a
    string, in which case the first character of that string is searched for
    in  str.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'strrchr',
'fn_strrchr',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'strrchr',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'char',
'strrchr',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_strstr',
'strstr',
'string',
'substring search',
'strcasestr performs a
    substring search, returning a zero-based index pointing to
    beginning of first occurrence of sub or
    NULL if not found.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'strstr',
'fn_strstr',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'strstr',
  'varchar','in',
'String to search from.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sub',
'strstr',
  'varchar','in',
'Substring to search for.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_subseq',
'subseq',
'string',
'returns substring of a string or sub-vector of a vector',
'subseq returns a copy of subsequence of string or vector str using zero-based
    indices from (inclusive) and to (exclusive) to delimit the substring or the vector
    extracted.

    If to is omitted or is NULL, then it equals by default to the length of
    str, i.e. everything from from to the end of str is returned.

    If to and from are equal, an empty string @@(empty vector) is returned.

    If from is greater than to or length of str an error is signalled.

    If str is NULL then NULL is returned.

The last one with string argument returns a copy of the string cut from the first slash,
leaving it and everything following out, and in the case where there
are no slashes present, returns a copy of the whole string.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'subseq',
'fn_subseq',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'subseq',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'from',
'subseq',
  'integer','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'to',
'subseq',
  'integer','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_substring',
'substring',
'string',
'returns a substring of a string  ',
'
    substring returns  a substring of string str. The start index is 1 based. The substring is sublen characters long.



This function follows SQL 92.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'substring',
'fn_substring',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'substring',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'from',
'substring',
  'integer','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sublen',
'substring',
  'integer','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sub_schedule',
'sub_schedule',
'repl',
'add scheduled job for periodic synchronization of a subscription',
'Add scheduled job for periodically synchronizing a  subscription.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sub_schedule',
'fn_sub_schedule',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'server_name',
'sub_schedule',
  'varchar','in',
'target publisher server name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'publication',
'sub_schedule',
  'varchar','in',
'publication  name.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'interval',
'sub_schedule',
  'integer','in',
'interval between synchronization attempts (in minutes).'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sync_repl',
'sync_repl',
'repl',
'synchronize all subscriptions',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sync_repl',
'fn_sync_repl',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'',
'sync_repl',
  '','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_system',
'system',
'misc',
'runs a shell command from SQL',
'
The system function will run a shell command from SQL. The shell command is executed
in the server@s current directory as the user that owns the database server process.

This function is available to dba users only. Since this is a security
risk this feature is normally disabled. It can be enabled by setting the
AllowOSCalls setting in virtuoso.ini to 1.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'system',
'fn_system',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'command',
'system',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sys_stat_analyze',
'sys_stat_analyze',
'sys_stat_analyze',
'Collects the column & table statistics for the optimized SQL compiler',
'
This function collects (or updates) column statistics for the table columns.

It collects minimum, maximum average adn distinct values for a column and a row count for the table and puts the
data in DB.DBA.SYS_COL_STAT table.

It doesn"t make historgrams for the columns.

The statistics are then used by the Optimized SQL compiler. All the cached compilations are
discarded, because some of them may compile differently in the light of the new data.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sys_stat_analyze',
'fn_sys_stat_analyze',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sys_stat_analyze',
  'varchar','in',
'The full name of the table exactly as in the KEY_TABLE column of SYS_KEYS.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'prec',
'sys_stat_analyze',
  'integer','in',
'The density of the rows examined. Defaults to 1 - all the rows',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_sys_stat_histogram',
'sys_stat_histogram',
'sys_stat_histogram',
'Collects the column & table statistics for the optimized SQL compiler',
'
This function collects (or updates) values distribution data for a given column.

It splits the sorted column values in n_buckets intervals and collects the last value of each interval.
The values are then inserted into the SYS_COL_HIST table.

If the table in question hasn"t been analyzed, then it calls SYS_STAT_ANALYZE for the table.

The histograms are then used by the Optimized SQL compiler. All the cached compilations are
discarded, because some of them may compile differently in the light of the new data.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sys_stat_histogram',
'fn_sys_stat_histogram',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table_name',
'sys_stat_histogram',
  'varchar','in',
'The full name of the table exactly as in the KEY_TABLE column of SYS_KEYS.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'column_name',
'sys_stat_histogram',
  'varchar','in',
'The full name of the column exactly as in the COLUMN column in SYS_COLS.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'n_buckets',
'sys_stat_histogram',
  'integer','in',
'How much intervals to form. If more intervals are available, the estimation
         of column predicates costs is more precise.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'prec',
'sys_stat_histogram',
  'integer','in',
'The density of the rows examined. Defaults to 1 (all the rows)',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_tidy_html',
'tidy_html',
'xml',
'Invoke built-in version of HTML Tidy utility to fix typical errors in  HTML text',
'
This function improves the given source HTML text, by invoking a
custom version of HTML Tidy utility.
To learn more about Tidy see http://www.w3.org/People/Raggett/tidy/ .
Some particular combinations of errors in source HTML may cause Tidy to
misinterpret the source so the output may be incomplete or corrupted.
This is an  unavoidable problem, due to heruistic nature of the procedure.
 On the other hand, Tidy will process almost any HTML suitable for some
"popular" browser, e.g. Internet Explorer or Netscape Navigator.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'tidy_html',
'fn_tidy_html',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'raw_html',
'tidy_html',
  'varchar','in',
'
Source HTML text to process.
Note that the encoding of this text must be specified in
tidy_config string,
and default encoding of session will not be mentoined by Tidy.
'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tidy_config',
'tidy_html',
  'varchar','in',
'
Configuration string is a list of options, delimited by newlines,
with exactly the same syntax as original Tidy@s configuration file.
Not all options of original Tidy will work, due to obvious reasons,
unsupported options will be silently ignored, so you may read your
favorite Tidy@s configuration file by file_to_string function and
pass it to tidy_html.
If set to yes (the default) Tidy will add a meta
element to the document head to indicate that the document has
been tidied. To suppress this, set tidy-mark to no. Tidy
won@t add a meta element if one is already present.Determines whether Tidy generates a pretty printed version of
the markup. Bool values are either yes or no.
Note that Tidy won@t generate a pretty printed version if it
finds unknown tags, or missing trailing quotes on attribute
values, or missing trailing @>@ on tags. The default is
yes.Sets the right margin for line wrapping. Tidy tries to wrap
lines so that they do not exceed this length. The default is 66.
Set wrap to zero if you want to disable line wrapping.If set to yes, attribute values may be wrapped
across lines for easier editing. The default is no. This option
can be set independently of wrap-scriptletsIf set to yes, this allows lines to be wrapped
within string literals that appear in script attributes. The
default is no. The example shows how Tidy wraps a really
really long script string literal inserting a backslash character
before the linebreak:

<a href="somewhere.html" onmouseover="document.status = @...some \
really, really, really, really, really, really, really, really, \
really, really long string..@;">test</a>

If set to no, this prevents lines from being wrapped
within ASP pseudo elements, which look like:
<% ... %>. The default is yes.If set to no, this prevents lines from being wrapped
within JSTE pseudo elements, which look like:
<# ... #>. The default is yes.If set to no, this prevents lines from being wrapped
within PHP pseudo elements. The default is yes.If set to yes, this ensures that whitespace
characters within attribute values are passed through unchanged.
The default is no.Sets the number of columns between successive tab stops. The
default is 4. It is used to map tabs to spaces when reading
files. Tidy never outputs files with tabs.If set to yes, Tidy will indent block-level tags.
The default is no. If set to auto Tidy will
decide whether or not to indent the content of tags such as
title, h1-h6, li, td, th, or p depending on whether or not the
content includes a block-level element. You are advised to avoid
setting indent to yes as this can expose layout bugs in some
browsers.Sets the number of spaces to indent content when indentation
is enabled. The default is 2 spaces.If set to yes, each attribute will begin on a new
line. The default is no.If set to yes, optional end-tags will be omitted
when generating the pretty printed markup. This option is ignored
if you are outputting to XML. The default is no.If set to yes, Tidy will use the XML parser rather
than the error correcting HTML parser. The default is
no.If set to yes, Tidy will use generate the pretty
printed output writing it as well-formed XML. Any entities not
defined in XML 1.0 will be written as numeric entities to allow
them to be parsed by an XML parser. The tags and attributes will
be in the case used in the input document, regardless of other
options. The default is no.If set to yes, Tidy will add the XML declatation
when outputting XML or XHTML. The default is no. Note
that if the input document includes an <?xml?> declaration
then it will appear in the output independent of the value of
this option.If set to yes, Tidy will generate the pretty printed
output writing it as extensible HTML. The default is no.
This option causes Tidy to set the doctype and default namespace
as appropriate to XHTML. If a doctype or namespace is given they
will checked for consistency with the content of the document. In
the case of an inconsistency, the corrected values will appear in
the output. For XHTML, entities can be written as named or
numeric entities according to the value of the "numeric-entities"
property. The tags and attributes will be output in the case used
in the input document, regardless of other options.This property controls the doctype declaration generated by
Tidy. If set to omit the output file won@t contain a
doctype declaration. If set to auto (the default) Tidy
will use an educated guess based upon the contents of the
document. If set to strict, Tidy will set the doctype to
the strict DTD. If set to loose, the doctype is set to
the loose (transitional) DTD. Alternatively, you can supply a
string for the formal public identifier (fpi) for example:

doctype: "-//ACME//DTD HTML 3.14159//EN"

If you specify the fpi for an XHTML document, Tidy will set
the system identifier to the empty string. Tidy leaves the
document type for generic XML documents unchanged.Determines how Tidy interprets character streams. For
ascii, Tidy will accept Latin-1 character values, but
will use entities for all characters whose value > 127. For
raw, Tidy will output values above 127 without
translating them into entities. For latin1 characters
above 255 will be written as entities. For utf8, Tidy
assumes that both input and output is encoded as UTF-8. You can
use iso2022 for files encoded using the ISO2022 family
of encodings e.g. ISO 2022-JP. The default is
ascii.Causes entities other than the basic XML 1.0 named entities
to be written in the numeric rather than the named entity form.
The default is noIf set to yes, this causes " characters to be
written out as &quot; as is preferred by some editing
environments. The apostrophe character @ is written out as
&#39; since many web browsers don@t yet support &apos;.
The default is no.If set to yes, this causes non-breaking space
characters to be written out as entities, rather than as the
Unicode character value 160 (decimal). The default is
yes.If set to yes, this causes unadorned &
characters to be written out as &amp;. The default is
yes.If set to yes, this changes the parsing of
processing instructions to require ?> as the terminator rather
than >. The default is no. This option is
automatically set if the input is in XML.If set to yes, this causes backslash characters "\"
in URLs to be replaced by forward slashes "/". The default is
yes.If set to yes, Tidy will output a line break before
each <br> element. The default is no.Causes tag names to be output in upper case. The default is
no resulting in lowercase, except for XML input where
the original case is preserved.If set to yes attribute names are output in upper
case. The default is no resulting in lowercase, except
for XML where the original case is preserved.If set to yes, Tidy will go to great pains to strip
out all the surplus stuff Microsoft Word 2000 inserts when you
save Word documents as "Web pages". The default is no.
Note that Tidy doesn@t yet know what to do with VML markup from
Word, but in future I hope to be able to map VML to SVG.
 Microsoft has developed its own optional filter for exporting to
HTML, and the 2.0 version is much improved. You can download the
filter free from the 
Microsoft Office Update site.If set to yes, causes Tidy to strip out surplus
presentational tags and attributes replacing them by style rules
and structural markup as appropriate. It works well on the html
saved from Microsoft Office@97. The default is no.If set to yes, causes Tidy to replace any occurrence
of i by em and any occurrence of b by strong. In both cases, the
attributes are preserved unchanged. The default is no.
This option can now be set independently of the clean and
drop-font-tags options.If set to yes, empty paragraphs will be discarded.
If set to no, empty paragraphs are replaced by a pair of
<br> elements as HTML4 precludes empty paragraphs. The
default is yes.If set to yes together with the clean option (see
above), Tidy will discard font and center tags rather than
creating the corresponding style rules. The default is
no.If set to yes, this causes Tidy to enclose any text
it finds in the body element within a p element. This is useful
when you want to take an existing html file and use it with a
style sheet. Any text at the body level will screw up the
margins, but wrap the text within a p element and all is well!
The default is no.If set to yes, this causes Tidy to insert a p
element to enclose any text it finds in any element that allows
mixed content for HTML transitional but not HTML strict. The
default is no.If set to yes, this causes Tidy to replace
unexpected hyphens with "=" characters when it comes across
adjacent hyphens. The default is yes. This option is
provided for users of Cold Fusion which uses the comment syntax:
<!--- --->If set to yes, this causes Tidy to add
xml:space="preserve" to elements such as pre, style and script
when generating XML. This is needed if the whitespace in such
elements is to be parsed appropriately without having access to
the DTD. The default is no.This allows you to set the default alt text for img
attributes. This feature is dangerous as it suppresses further
accessibility warnings. YOU ARE RESPONSIBLE FOR MAKING YOUR
DOCUMENTS ACCESSIBLE TO PEOPLE WHO CAN@T SEE THE
IMAGES!!!If set to yes, Tidy will write back the tidied
markup to the same file it read from. The default is no.
You are advised to keep copies of important files before tidying
them as on rare occasions the result may not always be what you
expect.If set to yes, Tidy won@t alter the last modified
time for files it writes back to. The default is yes.
This allows you to tidy files without effecting which ones will
be uploaded to the Web server when using a tool such as
@SiteCopy@. Note that this feature may not work on some
platforms.Writes errors and warnings to the named file rather than to
stderr.If set to no, warnings are suppressed. This can be
useful when a few errors are hidden in a flurry of warnings. The
default is yes.If set to yes, Tidy won@t output the welcome message
or the summary of the numbers of errors and warnings. The default
is no.If set to yes, Tidy changes the format for reporting
errors and warnings to a format that is more easily parsed by GNU
Emacs. The default is no.If set to yes Tidy will use the input file to create
a sequence of slides, splitting the markup prior to each
successive <h2>. You can see an example of the results in a

recent talk on XHTML. The slides are written to
"slide1.html", "slide2.html" etc. The default is
no.Use this to declare new empty inline tags. The option takes a
space or comma separated list of tag names. Unless you declare
new tags, Tidy will refuse to generate a tidied file if the input
includes previously unknown tags. Remember to also declare empty
tags as either inline or blocklevel, see below.Use this to declare new non-empty inline tags. The option
takes a space or comma separated list of tag names. Unless you
declare new tags, Tidy will refuse to generate a tidied file if
the input includes previously unknown tags.Use this to declare new block-level tags. The option takes a
space or comma separated list of tag names. Unless you declare
new tags, Tidy will refuse to generate a tidied file if the input
includes previously unknown tags. Note you can@t change the
content model for elements such as table, ul, ol and dl. This is
explained in more detail in the original release notes.Use this to declare new tags that are to be processed in
exactly the same way as HTML@s pre element. The option takes a
space or comma separated list of tag names. Unless you declare
new tags, Tidy will refuse to generate a tidied file if the input
includes previously unknown tags. Note you can@t as yet add new
CDATA elements (similar to script).'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_tidy_list_errors',
'tidy_list_errors',
'xml',
'Invoke built-in version of HTML Tidy utility to get list of errors in given input HTML text',
'This function lists errors in given source HTML text, by invoking some
    custom version of HTML Tidy utility. To learn more about Tidy see
    
    http://www.w3.org/People/Raggett/tidy/.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'tidy_list_errors',
'fn_tidy_list_errors',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'raw_html',
'tidy_list_errors',
  'varchar','in',
'Source HTML text to validate. Note that the encoding of this text
      must be specified in tidy_config string,
      and default encoding of session will not be mentoined by Tidy.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tidy_config',
'tidy_list_errors',
  'varchar','in',
'Configuration string, space-delimited list of options, exactly as
      in original Tidy@s command-line or in Tidy@s configuration file.
      Not all options of original Tidy will work, due to obvious reasons,
      unsupported options will be silently ignored, so you may read your
      favorite Tidy@s configuration file by file_to_string function and
      pass it to tidy_list_errors. For more datails, see
      tidy_html.
      '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_timezone',
'timezone',
'date',
'get timezone difference from a datetime',
'timezone takes a datetime and returns 
    an integer containing localtime - GMT in minutes.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'timezone',
'fn_timezone',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'timezone',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_trace_on',
'trace_off',
'misc',
'disable extra logging for Virtuoso server',
'
  This function is used to disable logging of various information enabled with the trace_on() function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'trace_off',
'fn_trace_on',
'void',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'parameter',
'trace_off',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_trace_on',
'trace_on',
'misc',
'Enable extra logging on the Virtuoso server',
'
  This function allow to start logging the actoins performed against Virtuoso server.
  The log entries will be shown at the server console (if started with foreground option) and will be written into the server log file. 
  The domains are divided on several groups: user activity, transactions, compilation of the SQL statements, DDL statements, statements execution and VDB actions.
  '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'trace_on',
'fn_trace_on',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'parameter',
'trace_on',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_trace_on',
'trace_status',
'misc',
'show current trace settings',
'
 This function returns an array of all available trace options and current status of the traces.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'trace_status',
'fn_trace_on',
'void',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_tree_md5',
'tree_md5',
'misc',
'returns MD5 checksum of array argument',
'Returns a string of 16 characters representing the binary MD5 checksum of the argument.  The argument can be any array or scalar.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'tree_md5',
'fn_tree_md5',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tree',
'tree_md5',
  'any/variable','in',
'String or string_session to be processed with MD5 algorithm.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_acos',
'trigonometric',
'number',
'trigonometric functions',
'
All these functions work with double precision floating point numbers.
They convert their argument to an IEEE 64-bit float and return a result of that
type.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'acos',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'acos',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'asin',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'asin',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'atan',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'atan',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'atan2',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'atan2',
  'double precision','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'y',
'atan2',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cos',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'cos',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'cot',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'cot',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'degrees',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'degrees',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'pi',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'radians',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'radians',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sin',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'sin',
  'double precision','in',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'tan',
'fn_acos',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'x',
'tan',
  'double precision','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_trim',
'trim',
'string',
'removes characters from both ends of string argument',
'trim returns a copy of subsequence of string str
    with all the characters present in trimchars trimmed off from the beginning.
    If the second argument is omitted, it is a space @ @ by default.rtrim is similar except that it trims from
    the right.trim trims from both ends.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'trim',
'fn_trim',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'trim',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'trimchars',
'trim',
  'varchar','',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_txn_error',
'txn_error',
'txn',
'poison current transaction forcing rollback',
'
Calling this function will poison the current transaction.  This means that
it is forced to roll back at when committed.  The code can be
in integer that selects the error message generated when trying to commit.
This is useful before signalling application errors from SQL code that runs
in manual commit mode.  This can ensure that even if the client attempts
a commit after getting the error signalled by the application the transaction
will not commit.

The code should be the constant 6, resulting the in the @transaction
rolled back due to previous SQL Error@.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'txn_error',
'fn_txn_error',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'code',
'txn_error',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_txn_killall',
'txn_killall',
'txn',
'kill all pending transactions',
'
This function will terminate all pending transactions.  This can be used
for resetting infinite loops in stored procedures etc.
	
The code determines the error reported to the client. Number 6 is preferable,
corresponding to the @transaction rolled back due to previous SQL error@.
	
Once any SQL statement or procedure notices that its transaction is dead,
e.g. deadlocked, it signals the error and takes appropriate action, which is typically
to signal the error to the caller and ultimately to the client.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'txn_killall',
'fn_txn_killall',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'code',
'txn_killall',
  'integer','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_ucase',
'ucase',
'string',
'returns upper case version of string argument',
'ucase returns a copy of string str with all
    the lowercase alphabetical
    characters converted to corresponding uppercase letters. This includes
    also the diacritic letters present in the ISO 8859/1 standard in range
    224 - 254 decimal, excluding the character 255, y diaeresis, which is not
    converted to a German double-s.upper is just an alias for ucase.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ucase',
'fn_ucase',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'ucase',
  'varchar','',
'String to convert to upper case.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_delete_binding',
'uddi_delete_binding',
'uddi',
'Causes one or more bindingTemplate
structures to be deleted.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_delete_business',
'uddi_delete_business',
'uddi',
'Remove one or more businessEntity structures.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_delete_service',
'uddi_delete_service',
'uddi',
'Remove one or more businessService structures.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_delete_tModel',
'uddi_delete_tModel',
'uddi',
'Remove or retire one or more tModel structures.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_discard_authToken',
'uddi_discard_authToken',
'uddi',
'Inform a UDDI server that the authentication token can be discarded.',
'
The uddi_discard_authToken message is used to tell a UDDI-enabled server
that the authentication token  can be discarded.  Subsequent calls that
use the same authToken may be rejected.  This message is optional for
UDDI-enabled servers  that do not manage session state or that do not
support the get_authToken message.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_find_binding',
'uddi_find_binding',
'uddi',
'Retrieves matching bindings',
'
The uddi_find_binding message returns a bindingDetail message that contains a
bindingTemplates structure with zero or more bindingTemplate structures
matching the criteria specified in the argument list.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_find_business',
'uddi_find_business',
'uddi',
'Retrieves a businessList message matching supplied criteria.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_find_service',
'uddi_find_service',
'uddi',
'Retrieves serviceList message matching search criteria',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_find_tModel',
'uddi_find_tModel',
'uddi',
'locate list of tModel entries matching supplied criteria',
'
This uddi_find_tModel message is for locating a list of tModel entries that match a
set of specific criteria.  The response will be a list of abbreviated
information about tModels that match the criteria  (tModelList).
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_authToken',
'uddi_get_authToken',
'uddi',
'Obtain authentication token.',
'
The uddi_get_authToken message is used to obtain an
authentication token.  Authentication tokens are opaque values that are
required for all other publisher API calls.  This message is not required
for UDDI-enabled servers that have an external mechanism defined for users
to get an authentication token.  This API is provided for implementations
that do not have some other method of obtaining an authentication token or
certificate, or that choose to use password-based authentication.
'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_bindingDetail',
'uddi_get_bindingDetail',
'uddi',
'Request run-time bindingTemplate location information.',
'
The uddi_get_bindingDetail message requests the
run-time bindingTemplate information for the
purpose of invoking a registered business API.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_businessDetail',
'uddi_get_businessDetail',
'uddi',
'returns complete businessEntity information for one or more specified businessEntities',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_businessDetailExt',
'uddi_get_businessDetailExt',
'uddi',
'Returns extended businessEntity information for one or more specified businessEntities.',
'
The uddi_get_businessDetailExt message returns extended businessEntity information for
one or more specified businessEntities.  This message returns exactly the same
information as the get_businessDetail message, but may contain additional
attributes if the source is an external  registry that is compatible with
this API specification, rather than a UDDI-enabled server.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_registeredInfo',
'uddi_get_registeredInfo',
'uddi',
'Retrieve an abbreviated list of all businessEntity keys.',
'
The uddi_get_registeredInfo message is used to get an abbreviated list of
all businessEntity keys and tModel keys controlled by the
entity associated with the credentials passed.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_serviceDetail',
'uddi_get_serviceDetail',
'uddi',
'request full information about a known businessService structure',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_tidy_get_timestamp',
'uddi_tidy_get_timestamp',
'uddi',
'Mitko',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_get_tModelDetail',
'uddi_get_tModelDetail',
'uddi',
'Request full information about a known tModel structure.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_save_binding',
'uddi_save_binding',
'uddi',
'save or update a complete bindingTemplate structure',
'
The uddi_save_binding message is used to save or update a complete bindingTemplate structure.
This message can be used to add or update one or more bindingTemplate structures
to one or more existing businessService structures.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_save_business',
'uddi_save_business',
'uddi',
'Save or update information about a complete businessEntity structure.',
'
The uddi_save_business message is used to save or update information about a
complete businessEntity structure.  This message has the broadest scope of
all of the save calls in the publisher@s API, and can be used to make
sweeping changes to the published information for one or more businessEntity
structures controlled by an identity.
  '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_save_service',
'uddi_save_service',
'uddi',
'Adds or updates one or more businessService structures.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'me_uddi_save_tModel',
'uddi_save_tModel',
'uddi',
'Adds or updates one or more tModel structures.',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_upper',
'upper',
'string',
'returns upper case version of string argument',
'ucase returns a copy of string str with
      all the lowercase alphabetical
      characters converted to corresponding uppercase letters. This includes
      also the diacritic letters present in the ISO 8859/1 standard in range
      224 - 254 decimal, excluding the character 255, y diaeresis, which is not
      converted to a German double-s.upper is just an alias for ucase.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'upper',
'fn_upper',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'str',
'upper',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_username',
'username',
'sql',
'returns the login name of the current user',
'Returns the login name of the user of the connection. 
    Selecting >user is equivalent.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'username',
'fn_username',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_user_set_password',
'user_set_password',
'admin',
'Allows dba to change a user@s password.',
'Explicitly sets a new password for the SQL account
    user_name to new_password.
    Only users in the dba group may execute this function. It allows the
    database administrator to reset lost passwords of SQL accounts.
    The new password will be set without further comfirmation, so
    the DBA must be sure of the new password.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'user_set_password',
'fn_user_set_password',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'user_name',
'user_set_password',
  'varchar','in',
'SQL user account name to change.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'new_password',
'user_set_password',
  'varchar','in',
'New password for the user as plain text.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_uudecode',
'uudecode',
'mail',
'Decodes a string previously encoded by uuencode',
'
Uudecode transforms uuencoded data into original form.
Uuencode may return a number of sections as a vector of them,
each of these sections should be decoded by separate call. and results
should be concatenated in order to compose original text.
The mode of decoding should match to the mode used for encoding, of course.
    
RFC 2045,
(N. Borenstein, N. Freed.
MIME (Multipurpose Internet Mail Extensions) Part One:
The Format of Internet Message Bodies),
contains detailed description of most important encodings used by mail
systems.
Older RFC 1521 is now obsoleted.
    
Currently, eight conventions are used for mail attachments.
In Virtuoso, they are enumerated by integer IDs.
    
If there@s no information about the encoding used in the message,
zero may be passed to the uudecode() function instead of proper ID.
uudecode() will try to guess the proper algorithm.
In any case, decoder feels no difference between modes 2 and 3
(two slightly different "Base64" encodings) and between modes
11 and 12 (two "Quoted-Printable" methods which are different
only encoding side).
Application may try all methods in turn if automatic guess will fail.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'uudecode',
'fn_uudecode',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'input',
'uudecode',
  'varchar','in',
'String or string-output session with data to be encoded.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'uudecode',
  'integer','in',
'Integer ID of encoding to be used.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_uuencode',
'uuencode',
'mail',
'Encodes string or string session into sequence of printable characters, suitable for transfer via "ASCII-only" data channels',
'
There are many protocols, like classic UNIX uuencode,
which are used to transmit binary files
over transmission mediums that do not support other than
simple ASCII data. The epoch of physical lines of such sort is
in past but file attachments in most popular mail systems still
follow old regulations.
    
Encoded data are transmitted as a sequence of one or more "sections".
They may be stored or sent as independent documents.
Every section contains some range of original document@s data.
They may be decoded one after another, and original
document may be composed by concatenation of decoded fragments.
If the document is small (or if there@s no limit on the size of message),
it may be sent as single section.
    
Every section has some header and footer and a set of
lines with data between them. Headers and especially footers are
usually optional and may vary from system to system whereas
data lines are described by standards. Data lines of any two
consequent sections may be concatenated together, if needed, to
create longer section.
    
uuencode creates a vector of strings, where
every string contains some number of data lines, without headers or
footers. A PL/SQL stored procedure may be used to create some output
stream(s) and put there sections of appropriate format with
data lines from vector.
Every item of the created vector will contain up to
maxlines lines of data,
usually 60 to 80 bytes per line; maxlines
may vary from 10 to 120000 so section may be 0.8Kb to 10Mb long
depending on your choice.
Last section may be shorter than other, if only partially filled.
10Mb limit may be bypassed by sending of sections one after another
without intermediate footers or headers, but please keep in
mind that you cannot concatenate two strings in memory if
the sum of their lengths exceeds system-wide 10Mb.
    
RFC 2045,
(N. Borenstein, N. Freed.
MIME (Multipurpose Internet Mail Extensions) Part One:
The Format of Internet Message Bodies),
contains detailed description of most important encodings used by mail
systems.
Older RFC 1521 is now obsoleted.
    
Currently, eight conventions are used for mail attachments.
In Virtuoso, they are enumerated by integer IDs.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'uuencode',
'fn_uuencode',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'input',
'uuencode',
  'varchar','in',
'String or string-output session with data to be encoded.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'uuencode',
  'integer','in',
'Integer ID of encoding to be used.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'maxlines',
'uuencode',
  'integer','in',
'Number of data lines per section. Should be in range 10 to 120000,
otherwise nearest suitable value will be used without reporting any error.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_uuvalidate',
'uuvalidate',
'mail',
'Encodes string or string session into sequence of printable characters, suitable for transfer via "ASCII-only" data channels',
'
This function tries to ensure what applied data have a pointed encoding mode.
If mode parameter is 0 (ie unknown) or if the validation fails,
it will try to determine which mode was used in fact.
    
RFC 1521,
(N. Borenstein, N. Freed.
MIME (Multipurpose Internet Mail Extensions) Part One:
Mechanisms for Specifying and Describing
the Format of Internet Message Bodies),
contains detailed description of most important encodings used by mail
systems.
RFC 2045,
(N. Borenstein, N. Freed.
MIME (Multipurpose Internet Mail Extensions) Part One:
The Format of Internet Message Bodies).
    
Currently, seven conventions are used for mail attachments.
In Virtuoso, they are enumerated by integer IDs.
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'uuvalidate',
'fn_uuvalidate',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'input',
'uuvalidate',
  'varchar','in',
'String or string-output session with data to be encoded.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mode',
'uuvalidate',
  'integer','in',
'Integer ID of encoding to be used.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_check',
'VAD_CHECK',
'VAD',
'Checks the package has not been altered since installation',
'This checks to see if the elements of the package are as they are 
  defined in the original distribution.  A list of differing elements is returned.  
  This does not always indicate a corruption since a later version or another 
  package may add columns to tables, and some resources may be customized 
  after installation.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'CHECK',
'fn_vad_check',
'array DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_name',
'CHECK',
  'varchar','in',
'name of package @/@ version e.g: @virtodp/1.0@'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_check_installability',
'VAD_CHECK_INSTALLABILITY',
'VAD',
'Checks the presence and correct versions of required packages and of the Virtuoso platform',
'Checks the presence and correct versions of required packages and 
  of the Virtuoso platform. It does not execute any pre-install PL/SQL code 
  from the package, so there is no guarantee that installation will be 
  successful if the check found no error.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VAD_CHECK_INSTALLABILITY',
'fn_vad_check_installability',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_uri',
'VAD_CHECK_INSTALLABILITY',
  'varchar','in',
'URI of VAD file'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_check_uninstallability',
'VAD_CHECK_UNINSTALLABILITY',
'VAD',
'Checks if the package can be uninstalled.',
'Checks if the package can be uninstalled. It does not executes any 
  pre-uninstall PL/SQL code from the package, so there is no guarantee that 
  uninstallation will be successful if the check found no error.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'CHECK_UNINSTALLABILITY',
'fn_vad_check_uninstallability',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_name',
'CHECK_UNINSTALLABILITY',
  'varchar','in',
'name of package @/@ version e.g: @virtodp/1.0@'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_fail_check',
'VAD_FAIL_CHECK',
'VAD',
'Signals package check failure',
'makes "rollback work", exits from atomic mode and fails server with raw_exit(-1)'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'FAIL_CHECK',
'fn_vad_fail_check',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'msg',
'FAIL_CHECK',
  'varchar','in',
'text of message'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_install',
'VAD_INSTALL',
'VAD',
'Invoke VAD installation process',
'Invoke the install operation from interactive SQL or from the web user 
  interface.  This will:If there was a failure in mid-install, such as running out of disk or 
  some other serious unrecoverable database error, the server exits.  The 
  installation can be undone manually by halting the server, deleting the 
  transaction log file and restarting. The server will start from the checkpoint 
  as if the installation was never attempted.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VAD_INSTALL',
'fn_vad_install',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_uri',
'VAD_INSTALL',
  'varchar','in',
'URI of VAD file'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_load_file',
'VAD_LOAD_FILE',
'VAD',
'executes statements of a SQL file',
'This splits a plain sql file into single statements and executes 
  them one by one.  The root directory for this procedure is the @code@ 
  root of VAD@s repository.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'load_file',
'fn_vad_load_file',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'fname',
'load_file',
  'varchar','in',
'path to file to exec'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_pack',
'VAD_PACK',
'VAD',
'get VAD resource',
'This function gets the resource identified by the sticker_uri, which contains 
  the vad:package root element.  The URIs present there are interpreted in the context 
  of the base_uri_of_resources and the individual resources are fetched.  These are 
  parsed to make sure that they are syntactically correct and the resources are 
  appended to the generated package resource, which is stored into the result_uri.  
  vad_pack() returns a human-readable log of error and warning messages, vad_pack() 
  will signal errors if some resources or database objects will be unavailable.  
  By convention, VAD package files have the extension @.vad@. '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VAD_PACK',
'fn_vad_pack',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sticker_uri',
'VAD_PACK',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base_uri_of_resources',
'VAD_PACK',
  'varchar','in',
'inlined resources root'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_uri',
'VAD_PACK',
  'varchar','in',
'path of output VAD file'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_safe_exec',
'VAD_SAFE_EXEC',
'VAD',
'execute without requiring success',
'safe way to do something without generating an exception, e.g.: when it is 
  necessary to drop a table without insurance of it@s existance.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'safe_exec',
'fn_vad_safe_exec',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'expr',
'safe_exec',
  'varchar','in',
'text of expression'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vad_uninstall',
'VAD_UNINSTALL',
'VAD',
'Vad package uninstallation',
'Invokes the uninstall operation from interactive SQL or from the 
  web user interface. This will:'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'UNINSTALL',
'fn_vad_uninstall',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'package_name',
'UNINSTALL',
  'varchar','in',
'name of package @/@ version e.g: @virtodp/1.0@'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vd_remote_data_source',
'vd_remote_data_source',
'rmt',
'prepares a remote DSN  for use',
'
A remote data source is uniquely identified by its DSN, the dsn argument
to this function. The connstr argument is presently ignored. The user and
password are the login name and password to use when communicating with
the remote data source. All Virtuoso users dealing with the remote data
source will appear as this user to the remote data source. Virtuoso will
make as many connections as there are concurrent users of the data source.
Connections are cached by Virtuoso.

The default qualifier of the user of the remote data source is usually
not relevant.  This function connects to the DSN in order to retrieve various meta data, which it stores locally.  The DSN should be defined in the server@s environment and the DSN@s database should be on line.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vd_remote_data_source',
'fn_vd_remote_data_source',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'vd_remote_data_source',
  'varchar','in',
'The name of the remote datasource to prepare.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'connstr',
'vd_remote_data_source',
  'varchar','in',
'Currently ignored parameter.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'user',
'vd_remote_data_source',
  'varchar','in',
'username for the connection.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'password',
'vd_remote_data_source',
  'varchar','in',
'password for the user.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vd_remote_table',
'vd_remote_table',
'rmt',
'declares an existing table as resident on a DSN previously declared with vd_remote_data_source',
'
Declares an existing table as resident on a data source previously
declared with vd_remote_data_source().

This function declares the table local_name as table remote_name on
the dsn. The tables names should be full, names with qualifier and
owner. The names are case sensitive and must be in the exact case where
they appear in the local and remote schemas.

If remote_name is NULL, the effect of a possible previous vd_remote_table
is reversed. The table is thereafter treated as a local table, except
in procedures and statements compiled when the remote declaration was
in effect.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vd_remote_table',
'fn_vd_remote_table',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'vd_remote_table',
  'varchar','in',
'The name of the remote datasource previously connected using vd_remote_data_source()'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'local_name',
'vd_remote_table',
  'varchar','in',
'Fully qualified name of a local table.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'remote_name',
'vd_remote_table',
  'varchar','in',
'Fully qualified name of the remote table.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vdd_disconnect_data_source',
'vdd_disconnect_data_source',
'rmt',
'Disconnects a data source if no active transactions are using resources from it.',
'
This function disconnects all the idle opened connections to a VDB datasource.
If there are active transactions server-side, using connections to that datasource,
they are not closed.  After they finish, this function can be called again to disconnect
the new idle connections.

The datasource continues to be valid and any subsequent transactions using this datasource
will open a new connection to it.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vdd_disconnect_data_source',
'fn_vdd_disconnect_data_source',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dsn',
'vdd_disconnect_data_source',
  'varchar','in',
'The name of the remote datasource to disconnect.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vector',
'vector',
'array',
'make a vector',
'vector returns a new vector (one-dimensional array) constructed from the given arguments.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vector',
'fn_vector',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elem1',
'vector',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elem2',
'vector',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'vector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'elem-n',
'vector',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vector_concat',
'vector_concat',
'array',
'concatenate vectors',
'vector_concat takes a variable number of 
      vectors (heterogeneous arrays) and constructs a new vector containing 
      copies of each (top level) element in the arguments.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vector',
'fn_vector_concat',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vec1',
'vector',
  'vector','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vec2',
'vector',
  'vector','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'vector',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vec-n',
'vector',
  'vector','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vhost_define',
'VHOST_DEFINE',
'ws',
'define a virtual host or virtual directory',
'VHOST_DEFINE is used to define virtual hosts and virtual paths on the Virtuoso HTTP server. Effectively this procedure inserts a row in table DB.DBA.HTTP_PATH Virtuoso supports both flavours of virtual hosting: IP-based and name-based.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VHOST_DEFINE',
'fn_vhost_define',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vhost',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the virtual host name that the
browser presents as Host: entry in the request headers. i.e. Name-based virtual hosting.
The default value is taken from the Virtuoso INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'lhost',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the  address of the network
interface the Virtuoso HTTP server uses to listen and accept connections.
The default value is taken from the Virtuoso INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'lpath',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the path component of the
URI for the logical path.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ppath',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the physical path that the logical
path points to. i.e. a directory or a path to dav collection on server.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_dav',
'VHOST_DEFINE',
  'boolean','in',
'An integer. If non-zero, it indicates that
the physical_path points to a collection in DAV
repository.  Default value is 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_brws',
'VHOST_DEFINE',
  'boolean','in',
'An integer. If non-zero, it indicates that the server will
generate a directory listing in case a default page is absent.  Default value is 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'def_page',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the file name of
the default page.  Default value is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_fn',
'VHOST_DEFINE',
  'varchar','in',
'A string that contains the fully qualified Virtuoso/PL
procedure name of authentication hook function that will check and perform
authentication for this virtual host or directory. If NULL, Virtuoso will not
attempt authentication.  The default value is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'realm',
'VHOST_DEFINE',
  'varchar','in',
'A string with the realm to be passed to the
authentication function auth_func.  The
default value is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ppr_fn',
'VHOST_DEFINE',
  'varchar','in',
'A string containing the fully qualified name of the
Virtuoso/PL stored procedure used for post-processing of the page.
The default values is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vsp_user',
'VHOST_DEFINE',
  'varchar','in',
'A string containing a valid DB user name.  The VSP pages
contained in the virtual directory shall be run with the grants effective for
this user at time of execution.  The default values is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'soap_user',
'VHOST_DEFINE',
  'varchar','in',
'A string containing a valid SOAP user for SOAP calls.
The default values is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sec',
'VHOST_DEFINE',
  'varchar','in',
'Security restrictions (SSL, Digest).  The default values is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ses_vars',
'VHOST_DEFINE',
  'boolean','in',
'An integer. If non-zero, indicates that session
variables are persistent.  The default values is 0.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'soap_opts',
'VHOST_DEFINE',
  'any/variable','in',
'Options for SOAP service.
The default values is NULL.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'auth_opts',
'VHOST_DEFINE',
  'any/variable','in',
'Options for the authentication hook and HTTPS listen hosts.  The default values is NULL.
      If the sec_method (security method) defined as @SSL@ the following auth_options must be supplied:
      https_cert - HTTPS server certificate file path, https_key - HTTPS server private key file path.
      In addition to check X509 certificate of clients, the https_cv option with path to the file containing trusted certificate authorities must be supplied and https_cv_depth - integer to set depth of client certificate checking.
      '

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vhost_remove',
'VHOST_REMOVE',
'ws',
'remove a virtual host or virtual directory',
'vhost_remove is used to remove virtual hosts and virtual paths on the Virtuoso HTTP server.  Effectively this procedure deletes a row in the table DB.DBA.HTTP_PATH.
Virtuoso supports both flavours of virtual hosting: IP-based and name-based.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VHOST_REMOVE',
'fn_vhost_remove',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vhost',
'VHOST_REMOVE',
  'varchar','in',
'A string containing the virtual host name that the
browser presents as Host: entry in the request headers. i.e. Name-based
virtual hosting.  Default value as defined in the Virtuoso INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'lhost',
'VHOST_REMOVE',
  'varchar','in',
'A string containing the  address of the network
interface the Virtuoso HTTP server uses to listen and accept connections.
Default value as defined in the Virtuoso INI file.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'lpath',
'VHOST_REMOVE',
  'varchar','in',
'A string containing the path component of the
URI for the logical path.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'del_vsps',
'VHOST_REMOVE',
  'integer','in',
'if a positive number will indicate to the server to drop all
compilations of VSP files in this domain.  Default value is 0.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_virtuoso_ini_path',
'virtuoso_ini_path',
'admin',
'Return full name of configuration INI file',
'This function returns the complete path to the configuration
    INI file. It is typically used by the cfg_ functions that
    modify or read the contents of the INI file.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'virtuoso_ini_path',
'fn_virtuoso_ini_path',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_batch',
'vt_batch',
'ft',
'Returns a vt batch object.',
'
This object can be used to update a free text index by feeding document
information into it using vt_batch_d_id to set the free text document ID and
vt_batch_feed to feed actual words.

This object may not be assigned to other variables and may only be passed as
an inout parameter.

The batch is applied to the index by calling the
VT_BATCH_PROCESS_<table>_<column> function generated
by CREATE TEXT INDEX.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_batch',
'fn_vt_batch',
'batch object',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_batch_d_id',
'vt_batch_d_id',
'ft',
'Specify a document to update in a vt batch.',
'
Multiple documents may be indexed or unindexed with a single batch. In this
case this function will be called for each document id, in ascending order
of ID.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_batch_d_id',
'fn_vt_batch_d_id',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'd_id',
'vt_batch_d_id',
  'any/variable','in',
'the free text document ID of the row  whose index entry is to be
updated.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_batch_feed',
'vt_batch_feed',
'ft',
'Add words to a free text update batch.',
'This function allows you to add words to a free text update batch.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_batch_feed',
'fn_vt_batch_feed',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'vt_batch',
'vt_batch_feed',
  'any/variable','in',
'must be an object returned by vt_batch on which
vt_batch_d_id has been called.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'text',
'vt_batch_feed',
  'any/variable','in',
'must be a blob, wide blob, varchar, nvarchar or  XML entity object'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_del',
'vt_batch_feed',
  'integer','in',
'if 0 means that the data is to be added, 1 means the data is to
be deleted.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_xml',
'vt_batch_feed',
  'integer','in',
'if 1, means that the text must be a well formed XML fragment and
that it will be indexed accordingly for use with XCONTAINS.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_batch_update',
'vt_batch_update',
'ft',
'Perform batch mode update of free text indexing.',
'
This causes the generated triggers to log the changes into an
automatically created table named VTLOG_<q>_<o>_<table>, in the qualifier and
owner of the indexed table, where q, o and table are the qualifier, owner
and name of the table.
The changes accumulated into that table can be explicitly applied to the
index using the VT_INC_INDEX_<q>_<o>_<table> function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'VT_BATCH_UPDATE',
'fn_vt_batch_update',
'integer DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table',
'VT_BATCH_UPDATE',
  'varchar','in',
'the name of the table to perform batch updating of.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'interval_minutes',
'VT_BATCH_UPDATE',
  'integer','in',
'the update interval'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_create_text_index',
'vt_create_text_index',
'ft',
'Add text index to an existing table',
'
The vt_create_text_index procedure adds a text index to an existing table.
There can at most be one text index per table, including super tables and
subtables.
  
The table argument is a string naming the table. The column is the name of the column
to index. The id_col should be the name of a unique integer row identifier column.  If null,
the system will either add such a column or use an existing integer primary key if one
is available.  The is_xml argument, if non-0, specifies that the values of the indexed column
should be checked for XML well formedness and that the XML structure should be taken into account in indexing the
values.
  
Use the CREATE TEXT INDEX statement as an alternative to the vt_create_text_index function.
  
In order for a table to be referenced in a text index it must have
a uniquely identifying integer key.  If the table in question has such a 
key this can be used as the id column.  If there is no such column this 
procedure makes one.  Using a previously existing identifier column saves 
space and if that is the primary key of the table this also saves in 
retrieval time.
	
If the table being indexed has a single part integer primary key 
vt_create_text_index will automatically use this as the identifier.  Note 
that the zero and negative numbers may not be used as identifier values.
	
Creating the index will read through the table@s contents and generate 
the index.  When the table is changed the index can either be updated after 
each change or periodically, depending on the application needs.  The rationale 
for background maintenance of the text index is that it is up to several times
more efficient to maintain a text index in batches of several changed documents 
than after each single document change.  The default maintenance mode is 
synchronous, meaning that each insert, delete or update of the indexed column 
will be immediately reflected in the index.  This mode can be set using 
the vt_batch_update() procedure.
The mode should be set to batch if there are 
any massive operations on the table.
	
It will create two additional tables:
	
 and
	
 and two procedures:
	
 and
	
The table <datatable>_<datafield>_WORDS contains the full text index data.

The table VTLOG_<datatable>_<datafield> is an update tracking table, similar to the snapshot log table but using the key column instead of the primary key.
in the transaction semantics section that there is the sync mode for the purpose of creating a text index.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_create_text_index',
'fn_vt_create_text_index',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'table',
'vt_create_text_index',
  'varchar','in',
'the table containing the data to index.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'col',
'vt_create_text_index',
  'varchar','in',
'the column in the data table containing the data to index (a long varchar column).'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'id_col',
'vt_create_text_index',
  'varchar','in',
'an integer unique indexed column used by the free text index as a key.  If Virtuoso tries  
to choose such a column among the existing in the table and if it doesn@t find a suitable column it 
adds such a column with the name <datacolumn>_ID, fills that up and makes an unique index on it.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'is_xml',
'vt_create_text_index',
  'integer','in',
'if greater than 0 installs two additional triggers before insert and before update on the data table 
to ensure the data being inserted into it are valid XML documents.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'defer_generation',
'vt_create_text_index',
  'integer','in',
'if nonzero then the free-text index will not be filled by actual data
immediately after the creation. It will remain empty until explicit request for
"incremental indexing".'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'clustered_columns',
'vt_create_text_index',
  'any/variable','in',
'a vector of names of "clustered columns" or NULL to not store such data in the index.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'use_hook_function',
'vt_create_text_index',
  'integer','in',
'if nonzero, two user-defined Virtuoso/PL functions will be
called when free-text data are updated, not the default system routine.
These functions are recognized by their special names:
<datatable>_<datafield>_INDEX_HOOK will be called to index
new documents and
<datatable>_<datafield>_UNINDEX_HOOK will be called to
remove obsolete index information about deleted documents.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'language_name',
'vt_create_text_index',
  'varchar','in',
'the name of the language that is used for building the index.
If the parameter is omitted or is equal to @*ini*@ string, indexing routines
will use the language specified in server@s configuration.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'encoding_name',
'vt_create_text_index',
  'integer','in',
'the name of the encoding that is used by default to
index source texts.
If the parameter is omitted or is equal to @*ini*@ string, indexing routines
will use the encondig specified by charset of the RDBMS connection that is
in use when the index is created.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_drop_ftt',
'vt_drop_ftt',
'ft',
'drop free text trigger',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_drop_ftt',
'fn_vt_drop_ftt',
'DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'target_table_name',
'vt_drop_ftt',
  'varchar','in',
'the table containing the trigger'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'opt_data_column or NULL',
'vt_drop_ftt',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_vt_is_noise',
'vt_is_noise',
'ft',
'determines whether input is a noise word',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'vt_is_noise',
'fn_vt_is_noise',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'word',
'vt_is_noise',
  'varchar','in',
'Narrow string of the word to be checked'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'encoding',
'vt_is_noise',
  'varchar','in',
'valid encoding string'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'language',
'vt_is_noise',
  'varchar','in',
'valid language string'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_week',
'week',
'date',
'get number of week from a datetime',
'week takes a datetime and returns 
    an integer containing a number representing the week of year of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'week',
'fn_week',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'week',
  'datetime','in',
'A datetime.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_auto',
'xml_auto',
'xml',
'prepares and executes given SQL for XML string output',
'
This function prepares and executes the given SQL string, which should be a query expression with
the FOR XML clause at the end of the last term.  The query
is passed the parameters from the params vector, which should have one element for
each ? in the query text, values assigned from left to right.  Consider the
query: select a, b from table where a = ? and b = ?; then the params vector
could reasonably be: vector(1, @myfilter@).

The result set is converted to XML and appended to the string_output.
If the string_output is omitted and the function executes in the context
of a VSP page, the output is sent to the stream going to the user agent.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_auto',
'fn_xml_auto',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sql_text ',
'xml_auto',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'params ',
'xml_auto',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'string_output ',
'xml_auto',
  'varchar','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_auto_dtd',
'xml_auto_dtd',
'xml',
'returns an XML DTD for the result of a SQL query with a FOR XML clause',
'
This function returns an XML DTD for the results of a SQL query with
a FOR XML clause.  The returned DTD will apply to the output generated
by xml_auto with the query in question after wrapping it into the specified root element.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_auto_dtd',
'fn_xml_auto_dtd',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'query',
'xml_auto_dtd',
  'varchar','in',
'valid SQL query'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root_element',
'xml_auto_dtd',
  'varchar','in',
'name of root element to wrap result into'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_auto_schema',
'xml_auto_schema',
'xml',
'returns an XML schema for the result of an SQL query with a FOR XML clause',
'
This function returns an XML schema for the results of an SQL query
with a FOR XML clause.  The returned schema will apply to the output
generated by xml_auto() with the query in
question after wrapping it in the specified root element.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_auto_schema',
'fn_xml_auto_schema',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'query',
'xml_auto_schema',
  'varchar','in',
'SQL query'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root_element',
'xml_auto_schema',
  'varchar','in',
'name of root element container'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_cut',
'xml_cut',
'xml',
'creates a new XML document which contains a copy of data pointed by given XML tree- or XPER- entity',
'
In some special cases, some part of XML document,
being pointed by a XML entity, should be copied into a new separate document
with new entity pointing to the root of this document.
One reason for doing this is optimization of XPER processing (see xper_cut).
Another way to use this functionality is passing of some XML entity
to a function, when function uses XPath operations with references to
the "document@s root".
		
The origin of the bug is @//C@ path in get_C(), which returns not
the "C element inside given b element", but
"C element inside the document where given b element is located",
thus get_C returns the first C element in the whole document with any of
two B elements given.
      
There are two ways to fix this bug.
It is better to correct get_C():
      
If you cannot patch get_C() for some reason, xml_cut will help,
but it will waste both memory and CPU time for copying a branch of
XML tree:
      
With XPER entity given, xml_cut() works exactly as xper_cut().
      '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_cut',
'fn_xml_cut',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'source_entity',
'xml_cut',
  'any/variable','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_load_schema_decl',
'xml_load_schema_decl',
'xml',
' returns a string with list of errors detected by XML 
		Schema processor on reading given XML Schema definition 
		document. ',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_load_schema_decl',
'fn_xml_load_schema_decl',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base_uri',
'xml_load_schema_decl',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from given base_uri (http://<host>:<port>/<path>)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document_uri',
'xml_load_schema_decl',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_encoding',
'xml_load_schema_decl',
  'varchar','in',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for HTML mode'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_language',
'xml_load_schema_decl',
  'varchar','in',
'string with language tag of content of <document>; valid names are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages)'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_add_system_path',
'xml_add_system_path',
'xml',
'Adds path to the internal list of system paths.',
' When validating XML parser tries to resolve system entities it 
	searches in http_root directory.
	If it fails parser iterates internal list of system paths and tries to
	find required files there. The function adds new path in this list.
	List of system paths contains one direcory item by default - 
	"file://system/".
    NOTE: List of system paths is not persistent. It means that you must
	add desired path each time when server starts. An ideal place for this
	operation in "autoexec.isql" file. '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_add_system_path',
'fn_xml_add_system_path',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'path',
'xml_add_system_path',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_get_system_paths',
'xml_get_system_paths',
'xml',
'Returns vector of all system paths.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_get_system_paths',
'fn_xml_get_system_paths',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_persistent',
'xml_persistent',
'xml',
'returns an entity object (@XPER entity@) created from given XML document',
'
This parses the argument, which is expected to be a well formed XML
fragment and returns a parse tree as a special object with underlying disk structure, named
"persistent XML" or "XPER"
While the result of xml_tree is a memory-resident array of vectors,
the XPER object consumes only a little amount of memory, and almost all data is disk-resident.
    
This function is equivalent to xper_doc, and the only
difference is in the order of arguments; xper_doc() has the same order of arguments as
xml_tree.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_persistent',
'fn_xml_persistent',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xml_persistent',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'parser_mode',
'xml_persistent',
  'integer','in',
'0, 1 or 2; 0 - XML parser mode, 1 - HTML parser mode, 2 - @dirty HTML@ mode (with quiet recovery after any syntax error)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'xml_persistent',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from given base_uri (http://<host>:<port>/<path>)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_encoding',
'xml_persistent',
  'varchar','in',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for HTML mode',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_language',
'xml_persistent',
  'varchar','in',
'string with language tag of content of <document>; valid names are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'dtd_validator_config',
'xml_persistent',
  'varchar','in',
'configuration string for DTD validator, default is empty string meaning that DTD validator should be fully disabled',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_tree',
'xml_tree',
'xml',
'Parses an XML fragment and returns the parse tree as nested vectors.',
'This parses the argument, which is expected to be a well formed XML
      fragment and returns a parse tree as a structure of nested heterogeneous vectors.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_tree',
'fn_xml_tree',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xml_tree',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'parser_mode',
'xml_tree',
  'integer','in',
'0, 1 or 2; 0 - XML parser mode, 1 - HTML parser mode, 2 - @dirty HTML@ mode (with quiet recovery after any syntax error)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'xml_tree',
  'varchar','in',
'(optional) in HTML parser mode change all absolute references to relative from given base_uri (http://<host>:<port>/<path>)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_encoding',
'xml_tree',
  'varchar','in',
'(optional) string with content encoding type of <document> valid is @ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_language',
'xml_tree',
  'varchar','in',
'(optional) - string with language tag of content of <document>; valid names are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages).',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'dtd_validator_config',
'xml_tree',
  'varchar','in',
'configuration string for DTD validator, default is empty string meaning that DTD validator should be fully disabled. Seexml_validate_dtd for details.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_tree_doc',
'xml_tree_doc',
'xml',
'returns an entity object given a tree from xml_tree',
'
This returns an entity object given a tree of the form returned by xml_tree.
	
If it is given a string as an argument, it will automatically generate
the parse tree and use it to make the entity instead requiring you to run the string through
xml_tree first.
	
Any other type of argument is illegal.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_tree_doc',
'fn_xml_tree_doc',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'tree',
'xml_tree_doc',
  'any/variable','in',
'either an XML tree such as that returned by xml_tree(), or a string of XML data.
If a string is provided then it will automatically generate the parse tree and form an
entity instead of requiring you to run the string through xml_tree first.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'xml_tree_doc',
  'varchar','in',
'Base URI of the original document, if known.
It will be useful if the document is not "standalone" and some entity references
are relative references to resources located "somewhere near" the
"top-level" document passes as "tree" parameter.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_uri_get',
'xml_uri_get',
'xml',
'Retrieve a resource based on a URI',
'
This function combines a base URI and a relative URI and returns the referenced resource.

The supported protocol identifiers are http: file: and virt:.  The virt: allows
referencing data stored in local Virtuoso tables without passing through HTTP.   See
@Entity References in Stored XML@ for details.

The effective URI will be the reference if the URI of the reference is absolute.  Otherwise it will
be the base URI modified by the relative reference.

Authorization is derived from the SQL or DAV identification of the caller.  The DAV
identification is used if processing DAV content in response to a DAV request.  The SQL user
account is used otherwise.

xml_uri_get returns the text of the requested resource. If specific encodings
or special authentication schemes are desired one may use
http_get directly.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_uri_get',
'fn_xml_uri_get',
'varchar DB.DBA.',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base',
'xml_uri_get',
  'varchar','in',
'A string containing the name of the location (URI) of the resource to be referenced.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'ref',
'xml_uri_get',
  'varchar','in',
'The name of the resource as a relative reference from the base URI.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_validate_dtd',
'xml_validate_dtd',
'xml',
'returns a string with list of errors detected by DTD validator on reading given XML document',
'
This parses the argument, which is expected to be an XML
fragment (possibly with syntax errors, violations of validity conditions etc.)
and returns a human-readable list of errors as a string.
 DTD validation may be performed during any reading of XML
source in functions xml_tree, xml_persistent or xper_doc, so that an application may
check XML source on the fly; severe constraint violations in source XML will
be signalled as SQL runtime errors. Configuration string is a sequence of pairs
parameter=value, delimited by spaces. No errors are reported if a parameter
is specified twice, in which case the last specified value will be used.   The only exception is the @Validation@ parameter which
sets typical values for all parameters. Both names and values are case-insensitive. Many parameters are used to specify the importance of a
particular error. For a particular application some validity constraints may be much more
important than others. Because less than perfectly valid XML is common in practice it
is important to configure the validator to report only those errors which  are relevant to the application.  Using configuration parameters, one may specify "importance levels"
for every group of problems. There are 5 "importance levels":
Some parameters are just switches, with only two values available: @ENABLE@ and @DISABLE@.
AttrCompletion (ENABLE/DISABLE, default is DISABLE)
is useful when DTD validator is invoked from XML parser.
When enabled, the XML document built will contain default values of @IMPLIED@ attributes as if they present in source text.
It may be useful if application should perform free-text search on all attribute values including defaults or if XML should be converted in form suitable for external non-validating XML processor or if given XML data should be stored later as part of composite document and composite document will have another DTD with other default values.
AttrMisFormat (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report errors in syntax of attributes@ values.
AttrUnknown (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report attributes whose names are not listed in DTD.
BadRecursion (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report circular references, when replacement text of an entity contains reference to this entity again, either directly (e.g. @<!ENTITY bad "some &bad; replacement">) or through other entities (e.g. @<!ENTITY a "&b;"> @<!ENTITY b "&a;">).
BuildStandalone (ENABLE/DISABLE, default is DISABLE)
when enabled, replacement texts of external entities will be inserted instead of references to these entities, thus all data from a composite document will be gathered together into one large XML.
This is useful for checking the element content model of the whole document without breaks on references or if parsed XML will be passed to external application as standalone document.
Fsa (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of specified element-content model.
Virtuoso@s DTD validator contains a finite state automaton which can detect the first error in the content of some element, but remaining errors in the same element become "obscured" by the first one and will not be reported.
Moreover, if element-content model is not SGML-compatible, some errors may remain undiscovered: it is possible to write a complex rule, so ambiguous that full check of all its interpretations will take prohibitively much time and memory.
The validator will simplify such rules to make check faster, thus some errors will not be reported.
FsaBadWs (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report the most popular violation of element-content model specified by DTD:
the use of whitespace characters in positions where only elements are allowed, not PCDATA.
It usually happens when XML is indented for readability.
You may wish to specify @FsaBadWs=IGNORE@ to eliminate redundant messages about this violation.
Note that if you will specify @FsaBadWs=DISABLE@ then you will disable the check of illegal PCDATA tokens for this particular case,
so common rule for @Fsa@ violations will be applied and you will see messages.
FsaSgml (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of SGML compatibility in element-content model.
Some complex DTD rules for elements are not supported by SGML processors and the validator may report the use of such rules.
GeRedef (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report redundant definitions of generic entities.
There redefinitions are errors in SGML but they may be ignored in XML processing (the first definition will be used and others will be ignored).
IdDuplicates (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report non-unique values of ID attributes.
It is a data integrity error, because IDs are usually parts of some primary keys, and are expected to be unique.
IdrefIntegrity (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report "dangling references".
Any value of IDREF attribute and any name from value of IDREFS attribute should appear in the same XML document as value of some ID attribute.
You can think that ID attribute specifies an hyperlink anchor and IDREF is a hyperlink, so it@s a data integrity error if hyperlink points to unknown location.
Include (FATAL/ERROR/WARNING/IGNORE/DISABLE)
configures reading of external sub-documents into "main" document you validate (and maybe load in database).
If @DISABLE@, no additional documents will be read, otherwise external parameter-entities, external generic-entities and external DTD will be located, using their SYSTEM names.
External documents may reside in file system, in database or in the Web. Absolute SYSTEM names (of form @protocol://server/resource@) will be used without any modifications, relative SYSTEM names should be "resolved", i.e. converted to absolute by adding prefix from base_uri argument of SQL function.
MaxErrors (integer from 1 to 10000, default is 25)
specifies how many errors may be logged before "Too many error messages" fatal error will be reported.
MaxWarnings (integer from 0 to 10000, default is 100)
specifies how many warnings may be logged before "Too many warning messages" event will stop their logging.
NamesUnknown (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report if document contains element names which are not declared in DTD.
They may be typos in element names or signal that DTD is incomplete or obsolete.
In addition, unknown names may be reported as element-content model violations.
NamesUnordered (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report element names not declared before use in DTD.
Proper order ("declare element name before use it") is important solely for compatibility with SGML standard.
NamesUnresolved (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report if element name used in DTD is not declared at all.
It may occur if DTD is incomplete or if some declaration are in ignored conditional sections.
Unresolved names cause no data integrity errors while remain unused in data section of the XML document, NamesUnknown parameter defines what happens if they@re actually used.
PeRedef (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report redundant definitions of parameter entities.
Similarly to redefinitions of generic entities, there redefinitions are errors in SGML but they may be ignored in XML processing (the first definition will be used and others will be ignored).
Sgml (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of SGML compatibility.
In fact, not all such violations are detected by current version of Virtuoso Server, because known SGML readers are insensitive to some sorts of violations.
TooManyWarns (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report "Too many warning messages" event.
While "Too many errors" is fatal error and terminates XML processing, "Too many warning messages" may have arbitrary "importance levels".
TraceLoading (ENABLE/DISABLE, default is DISABLE)
If enabled, the validator will log every reading of any resource, for easier tracking of URI resolving problems.
It@s possible that some readings of sub-documents will not be reported: there@s a limit for number of records in the log returned by the validator.
In addition, sub-documents may be cached inside validator, so only first references to some sub-document will require reading procedure.
Validation (SGML/RIGOROUS/QUICK/DISABLE, default is DISABLE)
loads one of four "preset configurations". It must be the first parameter in configuration string, if used.
DISABLE means "do not check for any type of error", QUICK is to check only for violation of "local" validity constraints, with disabled FsaBadWs, IdDuplicates and IdrefIntegrity, RIGOROUS enables these three groups, too, SGML enables all checks including all checks for SGML compatibility.
VcData (ENABLE/DISABLE, default is DISABLE)
describes how to report violations of generic validity constraints in data section of XML document.
If constraint is not configured by other parameters listed here, it will be configured by these parameter (or by VcDtd if relates to the text of DTD section).
VcDtd (ENABLE/DISABLE, default is DISABLE)
describes how to report violations of generic validity constraints in DTD section of XML document.
If constrain is not configured by other parameters listed here, it will be configured by these parameter (or by VcData if relates to the text of data section).'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_validate_dtd',
'fn_xml_validate_dtd',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xml_validate_dtd',
  'varchar','in',
'XML or HTML document to check'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'parser_mode',
'xml_validate_dtd',
  'integer','in',
'0 or 1; 0 - XML parser mode 1 - HTML parser mode'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base_uri',
'xml_validate_dtd',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from given base_uri (http://<host>:<port>/<path>)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_encoding',
'xml_validate_dtd',
  'varchar','in',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for HTML mode'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_language',
'xml_validate_dtd',
  'varchar','in',
'string with language tag of content of <document>; valid names are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dtd_validator_config',
'xml_validate_dtd',
  'varchar','in',
'configuration string of the validator, default is empty string meaning that DTD validator should be fully disabled and only critical errors should be reported'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_validate_schema',
'xml_validate_schema',
'xml',
'returns a string with list of errors detected by DTD and XML Schema validator on reading given XML document',
'
This parses the argument, which is expected to be an XML 
fragment (possibly with syntax errors, violations of validity conditions etc.)
and returns some human-readable list of errors as a string.
If there is "schemaLocation" attribute in root element,
XML Schema declaration will be loaded and partial
schema validation will be performed. Configuration string is a sequence of pairs parameter=value, delimited by spaces. No errors are reported if a parameter is specified twice, in which case the last specified value will be used to avoid conflict.   The only exception is the @Validation@ parameter which sets typical values for all parameters. Both names and values are case-insensitive. Many parameters are used to specify the importance of a particular error. For particular use, some validity constraints may be much more than others, and you usually will never see perfect XMLs in real life, so it@s important to configure the validator to report only those errors you want to catch. Using configuration parameters, you may specify "importance levels" for every group of problems. There are 5 "importance levels":
Some parameters are just switches, with only two values available: @ENABLE@ and @DISABLE@.
AttrCompletion (ENABLE/DISABLE, default is DISABLE)
is useful when DTD validator is invoked from XML parser.
When enabled, the XML document built will contain default values of @IMPLIED@ attributes as if they present in source text.
It may be useful if application should perform free-text search on all attribute values including defaults or if XML should be converted in form suitable for external non-validating XML processor or if given XML data should be stored later as part of composite document and composite document will have another DTD with another default values.
AttrMisFormat (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report errors in syntax of attributes@ values.
AttrUnknown (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report attributes whose names are not listed in DTD.
BadRecursion (FATAL/ERROR/WARNING/IGNORE/DISABLE) describes how to report circular references, when replacement text of an entity contains reference to this entity again, either directly (e.g. @<!ENTITY bad "some &bad; replacement">) or through other entities (e.g. @<!ENTITY a "&b;"> @<!ENTITY b "&a;">).
BuildStandalone (ENABLE/DISABLE, default is DISABLE)
when enabled, replacement texts of external entities will be inserted instead of references to these entities, thus all data from composite document will be gathered together into one large XML. It is useful if you want to check element-content model of whole document without breaks on references or if parsed XML will be passed to external application as standalone document.
Fsa (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of specified element-content model.
Virtuoso@s DTD validator contains finite state automaton which can detect the first error in content of some element, but remaining errors in the same element become "obscured" by the first one and will not be reported.
Moreover, if element-content model is not SGML-compatible, some errors may remain undiscovered: it is possible to write complex rule, so ambiguous that full check of all its interpretations will take prohibitively large time and memory.
Validator will simplify such rules to make check faster, thus some errors will not be reported.
FsaBadWs (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report the most popular violation of element-content model specified by DTD:
the use of whitespace characters in positions where only elements are allowed, not PCDATA.
It usually happens when XML is indented for readability.
You may wish to specify @FsaBadWs=IGNORE@ to eliminate redundant messages about this violation.
Note that if you will specify @FsaBadWs=DISABLE@ then you will disable the check of illegal PCDATA tokens for this particular case,
so common rule for @Fsa@ violations will be applied and you will see messages.
FsaSgml (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of SGML compatibility in element-content model.
Some complex DTD rules for elements are not supported by SGML processors and validator may report the use of such rules.
GeRedef (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report redundant definitions of generic entities.
There redefinitions are errors in SGML but they may be ignored in XML processing (the first definition will be used and others will be ignored).
IdDuplicates (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report non-unique values of ID attributes.
It is data integrity error, because IDs are usually parts of some primary keys, and are expected to be unique.
IdrefIntegrity (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report "dangling references".
Any value of IDREF attribute and any name from value of IDREFS attribute should appear in the same XML document as value of some ID attribute.
You can think that ID attribute specifies an hyperlink anchor and IDREF is a hyperlink, so it@s data integrity error if hyperlink points to unknown location.
Include (FATAL/ERROR/WARNING/IGNORE/DISABLE)
configures reading of external sub-documents into "main" document you validate (and maybe load in database).
If @DISABLE@, no additional documents will be read, otherwise external parameter-entities, external generic-entities and external DTD will be located, using their SYSTEM names.
External documents may reside in file system, in database or in the Web. Absolute SYSTEM names (of form @protocol://server/resource@) will be used without any modifications, relative SYSTEM names should be "resolved", i.e. converted to absolute by adding prefix from base_uri argument of SQL function.
MaxErrors (integer from 1 to 10000, default is 25)
specifies how may errors may be logged before "Too many error messages" fatal error will be reported.
MaxWarnings (integer from 0 to 10000, default is 100)
specifies how may warnings may be logged before "Too many warning messages" event will stop their logging.
NamesUnknown (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report if document contains element names which are not declared in DTD.
They may be typos in element names or signal that DTD is incomplete or obsolete.
In addition, unknown names may be reported as element-content model violations.
NamesUnordered (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report element names not declared before use in DTD.
Proper order ("declare element name before use it") is important solely for compatibility with SGML standard.
NamesUnresolved (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report if element name used in DTD is not declared at all.
It may occur if DTD is incomplete or if some declaration are in ignored conditional sections.
Unresolved names cause no data integrity errors while remain unused in data section of the XML document, NamesUnknown parameter defines what happens if they@re actually used.
PeRedef (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report redundant definitions of parameter entities.
Similarly to redefinitions of generic entities, there redefinitions are errors in SGML but they may be ignored in XML processing (the first definition will be used and others will be ignored).
Sgml (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report violations of SGML compatibility.
In fact, not all such violations are detected by current version of Virtuoso Server, because known SGML readers are insensitive to some sorts of violations.
TooManyWarns (FATAL/ERROR/WARNING/IGNORE/DISABLE)
describes how to report "Too many warning messages" event.
While "Too many errors" is fatal error and terminates XML processing, "Too many warning messages" may have arbitrary "importance levels".
TraceLoading (ENABLE/DISABLE, default is DISABLE)
If enabled, validator will log every reading of any resource, for easier tracking of URI resolving problems.
It@s possible that some readings of sub-documents will not be reported: there@s a limit for number of records in the log returned by validator.
In addition, sub-documents may be cached inside validator, so only first references to some sub-document will require reading procedure.
Validation (SGML/RIGOROUS/QUICK/DISABLE, default is DISABLE)
loads one of four "preset configurations". It must be the first parameter in configuration string, if used.
DISABLE means "do not check for any type of error", QUICK is to check only for violation of "local" validity constraints, with disabled FsaBadWs, IdDuplicates and IdrefIntegrity, RIGOROUS enables these three groups, too, SGML enables all checks including all checks for SGML compatibility.
VcData (ENABLE/DISABLE, default is DISABLE)
describes how to report violations of generic validity constraints in data section of XML document.
If constrain is not configured by other parameters listed here, it will be configured by these parameter (or by VcDtd if relates to the text of DTD section).
VcDtd (ENABLE/DISABLE, default is DISABLE)
describes how to report violations of generic validity constraints in DTD section of XML document.
If constrain is not configured by other parameters listed here, it will be configured by these parameter (or by VcData if relates to the text of data section).'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_validate_schema',
'fn_xml_validate_schema',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xml_validate_schema',
  'varchar','in',
'XML or HTML document to check'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'parser_mode',
'xml_validate_schema',
  'integer','in',
'0 or 1; 0 - XML parser mode 1 - HTML parser mode'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'base_uri',
'xml_validate_schema',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from given base_uri (http://<host>:<port>/<path>)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_encoding',
'xml_validate_schema',
  'varchar','in',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for HTML mode'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'content_language',
'xml_validate_schema',
  'varchar','in',
'string with language tag of content of <document>; valid names are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages)'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dtd_validator_config',
'xml_validate_schema',
  'varchar','in',
'configuration string of the validator, default is empty string meaning that DTD validator should be fully disabled and only critical errors should be reported'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_view_dtd',
'xml_view_dtd',
'xml',
'returns an XML DTD for the output of given XML VIEW',
'
This function will return an XML DTD for the output of a given XML VIEW.
The returned DTD will be valid if the HTTP_... output of the view is
wrapped into the specified root element.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_view_dtd',
'fn_xml_view_dtd',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'view_name',
'xml_view_dtd',
  'varchar','in',
'Name of an XML View.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root_element',
'xml_view_dtd',
  'varchar','in',
'Name of the root element.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xml_view_schema',
'xml_view_schema',
'xml',
'returns an XML schema for the output of given XML VIEW',
'
This function return an XML schema for the output of given XML VIEW.
The returned schema will be valid if the HTTP_... output of view
wrapped into the specified root element.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xml_view_schema',
'fn_xml_view_schema',
'varchar',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'query ',
'xml_view_schema',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'root_element ',
'xml_view_schema',
  'varchar','in',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xmlsql_update',
'xmlsql_update',
'xml',
'Performs insert/update/delete operations
    based on an XML updategram.',
'xmlsql_update() supports XML-based insert,
    update, and delete operations performed on an existing table in the
    database. See Updategrams basics
    in the "Web and XML section" for a detailed explanation.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xmlsql_update',
'fn_xmlsql_update',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xml_grams',
'xmlsql_update',
  'XML_Entity','in',
'Mandatory parameter containing the XML document with gram(s).
      This can be produced with sequential calls to the
    xml_tree() and
      xml_tree_doc() functions.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'input_parameters',
'xmlsql_update',
  'vector','in',
'Optional array or vector of parameter pairs (parameter_name, parameter_value).',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xpath_eval',
'xpath_eval',
'xml',
'Applies an XPATH expression to a context node and returns result(s).',
'
This function returns the result of applying the XPath
expression to the context node.  By default only the first result is
returned, but supplying a third argument allows you to specify an
index for the value; the default assumes a value of 1 here.  A value
of 0 returns an array of 0 or more elements, one for each value
selected by the XPath expression.
	
When this function returns an entity in a result set, the client will
see an nvarchar value containing the serialization of the entity,
complete with markup.  When the entity is passed as an SQL value it
remains an entity referencing the node of a parsed XML tree,
permitting navigation inside the tree.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xpath_eval',
'fn_xpath_eval',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xpath_expression ',
'xpath_eval',
  'varchar','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xml_tree ',
'xpath_eval',
  'XML Entity','in',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'index ',
'xpath_eval',
  'integer','in',
'',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xper_cut',
'xper_cut',
'xml',
'creates a new "persistent XML"document which contains a copy of data pointed by given XPER entity',
'
As noted in the Storage in Database section,
a subtree may be extracted from a document during writing of "persistent XML"
entity into field of type LONG VARCHAR. The procedure of converting a subtree into
complete document is known as "cutting".  Cutting is performed only for
"persistent XML" documents, it has nothing common with serialization of
XML entities in form of plain XML text.
Usually it is the job of the Server itself who
decides whether a cutting operation should be performed or not, without any specific
activity at application level.
The CPU time occupied due to cutting is up to 10 times greater than the CPU time of plain copying of LONG VARCHAR,
but the amount of disk IO is about the same, so the optimization rules discussed below are
important only for time-critical, memory-located database applications.
The Virtuoso Server tries to reduce the number of cuttings to an absolute minimum.
First of all, cutting is not performed when a given XML entity
refers to the root of the document, or to the only child of the root,
because the result of such cutting will be identical to original document.
In addition, every document remembers the result of last cutting performed on data from
this document, so if data of some XML entity are saved in many places without saving of
other XML entities between them, cutting will be done only once and plain copying will
be done for every subsequent saving.
The only situation when cutting may be seriously optimized by the application developer is in code
like the following:
Calls of xpath_eval are outside the loop, so it is faster than retrieval of suitable form for
every selected record.  But values of both _plain and _isdn shares the same underlaying XML document
and they will be assigned many times by the @insert@ operation.  The XML document has no place to cache
two results of cuttings, so new cutting will be done every time
when _isdn entity is saved after _plain or _plain saved after _isdn.  To optimize, it is better to
cut them once outside the loop:'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_cut',
'fn_xper_cut',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'source_xper',
'xper_cut',
  'XML_Entity','in',
'XML Entity'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xper_doc',
'xper_doc',
'xml',
'returns an entity object (@XPER entity@) created from an XML document',
'
This parses the argument, which is expected to be a well formed XML
fragment and returns a parse tree as a special object with underlying disk structure, named
"persistent XML" or "XPER"
While the result of xml_tree is a memory-resident array of vectors,
the XPER object consumes only a little amount of memory, and almost all data are disk-resident.
XPERs are better then "XML trees" for large documents and
for "write once -- read many" stores such as a table with
one XML document per row used as a "library" of documents.
To be saved in a LONG VARCHAR column, "XML tree" entity will be
converted back to plain text of XML syntax; but "XPER" entity
will be saved as a ready-to-use disk structure.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_doc',
'fn_xper_doc',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xper_doc',
  'varchar','in',
'well formed XML or HTML document'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'parser_mode',
'xper_doc',
  'integer','in',
'0, 1 or 2; 0 - XML parser mode, 1 - HTML parser mode, 2 - @dirty HTML@
mode (with quiet recovery after any syntax error)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'xper_doc',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from
given base_uri (http://<host>:<port>/<path>)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_encoding',
'xper_doc',
  'varchar','in',
'string with content encoding type of <document>; valid are
@ASCII@, @ISO@, @UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for
XML mode and @LATIN-1@ for HTML mode.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_language',
'xper_doc',
  'varchar','in',
'string with language tag of content of <document>; valid names
are listed in IETF RFC 1766, default is @x-any@ (it means @mix of words from various
human languages)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'dtd_validator_config',
'xper_doc',
  'varchar','in',
'configuration string for DTD validator, default is empty string meaning
that DTD validator should be fully disabled. Seexml_validate_dtd
for details.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'index_attrs',
'xper_doc',
  'integer','in',
'1 or 0, indicating if additional free-text indexing information must be
stored for all attributes of the document. It is 1 by default. If set to @0@, it will
produce a disk structure compatible with old versions of Virtuoso and will give a small
benefit in disk usage but it will disable some important optimizations in free-text
search operations.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xper_locate_words',
'xper_locate_words',
'xml',
'returns a smallest fragment of persistent XML entity object (@XPER entity@) such that it contains some range of words in its text',
'This receives the XML entity and returns its fragment or signals an error.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_locate_words',
'fn_xper_locate_words',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'entity',
'xper_locate_words',
  'any/variable','in',
'A @persistent XML@ entity to be searched'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'starting_word',
'xper_locate_words',
  'integer','in',
'The number of the leftmost word which should be in the selected fragment',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'ending_word',
'xper_locate_words',
  'integer','in',
'The number of the rightmost word which should be in the selected fragment',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xper_right_sibling',
'XPER navigation',
'xml',
'low-level navigation functions for persistent XMLs, useful for import of huge amounts of XML data',
'
All these functions work with "persistent XML" (XPER) entities only, signalling errors if
given entity points to "XML tree".  They are useful when applications need to read a
huge XML document, especially something like a datasheet dump or event log with a large number
of uniform records, and is required to process all records of the document, e.g. import them into
the database.

Consider a real sample of import all data from ODP@s content.xml dump which contains more than
2,000,000 descriptions of various Web-sites, and the length of the file is more than 600Mb.  The
file has root element named @RDF@ and all descriptions are their children named either @Topic@ or
@ExternalPage@. This code looks suitable for importing these children:
It looks fine and it passes small tests but it will not work on real data!
First problem is regular checkpoints (every 1 hour by default),
so import_content_xml has no chance to be completed if it takes 1.5 hours of CPU time;
the function checkpoint_interval should be used to temporarily disable these checkpoints.
Then, the length of transaction log become extremely large after switching checkpoints off,
and it is better to insert explicit checkpoints between calls of these functions.
Finally, import_content_xml will change more than 4 gigabytes of data in one transaction.
This would be impossible on any 32-bit platform, because both memory available and address space
become insufficient.  Adding intermediate @commit work@ statements inside the loop@s body
will not help because both @commit work@ and @rollback work@ statements will close all opened cursors.
Loop @for select ... from ... do@ uses an implicit cursor to iterate the resultset, but the
@commit work@ operator will close this cursor and abort the loop.
Function xper_right_sibling is designed specially to solve the last problem.  It allows you
to iterate children of some element without using any cursor at all.
It returns the right child of the entity passed as its argument.  If the given entity
is the last child of its parent, the function will return NULL.  Similarly, xper_left_sibling will
return the previous child or NULL for the first child, xper_parent will return parent of
entity or NULL for the document@s root and xper_root_entity will return the root for any
entity.  Using these functions, it is possible to scan the document forward (from left
to right), backward and to "climb up" toward the root of the elements@ tree.  These
functions are called XML Navigation Functions because they are like
the statements "next record", "prev record" etc., used in cursor
like navigation of databases.
There are no special functions to "go down", e.g. to find first children of
given element, because xpath_eval can do any such movement very quickly.
Sometimes data import is controlled from some client application.  If one operation takes
hours, some sort of "progress bar" becomes very useful, at least to see whether
application works or hangs. xper_length takes an XPER entity and returns whole length of
XPER disk image in bytes. xper_tell takes an XPER entity and returns something like entity@s offset
inside the document.  Their results may be used by the client application to monitor the progress
and estimate the time until completion.  They may be especially useful for debugging purposes,
e.g. to report position of error.  Unfortunately "xper_seek" is not possible for
XPERs, unlike typical random access to files.
Ultimately, the working version of the procedure described above will look like this:'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_left_sibling',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_left_sibling',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_length',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_length',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_parent',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_parent',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_right_sibling',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_right_sibling',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_root_entity',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_root_entity',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xper_tell',
'fn_xper_right_sibling',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xper_entity',
'xper_tell',
  'XML_entity','in',
'Persistent XML entity to operate on.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xpf_extension',
'xpf_extension',
'xml',
'declare an XPath extension function ',
'
    This function is used to declare a new XPath extension function or
redefine an existing function.  It can be used in XPath queries and
XSLT stylesheets.  You should use QNames for extension functions.
Note that the standard XPath functions cannot be redefined.xpf_extension() stores the functions into
the SYS_XPF_EXTENSIONS system table.
    
    The input parameters will be retreived as a strings and then will be converted to the datatype of 
    the corresponding argument of the stored procedure. 
    '

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xpf_extension',
'fn_xpf_extension',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'fname',
'xpf_extension',
  'varchar','in',
'The name of the extension function, which must be the expanded QName 
      of the extension function'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'procedure_name',
'xpf_extension',
  'varchar','in',
'The fully qualified name of the PL procedure which acts as 
      the extension function.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xpf_extension_remove',
'xpf_extension_remove',
'xml',
'discards an XPath extension function',
'Removes a user-defined XPath function.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xpf_extension_remove',
'fn_xpf_extension_remove',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'fname',
'xpf_extension_remove',
  'varchar','in',
'The expanded QName of the
    extension function to be removed'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'procedure_name',
'xpf_extension_remove',
  'varchar','in',
'The fully qualified
    name of the PL procedure which acts as the extension
    function.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xquery_eval',
'xquery_eval',
'xml',
'Applies an XQUERY expression to a context node and returns result(s).',
'
The xquery_eval function returns the result of applying the xquery expression to the
context node.  By default only the first result is returned, but supplying a third argument
allows you to specify an index for the value, the default assumes a value of 1 here.
A value of 0 returns an array of 0 or more elements, one for each value calculated by the
xquery expression.
	
When an entity is returned in a result set to a client the client will see an nvarchar value containing the
serialization of the entity, complete with markup.
When the entity is passed as a SQL value it remains
an entity referencing the node of a parsed XML tree, permitting navigation inside the tree.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xquery_eval',
'fn_xquery_eval',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xquery_expression',
'xquery_eval',
  'varchar','in',
'A valid xquery expression'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'xml_tree',
'xquery_eval',
  'XML Entity','in',
'An XML entity such as that returned from the xtree_doc function.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'index',
'xquery_eval',
  'integer','in',
'Result index.  This parameter is optional.  If omitted a value of 1 is assumed,
meaning only the first result is returned.  If a value of 0 is supplied then an array of 0 or more
elements is returned containing on element per result.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xslt',
'xslt',
'xml',
'returns an XML document transformed by an XSLT stylesheet',
'
This function takes a URI of a stylesheet and an XML entity and
produces an XML entity representing the transformation result of the
given entity with the given stylesheet.  The result tree is separate
from the argument tree and the only reference to it is the returned
entity.  Errors occurring in the transformation will be signalled as
SQL states, with XML or XSLT specific conditions beginning with XS or
XP.

The stylesheet can be passed parameters by specifying a third argument
to xslt().  This will be a vector of name/value
pairs. The values can be referenced from inside XPath expressions in
the stylesheet. You may use any Virtuoso data type.  The names in the
parameter vector should appear without the @$@ sign.  If any of the
parameter values is NULL the parameter will be ignored because NULL
has no XPath counterpart.

xslt() applies the transformation in the sheet to
the specified entity.  The result is the root element of the result
tree, an XML entity.  This entity can be used as input to another
transformation, can be serialized and sent to an HTTP client or stored,
etc.

The URI of the sheet is used to locate the stylesheet.  The protocol
can be http, file or virt.  Once the stylesheet has been retrieved it
is cached and not refetched until the cache is invalidated with
xslt_stale().  Included or imported style sheets
will be fetched automatically, using the initial URI as base for any
relative references.  The sheet_uri is the URI
of a stylesheet.  This should be an absolute URI resolvable with
xml_uri_get().  If the URI has previously been
used as a stylesheet and has not been marked stale with
xslt_stale(), Virtuoso will use the cached data
instead of fetching and parsing the stylesheet resource.

When a resource with a .xsl extension is stored into the WebDAV,
Virtuoso marks as stale any related cached resource.  The URI for such
stylesheets will be
virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:<path>. See
the section about entity references in stored text for more on this
type of URI.  If the URI uses the file protocol, Virtuoso will compare
the date of the file against the date of the cached stylesheet,
automatically reloading the sheet if the file changes.  This protocol
is subject to the limitations on file system access imposed by the
host operating system and the virtuoso.ini file system access control
settings.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xslt',
'fn_xslt',
'xml_entity',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sheet_uri',
'xslt',
  'varchar','in',
'URI pointing to the location of an XSL stylesheet.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'entity',
'xslt',
  'any/variable','in',
'parsed XML entity such as that returned by the xml_tree_doc() function'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'sheet_params',
'xslt',
  'vector','in',
'A vector of keyword/value parameters to be passed to the
    XSLT engine for use in the transformation.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xslt_format_number',
'xslt_format_number',
'xml',
'returns formated string representation of a numeric value',
'xslt_format_number is an BIF wrapper for the format-number() XSLT function.It always uses the default formating parameters described in the XSLT standard.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xslt_format_number',
'fn_xslt_format_number',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'number',
'xslt_format_number',
  'any/variable','',
'
        integer, numeric or string.
      '

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'format_string',
'xslt_format_number',
  'varchar','',
'string'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xslt_profile_enable',
'xslt_profile_enable',
'xml',
'',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xslt_profile_enable',
'fn_xslt_profile_enable',
'',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xslt_sheet',
'xslt_sheet',
'xml',
'declares an XSL stylesheet for use',
'
This function takes a name and the root element of a parsed XML
document and defines these as a stylesheet.  The unique element child
of the entity object@s document should be an xsl:stylesheet
element.  Included or imported stylesheets will be located relative to
the base URI of the entity passed to
xslt_sheet().  Once a stylesheet thus defined it
can be used as the stylesheet argument of xslt.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xslt_sheet',
'fn_xslt_sheet',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uri',
'xslt_sheet',
  'varchar','in',
'The location of the XSLT style sheet'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'entity',
'xslt_sheet',
  'any/variable','in',
'A valid XSL style sheet, XML entity parsed using the xml_tree_doc() function'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xslt_stale',
'xslt_stale',
'xml',
'force reload of XSL stylesheet',
'
This function can be used to force Virtuoso to reload a cached
stylesheet from the URI when next used with
xslt() or http_xslt().
Using this function before every application of the stylesheet is
extremely inefficient.  If stylesheets are stored in the database, you
can use this function in an update trigger on the table storing the
stylesheets but you should not use it before every application of the
sheet.
This function never needs to be applied to a stylesheet URI with
the file protocol since xslt() and
http_xslt() will automatically detect a stale
cache entry.  However if the stylesheet is stored on a remote web
server, this function is needed to force a reload.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xslt_stale',
'fn_xslt_stale',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'uri',
'xslt_stale',
  'varchar','in',
'The location of the style sheet to force a reload.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_xtree_doc',
'xtree_doc',
'xml',
'returns an entity object created from an XML document',
'
This parses the argument, which is expected to be a well formed XML 
fragment and returns a parse tree as a special memory-resident object.
While xper_doc
creates some disk-resident data structure, xtree_doc() will work
faster but it may require more memory.
You may wish to use xtree_doc for small documents (e.g. less than
5 megabytes and xper_doc for larger documents.
	'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'xtree_doc',
'fn_xtree_doc',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document',
'xtree_doc',
  'varchar','in',
'well formed XML or HTML document'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'parser_mode',
'xtree_doc',
  'integer','in',
'0, 1 or 2; 0 - XML parser mode, 1 - HTML parser mode, 2 - @dirty HTML@ 
mode (with quiet recovery after any syntax error)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'xtree_doc',
  'varchar','in',
'in HTML parser mode change all absolute references to relative from given 
base_uri (http://<host>:<port>/<path>)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_encoding',
'xtree_doc',
  'varchar','in',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@, 
@UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for 
HTML mode.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_language',
'xtree_doc',
  'varchar','in',
'string with language tag of content of <document>; valid names are listed in 
IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages@)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'dtd_validator_config',
'xtree_doc',
  'varchar','in',
'configuration string for DTD validator, default is empty string meaning that DTD 
validator should be fully disabled. Seexml_validate_dtd 
for details.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_and',
'and',
'XPATH',
'Returns false if a value of some argument is false, otherwise returns true.',
'
This function calculates values of its arguments, from left to right.
If the value of calculated parameter is false, the function returns false immediately,
without calculating of the remaining parameters.
If the lsit of arguments ends without any false value calculated, the function
returns true (Thus it will return true if called without arguments).

The name of this function is the same as name of "and" XPATH and XQUERY operator.
Thus it must be surronded bu double quotes when used in XPATH or XQUERY expressions.
Moreover, this function is not a part of XPATH standard, so it cannot be used if
portability is important.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'and',
'xpf_and',
'boolen',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val1',
'and',
  'boolean','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val2',
'and',
  'boolean','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'and',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'valN',
'and',
  'boolean','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_append',
'append',
'XPATH',
'Creates an sequence of all items from given sequences.',
'
This function calculates all given arguments from left to right,
and creates a sequence which contains all items of the first calculated sequence,
then all items of the second calculated sequence and so on, preserving
the order of items from every sequence.
The result is identical to the result of XQUERY "comma operator".

This function is not a part of XPATH 1.0 or XQUERY 1.0 libraries of standard functions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'append',
'xpf_append',
'sequence',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seq1',
'append',
  'array','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seq2',
'append',
  'array','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'append',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seqN',
'append',
  'array','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_avg',
'avg',
'XPATH',
'Returns average value of all its arguments.',
'
The function returns the average of all values in all its arguments,
For each node in every argument node-set, it converts the string-value of the node to a number and adds the result to the sum.
If some arguments are not node-sets, they are converted to numbers first and added to the sum.
Then sum is divided by number of values added and the result is returned.

This function is not a part of XPATH 1.0 standard library.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'avg',
'xpf_avg',
'number',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'avg',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'avg',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'avg',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'argN',
'avg',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_boolean',
'boolean',
'XPATH',
'Converts its argument to boolean',
'
The function converts its argument to a boolean as follows:

A number is true if and only if it is neither zero nor NaN.
A node-set is true if and only if it is non-empty.
A string is true if and only if its length is non-zero.
An object of a type other than the four basic types is converted to a boolean in a way that is dependent on that type.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'boolean',
'xpf_boolean',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'obj',
'boolean',
  'any/variable','',
'The object to be converted into boolean.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_ceiling',
'ceiling',
'XPATH',
'Returns the smallest integer that is not less than the argument.',
'
This function returns the smallest (closest to negative infinity) number that is not less than the argument and that is an integer.
In other words, it "rounds up" the given value.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ceiling',
'xpf_ceiling',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'ceiling',
  'numeric','',
'The value to be "rounded up"'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_concat',
'concat',
'XPATH',
'Returns the concatenation of its arguments.',
'
The function converts all its arguments into strings using the same rules as XPATH function string(),
then it performs concatenation and returns the resulting string.

XPATH 1.0 standard states that concat() function must have at least 2 arguments,
but in Virtuoso XPATH this restriction is eliminated.
concat() may be called without arguments (it will return an empty string)
or with one argument (it will work like string() function).
This may be useful if the text of XPATH expression must be generated by
an application.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'concat',
'xpf_concat',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg1',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg2',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'concat',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strgN',
'concat',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_contains',
'contains',
'XPATH',
'Returns true if the first argument string contains the second argument string, and otherwise returns false.',
'
For two given strings, this function checks if the first string conctains the second string.
If any argument is not a string, it is converted to string using rules from string() XPATH function.
Thus if the second argument has no string value, the function returns true, because it will
be converted to an empty string first.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'contains',
'xpf_contains',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'haystack',
'contains',
  'varchar','',
'String where the search is performed'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'needle',
'contains',
  'varchar','',
'String to search'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_count',
'count',
'XPATH',
'Returns the number of values in the sequence.',
'Returns 1 if the argument is a single value or a count of elements in the given sequence of values.This function must be called with an argument, it do nothing with context.
To count nodes in context node-set, use last().'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'count',
'xpf_count',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seq',
'count',
  'any/variable','',
'Sequence of values to be counted.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_current',
'current',
'XPATH',
'Returns a node-set that has the current node as its only member.',
'
The function returns a node-set that has the current node as its only member.
For an outermost expression (an expression not occurring within another expression),
the current node is always the same as the context node. For an expression
occuring within another expression, e.g. within predicate in some path,
the current node is the same as the context node of the first step in the path.

Please refer XSL standard before the first use of this function,
to understand exact difference between "current" and "context" node.

XSLT 1.0 states that it is an error to use the current() function in a XSL "pattern",
e.g. in "match" attribute of <xsl:key> element, because patterns
have no value assigned for current node assigned processing.
Instead of reporting the error, Virtuoso@s XSLT processor uses context node
if current node is not set.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'current',
'xpf_current',
'node-set',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_document',
'document',
'XPATH',
'Returns data from XML documents other than the main source document.',
'
The function tries to access an XML text at location specified by document_uri
and optionally base_uri. On success, it parses the text and returns
the root entity of the "XML Tree" document; the result is identical to
the entity created by xtree_doc() PL/SQL function.

If the document_uri argument is node-set, not a string,
then a node-set is returned as if document() function is applied to string-value of every node
of the node-set.

Note that the list of attributes of the function differs from specified in XSLT 1.0 standard.
In XPATH 1.0, there is no such function at all.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'document',
'xpf_document',
'node-set',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'document_uri',
'document',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'parser_mode',
'document',
  'integer','',
'0, 1 or 2; 0 - XML parser mode, 1 - HTML parser mode, 2 - @dirty HTML@
mode (with quiet recovery after any syntax error)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'base_uri',
'document',
  'varchar','',
'in HTML parser mode change all absolute references to relative from given
base_uri (http://<host>:<port>/<path>)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_encoding',
'document',
  'varchar','',
'string with content encoding type of <document>; valid are @ASCII@, @ISO@,
@UTF8@, @ISO8859-1@, @LATIN-1@ etc., defaults are @UTF-8@ for XML mode and @LATIN-1@ for
HTML mode.',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'content_language',
'document',
  'varchar','',
'string with language tag of content of <document>; valid names are listed in
IETF RFC 1766, default is @x-any@ (it means @mix of words from various human languages@)',
1

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'dtd_validator_config',
'document',
  'varchar','',
'configuration string for DTD validator, default is empty string meaning that DTD
validator should be fully disabled. Seexml_validate_dtd()
for details.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_empty',
'empty',
'XPATH',
'Returns true if given argument is an empty sequence, false if it is any single value or nonempty sequence.',
'Returns true if given argument is an empty sequence, false if it is any single value or nonempty sequence.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'empty',
'xpf_empty',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'seq',
'empty',
  'any/variable','',
'Sequence of values to be checked.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_ends_with',
'ends-with',
'XPATH',
'Returns true if the first argument string ends with the second argument string, and otherwise returns false.',
'For two given strings, this function checks if the first string ends with characters of second string.
If any argument is not a string, it is converted to string using rules from string() XPATH function.
Thus if the second argument has no string value, the function returns true, because it will
be converted to an empty string first.Unlike start-with() XPATH function, this function is not described in XPATH 1.0 standard.
To write portable XPATH expression, use substring().'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'ends-with',
'xpf_ends_with',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg',
'ends-with',
  'varchar','',
'String whose first characters must be compared'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'suffix',
'ends-with',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_every',
'every',
'XPATH',
'Returns true if all items of given sequence matches given criterion.',
'
The function creates a temporary local variable, whise name is specified by
varname argument.
Then, for every item of test_set sequence it
calculates the test_expn boolean expression
having set the created variable to that "current" item.
If the value of expression is false, the function immediately returns
false without processing the rest of test_set sequence.
If all items of the sequence are probed without getting false,
true is returned. (So if the sequence is empty, the function returns true).

In any case, temporary variable is destroyed on return.

This function is used in the implementation of
"EVERY" logical operator in XQUERY, so you will probably use that operator
in XQUERY expessions, not the function.
This function may be useful in XPATH expressions and in XSLT stylesheets.
It is not a part of library of standard XQUERY 1.0 functions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'every',
'xpf_every',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'varname',
'every',
  'varchar','',
'Name of temporary variable'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'test_set',
'every',
  'array','',
'Sequence of items; these items will be tested by test_expn'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'test_expn',
'every',
  'boolean','',
'Boolean expression which should be calculated for items of test_set.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_false',
'false',
'XPATH',
'Returns false.',
'This function returns boolean contant "false".'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'false',
'xpf_false',
'boolean',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_floor',
'floor',
'XPATH',
'Returns the largest integer that is not greater than the argument.',
'
This function returns the largest (closest to positive infinity) number that is not greater than the argument and that is an integer.
In other words, it "rounds down" the given value.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'floor',
'xpf_floor',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'floor',
  'numeric','',
'The value to be "rounded down"'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_for',
'for',
'XPATH',
'Returns true if all items of given sequence matches given criterion.',
'
The function creates a temporary local variable, whise name is specified by
varname argument.
Then, for every item of source_set sequence it
calculates the value of mapping_expn expression
having set the created variable to that "current" item.
It returns the "flattened" sequence of values returned by
mapping_expn in the same order as they are calculated.
"Flattened" means that if mapping_expn
returns an sequence, items of this sequence will be added into the end of
resulting sequence, one by one, instead of adding one item of type "sequence".

In any case, temporary variable is destroyed on return.

This function is used in the implementation of
"FOR" control operator in XQUERY,
so you will probably use that operator in XQUERY expessions, not the function.
This function may be useful in XPATH expressions and in XSLT stylesheets.
It is not a part of library of standard XQUERY 1.0 functions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'for',
'xpf_for',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'varname',
'for',
  'varchar','',
'Name of temporary variable'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'source_set',
'for',
  'array','',
'Sequence of items; every item will cause one call of mapping_expn'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'mapping_expn',
'for',
  'any/variable','',
'An expression which should be calculated for items of source_set.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_format_number',
'format-number',
'XPATH',
'',
'
The function converts the num argument to a string
using the format pattern string specified by the format_pattern
and the decimal-format named by the decimal_format,
or the default decimal-format, if there is no third argument.

The format pattern string is in the syntax specified by the JDK 1.1 DecimalFormat class.
The following describes the structure of the pattern.

The pattern consists of one or two subpatterns, first is for
positive numbers and zero, second is for negative numbers.
Two subpatterns are delimited by semicolon.
If there is only one subpattern, - is prefixed to the positive subpattern.

Every subpattern consists of
optional prefix characters
followed by an integer part
followed by an optional fraction part
followed by an optional suffix characters.


Prefix and suffix characters are any Unicode characters except special formatting
characters described below, while integer and fraction part consist
only from that special formatting characters. (As an exception,
special characters may appear in prefix in suffix parts if enclosed in single quotes.


If fractional present, it starts from @.@ character, and only one @.@
may occur in the subformat. Thus it is easy to find where each part begins.



By default, the following characters are treated as special when used in the parts of the subpattern:

    
      
       SymbolMeaning
	
	  0A digit, zero will be printed. 0 must be the last character of integer part.
	  #A digit, zero will not be printed.
	  .Placeholder for decimal separator in the beginning of fraction part.
	  ,Placeholder for grouping separator. It may appear only in integer part. All commas except the last will be ignored.
	  ;Separates formats. It may appear only once in the pattern.
	  -Placeholder for negative prefix.
	  %Indicates that the value must be multiplied by 100 and shown as percentage.
	  ?Indicates that the value must be multiplied by 1000 and shown as per mille.
	
      
    
The pattern consists of one or two subpatterns, first is for
positive numbers and zero, second is for negative numbers.
Two subpatterns are delimited by semicolon.
If there is only one subpattern, - is prefixed to the positive subpattern.
Every subpattern consists of
optional prefix characters
followed by an integer part
followed by an optional fraction part
followed by an optional suffix characters.

Prefix and suffix characters are any Unicode characters except special formatting
characters described below, while integer and fraction part consist
only from that special formatting characters. (As an exception,
special characters may appear in prefix in suffix parts if enclosed in single quotes.

If fractional present, it starts from @.@ character, and only one @.@
may occur in the subformat. Thus it is easy to find where each part begins.

By default, the following characters are treated as special when used in the parts of the subpattern:

Note that character @¤@ have a special meahing in DecimalFormat of JDK 1.1, but not in XPATH.

The format pattern string may be in a localized notation.
The decimal_format may determine what characters have a special meaning in the pattern
(with the exception of the quote character, which is not localized).
The decimal_format must be a QName,
and a search will be performed for top-level <xsl:decimal-format> key
whose "key" attribute is equal to decimal_format;
all names will be expanded before the search.
It is an error if the stylesheet does not contain a declaration of the decimal-format with the specified expanded name.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'format-number',
'xpf_format_number',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'format-number',
  'numeric','',
'Number to format.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'format_pattern',
'format-number',
  'varchar','',
'Format pattern which must be applied to the number.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'decimal_format',
'format-number',
  'varchar','',
'Name of <xsl:decimal-format> element which must be used to parse format pattern.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_function_available',
'function-available',
'XPATH',
'Returns true if XPATH extension function with the requested name is defined in the XPATH Processor, otherwise returns false.',
'
The function returns true if XPATH Processor can execute
XPATH extension function with the name specified by
funname argument.
If such function is not defined, function-available returns false.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'function-available',
'xpf_function_available',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'funname',
'function-available',
  'varchar','',
'The name of XPATH extension function'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_generate_id',
'generate-id',
'XPATH',
'Returns a string that uniquely identifies the node.',
'
The function returns a string that uniquely identifies the first node in
the place argument node-set.
The unique identifier will consist of ASCII alphanumeric characters and will start with an alphabetic character.
Thus, the string is syntactically an XML name.
It always generates the same identifier for the same node.
It always generates different identifiers from different nodes.
This function is under no obligation to generate the same identifiers each time a document is transformed.
There is no guarantee that a generated unique identifier will be distinct from any unique IDs specified in the source document.

If the argument node-set is empty, the empty string is returned.

If the argument is omitted, it defaults to the context node.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'generate-id',
'xpf_generate_id',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'place',
'generate-id',
  'node set','',
'Node-set whose first node is used as a key to generate a resulting ID'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_id',
'id',
'XPATH',
'This XPATH 1.0 function is not implemented in the current version of Virtuoso.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'id',
'xpf_id',
'node-set',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'id_names',
'id',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_if',
'if',
'XPATH',
'If the boolean value is true then calculates one expression, otherwise calculates another expression.',
'
This function calculates the value of test argument.
If the value is true, the function calculates the then_branch
expression and returns its value.
If the value is false, the function calculates the else_branch
expression and returns its value.

Note that unlike other programming languages, else_branch
is required argument, not optional.

This function is used in the implementation of
"IF" control operator in XQUERY,
so you will probably use that operator in XQUERY expessions, not the function.
This function may be useful in XPATH expressions and in XSLT stylesheets.
It is not a part of library of standard XQUERY 1.0 functions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'if',
'xpf_if',
'any',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'test',
'if',
  'boolean','',
'Boolean value used to choose an expression to execute'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'then_branch',
'if',
  'any/variable','',
'Expression which is calculated if test argument is true'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'else_branch',
'if',
  'any/variable','',
'Expression which is calculated if test argument is false'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_key',
'key',
'XPATH',
'This XSLT 1.0 function is not implemented in the current version of Virtuoso.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'key',
'xpf_key',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'keyname',
'key',
  'varchar','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'keyvalues',
'key',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_lang',
'lang',
'XPATH',
'Returns true if the language of context node matches given language name.',
'
The lang function returns true or false depending on whether the language of
the context node as specified by xml:lang attributes is the same as or is a
sublanguage of the language specified by the argument string.
The language of the context node is determined by the value of the xml:lang
attribute on the context node, or,
if the context node has no xml:lang attribute,
by the value of the xml:lang attribute on the nearest ancestor of the context node that has an xml:lang attribute.
If there is no such attribute, then lang returns false.
If there is such an attribute, then lang returns true
if the attribute value is equal to the argument ignoring case,
or if there is some suffix starting with "-" such that the attribute value is equal to the argument ignoring that suffix of the attribute value and ignoring case.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'lang',
'xpf_lang',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'lang_name',
'lang',
  'varchar','',
'Name of the language'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_last',
'last',
'XPATH',
'Returns the context size from expression evaluation context.',
'
Context size is the number of nodes in the node-set where the context node comes from.
For the most popular case, when last() is used inside a predicate,
and the predicate relates to some axis of the path,
last() is the number of elements found by that axis at once;
in other words, the number of elements to be tested by predicate.

'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'last',
'xpf_last',
'number',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_local_name',
'local-name',
'XPATH',
'Returns the local part of the expanded name of the argument.',
'For given node, it returns local part of the node,
i.e. the name of given attribute or element with namespace prefix removed.
If the argument is node-set, first node of the node-set will be considered.
Empty string is returned if the argument is an empty node-set, a node without
name or if the argument is not a node.If the argument is omitted, context node is used instead as if it is a node-set of one element.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'local-name',
'xpf_local_name',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'node_obj',
'local-name',
  'any/variable','',
'Node whose name is to be returned',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_max',
'max',
'XPATH',
'Returns maximum value among all its arguments.',
'
The function returns the maximum value among all values in all its arguments,
For each node in every argument node-set, it converts the string-value of the node to a number.
If some arguments are not node-sets, they are converted to numbers.
The maximum number found is returned.

This function is not a part of XPATH 1.0 standard library.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'max',
'xpf_max',
'number',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'max',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'max',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'max',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'argN',
'max',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_min',
'min',
'XPATH',
'Returns minimum value among all its arguments.',
'
The function returns the minimum value among all values in all its arguments,
For each node in every argument node-set, it converts the string-value of the node to a number.
If some arguments are not node-sets, they are converted to numbers.
The minimum number found is returned.

This function is not a part of XPATH 1.0 standard library.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'min',
'xpf_min',
'number',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'min',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'min',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'min',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'argN',
'min',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_name',
'name',
'XPATH',
'Returns the expanded name of the argument.',
'For given node, it returns extended name of the node,
i.e. the name of given attribute or element with namespace prefix replaced
with namespace URI string.
If the argument is node-set, first node of the node-set will be considered.
Empty string is returned if the argument is an empty node-set, a node without
name or if the argument is not a node.If the argument is omitted, context node is used instead as if it is a node-set of one element.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'name',
'xpf_name',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'node_obj',
'name',
  'any/variable','',
'Node whose name is to be returned.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_namespace_uri',
'namespace-uri',
'XPATH',
'Returns the namespace URI of the extended name of the given node',
'If given argument is a node, the function returns the URI string of the
namespace specified in the name of node.
If the argument is node-set, first node of the node-set will be considered.
Empty string is returned if the argument is an empty node-set, a node without
name or if the argument is not a node.If the argument is omitted, context node is used instead as if it is a node-set of one element.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'namespace-uri',
'xpf_namespace_uri',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'node_obj',
'namespace-uri',
  'any/variable','',
'Node whose namespace URI is to be returned.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_normalize_space',
'normalize-space',
'XPATH',
'Returns the argument string with whitespace normalized.',
'
The function returns the argument string with whitespace
normalized by stripping leading and trailing whitespace and
replacing sequences of whitespace characters by a single space.
Whitespace characters are the same as those allowed by the S production in XML,
i.e. space (#x20), carriage returns (#xD), line feeds (#xA), and tabs (#x9).
If the argument is omitted, it defaults to the context node converted to a string,
in other words the string-value of the context node.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'normalize-space',
'xpf_normalize_space',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'strg',
'normalize-space',
  'varchar','',
'A string to be normalized',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_not',
'not',
'XPATH',
'Returns true if its argument is false, and false otherwise.',
'
This function returns true if its argument is false, and false otherwise.
If the argument is not a value of boolean type, it will be converted to boolean
first.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'not',
'xpf_not',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'obj',
'not',
  'boolean','',
'Boolean value'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_number',
'number',
'XPATH',
'Converts its argument to a number.',
'
The number function converts its argument to a number as follows:

A string that consists of decimal number and optional whitespaces is converted to the number recorded.
Any other string is converted to NaN ("not-a-number" value).
More precisely,
a string that consists of
optional whitespace followed by an optional plus or minus sign
followed by a Number followed by whitespace is converted to the
IEEE 754 number that is nearest
(according to the IEEE 754 round-to-nearest rule)
to the mathematical value represented by the string.
Note that it differs from XPATH 1.0 standard where plus sign is not allowed
before Number part of the string.

Boolean true is converted to 1; boolean false is converted to 0.

A node-set is first converted to a string as if by a call to the string function and then converted in the same way as a string argument.

An object of a type other than the four basic types is converted to a number in a way that is dependent on that type.

If the argument is omitted, it defaults to a node-set with the context node as its only member.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'number',
'xpf_number',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'obj',
'number',
  'any/variable','',
'Value to be converted to a number.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_or',
'or',
'XPATH',
'Returns true if a value of some argument is true, otherwise returns false.',
'
This function calculates values of its arguments, from left to right.
If the value of calculated parameter is true, the function returns true immediately,
without calculating of the remaining parameters.
If the list of arguments ends without any true value calculated, the function
returns false (Thus it returns true when called without arguments).

The name of this function is the same as name of "or" XPATH and XQUERY operator.
Thus it must be surronded bu double quotes when used in XPATH or XQUERY expressions.
Moreover, this function is not a part of XPATH standard, so it cannot be used if
portability is important.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'or',
'xpf_or',
'boolen',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val1',
'or',
  'boolean','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'val2',
'or',
  'boolean','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'or',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'valN',
'or',
  'boolean','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_position',
'position',
'XPATH',
'Returns the context position from expression evaluation context.',
'
Context position is the number of nodes in the node-set where the context node comes from.
For the most popular case, when position() is used inside a predicate,
and the predicate relates to some axis of the path,
position() is the number of calls of the predicate,
including the "current" call which is in progress when the
function is called.
Thus, context position cannot be greater than context size.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'position',
'xpf_position',
'number',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_round',
'round',
'XPATH',
'Returns the integer that is the nearests to the argument.',
'
The function returns the number that is closest to the argument and that is an integer.
If there are two such numbers, then the one that is closest to positive infinity is returned.
If the argument is NaN, then NaN is returned.
If the argument is positive infinity, then positive infinity is returned.
If the argument is negative infinity, then negative infinity is returned.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'round',
'xpf_round',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'num',
'round',
  'numeric','',
'The value to be rounded'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_serialize',
'serialize',
'XPATH',
'Serializes a value of its argument following the rules of the host RDBMS.',
'The serialize() function converts an object to a string as follows:An empty sequence is converted to an empty string.
A nonempty node-set is converted to a string by serialization of its first node.
A non-attribute XML entity is serialized as if it is serialized by http() BIF function.
In other words, the result is a plain text of XML syntax.
For an attribute XML entity, the value of attribute is returned.Values of other types are converted into strings as cast(... as varchar) do this in PL/SQL, exactly.If the argument is omitted, context node is converted instead as if it is a node-set of one element.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'serialize',
'xpf_serialize',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'obj',
'serialize',
  'any/variable','',
'Value to be converted into the string',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_some',
'some',
'XPATH',
'Returns true if at least one item of given sequence matches given criterion.',
'
The function creates a temporary local variable, whise name is specified by
varname argument.
Then, for every item of test_set sequence it
calculates the test_expn boolean expression
having set the created variable to that "current" item.
If the value of expression is true, the function immediately returns
true without processing the rest of test_set sequence.
If all items of the sequence are probed without getting true,
false is returned. (So if the sequence is empty, the function returns false).

In any case, temporary variable is destroyed on return.

This function is used in the implementation of
"SOME" logical operator in XQUERY, so you will probably use that operator
in XQUERY expessions, not the function.
This function may be useful in XPATH expressions and in XSLT stylesheets.
It is not a part of library of standard XQUERY 1.0 functions.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'some',
'xpf_some',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'varname',
'some',
  'varchar','',
'Name of temporary variable'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'test_set',
'some',
  'array','',
'Sequence of items; these items will be tested by test_expn'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'test_expn',
'some',
  'boolean','',
'Boolean expression which should be calculated for items of test_set.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_starts_with',
'starts-with',
'XPATH',
'Returns true if the first argument string starts with the second argument string, and otherwise returns false.',
'For two given strings, this function checks if the first string starts with characters of second string.
If any argument is not a string, it is converted to string using rules for string() XPATH function.
Thus if the second argument has no string value, the function returns true, because it will
be converted to an empty string first.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'starts-with',
'xpf_starts_with',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg',
'starts-with',
  'varchar','',
'String whose first characters must be compared'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'prefix',
'starts-with',
  'varchar','',
'String whose characters must be compared with first characters of strg'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_string',
'string',
'XPATH',
'Returns a string value of its argument.',
'The string() function converts an object to a string as follows:An empty sequence is converted to an empty string.
A nonempty node-set is converted to a string by returning the string-value of the first node in the node-set.
Note that the XPATH standard says that @first@ means @first in document order@ here, not @first value returned@.
For almost all queries, there is no difference between these two orders;
it may be important only for node-sets calculated by so-called reverse-order axis.
Moreover, the rure of standard is senseless if node-set contains nodes from more than one document.
That is why the standard is violated here, intentionally.
A nonempty sequence which is not a node-set is converted to a string by returning the string-value of the first node in the sequence.A NaN number is converted to the string @NaN@.Zero is converted to the string @0@.Positive infinity is converted to the string @Infinity@Negative infinity is converted to the string @-Infinity@Integer number is represented in decimal form with no decimal point and no leading zeros, preceded by a minus sign @-@ if the number is negative.
Non-integer number is represented in decimal form including a decimal point with at least one digit before the decimal point and at least one digit after the decimal point, preceded by a minus sign @-@ if the number is negative;
there must be no leading zeros before the decimal point apart possibly from the one required digit immediately before the decimal point;
beyond the one required digit after the decimal point there will be be as many, but only as many, more digits as are needed to uniquely distinguish the number from all other IEEE 754 numeric values.The boolean false value is converted to the string @false@. The boolean @true@ value is converted to the string @true@.An object of a type other than the listed above is converted to a string in a way that is dependent on that type.If the argument is omitted, context node is converted instead as if it is a node-set of one element.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string',
'xpf_string',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'obj',
'string',
  'any/variable','',
'Value to be converted into the string',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_string_length',
'string-length',
'XPATH',
'Returns the number of characters in the string.',
'
The string-length() XPATH function returns the number of characters in the string.
If the argument is omitted, it defaults to the context node converted to a string,
in other words the string-value of the context node.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'string-length',
'xpf_string_length',
'integer',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'strg',
'string-length',
  'varchar','',
'The string whose length must be measured.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_substring',
'substring',
'XPATH',
'Returns the substring of the first argument starting at the position specified in the second argument with length specified in the third argument.',
'
The substring() XPATH function returns the substring of the strg
starting at the position specified in start argument with length
specified in length argument.
If length is not specified,
it returns the substring starting at the position specified in the start argument
and continuing to the end of the string.

XPATH 1.0 defines that "each character in the string... is considered to have a numeric position: the position of the first character is 1, the position of the second character is 2 and so on.
This differs from Java and ECMAScript, in which the String.substring method treats the position of the first character as 0."
The returned substring contains those characters for which the position of the character is greater than or equal to start and,
if length is specified, less than the sum of start and length.

If start and/or length are not integers,
they are converted to integers following rules for round() XPATH function, before doing any other processing.
So they will be rounded first, and the sum of rounded values will be used as "end position"

If start is greater than or equal to the length of string, the empty string is returned.
If length is specified and the sum of start is less than or equal to 1, the empty string is returned, too.
Otherwise, the result string will contains some characters even if start is less than 1.

If length start is greater than or equal to the length of string, the empty string is returned.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'substring',
'xpf_substring',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg',
'substring',
  'varchar','',
'Source string. If the argument is not a string, it is converted to string first.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'start',
'substring',
  'integer','',
'Position of first character of the substring in the source string.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION, OPTIONAL) VALUES (

'length',
'substring',
  'integer','',
'Number of characters in the substring, if specified.',
1

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_substring_after',
'substring-after',
'XPATH',
'Returns the substring of the first argument string that follows the first occurrence of the second argument string in the first argument string.',
'
If the source_strg does not contain sub_strg,
the function returns the empty string.
Otherwise, it finds the first occurence of sub_strg and returns
the pert of source_strg that follows the occurence.
If any argument is not a string, it is converted to string using rules for string() XPATH function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'substring-after',
'xpf_substring_after',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'source_strg',
'substring-after',
  'varchar','',
'String where the search is performed'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sub_strg',
'substring-after',
  'varchar','',
'String to search'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_substring_before',
'substring-before',
'XPATH',
'Returns the substring of the first argument string that precedes the first occurrence of the second argument string in the first argument string.',
'
If the source_strg does not contain sub_strg,
the function returns the empty string.
Otherwise, it finds the first occurence of sub_strg and returns
the pert of source_strg that precedes the occurence.
If any argument is not a string, it is converted to string using rules for string() XPATH function.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'substring-before',
'xpf_substring_before',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'source_strg',
'substring-before',
  'varchar','',
'String where the search is performed'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'sub_strg',
'substring-before',
  'varchar','',
'String to search'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_sum',
'sum',
'XPATH',
'Returns sum of all its arguments',
'
The function returns the sum, for each node in every argument node-set, of the result of converting the string-values of the node to a number.
If some arguments are not node-sets, they are converted to numbers first.

Note that this definition differs from XPATH 1.0 standard, where sum() function
must have exactly one argument of type node-set.
It is important that other XPATH processors may quietly ignore all arguments except the first
one, producing unexpected results.

Being called without arguments, sum() will return zero.
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'sum',
'xpf_sum',
'number',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg1',
'sum',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'arg2',
'sum',
  'any/variable','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'...',
'sum',
  '','',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'argN',
'sum',
  'any/variable','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_system_property',
'system-property',
'XPATH',
'This XSLT 1.0 function is not implemented in the current version of Virtuoso.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'system-property',
'xpf_system_property',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'propname',
'system-property',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_text_contains',
'text_contains()',
'XPATH',
'Returns true if the text value of some node in the given node-set 
    contains the text matching the given free-text query, otherwise returns 
    false.',
'This function calculates text values of nodes from the 
    scope, and checks whether the current text value 
    contains any fragment that matches the query.  
    When the first match is found, the rest of the node-set is ignored the 
    boolean @true@ is returned.  If the node-set ends before any match is 
    found, @false@ is returned.The text_contains() function may be used only 
    in XPath expressions that are arguments of xcontains().  
    This restriction is for optimization purposes.  When Virtuoso executes an 
    SQL statement that uses xcontains(), it performs some 
    sophisticated free-text search, and it applies the XPath expression not to 
    all available documents but only to documents that satisfied the free-text 
    search criterion.  Moreover, the server uses the intermediate free-text 
    data to optimize the search inside a selected document.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'text_contains()',
'xpf_text_contains',
'boolean',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'scope',
'text_contains()',
  'node-set','',
'The node-set where the text search is performed.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'query',
'text_contains()',
  'varchar','',
'The text of the query.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_translate',
'translate',
'XPATH',
'Prforms char-by-char translation of given string',
'
The function returns the strg with occurrences of
characters in the search_list
replaced by the character at the corresponding position in the replace_list.
If there is a character in the search_list with no character at a
corresponding position in the replace_list
(because the replace_list is longer than the replace_list),
then occurrences of that character in strg string are removed.

If a character occurs more than once in the search_list,
then the first occurrence determines the replacement character.
If the replace_list is longer than the search_list,
then excess characters are ignored.

Two popular use cases for this function are case conversion and sorting with collation.
For "to-upper" case conversion,
the search_list consists of all lowercase characters of some language and
the replace_list consists of all uppercase characters of that language.
For "to-lower" case conversion, uppercase chars are in the search_list
and lowercase are in the replace_list.
For sorting with collation, the function must be used in "select" string expression
attribute of <xsl:sort> element; the search_list consists of all
characters reordered by collation and the replace_list consists of
corresponding characters from "collation string".
'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'translate',
'xpf_translate',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'strg',
'translate',
  'varchar','',
'String that must be translated.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'search_list',
'translate',
  'varchar','',
'String of characters that must be edited in the strg.'

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'replace_list',
'translate',
  'varchar','',
'String of characters that must be inserted in the strg.'

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_true',
'true',
'XPATH',
'Returns true',
'This function returns boolean contant "true"'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'true',
'xpf_true',
'boolean',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'xpf_unparsed_entity_uri',
'unparsed-entity-uri',
'XPATH',
'This XSLT 1.0 function is not implemented in the current version of Virtuoso.',
''

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'unparsed-entity-uri',
'xpf_unparsed_entity_uri',
'string',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'unparsed_entity_name',
'unparsed-entity-uri',
  'varchar','',
''

);

INSERT INTO DB.DBA.REFENTRY (ID, TITLE, CATEGORY, PURPOSE, DESCRIPTION) VALUES (

'fn_year',
'year',
'date',
'get year from a datetime',
'year takes a datetime and returns 
    an integer containing a number representing the year of the datetime.'

);

INSERT INTO DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID, RETURN_TYPE, RETURN_DESC) VALUES (

'year',
'fn_year',
'',
''

);

INSERT INTO DB.DBA.PARAMETER (PARAMETER, FUNCTIONNAME, TYPE, DIRECTION, DESCRIPTION) VALUES (

'dt',
'year',
  'datetime','in',
'A datetime.'

);
