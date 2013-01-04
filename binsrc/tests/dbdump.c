/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

/* #define DBDUMP_VERSION "0.974"  16-MAY-1997 */
/* #define DBDUMP_VERSION "0.975" 06-NOV-1997 */
/* #define DBDUMP_VERSION "0.976" 28-JAN-1998 */
/* #define DBDUMP_VERSION "0.977" 29-JAN-1998 */
/* #define DBDUMP_VERSION "0.978" 17-MAR-1998 */
/* #define DBDUMP_VERSION "0.979" 29-MAR-1998 */
#define DBDUMP_VERSION "0.980"	/* 22-JUN-1998 */

/*
   dbdump - Database Dump using ODBC API calls.

   Programmed in January 1997 - March 1998 by Antti Karttunen

   A generic ODBC tool for dumping out both the schema and
   the contents of the database, in the format appropriate
   for the later feeding to the same or another database
   with the ISQLO utility. That is, the format used is the series
   of SQL-statements CREATE TABLE, CREATE INDEX and INSERT
   terminated by a semicolon.

   Currently tested only with Kubl and Microsoft Access.
   To work with Kubl requires the KUBL ODBC driver version 0.92b
   or later.

   For more info compile and execute without arguments, and
   with the option -h also. (See the end of this module!)

   First version was 0.971

   CHANGES since 8-FEB-1997

   08-FEB-1997 AK   Added issuing of DROP TABLE and DROP INDEX commands
                    when needed.
                    Added select override feature.
                    Corrected the counting of tables in the main loop.
                    (Previously duplicate values were given).

   10-FEB-1997 AK   Added foreach blob output for LONG VARCHAR and
                    LONG VARBINARY columns. Currently allows only
                    one blob per row to be inserted in this way.
                    Version is now 0.972.

   20-FEB-1997 AK   Added checking for object_id index definitions.
                    Detects these only if the version 0.94b or newer
                    of WIODBC.DLL is used. (sqlext.c was respectively
                    changed. Uses own kludgous private index type 9
                    See define SQL_INDEX_OBJECT_ID later in this file.).

                    Made C-style string literal escaping a default.
                    Now you get with a single -e the same effect as
                    previously with double -ee.
                    Use option -n if you want to disable C-style escaping,
                    and use just standard SQL-escaping for single quotes.
                    Changed version number to 0.973

                    Changed after sleeping and reading the documentation
                    the definition of SQL_INDEX_OBJECT_ID to 8.
                    Now the ordinary SQL_INDEX_CLUSTERED, etc. values
                    are plussed to 8, so CLUSTERED and OBJECT_ID can
                    occur at the same time, which is needed when dumping
                    the tables that have real object_id indices.
                    An excerpt from KUBLMAN.DOC clarifies the decision:

   08-MAR-1997 AK   Added a piece of code into main for checking that
                    if the Kubl ODBC driver is greater than or equal
                    0.96, then the lengths of strings returned for bound
                    columns and strings got with SQLGetData are counted
                    without the terminating zero byte.


   Index options can be specified in a CREATE INDEX statement and in
   the PRIMARY KEY clause of a CREATE TABLE.
   The default for a primary key is to cluster it in its own cluster,
   to make it unique and not to make it an object ID.  Specifying
   CLUSTERED will cause the primary key to be clustered by value,
   i.e. to be non-contiguous, mixed with any other keys with values
   in the same range.  Specifying OBJECT_ID together with CLUSTERED
   makes this an object ID key. In this case it should have only one
   key part, the ID, whichever column that is.

   The default for a non-primary key is non-unique, clustered separate
   from other keys and non-object ID.  Specifying CLUSTERED will cluster
   the key by value, dispersing it among other keys with similar key part
   values.  The CLUSTERED OBJECT_ID combination makes this key an object
   ID key.  The UNIQUE option can be given to enforce uniqueness of key
   values.

   The primary key does not have an explicit name in the declaration. It
   is given the same name as the table and thus no other key can be named
   after the table.

   If an UNDER clause appears in CREATE TABLE there may not be a
   PRIMARY KEY since that will be inherited from the table given as
   super table in the UNDER clause.

Further, a note about Object IDs:

   An object ID is a special data type that encodes an identity based
   reference. The object ID is logically composed of the ID, a variable
   length binary string and of a 4 byte class specification that encodes
   the class of the referenced entity.
   Only the ID part of an object ID is meaningful in  comparing ID's.
   An object, i.e. row of any table can be located given its object ID
   by searching  the object ID index cluster which holds all 'object ID'
   keys.
   A key can have the object ID property.  If so, its first key part
   should be of the object ID type and should uniquely identify the
   object.
   Any object that belongs to a table which has an object ID key can be
   retrieved without specification of table by using the ID.

TO BE IMPLEMENTED, how to dump "the first key part that should be of the
object ID type", so that it will retain its object ID nature also when
later loaded through ISQL. (Should we use make_oid function?)
How to detect here that we have a DV_G_REF_CLASS, SQL_C_OID or whatever
object, instead of an ordinary string, as conversion to SQL_C_CHAR will
show it as any ordinary string? (with 4 byte class specification cut off)
(See dv_to_place function is cliuti.c to see how it is handled in that
 case.)

  16-MAY-1997  AK  Version changed to 0.974.
                   Added the definitions of Kubl Extension Option Values
                   SQL_MODE_READ_ONLY_PERMANENTLY, SQL_INDEX_OBJECT_ID
                   and SQL_INDEX_OBJECT_ID_STR into kublext(w).h
                   so removed from here.
                   Corrected also list_data_sources to return
                   correct string when compiled on Unix platforms.

                   Added n+1 SCP and UCP cast-macros make code compilable
                   in C++ as well.

  19-MAY-1997  AK  Some minor bugfixes.
  21-MAY-1997  AK  Now prints precision (in parenthesis) of VARCHAR
                   columns also.

  06-NOV-1997  AK  Version 0.975. Corrected the printing of UNDER
                   keyword in table definitions in case of subtables
                   with no additional columns to supertable.
                   (e.g. CREATE TABLE SUCCUBUS(UNDER INCUBUS); )

                   Replaced all calls to malloc and strdup with
                   our own calls chemalloc and chestrdup, so
                   checking that the memory is not exhausted.
                   With a lots of list linkages where only a
                   slight screw-up could produce circularities
                   or ever-growing list-structures, this is
                   not too prudent.

                   User can now specify multiple,
                   comma-and/or-space-separated tablename patterns
                   in tablename argument.
                   E.g. if the user has given
                          tablequalifier=a
                          tableowner=b
                          tablename=x%,p.q.z%,k.w,l..y
                   then following search patterns are effectively
                   given to SQLTables:
                          a.b.x%
                          p.q.z%
                          a.k.w
                          l..y
                   Of course current Kubl doesn't care a hitch about
                   those prefixes, tablequalifier and tableowner,
                   but some other datasource might care.

                   In case get_real_supertable detects a supertable
                   that has not matched to the patterns given by the
                   user, it is also loaded to all_tables_list.

                   However, tables included in this way do not appear
                   in the output, unless the user explicitly gives
                   T, I, and/or C options, Table definitions, Indices
                   and Contents respectively.

  15-NOV-1997  AK  More new stuff. Specifiers init=, unquoted_columns=
                   etc. Options -p and -+p for plain and prefixed
                   table names.

  28-JAN-1998  AK  Version 0.976.
                   Added -P option (Produce Primary Key by any means)
                   and for that, the new functions
                         get_table_bestrow_columns
                   and   find_first_index_like

                   Modified print_table_definition_banner respectively,
                   as well as added bestrow_columns element to
                   struct tabledeflist.

                   New option -N for "Nicer Output", e.g. with
                   indented table definitions, with one column per line,
                   etc.

                   Added also universal_transfer_flag
                   and for that added new experimental templates
                     transfer_html_page_string1 and
                     transfer_html_page_string2
                   to the end of this source file.
                   Modified output_html_page and output_html_file
                   respectively.

  29-JAN-1998  AK  Version 0.977.
                   Added new_name option, and for
                   substituting its !Q, !O and !N namepart-markers,
                   created function substitute_tablename_expr
                   and str_replace for its needs.

  15 - 17-MAR-1998 AK  Version 0.978.
                   Added DATADEST_TOKEN and TABLELIST_TOKEN
                   into output_html_page and the former also
                   to list_data_sources.

                   Lots of modifications to default template.
                   (E.g. the new optional Data Destination field
                    and its associated username and password fields
                    for the needs of direct table linking).

                   Added direct table linking with functions
                   link_remote_data_source, link_local_and_remote_table
                   do_generic_dest_statement
                   Modified print_table_definition_banner respectively.
                   (print_indexdeflist should be probably modified
                    in the same way).

                   Added last_SQL_state and last_SQL_message fields
                   to struct tabledeflist.

                   Added summary function check_for_failed_tables
                   (which looks for those two fields, possibly set in
                    print_table_definition_banner)

                   Option -a, surround column and index names with
                   doublequotes, implemented.

                   Added Javascript function
                   add_selected_items_to_the_text_elem
                   for the needs of TABLELIST_TOKEN

                   Also set_options_according_to_action
                   which is called on submit, as well as
                   when the SELECT/LIST OPCODE changes.

                   To be done: update the function
                    get_real_supertables to take heed of
                   the new Kubl Table Qualifier and Owner parts
                   (not anymore constant DB and DBA as before)
                   There's also a minor bug in SQLPrimaryKeys
                   in this respect.

                   There are many unnecessary commits
                   after read-operations from the Data Source.
                   They may get removed in the next release.


  29-MAR-1998 AK   Version 0.979.
                   Added the first version of function
                     compose_whole_tablename
                   and for its needs the elements
                     tl_qual_only, tl_own_only and tl_name_only
                   to struct tabledeflist.
                   Note how these new elements will make
                   the call to function divide_tablename_aux
                   unnecessary in many cases.

  22-JUN-1998 YR   Version 0.980
                   Did a quick fix to change behaviour of available
		   tables selection box which caused multiple
		   entries in the selected tables textarea.
		   Removed submit from datasource select.
		   Added some horizontal rules to improve grouping,
		   applied some other quick cosmetics,
		   moved the upper submit button to a more sensible(?)
		   place.
*/



#ifdef UNIX
#define DBDUMP_CGI_LOCATION "dbdump.cgi"	/* Assuming Apache HTTP server. */
#define TRANSFER_PROGRAM_CGI_LOCATION "isqlo.cgi"
#else /* Assuming it is for Microsoft IIS under Windows NT */
#define DBDUMP_CGI_LOCATION "/scripts/dbdump.exe"
#define TRANSFER_PROGRAM_CGI_LOCATION "isqlo.exe"
#endif

/* The above works with Microsoft IIS in Windows NT, when the executable
   dbdump.exe is copied to the directory \InetPub\scripts
   In Unix it should probably be something different.
   If running under Apache Web-server, build the executable with
   the name dbdump.cgi and then reference it with that name from the URL.
   Now assumes that isqlo.cgi or isqlo.exe is copied to the same
   directory as where this is invoked from in cgi-bin usage.
 */

#include <stdio.h>
#include <string.h>

#include <Dk.h>
#include <libutil.h>
#include "odbcinc.h"
#include "virtext.h"
#include "timeacct.h"


#define strncasecmp strnicmp
#define strcasecmp  stricmp

/* T should be a string constant, like "poisson"
   If the string S begins with it, then pointer to the next character
   is returned. Otherwise NULL is returned.
   Note how the order of testing is significant. You should first
   check for "foubar" before "fou".
 */
#define string_begins_with(S,T)\
 ( (!strncasecmp(SCP(S),SCP(T),(sizeof((T))-1) )) ? ((S)+(sizeof((T))-1))\
                                                  : NULL)

#ifndef SQL_NO_TOTAL
#define SQL_NO_TOTAL (-4)
#endif

#ifdef UNIX_UDBC
/* At least version 1.0 of libudbc doesn't seem to contain _UDBC_GetFunctions
   Let's define our own dummy macro that returns TRUE for all: */
#define SQLGetFunctions(HDBC_X, API_NUM_X, PTR_TO_FLAG)\
 (( *(PTR_TO_FLAG) = TRUE ), SQL_SUCCESS)
#endif


#define debug_fprintf if(dbdump_debug_level) fprintf
#define DEFAULT_DATASOURCE_IN_UNIX "localhost:1111"
#define DEFAULT_HTML_TEMPLATE_FILE "dbdump.htm"
#define DEFAULT_TRANSFER_TEMPLATE1 "kubltr1.htm"	/* Not actually anywhere */
#define DEFAULT_TRANSFER_TEMPLATE2 "kubltr2.htm"	/* used just as selectors */

#define DATASOURCE_TOKEN "INPUT_DATASOURCE"
#define DATADEST_TOKEN   "INPUT_DATADEST"
#define TABLELIST_TOKEN  "INPUT_TABLES"
#define DEFAULT_CONVERSIONS_TOKEN "DEFAULT_CONVERSIONS"
#define VERSION_TOKEN    "VERSION"


#define NO  !
#define NOT !
#define empty_stringp(X) (!*(X))

#define UCP(X) ((unsigned char *) ((X)))
#define SCP(X) ((char *) ((X)))
#define SWD(X) ((SWORD) (X))

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif

HDBC hdbc = SQL_NULL_HDBC;
HENV henv = SQL_NULL_HENV;
HSTMT stmt = SQL_NULL_HSTMT;

HDBC datadest_hdbc = SQL_NULL_HDBC;
HSTMT datadest_link_stmt = SQL_NULL_HSTMT;	/* For DB..vd_remote_table(?,?,?) */
HSTMT datadest_gen_stmt = SQL_NULL_HSTMT;	/* For other dest statements, issued with SQLExecDirect */

/* For error messages and like. Will be overwritten with argv[0] in
   the beginning of main. This initial value here serves for seeing
   the version of the program even with strings utility of Unix. */
char *progname = ("Kubl dbdump version " DBDUMP_VERSION);

/* The default values can be overridden in parse_url_query_string. */
char *username = "dba";
char *password = "dba";
char *dest_username = "dba";
char *dest_password = "dba";
char *datasource = NULL;	/* Was: "localhost:1111"; */
char *datadest = NULL;
char *tablequalifier = NULL, *tableowner = NULL;
char *tablename = NULL, *tabletype = NULL;
char *new_name = NULL;

int dbdump_debug_level = 0;
int kubl_mode = 0;		/* Currently affects only how TIMESTAMPS are handled. */
int never_escape_tablenames_in_select = 0;
/* The Access Driver returns varchar columns with the same length as
   what strlen would return for that string (provided that it doesn't
   contain any null bytes between), but the Kubl driver (at least until
   we change it, in case that it is a bug or misfeature) returns them
   with the length strlen(s)+1.
   Now, 8-MAR-1997 wiodbc.dll (version 0.96b) has been changed to
   conform with ODBC, i.e. it returns the length of strings without
   counting the trailing zero-byte.
 */
int varchar_cols_returned_with_length_plus = 0;
unsigned long int getdata_extensions;
int bind_blobs_flag = 0;	/* By default, don't do it. */

int flag_get_list_of_tables = 0;

int web_mode = 0;		/* Is this program used via Web? */
/* When print_blobs_flag is non-zero the blobs are printed out in full. */
int print_blobs_flag = 1;
/* These are swapped automatically in the beginning if we use an
   Old Kubl driver, version less than 0.92: */
int times_conform_to_odbc_flag = 1, times_to_strings_flag = 0;
int verbose_flag = 1;

char *default_insert_mode = "INTO";
char *web_content_type = "text/plain";
#define SELECT_DEFAULT "SELECT * FROM %s"
char *select_statement_template = SELECT_DEFAULT;
char *init_statement = NULL;
char *foreach_end_token = "END";
char *foreach_blob_token = "BLOB";

char *unquoted_columns = NULL;

int only_table_definitions_flag = 0;
int only_index_definitions_flag = 0;
int only_contents_flag = 0;
int auto_only_table_definitions_flag = 0;
int auto_only_index_definitions_flag = 0;
int auto_only_contents_flag = 0;
int dont_issue_drop_commands_flag = 0;

#define DEFAULT_MAXLINELEN "160"
#define DEFAULT_MAXHEXLEN  "64"

/* If set to zero by user, then these have no effect.
   First initialized to default values in the beginning of main
   then later might be overridden in parse_url_query_string: */
long maxlinelength_for_foreach = 0;	/* DEFAULT_MAXLINELEN; */
long maxhexlength_for_foreach = 0;	/* DEFAULT_MAXHEXLEN;  */

int nicer_output_flag = 0;

int use_foreach_for_blobs_flag = 1;
int use_backslash_escapes_in_strings_flag = 1;	/* Now on by default. */
/* Normally singlequotes are escaped as \47, unless this is specified
   as 1, in which case they are escaped by doubling the singlequote: */
int use_singlequote_escape = 0;

unsigned char prefix_with_flag = 0, surround_with_flag = 0;
/* Normally we use SQLColumns, unless this is on. */
int use_sql_describe_flag = 0;
int primary_key_by_all_means_flag = 0;
int kubl_default_conversions_flag = 0;

/* Transfer Schema and/or data to another DBMS, but let the User edit it
   before that, in HTML-form. */
int universal_transfer_flag = 0;
int vd_procedures_flag = 0;
int all_or_nothing_flag = 0;	/* If non-zero, then all linkages must succeed. */

int use_table_prefixes_flag = 1;
int use_table_prefixes_flag_given = 0;

int list_data_sources_flag = 0;
int dump_html_template_file_flag = 0;
int output_html_file (char *filename);

#define IF_ERR_GO(stmt, tag, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);  \
    goto tag; \
 }


#define MAX_COLS    313
#define DEFAULT_MAXCOLUMN_WIDTH   3500
#define CHARCOL_LEN 80+1
#define MAXCOLNAME  CHARCOL_LEN

int maxcolumn_width = DEFAULT_MAXCOLUMN_WIDTH;

#define TMP1_LEN ((MAX_COLS*(CHARCOL_LEN+1))+11)	/* Enough? 25677 bytes */
char tmp1[TMP1_LEN + 1];	/* A global string buffer used by many functions */



#define MAX_CONVERSIONS 25


/*
   If kubl_default_conversions_flag is specified (option -K),
   conv_types_table is set to the beginning of this table,
   otherwise it points by default to the end of these
   definitions.
   Because get_converted_type loops the table from the end to the
   beginning, user's mappings (which will be copied after these
   default ones) will override any mappings given here.
   E.g. user can give CONVSRC1=TINYINT & CONVDST1=TINYINT
   to apply otherwise the conversions given here, BUT still keeping
   TINYINT as TINYINT (for whatever perverted reason).
 */

char *kubl_default_conv_types[(2 * (MAX_CONVERSIONS + 1)) + 16] = {
/*         SRC TYPE  ->   KUBL TYPE */
				/*  0 */ "DUMMY", "RUMMY",
				/* Pair 0-1, not used. */
/*  2 */ "TIME", "DATE",
/*  4 */ "BIT", "SMALLINT",
					/*  6 */ "BIT VARYING", "INTEGER",
					/* Really? */
/*  8 */ "BINARY", "CHAR",
/* 10 */ "VARBINARY", "VARCHAR",
/* 12 */ "BIGINT", "CHAR",
					/* 14 */ "TINYINT", "SMALLINT",
					/* SEE THE NOTE BELOW ABOUT conv_types_table ! */
				/* 16 */ NULL, NULL
				/* The rest should be NULL's */
};

#define N_KUBL_DEFAULT_CONVERSIONS 7	/* This should be half of the index of the last non-NULL in above table */

/* Was like this:
char *conv_types_table[2*(MAX_CONVERSIONS+1)] = { NULL };
 */
/* Instead, is now defined like below, pointing either to the beginning
   or to the last used place (index 14) of the above table, depending
   from the flag kubl_default_conversions_flag */
char **conv_types_table = &kubl_default_conv_types[2 * N_KUBL_DEFAULT_CONVERSIONS];


int n_conv_types = 0;		/* This indexes the "table" conv_types_table above, is always even. Indices 0 & 1 are not used. */




typedef struct _out
{
  char *o_buffer;		/* Buffer for SQLBindCol */
  SQLLEN o_col_len;		/* The length of the column on current row */
} stmt_out_t;


SWORD n_out_cols;
stmt_out_t out_cols[MAX_COLS + 1];


struct tabledeflist
{
  struct tabledeflist *next;
  char *name;
  char *tl_qual_only;		/* These three new slots added 29.March 1998 */
  char *tl_own_only;		/* For storing the three parts of tablename */
  char *tl_name_only;		/* returned by SQLTables */
  char *columns;		/* A list of columns: colname1,colname2,etc in string */
  char *all_columns;		/* Similar as above, but including cols of supers */
  char *bestrow_columns;	/* Columns got with SQLSpecialColumns if -P used */
  char *primary_key_name;	/* The name of the primary key. */
  char *primary_key_def;	/* A list of colnames: colname1,colname3,etc. */
  char *primary_key_type;	/* Possible index type like CLUSTERED, etc. */
  char *super_table;		/* Name of the super table if applicable. (KUBL) */
  char *insert_mode;		/* One of the: "INTO", "SOFT" or "REPLACING" */

  char *last_SQL_state;		/* Used only with direct linkage. */
  char *last_SQL_message;	/* The last SQL_error_state and SQL_error_message from the datadest, if statement failed. */

/* Included as supertable of subtable specified, but not itself specified
   by the user? */
  int automatically_included;
  /* In principle the following should contain the count of blob columns
     in this table. Instead it nowadays contains zero or the SQL-type
     of the first blob column encountered: */
  int contains_blobs;
  struct coldeflist *col_defs;
  struct indexdeflist *index_defs;
  struct tabledeflist *super_tl;
  struct subtablelist *sub_tables;
};

struct indexdeflist
{
  struct indexdeflist *next;
  char *index_name;		/* This is also duplicated in index_def. */
/* index_def will contain "CREATE INDEX name ON table (col1,col2,...,coln"
   without the final ending parenthesis. */
  char *index_def;
};

struct coldeflist
{
  struct coldeflist *next;
  char *col_name;
  int col_type;
  SQLULEN col_precision;
  int col_scale;
  int col_nullable;
  int col_unquoted;
/* Currently the following is 1 if this column is the first blob
   (LONG VARCHAR or LONG VARBINARY) column of this table.
   Otherwise, if it's not blob, or it's not the first blob,
   it will be zero: */
  int col_is_nth_blob;
};

struct subtablelist
{
  struct subtablelist *next;
  struct tabledeflist *sub_table;
};

struct tabledeflist *all_tables_list;	/* Initialized in main. */


/* ==================================================================== */
/* Checked malloc and strdup, called chemalloc and chestrdup, in case   */
/* that our virtual memory is exhausted...                              */
/* From isqlodbc.c  --  Should really be in a common module.            */
/* ==================================================================== */


char *
my_strncat (char *string1, const char *string2, size_t count)
{
  size_t str1len = strlen (string1);
  return (strncat (string1, string2, (count - str1len)));
}


char *
chemalloc (size_t size, char *where)	/* where can be NULL or empty */
{
  FILE *error_stream;
  int i = 0;
  char *result;

  if (NO (result = (char *) malloc (size)))
    {
      char num[11];
      sprintf (num, "%ld", (long) size);
    print_again:
      if (0 == i)
	{
	  error_stream = stderr;
	}
      else if (1 == i)
	{
	  error_stream = stdout;
	}
      else
	{
	  exit (1);
	}

      putc ('\n', error_stream);
      fputs (progname, error_stream);
      if (where && *where)	/* Not null, not empty. */
	{
	  fputs (" (", error_stream);
	  fputs (where, error_stream);
	  fputs (")", error_stream);
	}
      fputs (": chemalloc failed when tried to allocate ", stderr);
      fflush (error_stream);
      fputs (num, error_stream);
      fputs (" bytes\n", stderr);
      fflush (error_stream);
      i++;
      goto print_again;
    }
  else
    {
      return (result);
    }
}


char *
chestrdup (char *str, char *where)	/* where can be NULL or empty */
{
  FILE *error_stream;
  int i = 0;
  char *res;

  if (NOT (res = strdup (str)))
    {
    print_again:
      if (0 == i)
	{
	  error_stream = stderr;
	}
      else if (1 == i)
	{
	  error_stream = stdout;
	}
      else
	{
	  exit (1);
	}
/* Don't use fprintf if memory is on the red! */
      putc ('\n', error_stream);
      fputs (progname, error_stream);
      if (where && *where)	/* Not null, not empty. */
	{
	  fputs (" (", error_stream);
	  fputs (where, error_stream);
	  fputs (")", error_stream);
	}
      fputs (": chestrdup failed when tried to make a copy of: ", stderr);
      fflush (error_stream);
      fputs (str, error_stream);
      putc ('\n', error_stream);
      fflush (error_stream);
      i++;
      goto print_again;
    }
  else
    {
      return (res);
    }
}


/* Few macros for strncasestr, which is soon used by str_replace */

/* This returns true for range '\100' - '\177'
   (from '@' via 'A' and 'Z' to 'a' and 'z' and DEL)
   and for range '\300' - '\377' (from ISO8859.1 Agrave to ydieresis)
   In this latter range are most of the accented vowels and some consonants
   of the ISO8859.1, and for the most the upper-lower-relation holds.
 */

#define is_a_letter(C)        ((C) & 0100)	/* Bit-6 (64.) on */
/* This returns only true for 8-bit letters in range \300 - \377: */
#define is_a_iso_letter(C)    (((C) & 0300) == 0300)	/* Bit-7 and Bit-6 on */
#define is_a_lc_letter(C) (((C) & 0140) == 0140)	/* Both bits on */
#define is_a_uc_letter(C) (((C) & 0140) == 0100)	/* Bit-6 on, bit-5 off */
#define iso_to_lower(C) ((unsigned char)(((unsigned char)(C)) | 040))
/* Set bit-5 (32.) on to get a lowercase variant of the letter. */

/* Note that because these macros consider also the characters like
   @, [, \, ], and ^ to be 'letters', they will match against characters
   `, {, |, }, and ~ respectively, which is just all right, because
   in some older implementations of European character sets those
   characters mark the uppercase and lowercase variants of certain
   diacritic letters. (Well, I don't know whether it is always all right
   in applications like this..., well, but currently we just replace
   !Q, !O or !N, (or !q.!o.!n) nothing more).
 */



/* Returns pointer to that point of string1, where the first instance
   of string2 is found. Case doesn't matter. Checks max. maxbytes
   characters from the beginning of string1.
   Probably not the most optimal algorithm, but good enough for me.
   (Cleaned from nc_strstr function of string.c module.)
   If string1 is null terminated string (SQL_NTS) then maxbytes should
   be its length got with strlen(string1).
   Before the loop begins the length of string2 minus one is subtracted
   from it, so that string1 will not be unnecessarily scanned past the
   point where string2 cannot anymore occur as its tail.
 */

#define strncasestr dbdump_strncasestr

unsigned char *
strncasestr (unsigned char *string1, unsigned char *string2, size_t maxbytes)
{
  unsigned char first, d, e;
  unsigned char *s1, *s2;
  size_t str2len = strlen ((char *) string2);


  if (!str2len)
    {
      return (string1);
    }				/* If string2 is an empty string "" */

  first = iso_to_lower (*string2);

  for (maxbytes -= (str2len - 1); (maxbytes > 0) && (d = *string1); maxbytes--)
    {
      if (is_a_uc_letter (d))
	{
	  d = iso_to_lower (d);
	}

      if (d == first)
	{
/* e have to be fetched and checked before d in and-clause, otherwise
   we won't find substrings from the end of string1: */
	  for (s1 = string1, s2 = string2; ((e = *++s2) && (d = *++s1));)
	    {
	      if (is_a_uc_letter (d))
		{
		  d = iso_to_lower (d);
		}
	      if (is_a_uc_letter (e))
		{
		  e = iso_to_lower (e);
		}
	      if (d != e)
		{
		  break;
		}		/* Found first differing character. */
	    }
/* If we exited the above loop with value of e as zero, then we have
   found that the whole string2 is contained in string1: */
	  if (!e)
	    {
	      return (string1);
	    }
/* But if string1 was finished (although s2 still wasn't) then we return
   false, as the 'tail of string1' is now shorter than string2, so it's
   not anymore possible that string2 would fit into it:
   (Actually this case is not anymore possible because of new maxbytes
    counting done in the outer loop.)
 */
	  if (!d)
	    {
	      return (0);
	    }
/* Otherwise, it didn't match this time, let's try to find the next potential
   point of string1 where it would match: */
	}
      string1++;
    }

  return (0);			/* Return false as we didn't find it. */
}



/*
   str_replace(string_exp1, from_exp, to_exp, max_n_replacements)

   Replace every from_exp from string_exp1 with to_exp.
   If the optional fourth argument is non-zero, then replace
   at maximum that many occurrences.

   Modified from bif_replace in sqlbif.c
   (by AK 29. Nov 1997 & 29. Jan 1998)
   In contrast to that, this one does case-insensitive comparison.
   Also, if to_str is NULL, then the effect is same as it would be "",
   i.e. an empty string, so that each occurrence of from_str is just
   simply deleted.
 */
unsigned char *
str_replace (unsigned char *src_str, unsigned char *from_str, unsigned char *to_str, int only_n)
{
  char *me = "str_replace";
  int only_n_flag = (only_n);
  size_t src_len, from_len, to_len, difference, occurrences = 0;
  size_t res_len, non_changed_len, n_changes;
  unsigned char *ptr, *prevptr, *res_ptr;
  unsigned char *res;

  if ((NULL == src_str) || (NULL == from_str))
    {
      return (NULL);
    }

  if (NULL == to_str)
    {
      to_str = UCP ("");
    }

  src_len = strlen (SCP (src_str));
  from_len = strlen (SCP (from_str));
  to_len = strlen (SCP (to_str));
  difference = (to_len - from_len);	/* How many bytes longer? */

/* Don't know actually what we should do when from is an empty string.
   Now just return the string_exp1 back as it is. */
  if (0 == from_len)
    {
      return (UCP (chestrdup (SCP (src_str), me)));
    }
/* if(only_n_flag && (0 == only_n)) { return(box_copy(src_str)); } */

  if (0 != difference)		/* The resulting string would be longer or shorter. */
    {
      /* So we have to count the number of occurrences of from_str in src_src */
      occurrences = 0;
      ptr = src_str;
      while ((!only_n_flag || (occurrences < only_n)) && (ptr = strncasestr (ptr, from_str, (src_len - (ptr - src_str)))))
	{
	  occurrences++;
	  ptr++;
	}
      difference *= occurrences;	/* Now the difference in final length. */
      if (0 == occurrences)
	{
	  return (UCP (chestrdup (SCP (src_str), me)));
	}			/* Nothing to replace. */
    }

/* If from_str and to_str are identical strings? Not really necessary.
  if(((0 == difference) && (0 == strcmp(from_str,to_str))))
   {
     return(box_copy(src_str));
   }
*/

  res_len = (src_len + difference);	/* Difference can be -, 0, + */

/*
  printf("%s: Allocating res of len %d for src_len %d, with from_len %d,"
         " to_len %d, occurrences %d, difference %d, only_n=%d,%d\n",
          me,res_len,src_len,from_len,to_len,occurrences,difference,
          only_n_flag,only_n); fflush(stdout);
 */

  /* +1 for the final zero. */
  res = UCP (chemalloc ((res_len + 1), me));
  res_ptr = res;
  prevptr = src_str;
  n_changes = 0;
  while ((!only_n_flag || (n_changes < only_n)) && (ptr = strncasestr (prevptr, from_str, (src_len - (prevptr - src_str)))))
    {
      if (0 != (non_changed_len = (ptr - prevptr)))	/* Something stays same? */
	{
	  memcpy (res_ptr, prevptr, non_changed_len);
	  res_ptr += non_changed_len;
	}
      if (0 != to_len)		/* When to_len is zero, we actually delete items. */
	{
	  memcpy (res_ptr, to_str, to_len);
	  res_ptr += to_len;
	}
      prevptr = ptr + from_len;
      ptr++;
      n_changes++;
    }
  /* Copy the last remaining piece if necessary. */
  non_changed_len = (src_len - (prevptr - src_str));	/* (src_str+src_len)-prevptr */
  if (0 != non_changed_len)
    {
      memcpy (res_ptr, prevptr, non_changed_len);
      res_ptr += non_changed_len;
    }
  *res_ptr = '\0';		/* res [res_len] = 0; */
  return res;
}


/* =============================================================== */

UCHAR *substitute_tablename_expr (UCHAR * tablename_expr, UCHAR * whole_tablename_org);

char *
escapify (char *resbuf, char *name)
{
  char *retptr = resbuf;

  if (!prefix_with_flag && !surround_with_flag)
    {
      return (name);
    }

  if (prefix_with_flag)		/* For -b option */
    {
      *retptr++ = prefix_with_flag;
    }

  if (surround_with_flag)	/* For -a option */
    {
      *retptr++ = surround_with_flag;
    }

  strcpy (retptr, name);

  if (surround_with_flag)
    {
      retptr += strlen (retptr);
      *retptr++ = surround_with_flag;
      *retptr = '\0';
    }

  return (resbuf);
}

/* Note how -a option (surround_with_flag being doublequote)
   doesn't have any effect here.
   Instead, user has to specify new_name explicitly as "!Q"."!O"."!N"
   in Unix shell this can be given as new_name='"!Q"."!O"."!N"' and
   in Windows as new_name="""!Q"""."""!O"""."""!N"""
   (i.e. by tripling each doublequote).
 */
char *
escapify_and_form_dest_name (char *resbuf, int resbuf_maxsize, char *whole_table_name)
{
  char *resptr = resbuf;

  if (!prefix_with_flag && !new_name)
    {
      return (whole_table_name);
    }

  if (resbuf_maxsize >= 0)
    {
      *resbuf = '\0';
    }
  if (prefix_with_flag)
    {
      if (resbuf_maxsize >= 1)
	{
	  *resptr++ = '\\';
	}
    }
  if (new_name)
    {
      whole_table_name = SCP (substitute_tablename_expr (UCP (new_name), UCP (whole_table_name)));
    }

  strncpy (resptr, whole_table_name, (resbuf_maxsize - (resptr - resbuf)));
  *(resptr + (resbuf_maxsize - (resptr - resbuf))) = '\0';
  if (new_name)
    {
      free (whole_table_name);
    }				/* malloced by subst... */
  return (resbuf);
}



char *
get_converted_type (char *type)
{
  int i;

  /* Loop from the end to the beginning, so that it is possible
     for later conversion definitions to override the previous ones.
     (indices 0 and 1 of conv_types_table are not used. */
  for (i = (2 * n_conv_types); i; i -= 2)
    {
      /* If the destination is NULL, then ignore this conversion: */
      if (conv_types_table[i] && conv_types_table[i + 1] && !strcasecmp (conv_types_table[i], type))
	{
	  return (conv_types_table[i + 1]);
	}
    }

  return (type);		/* If not found from the table return back as it is. */
}


int
length_of_tablelist (struct tabledeflist *tl)
{
  int len = 0;

  while (tl)
    {
      len++;
      tl = tl->next;
    }

  return (len);
}


struct tabledeflist *
find_tabledef (char *table_name, struct tabledeflist *tl)
{
  while (tl)
    {
      if (0 == strcmp (table_name, tl->name))
	{
	  return (tl);
	}
      tl = tl->next;
    }

  return (NULL);
}

struct tabledeflist *
get_ancestor (struct tabledeflist *tl)
{
  if (tl->super_tl)
    {
      return (get_ancestor (tl->super_tl));
    }
  else
    {
      return (tl);
    }
}


int
index_is_found_from_indexdeflist (char *index_name, struct indexdeflist *il)
{
  while (il)
    {
      if (0 == strcmp (index_name, il->index_name))
	{
	  return (1);
	}
      il = il->next;
    }

  return (0);
}


struct indexdeflist *
find_first_index_like (struct indexdeflist *il, char *like_what)
{
  while (il)
    {
      if (!strncmp (il->index_def, like_what, strlen (like_what)))
	{
	  return (il);
	}
      il = il->next;
    }

  return (il);			/* That is, a NULL */
}

/* Returns 1 if table node tl has a super table definition, and index
   index_name has been defined in it, either as a primary key
   or some other kind of index.
   Calls recursively itself, in case that the table has not just
   a super table, but that in turn has another super table definition,
   and so on.
   Otherwise returns zero.
   Of course all the primary keys and all the indices of all the tables
   must have been read in already, so that means that we cannot use
   this function before we are ready to print out the index definitions.
   (Because SQLTables returns tables in alphabetical, not in historical
   order, subtables can be fetched before their parents.)
 */
int
index_has_been_defined_for_supertable (char *index_name, struct tabledeflist *tl)
{
  struct tabledeflist *suptl;

  if (tl->super_table == NULL)
    {
      return (0);
    }
  else
    {
      suptl = tl->super_tl;
      /* Was: find_tabledef(tl->super_table,all_tables_list); */
      if (suptl == NULL)
	{
/* E.g. this might happen if the user dumps selectively some tables
   with a wildcard expression, and some parent table(s) are left out.
   (NOT ANYMORE BECAUSE OF THE NEW CODE IN get_real_supertables)
 */
	  fprintf (stdout,
	      "-- Warning from index_has_been_defined_for_supertable(%s,%s):\n"
	      "-- Can't find the super table '%s' from the table definitions.\n", index_name, tl->name, tl->super_table);
	  return (0);
	}
      /* Either it is the primary key name of ancestor table? */
      if (suptl->primary_key_name && !strcmp (index_name, suptl->primary_key_name))
	{
	  return (1);
	}
      /* Or it is one of its indices? */
      if (index_is_found_from_indexdeflist (index_name, suptl->index_defs))
	{
	  return (1);
	}
      else			/* Otherwise, check same from the grandparent: */
	{
	  return (index_has_been_defined_for_supertable (index_name, suptl));
	}
    }
}

/* Concatenate subtable subtl at the end of sub_tables list of tl.
   A little bit slower than inserting them to the front, but this
   way we keep the original ascending alphabetical order in which
   SQLTables returns the table names.
 */
int
add_to_subtables (struct tabledeflist *subtl, struct tabledeflist *tl)
{
  struct subtablelist *sl, *newnode;
  int count = 1;
  char where[CHARCOL_LEN + 80];

  sprintf (where, "add_to_subtables(\"%s\",\"%s\")", (subtl->name ? subtl->name : "NULL"), (tl->name ? tl->name : "NULL"));

  /* First create a new node with a name subname. */
  newnode = ((struct subtablelist *) chemalloc (sizeof (struct subtablelist), where));
  newnode->next = NULL;
  newnode->sub_table = subtl;

  /* And then figure out where to put it. */
  if (NULL == (sl = tl->sub_tables))	/* First one? */
    {
      tl->sub_tables = newnode;
    }
  else
    {
      /* Find the last node of the sub_tables list: */
      for (; count++, sl->next; sl = sl->next);
      sl->next = newnode;	/* And concatenate the new node after that. */
    }
  return (count);
}

/* Make links between super tables.and their subtables. */
int
reorder_subtables (struct tabledeflist *tl)
{
  struct tabledeflist *supertl;

  while (tl)
    {
      if (tl->super_table)	/* It has a super table so it is a subtable */
	{
	  supertl = find_tabledef (tl->super_table, all_tables_list);
	  if (supertl == NULL)
	    {
/* E.g. this might happen if the user dumps selectively some tables
   with a wildcard expression, and some parent table(s) are left out.
   (NOT ANYMORE BECAUSE OF THE NEW CODE IN get_real_supertables)
 */
	      fprintf (stdout,
		  "-- Warning from reorder_subtables(%s):\n"
		  "-- Can't find the super table '%s' from the table definitions.\n", tl->name, tl->super_table);
	    }
	  else
	    {
	      tl->super_tl = supertl;	/* Link the table to its supertable */
	      add_to_subtables (tl, supertl);	/* And vice versa */
	    }
	}
      tl = tl->next;
    }

  return (1);
}


size_t
construct_where_clause_aux (char *resbuf, char *father, char *child, char *primcols, char *termstr,	/* A right parenthesis */
    size_t maxlength)
{
  size_t tmplen;
  char *ptr, *oldptr, *endptr;
  char tmpbuf[5 * CHARCOL_LEN + 2];
  char temp1[CHARCOL_LEN + 10], temp2[CHARCOL_LEN + 10];

  endptr = resbuf;
  oldptr = primcols;
  while (oldptr)		/* Loop over the comma-separated column names of pk */
    {
      ptr = strchr (oldptr, ',');	/* The next comma. */
      if (ptr)
	{
	  *ptr = '\0';
	}			/* Overwrite temporarily with zero. */
      sprintf (tmpbuf, "%s.%s = %s.%s%s",
	  escapify (temp1, child), oldptr, escapify (temp2, father), oldptr, (ptr ? " and " : termstr));
      if (ptr)
	{
	  *ptr = ',';
	  oldptr = ptr + 1;
	}			/* Restore the comma. */
      else
	{
	  oldptr = NULL;
	}			/* Will stop at the next time on loop top */
      tmplen = strlen (tmpbuf);
      if (tmplen > maxlength)
	{
	  return (0);
	}
      else
	{
	  maxlength -= tmplen;
	  strcpy (endptr, tmpbuf);
	  endptr += tmplen;
	}
    }

  return (endptr - resbuf);	/* Return the length of all stuff collected */
}


size_t
construct_where_clause_for_a_subtable (char *resbuf,
    struct tabledeflist *father, struct tabledeflist *child, char *primcols, size_t maxlength)
{
  size_t tmplen;
  char *endptr = resbuf;
  char tmpbuf[15 * CHARCOL_LEN + 2];
  char temp[CHARCOL_LEN + 10];

  sprintf (tmpbuf, " NOT EXISTS (select %s from %s where ", primcols, escapify (temp, child->name));
  tmplen = strlen (tmpbuf);
  if (tmplen > maxlength)
    {
      return (0);
    }
  else
    {
      maxlength -= tmplen;
      strcpy (endptr, tmpbuf);
      endptr += tmplen;
    }

  tmplen = construct_where_clause_aux (endptr, father->name, child->name, primcols, ")", maxlength);
  if (0 == tmplen)
    {
      return (0);
    }
  maxlength -= tmplen;
  endptr += tmplen;

  return (endptr - resbuf);	/* Return the length of all stuff collected */
}

#define WHERE_WHERE " WHERE"
#define WHERE_AND   " AND"

size_t
make_where_clause_for_table_with_children (char *text, struct tabledeflist *tl, size_t maxlength)
{
  struct subtablelist *sl;
  char *endptr;
  size_t tmplen;
  char *primcols = get_ancestor (tl)->primary_key_def;

  endptr = (text + strlen (text));
  tmplen = (sizeof (WHERE_WHERE) - 1);
  if (maxlength < tmplen)
    {
      return (0);
    }
  strcpy (endptr, WHERE_WHERE);
  maxlength -= tmplen;
  endptr += tmplen;

  sl = tl->sub_tables;
  while (sl)
    {
      tmplen = construct_where_clause_for_a_subtable (endptr, tl, sl->sub_table, primcols, maxlength);
      if (0 == tmplen)
	{
	  return (0);
	}
      maxlength -= tmplen;
      endptr += tmplen;
      if ((sl = sl->next) != NULL)
	{
	  tmplen = (sizeof (WHERE_AND) - 1);
	  if (maxlength < tmplen)
	    {
	      return (0);
	    }
	  strcpy (endptr, WHERE_AND);
	  maxlength -= tmplen;
	  endptr += tmplen;
	}
    }

  return (endptr - text);
}


char SQL_error_state[15] = { 'O', 'K', '\0' };
char SQL_error_message[1000] = { 'O', 'K', '\0' };

void
print_error (HENV e1, HDBC e2, HSTMT e3)
{
  short len;
  SQLError (e1, e2, e3, (UCHAR *) SQL_error_state, NULL,
      (UCHAR *) & SQL_error_message, sizeof (SQL_error_message), (SWORD *) & len);
  printf ("\n-- *** Error %s: %s\n", SQL_error_state, SQL_error_message);
  if (0 == strcmp (SQL_error_state, "08S01"))
    exit (2);
}

/* SQL data type codes.
   These were taken from ../sqlcli.h and ../sqlcli2.h header files.
   Added by AK 3-JAN-1997.
 */
char *
get_sql_type_title (int type)
{
  switch (type)
    {
#ifdef SQL_CHAR
    case SQL_CHAR:
      {
	return ("CHAR");
      }				/*  1 */
#endif
#ifdef SQL_NUMERIC
    case SQL_NUMERIC:
      {
	return ("NUMERIC");
      }				/*  2 */
#endif
#ifdef SQL_DECIMAL
    case SQL_DECIMAL:
      {
	return ("DECIMAL");
      }				/*  3 */
#endif
#ifdef SQL_INTEGER
    case SQL_INTEGER:
      {
	return ("INTEGER");
      }				/*  4 */
#endif
#ifdef SQL_SMALLINT
    case SQL_SMALLINT:
      {
	return ("SMALLINT");
      }				/*  5 */
#endif
#ifdef SQL_FLOAT
    case SQL_FLOAT:
      {
	return ("FLOAT");
      }				/*  6 */
#endif
#ifdef SQL_REAL
    case SQL_REAL:
      {
	return ("REAL");
      }				/*  7 */
#endif
#ifdef SQL_DOUBLE
    case SQL_DOUBLE:
      {
	return ("DOUBLE PRECISION");
      }				/*  8 */
#endif
#ifdef SQL_DATETIME
    case SQL_DATETIME:
      {
	return ("DATE");
      }				/*  9 */
#endif
#if defined  (SQL_DATE) && NOT defined (SQL_DATETIME)
    case SQL_DATE:
      {
	return ("DATE");
      }				/* 9 in sqlext.h */
#endif
#ifdef SQL_TIME
    case SQL_TIME:
      {
	return ("TIME");
      }				/* 10 in sqlext.h */
#endif
#if defined (SQL_INTERVAL) && ((NOT defined (SQL_TIME)) || (SQL_INTERVAL != SQL_TIME))
    case SQL_INTERVAL:
      {
	return ("TIME");
      }				/* 10 */
#endif
#ifdef SQL_TIMESTAMP
    case SQL_TIMESTAMP:
      {
	return ("TIMESTAMP");
      }				/* 11 */
#endif
#ifdef SQL_VARCHAR
    case SQL_VARCHAR:
      {
	return ("VARCHAR");
      }				/* 12 */
#endif
#ifdef SQL_BIT
    case SQL_BIT:
      {
	return ("BIT");
      }				/* 14 */
#endif
#ifdef SQL_BIT_VARYING
    case SQL_BIT_VARYING:
      {
	return ("BIT VARYING");
      }				/* 15 */
#endif
#ifdef SQL_LONGVARCHAR
    case SQL_LONGVARCHAR:
      {
	return ("LONG VARCHAR");
      }				/* (-1) */
#endif
#ifdef SQL_BINARY
    case SQL_BINARY:
      {
	return ("BINARY");
      }				/* (-2) in sqlext.h */
#endif
#ifdef SQL_VARBINARY
    case SQL_VARBINARY:
      {
	return ("VARBINARY");
      }				/* (-3) in sqlext.h */
#endif
#ifdef SQL_LONGVARBINARY
    case SQL_LONGVARBINARY:
      {
	return ("LONG VARBINARY");
      }				/* (-4) */
#endif
#ifdef SQL_BIGINT
    case SQL_BIGINT:
      {
	return ("BIGINT");
      }				/* (-5) in sqlext.h */
#endif
#ifdef SQL_TINYINT
    case SQL_TINYINT:
      {
	return ("TINYINT");
      }				/* (-6) in sqlext.h */
#endif

    default:
      {
	char tmp[33];
	sprintf (tmp, "UNK_TYPE:%d", type);
	return (chestrdup (tmp, "get_sql_type_title"));
      }
    }				/* switch */
}

/* Makes a new, safe copy of the stuff it returns as a result,
   if it is necessary. */
char *
get_sql_col_type_def (int type, SQLULEN precision, int scale, int nullable)
{
  char result[181], more[181];
  char *type_string;
  if (kubl_default_conversions_flag && (SQL_DECIMAL == type || SQL_NUMERIC == type))
    {
      if (scale == 0)
	type = SQL_INTEGER;
      else
	type = SQL_DOUBLE;
    }
  type_string = get_converted_type (get_sql_type_title (type));
  more[0] = '\0';

  if ((type == SQL_CHAR) || (type == SQL_VARCHAR))
    {
      sprintf (more, "(%ld)", precision);
    }
  if (nullable == SQL_NO_NULLS)
    {
      strcat (more, " NOT NULL");
    }

  if (*more)			/* Something to add? */
    {
      strcpy (result, type_string);
      strcat (result, more);
      return (chestrdup (result, "get_sql_col_type_def"));
    }
  else
    {
      return (type_string);
    }
}

/* ================================================================== */

/*

divide_tablename
Taken from isqlodbc.c, should be really in a common module.
See also the notes regarding the next function new_whole_tablename

This should divide tablename (in case that tablequalifier and tableowner
are NULL, i.e. not defined explicitly elsewhere) in the following manner:

tablequalifier = NULL, tableowner = NULL, tablename = qual.own.name
 -> tablequalifier = qual, tableowner = own, tablename = name

tablename = qual..name
 -> tablequalifier = qual, tableowner = NULL, tablename = name

tablename = ..  or tablename = .
 -> tablequalifier = NULL, tableowner = NULL, tablename = NULL

tablename = fool.baal.
-> tablequalifier = fool, tableowner = baal, tablename = NULL

tablename = fool.baal
-> tablequalifier = NULL, tableowner = fool, tablename = baal

tablename = qual..  -> tablequalifier = qual (others NULL)

tablename = .own.  (or own.) -> tableowner = own (others NULL)

tablename = ..name (or .name) -> tablename = name (others NULL)

Returns the new tablename.

If the short integer pointers cbTableName, cbTableQualifier and
cbTableOwner are not NULL, then store the length of corresponding
parts there, and leave the original tablename buffer intact.
If they are NULL, then overwrite the delimiting dots with null bytes.
 */

UCHAR *
divide_tablename_aux (UCHAR * tablename, SWORD * cbTableName,
    UCHAR ** p_tablequalifier, SWORD * cbTableQualifier, UCHAR ** p_tableowner, SWORD * cbTableOwner)
{
  unsigned char *ptr, *ptr2;
  unsigned short int piece1len = 0;

  if (tablename && (ptr = UCP (strchr (SCP (tablename), '.'))))
    {
      if (ptr > (tablename))	/* Period not in the beginning of tablename? */
	{
	  *p_tablequalifier = tablename;
	}
      piece1len = SWD (ptr - tablename);
      if (cbTableQualifier)
	{
	  *cbTableQualifier = piece1len;
	}
      else
	{
	  *ptr = '\0';
	}

      if ((ptr2 = (UCHAR *) strchr ((char *) (ptr + 1), '.')) != NULL)
	{
	  if (ptr2 > (ptr + 1))	/* Second period not right after first one? */
	    {
	      *p_tableowner = ptr + 1;
	    }

	  /* If pattern is like Q..N then p_tableowner is not set
	     (should be NULL presumably when called), but
	     *cbTableOwner is still set to 0 if it's not NULL */

	  if (cbTableOwner)
	    {
	      *cbTableOwner = SWD (ptr2 - (ptr + 1));
	    }
	  else
	    {
	      *ptr2 = '\0';
	    }

	  if (*(ptr2 + 1))
	    {
	      tablename = (ptr2 + 1);
	    }			/* Something following? */
	  else
	    {
	      tablename = NULL;
	    }			/* If nothing after second period. */
	}
      else			/* If only one period found. */
	{
	  *p_tableowner = *p_tablequalifier;
	  *p_tablequalifier = NULL;
	  if (cbTableOwner)
	    {
	      *cbTableOwner = piece1len;
	    }
	  if (cbTableQualifier)
	    {
	      *cbTableQualifier = 0;
	    }
	  /* Check that it's not dangling in the end: */
	  if (*(ptr + 1))
	    {
	      tablename = ptr + 1;
	    }
	  else
	    {
	      tablename = NULL;
	    }
	}
    }
  else				/* No periods found. Set the Qual and Owner count pointers to zero */
    {
      if (cbTableQualifier)
	{
	  *cbTableQualifier = 0;
	}
      if (cbTableOwner)
	{
	  *cbTableOwner = 0;
	}
    }

  if (cbTableName)
    {
      *cbTableName = SWD (tablename ? strlen (SCP (tablename)) : 0);
    }
  return (tablename);
}

/* Note that this corrupts the given tablename by inserting null bytes
   '\0's to the place of dots.
 */
UCHAR *
divide_tablename (UCHAR * tablename, UCHAR ** p_tablequalifier, UCHAR ** p_tableowner)
{
/* Has any effect only if tablequalifier and tableowner are not given
   elsewhere, i.e. they are still NULL. (Stupid rule for compatibility) */
  if (tablename && NO * p_tablequalifier && NO * p_tableowner)
    {
      return (divide_tablename_aux (tablename, NULL, p_tablequalifier, NULL, p_tableowner, NULL));
    }
  else
    {
      return (tablename);
    }
}


#ifdef MOST_CLEARLY_THIS_WOULD_NOT_WORK_IN_MANY_CASES

UCHAR *
repair_tablename (UCHAR * tablequalifier, UCHAR * tableowner, UCHAR * tablename)
{
  if (tablequalifier)
    {
      tablequalifier[strlen (SCP (tablequalifier))] = '.';
    }
  if (tableowner)
    {
      tableowner[strlen (SCP (tableowner))] = '.';
    }
  return (tablename);
}

#endif



#define TN_SQL_QUOTE \
  my_strncat(dest_buf, (char *) quote_char, (dest_size-2))




char *
compose_whole_tablename (struct tabledeflist *tl, char *dest_buf, int dest_size)
{
  static int SQLGetInfo_called = 0;
  static SQLULEN owner_usage, qualifier_usage;
  static UWORD qualifier_location;
  static char *owner_term, *qualifier_term, *qualifier_name_separator;
  static char sp_owner_term[257], sp_qualifier_term[257], sp_qualifier_name_separator[257];
  static SWORD cb_owner_term, cb_qualifier_term, cb_qualifier_name_separator;
  static SWORD cb_owner_usage, cb_qualifier_usage, cb_qualifier_location, cb_quote_char;
  static UCHAR quote_char[2];
  char *me = "compose_whole_tablename";

  if (0 == SQLGetInfo_called)
    {
      HDBC *ptr_to_hdbc = &hdbc;	/* Global to datasource, should be in some struct */
      SQLGetInfo_called = 1;

      /* Clear the string buffers first: */
      sp_owner_term[0] = sp_qualifier_term[0] = sp_qualifier_name_separator[0] = '\0';

      /* These are strictly for debugging: */
      strcpy (sp_owner_term, "omistaja");
      strcpy (sp_qualifier_term, "lunastaja");
      strcpy (sp_qualifier_name_separator, "separaattori");

      SQLGetInfo (*ptr_to_hdbc, SQL_IDENTIFIER_QUOTE_CHAR, quote_char, sizeof (quote_char), &cb_quote_char);
      if (' ' == quote_char[0])
	quote_char[0] = 0;
      SQLGetInfo (*ptr_to_hdbc, SQL_OWNER_TERM, sp_owner_term, (sizeof (sp_owner_term) - 1), ((SWORD *) & cb_owner_term));
      if (SQL_NULL_DATA == cb_owner_term)
	{
	  owner_term = NULL;
	}
      else
	{
	  owner_term = sp_owner_term;
	}

      SQLGetInfo (*ptr_to_hdbc, SQL_QUALIFIER_TERM, sp_qualifier_term,
	  (sizeof (sp_qualifier_term) - 1), ((SWORD *) & cb_qualifier_term));
      if (SQL_NULL_DATA == cb_qualifier_term)
	{
	  qualifier_term = NULL;
	}
      else
	{
	  qualifier_term = sp_qualifier_term;
	}

      SQLGetInfo (*ptr_to_hdbc, SQL_QUALIFIER_NAME_SEPARATOR, sp_qualifier_name_separator,
	  (sizeof (sp_qualifier_name_separator) - 1), ((SWORD *) & cb_qualifier_name_separator));
      if (SQL_NULL_DATA == cb_qualifier_name_separator)
	{
	  qualifier_name_separator = NULL;
	}
      else
	{
	  qualifier_name_separator = sp_qualifier_name_separator;
	}

      owner_usage = qualifier_usage = 0;
      qualifier_location = 0;

      SQLGetInfo (*ptr_to_hdbc, SQL_OWNER_USAGE, &owner_usage, ((SWORD) 4), ((SWORD *) & cb_owner_usage));

      SQLGetInfo (*ptr_to_hdbc, SQL_QUALIFIER_USAGE, &qualifier_usage, ((SWORD) 4), ((SWORD *) & cb_qualifier_usage));

      SQLGetInfo (*ptr_to_hdbc, SQL_QUALIFIER_LOCATION, &qualifier_location, ((SWORD) 2), ((SWORD *) & cb_qualifier_location));


      if (verbose_flag || dbdump_debug_level)
	{
	  fprintf (stdout,
	      "-- %s: owner_term=\"%s\", qualifier_term=\"%s\", qualifier_name_separator=\"%s\"\n"
	      "-- owner_usage=%08lx, qualifier_usage=%08lx, qualifier_location=%u (%s)\n"
	      "-- tl->tl_qual_only=\"%s\", tl->tl_own_only=\"%s\", tl->tl_name_only=\"%s\"\n",
	      me,
	      ((NULL == owner_term) ? "NULL" : owner_term),
	      ((NULL == qualifier_term) ? "NULL" : qualifier_term),
	      ((NULL == qualifier_name_separator) ? "NULL" : qualifier_name_separator),
	      owner_usage, qualifier_usage,
	      qualifier_location,
	      ((SQL_QL_START == qualifier_location) ? "SQL_QL_START"
		  : ((SQL_QL_END == qualifier_location) ? "SQL_QL_END"
		      : "UNKNOWN")),
	      ((NULL == tl->tl_qual_only) ? "NULL" : tl->tl_qual_only),
	      ((NULL == tl->tl_own_only) ? "NULL" : tl->tl_own_only), ((NULL == tl->tl_name_only) ? "NULL" : tl->tl_name_only));
	  fflush (stdout);
	}

    }


/* Anyways, no we should be able to compose the whole tablename
   as the remote end (the original datasource) understands it,
   using the information collected above, as well as the
   elements

     tl_qual_only, tl_own_only and tl_name_only

   in the tabledeflist node.

   Note that any of these, as well as any of SQLGetInfo values
   might be NULLs or empty strings as well.
 */

  dest_buf[0] = '\0';
  dest_buf[dest_size - 1] = '\0';

  if (tl->tl_qual_only && (0 != qualifier_usage) && (SQL_QL_END != qualifier_location))
    {
      TN_SQL_QUOTE;
      my_strncat (dest_buf, tl->tl_qual_only, (dest_size - 2));
      TN_SQL_QUOTE;
      if (NULL != qualifier_name_separator)
	{
	  my_strncat (dest_buf, qualifier_name_separator, (dest_size - 2));
	}
    }

  if (tl->tl_own_only && (0 != owner_usage))
    {
      TN_SQL_QUOTE;
      my_strncat (dest_buf, tl->tl_own_only, (dest_size - 2));
      TN_SQL_QUOTE;
      my_strncat (dest_buf, ".", (dest_size - 2));
    }

  if (tl->tl_name_only)
    {
      TN_SQL_QUOTE;
      my_strncat (dest_buf, tl->tl_name_only, (dest_size - 2));
      TN_SQL_QUOTE;
    }

  if (tl->tl_qual_only && (0 != qualifier_usage) && (SQL_QL_END == qualifier_location))
    {
      if (NULL != qualifier_name_separator)
	{
	  my_strncat (dest_buf, qualifier_name_separator, (dest_size - 2));
	}
      TN_SQL_QUOTE;
      my_strncat (dest_buf, tl->tl_qual_only, (dest_size - 2));
      TN_SQL_QUOTE;
    }

  return (dest_buf);
}


/*
   new_whole_tablename: An "inverse" function of divide_tablename
   This constructs a new whole tablename
   (into a new buffer allocated here for it)
   from the three parts given, i.e. tablequalifier.tableowner.tablename

   If tablequalifier and tableowner are NULL,
   then returns just a copy of tablename. (no dots).
   If only tablequalifier is NULL,
    returns a combination tableowner.tablename
   If only tableowner is NULL,
    returns a combination tablequalifier..tablename
   tablename itself should never be NULL.

   Later we could use SQLGetInfo options SQL_QUALIFIER_LOCATION
   and  SQL_QUALIFIER_NAME_SEPARATOR, so if they are for example
   detected to be SQL_QL_END and "@" instead of SQL_QL_START and ".",
   then we know to construct Oracle-style tablenames like
   "ADMIN.EMP@EMPDATA" instead of Kubl-like "EMPDATA.ADMIN.EMP".
   Similarly, divide_tablename should take heed of that.
   (Where are the column names appended/inserted in the full Oracle
    notation?)

   Maybe we should also check SQL_QUALIFIER_USAGE and SQL_OWNER_USAGE
   and if they are zeroes (but who trusts ODBC drivers?)
   the set use_tables_prefixes_flag to zero in the beginning.
   (But even nowadays the user can use his -p option anytime he wants.)

   YES, SEE THE FUNCTION compose_whole_tablename ABOVE!
 */
UCHAR *
new_whole_tablename (UCHAR * tablequalifier, UCHAR * tableowner, UCHAR * tablename, char *where)
{
  UCHAR *wholetablename;
  size_t whole_len, qual_len, own_len, tab_len;

  if (NULL == tablequalifier)
    {
      if (NULL == tableowner)
	{
	  return (UCP (chestrdup (SCP (tablename), where)));
	}
      else
	{
	  qual_len = 0;
	}
    }
  else
    {
      qual_len = strlen (SCP (tablequalifier)) + 1;	/* Plus one for dot */
      if (NULL == tableowner)	/* tableowner missing from between */
	{
	  tableowner = UCP ("");
	}
    }

  own_len = strlen (SCP (tableowner)) + 1;	/* Plus one for the dot. */
  tab_len = strlen (SCP (tablename));
  whole_len = qual_len + own_len + tab_len;

  wholetablename = UCP (chemalloc ((whole_len + 1), where));

  wholetablename[0] = '\0';

  if (NULL != tablequalifier)
    {
      strcat (SCP (wholetablename), SCP (tablequalifier));
      strcat (SCP (wholetablename), ".");
    }

  if (NULL != tableowner)
    {
      strcat (SCP (wholetablename), SCP (tableowner));
      strcat (SCP (wholetablename), ".");
    }

  strcat (SCP (wholetablename), SCP (tablename));

  return (wholetablename);
}


/*
   A new function by AK 29-JAN-1998.
   Returns a newly strdupped string, which is got by substituting
   from tablename_expr the "variables" !Q, !O and/or !N
   (can be in lowercase also) with the corresponding three parts
   of whole_tablename_org. (Of course, anyone of these
   could be missing, or appear more than once.).
   Makes strdupped copies, of the original whole_tablename_org
   (first argument), so that it is not corrupted in the division,
   as well as with some intermediate results. All these are free'd
   later, except the final result, which is on the responsibility
   of the caller to free.
 */



char *
dsn_to_owner_name (char *dsn)
{
  int inx;
  dsn = strdup (dsn);
  for (inx = 0; inx < 32; inx++)
    {
      char c = dsn[inx];
      if (!c)
	return dsn;
      if (c >= 'a' && c <= 'z')
	c -= 32;
      else if (c >= '0' && c <= '9');
      else if (c >= 'A' && c <= 'Z');
      else
	c = '_';
      dsn[inx] = c;
    }
  dsn[inx] = 0;			/* cut after 32 characters */
  return dsn;
}


UCHAR *
substitute_tablename_expr (UCHAR * tablename_expr, UCHAR * whole_tablename_org)
{
  char *dsn2;
  char *where = "form_local_tablename";
  UCHAR *rem_tablequal = NULL, *rem_tableown = NULL;
  UCHAR *rem_tablenam = NULL;
  UCHAR *whole_tablename = UCP (chestrdup (SCP (whole_tablename_org), where));
  UCHAR *res1 = NULL, *res2 = NULL, *res3 = NULL, *res4 = NULL;

  rem_tablenam = divide_tablename (whole_tablename, &rem_tablequal, &rem_tableown);

  res1 = str_replace (tablename_expr, UCP ("!Q"), rem_tablequal, 0);
  res2 = str_replace (res1, UCP ("!O"), rem_tableown, 0);
  res3 = str_replace (res2, UCP ("!N"), rem_tablenam, 0);
  dsn2 = dsn_to_owner_name (datasource);
  res4 = str_replace (res3, UCP ("!D"), UCP (dsn2), 0);

  if (whole_tablename)
    {
      free (whole_tablename);
    }
  if (res1)
    {
      free (res1);
    }
  if (res2)
    {
      free (res2);
    }
  if (res3)
    {
      free (res3);
    }

  return (res4);
}


/* First tries to find the combination table_name.column_name
   from tablecol_names (which should be loosely or tightly comma-separated)
   E.g. if we use tablequal and tableowner prefixing, then
   table_name.column_name might result a string like "QUOI.OWN.TABLA.COL",
   and if that were not found, then next "OWN.TABLA.COL" would be
   searched for, then "TABLA.COL" and finally only "COL".
   That means that user can specify "wildcard" column names like
   "VECTOR" in unquoted_columns, that will be left unquoted in
   whichever table they are ever encountered.
 */
char *
belongs_to (char *table_name, char *column_name, char *tablecol_names)
{
  char table_et_column_name_space[(4 * MAXCOLNAME) + 22];
  char *table_et_column_name = table_et_column_name_space;
  char *ptr, *ptr2;

  if ((NULL == tablecol_names) || empty_stringp (tablecol_names))
    {
      return (NULL);
    }
  sprintf (table_et_column_name, "%s.%s", table_name, column_name);

try_again:
  if ((ptr = strstr (tablecol_names, table_et_column_name)) && ((ptr == tablecol_names)	/* In the beginning? Or the prev char: */
	  || ((isspace (*(ptr - 1)) || (',' == *(ptr - 1)) || (';' == *(ptr - 1))))) && (ptr2 = ptr + strlen (table_et_column_name))	/* to following */
      && (!*ptr2 || isspace (*ptr2) || (',' == *ptr2) || (';' == *ptr2) || ('=' == *ptr2)))	/* For future additions. */
    {
      return (ptr2);
    }
  else if ((table_et_column_name = strchr (table_et_column_name, '.')) != NULL)
    {
      table_et_column_name++;	/* Skip the first part and the dot. */
      goto try_again;
    }
  else
    {
      return (NULL);
    }				/* No luck this time. */
}



/* ================================================================== */
/*         FUNCTIONS FOR READING INFORMATION ABOUT THE SCHEMA         */
/*         USING AVAILABLE ODBC CALLS SQLTables, SQLStatistics, etc.  */
/* ================================================================== */

struct tabledeflist *
new_tabledeflist_node (struct tabledeflist *next,
    char *name,
    char *tl_qual_only,
    char *tl_own_only,
    char *tl_name_only,
    char *columns,
    char *all_columns,
    char *primary_key_name,
    char *primary_key_def,
    char *primary_key_type,
    char *super_table,
    char *insert_mode,
    int automatically_included,
    int contains_blobs,
    struct coldeflist *col_defs, struct indexdeflist *index_defs, struct tabledeflist *super_tl, struct subtablelist *sub_tables)
{
  struct tabledeflist *tl;

  char where[CHARCOL_LEN + 80];

  sprintf (where, "new_tabledeflist_node(\"%s\")", (name ? name : "NULL"));

  tl = (struct tabledeflist *) chemalloc (sizeof (struct tabledeflist), where);

  tl->next = next;
  tl->name = name;
  tl->tl_qual_only = tl_qual_only;
  tl->tl_own_only = tl_own_only;
  tl->tl_name_only = tl_name_only;
  tl->columns = columns;
  tl->all_columns = all_columns;
  tl->primary_key_name = primary_key_name;
  tl->primary_key_def = primary_key_def;
  tl->primary_key_type = primary_key_type;
  tl->super_table = super_table;
  tl->insert_mode = insert_mode;
  tl->automatically_included = automatically_included;
  tl->contains_blobs = contains_blobs;
  tl->col_defs = col_defs;
  tl->index_defs = index_defs;
  tl->super_tl = super_tl;
  tl->sub_tables = sub_tables;

  tl->bestrow_columns = NULL;	/* An ugly exception! (not in args) */
  tl->last_SQL_state = NULL;	/* As well as these. */
  tl->last_SQL_message = NULL;

  return (tl);
}

/* Windows NT and Linux do not have strtok_r, the re-entrant
   variant of strtok, so we just bluntly define strtok_r as strtok
   (wholly ignoring the third argument).
   Ordinary strtok uses its own static buffer, so we should be
   sure that none of the API-functions like SQLTables etc calls uses it
   (not even if inside mutex).
   There are calls to strtok(_r) in few places in the driver-module
   cliuti.c, but they occur only in timestamp and date-conversion,
   which should not be needed by SQLTables.
   Of course, someday we should code a secure re-entrant strtok_r
   of our own for Linux and Windows NT builds.
 */
#if defined  (WIN32) || defined (LINUX)
#ifndef strtok_r
#define strtok_r(X,Y,Z) strtok((X),(Y))
#endif
#endif


struct tabledeflist *
get_all_tables (char *global_tablequalifier, char *global_tableowner, char *tablepatterns, char *tabletype, int *pcount)
{
  UCHAR szTableQualifier[CHARCOL_LEN + 2], szTableOwner[CHARCOL_LEN + 2],
      szTableName[CHARCOL_LEN + 2], szTableType[CHARCOL_LEN + 2];
  char *where = "get_all_tables";
  SQLLEN cbTableQualifier, cbTableOwner, cbTableName, cbTableType;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  UCHAR *wholetablename;	/* Concatenated from the three above elements. */
  int rc;
  int n_tables = 0;
  struct tabledeflist *orgtl = NULL, *tl = NULL, *new_node;
  char *tokseps = " ,\t\r\n", *toksave = NULL, *tabletok;
  UCHAR *tablequalifier, *tableowner, *tablename;
  /* Three above items are extracted from tabletok, which in turn
     is separated from tablepatterns.
   */


  if (NULL == tablepatterns)	/* Not specified, list all of this tabletype */
    {
      tabletok = tablepatterns;
      goto creep_into_loop;
    }
  /* Loop over comma and/or whitespace separated tablepatterns */
  for (tabletok = strtok_r (tablepatterns, tokseps, &toksave);	/* The 1st token. */
      (tabletok != NULL); tabletok = strtok_r (NULL, tokseps, &toksave)	/* The next token. */
      )
    {
    creep_into_loop:
      if (verbose_flag || dbdump_debug_level)
	{
	  fprintf (stdout,
	      "-- %s: tablepattern=\"%s\",%ld\n",
	      where, (SCP (tabletok) ? SCP (tabletok) : "NULL"), ((NULL != tabletok) ? strlen (SCP (tabletok)) : 0L));
	}
      tablequalifier = NULL;	/* divide_tablename doesn't do its job */
      tableowner = NULL;	/* unless these two are NULL when called. */
/* Was:
     tablename = divide_tablename(UCP(tabletok),&tablequalifier,&tableowner);
 */
      tablename = divide_tablename_aux (UCP (tabletok), &scbTableName,
	  &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);
      tableowner = ((tableowner || tablequalifier) ? tableowner : UCP (global_tableowner));
      tablequalifier = (tablequalifier ? tablequalifier : UCP (global_tablequalifier));

      if (dbdump_debug_level)
	{
	  fprintf (stdout,
	      "-- tablequalifier=%s,%d  tableowner=%s,%d  tablename=%s,%d  tabletype=%s\n",
	      (SCP (tablequalifier) ? SCP (tablequalifier) : "NULL"),
	      scbTableQualifier,
	      (SCP (tableowner) ? SCP (tableowner) : "NULL"),
	      scbTableOwner,
	      (SCP (tablename) ? SCP (tablename) : "NULL"), scbTableName, (SCP (tabletype) ? SCP (tabletype) : "NULL"));
	}

      strcpy (SCP (szTableName), SCP ("BEFORE_FIRST_TABLE"));

      rc = SQLTables (stmt, UCP (tablequalifier), scbTableQualifier,
	  UCP (tableowner), scbTableOwner, UCP (tablename), scbTableName, UCP (tabletype), SWD (tabletype ? SQL_NTS : 0));
      if (rc == SQL_SUCCESS)
	{
/*      if(use_table_prefixes_flag) We bind the ALWAYS! */
	  {
	    SQLBindCol (stmt, 1,	/* The first column is TableQualifier. */
		SQL_C_CHAR, szTableQualifier, CHARCOL_LEN, &cbTableQualifier);

	    SQLBindCol (stmt, 2,	/* The second column is TableOwner. */
		SQL_C_CHAR, szTableOwner, CHARCOL_LEN, &cbTableOwner);
	  }

	  SQLBindCol (stmt, 3,	/* The third column is TableName. */
	      SQL_C_CHAR, szTableName, CHARCOL_LEN, &cbTableName);

	  SQLBindCol (stmt, 4,	/* The fourth column is TableType. */
	      SQL_C_CHAR, szTableType, CHARCOL_LEN, &cbTableType);

	  while (TRUE)
	    {
	      rc = SQLFetch (stmt);
	      if (rc == SQL_NO_DATA_FOUND)
		{
		  break;
		}
	      IF_ERR_GO (stmt, error, rc);


/* We get NULL tablename's when pattern is either %.. or .%.
   or tabletype is % and others are NULL. This is the enumeration
   special usage for qualifiers, owners and types respectively.
 */
	      if (dbdump_debug_level || (SQL_NULL_DATA == cbTableName))
		{
		  if (dbdump_debug_level || verbose_flag)
		    {
		      fprintf (stdout,
			  "-- %s: %sTableQualifier=\"%s\",%ld TableOwner=\"%s\",%ld "
			  "TableName=\"%s\",%ld TableType=\"%s\",%ld  patterntoken=\"%s\"\n",
			  where,
			  ((SQL_NULL_DATA == cbTableName) ? "Skipping, because: " : ""),
			  (szTableQualifier[0] ? SCP (szTableQualifier) : "NULL"),
			  cbTableQualifier,
			  (szTableOwner[0] ? SCP (szTableOwner) : "NULL"),
			  cbTableOwner,
			  (szTableName[0] ? SCP (szTableName) : "NULL"),
			  cbTableName,
			  (szTableType[0] ? SCP (szTableType) : "NULL"),
			  cbTableType, (SCP (tabletok) ? SCP (tabletok) : "NULL"));
		    }
		  if ((SQL_NULL_DATA == cbTableName))
		    {
		      continue;
		    }
		}

	      if (use_table_prefixes_flag)
		{
		  wholetablename
		      = new_whole_tablename (((SQL_NULL_DATA == cbTableQualifier)
			  ? NULL : szTableQualifier), ((SQL_NULL_DATA == cbTableOwner) ? NULL : szTableOwner), szTableName, where);
		}
	      else
		{		/* If no table-prefixes are used, then make just a copy. */
		  wholetablename = UCP (chestrdup (SCP (szTableName), where));
		}

	      debug_fprintf (stdout, "-- %s: wholetablename=%s\n", where, wholetablename);

	      if (find_tabledef (SCP (wholetablename), orgtl))
		{
		  /* do not load twice the same tables, in case user's
		     search patterns overlap. So we have to free that
		     constructed/copied wholetablename, because it will
		     not be used anywhere
		     (as there already is in orgtl list similarly named one)
		   */
		  free (wholetablename);
		}
	      else
		{
		  new_node = new_tabledeflist_node (NULL,	/* struct tabledeflist *next, */
		      SCP (wholetablename),	/* char *name, */
		      ((SQL_NULL_DATA == cbTableQualifier) ? NULL : SCP (chestrdup (SCP (szTableQualifier), where))), ((SQL_NULL_DATA == cbTableOwner) ? NULL : SCP (chestrdup (SCP (szTableOwner), where))), ((SQL_NULL_DATA == cbTableName) ? NULL : SCP (chestrdup (SCP (szTableName), where))), "",	/* char *columns, */
		      NULL,	/* char *all_columns, */
		      NULL,	/* char *primary_key_name, */
		      "",	/* char *primary_key_def, */
		      "",	/* char *primary_key_type, */
		      NULL,	/* char *super_table, */
		      default_insert_mode,	/* char *insert_mode, */
		      0,	/* int  automatically_included, */
		      0,	/* int  contains_blobs, */
		      NULL,	/* struct coldeflist *col_defs, */
		      NULL,	/* struct indexdeflist *index_defs, */
		      NULL,	/* struct tabledeflist *super_tl, */
		      NULL);	/* struct subtablelist *sub_tables */

		  if (orgtl == NULL)	/* First element! */
		    {
		      tl = orgtl = new_node;	/* orgtl to new_node, and tl to same */
		    }
		  else
		    {		/* Update the next link of the previous node, and set tl
				   then point to this new node (from right to left) */
		      tl = tl->next = new_node;
		    }

		  if (pcount)
		    {
		      ++*pcount;
		    }
		  n_tables++;
		}
	    }			/* while(TRUE) */
	}

    error:;

      SQLFreeStmt (stmt, SQL_UNBIND);
      SQLFreeStmt (stmt, SQL_CLOSE);

      if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
	{
	  print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
	  exit (1);
	}
      if (NULL == tabletok)
	{
	  break;
	}			/* In case tablepatterns was NULL */
    }				/* loop for a while, while tokens last from tablepatterns string. */

  debug_fprintf (stdout, "-- get_all_tables: n_tables=%d\n", n_tables);
  return (orgtl);
}


/* Note from ODBC API Help file:

   SQLColumns returns the results as a standard result set, ordered
   by TABLE_QUALIFIER, TABLE_OWNER, and TABLE_NAME. The following
   table lists the columns in the result set. Additional columns
   beyond column 12 (REMARKS) can be defined by the driver.

 */


int
get_table_columns (struct tabledeflist *tl, int n_cols_with_describe_col)
		      /* If the second arg. is non-zero, then we use
		         SQLDescribeCol instead of SQLColumns */
{
  UCHAR *tablequalifier, *tableowner, *tablename;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  SWORD s_cbColumnName;		/* To avoid warnings, we must use 2 different */
  SQLLEN l_cbColumnName;	/* variants for SQLBindCol and SQLDescribeCol */
  SWORD Type, Scale, Nullable;
  SQLULEN Precision;
  SQLLEN cbType, cbPrecision, cbScale, cbNullable;
  int rc;
  UWORD inx = 0;
  struct coldeflist *cl = NULL;
  UCHAR Column_Name[CHARCOL_LEN + 2];
  char temp[CHARCOL_LEN + 2];
  char where[CHARCOL_LEN + 80];

  sprintf (where, "get_table_columns(\"%s\",%d)", (tl->name ? tl->name : "NULL"), n_cols_with_describe_col);

  debug_fprintf (stdout, "-- %s\n", where);

  if (0 == n_cols_with_describe_col)	/* Use SQLColumns */
    {
      tablequalifier = NULL;	/* divide_tablename doesn't do its job */
      tableowner = NULL;	/* unless these two are NULL when called. */
/* Was:
       tablename = divide_tablename(UCP(tl->name),&tablequalifier,&tableowner);
 */
      tablename = divide_tablename_aux (UCP (tl->name), &scbTableName,
	  &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);

      rc = SQLColumns (stmt, tablequalifier, scbTableQualifier, tableowner, scbTableOwner, tablename, scbTableName, NULL, 0);	/* All columns. */

      if (rc == SQL_SUCCESS)
	{
	  SQLBindCol (stmt, 4, SQL_C_CHAR, Column_Name, CHARCOL_LEN, &l_cbColumnName);
	  SQLBindCol (stmt, 5,	/* DATA TYPE is SMALLINT NOT NULL */
	      SQL_C_SSHORT, &Type, 0, &cbType);
	  SQLBindCol (stmt, 7, SQL_C_SLONG, &Precision, 0, &cbPrecision);	/* INTEGER */
	  SQLBindCol (stmt, 9, SQL_C_SSHORT, &Scale, 0, &cbScale);	/* SMALLINT */
	  SQLBindCol (stmt, 11,	/* SMALLINT NOT NULL */
	      SQL_C_SSHORT, &Nullable, 0, &cbNullable);
	}
      else
	{
	  IF_ERR_GO (stmt, error, rc);
	}
    }

  /* No other function (e.g. any of the ones we call in this loop)
     should use tmp1 meanwhile, because we use it for constructing
     the columns string. */
  for (tmp1[0] = '\0', inx = 1; TRUE; inx++)
    {
      if (n_cols_with_describe_col)
	{
	  if (inx > n_cols_with_describe_col)
	    {
	      break;
	    }
	  rc = SQLDescribeCol (stmt, inx,
	      Column_Name, ((SWORD) CHARCOL_LEN), &s_cbColumnName, &Type, &Precision, &Scale, &Nullable);
	}
      else			/* Using SQLColumns with variables bound above. */
	{
	  rc = SQLFetch (stmt);
	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      break;
	    }
	  if (cbScale == SQL_NULL_DATA)
	    {
	      Scale = 0;
	    }
	  if (cbPrecision == SQL_NULL_DATA)
	    {
	      Precision = 0;
	    }
	  if (cbNullable == SQL_NULL_DATA)
	    {
	      Nullable = SQL_NULLABLE_UNKNOWN;
	    }
	}
      IF_ERR_GO (stmt, error, rc);

      if ((n_cols_with_describe_col && (s_cbColumnName == SQL_NULL_DATA))
	  || (NOT n_cols_with_describe_col && (l_cbColumnName == SQL_NULL_DATA)))
	{			/* Shouldn't occur! */
	  fprintf (stdout, "-- Table %s has a column with NULL name (%d)!\n", tl->name, inx);
	  strcpy (SCP (Column_Name), "NULL");
	}

      if (tl->col_defs == NULL)	/* First column definition? */
	{			/* Start constructing the column definition list. */
	  cl = tl->col_defs = (struct coldeflist *) chemalloc (sizeof (struct coldeflist), where);
	}
      else
	{			/* Update the next link of the prev node. */
	  cl->next = (struct coldeflist *) chemalloc (sizeof (struct coldeflist), where);
	  cl = cl->next;
	}

      cl->col_name = chestrdup (SCP (Column_Name), where);
      cl->col_type = Type;
      cl->col_unquoted = !!belongs_to (SCP (tl->name ? tl->name : "NULL"), SCP (Column_Name), SCP (unquoted_columns));

      cl->col_is_nth_blob = 0;
#ifdef SQL_LONGVARCHAR
      if ((SQL_LONGVARCHAR == cl->col_type)
#ifdef SQL_LONGVARBINARY
	  || (SQL_LONGVARBINARY == cl->col_type)
#endif
	  )
	{
/* If tl->contains_blobs contained a count of blob columns in the table
   we would just increment it with:
          tl->contains_blobs++;
   But because now it contains the type of the first blob column
   (SQL_LONGVARCHAR or SQL_LONGVARBINARY), we use the following
   contraption:
*/
	  if (tl->contains_blobs)
	    {			/* There is already at least one blob column in this table? */
	      if (use_foreach_for_blobs_flag && verbose_flag)
		{
		  printf ("-- Table %s has more than one blob column.\n"
		      "-- The column %s of type %s might not get properly inserted.\n",
		      tl->name, cl->col_name, get_sql_type_title (cl->col_type));
		}
	      cl->col_is_nth_blob = 2;
	    }
	  else
	    {
	      tl->contains_blobs = cl->col_type;
	      cl->col_is_nth_blob = 1;
	    }
	}
#endif

      cl->col_precision = Precision;
      cl->col_scale = Scale;
      cl->col_nullable = Nullable;
      cl->next = NULL;
      /* The next two are for building the value of tl->columns */
      if (*tmp1)
	{
	  strcat (tmp1, ",");
	}
      strcat (tmp1, escapify (temp, SCP (Column_Name)));
    }				/* for loop */

  /* If we have come here after select * from table, then we have got */
  if (n_cols_with_describe_col)	/* all the columns, including those of */
    {
      tl->all_columns = chestrdup (tmp1, where);
    }				/* the possible supertables */
  tl->columns = chestrdup (tmp1, where);

  /* If we have used SQLDescribeCol, return here, don't free anything. */
  if (n_cols_with_describe_col)
    {
      return (n_cols_with_describe_col);
    }
error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  return (inx);
}


/* Taken from the KUBLREF.DOC:
   (Alternatives between (* and *) have been commented out from Kubl
   SQL Parser.)

base_table_def:
        CREATE TABLE table_name '(' base_table_element_commalist ')'
    ;

base_table_element_commalist:
        base_table_element
    |    base_table_element_commalist ',' base_table_element
    ;

base_table_element:
        column_def
    |    table_constraint_def
    ;

column_def:
        column data_type column_def_opt_list
    ;

column_def_opt_list:
        (* empty *)
    |    column_def_opt_list column_def_opt
    ;

column_def_opt:
        NOT NULL
(*    |    NOT NULL UNIQUE
    |    NOT NULL PRIMARY KEY opt_index_option_list
    |    DEFAULT literal
    |    DEFAULT NULL
    |    DEFAULT USER
    |    CHECK '(' search_condition ')'
    |    REFERENCES table
    |    REFERENCES table '(' column_commalist ')'
*)
    ;

table_constraint_def:
        UNDER table_name
    |    PRIMARY KEY '(' column_commalist ')' opt_index_option_list
(*    |    UNIQUE '(' column_commalist ')'
    |    FOREIGN KEY '(' column_commalist ')'
            REFERENCES table
    |    FOREIGN KEY '(' column_commalist ')'
            REFERENCES table '(' column_commalist ')'
    |    CHECK '(' search_condition ')'
*)
    ;

column_commalist:
        column
    |    column_commalist ',' column
    ;

index_option:
        CLUSTERED
    |    UNIQUE

    |    OBJECT_ID
    ;

index_option_list:
        index_option
    |    index_option_list index_option
    ;

opt_index_option_list:

    |    index_option_list
    ;

create_index_def:
        CREATE opt_index_option_list INDEX index
                        ON table_name '(' column_commalist ')'
    ;

E.g. only
        create table test(num integer, txt varchar, primary key(num))
works. But not the following:
        create table test(num integer not null primary key, txt varchar)
(From Tismer's mail).

The following examples work:

create table turilas(aapo integer, b varchar, primary key(aapo) unique);

create table purilas(aapo integer, b varchar, primary key(aapo) clustered);

create index huuli on purilas(b,aapo);

create unique index viili on purilas(b,aapo);

The following examples don't work:

SQL> create table test2(a integer, b varchar, primary key(a) not null);
*** Error 37000: 1: syntax error at not

SQL> create table test2(a integer not null, b varchar);
*** Error ....: A table must either have an UNDER or PRIMARY KEY
specification.
SQL> create table test2(a integer not null primary key, b varchar);
*** Error 37000: 1: syntax error at primary

SQL> create table cerdito(pekoni integer, juusto varchar, under cerdo,
                          primary key(pekoni,kalapussi));

*** Error ....: A table can't have both UNDER and PRIMARY KEY.

*/


/*
   scope_specified can be either:
        SQL_SCOPE_CURROW                        0 (default)
        SQL_SCOPE_TRANSACTION                   1
        SQL_SCOPE_SESSION                       2

   nullability can be either
        SQL_NO_NULLS                            0
        SQL_NULLABLE                            1

 */
int
get_table_bestrow_columns (struct tabledeflist *tl, UWORD scope_specified, UWORD nullability)
{
  UCHAR *tablequalifier, *tableowner, *tablename;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  SWORD SCOPE, PSEUDO_COLUMN;
  SQLLEN cbSCOPE, cbPSEUDO_COLUMN;
  int rc, count = 0;
  UCHAR Column_Name[CHARCOL_LEN + 2];
  SQLLEN cbColumnName;
  char temp[CHARCOL_LEN + 10], where[CHARCOL_LEN + 80];

  sprintf (where, "get_table_bestrow_columns(\"%s\",%d,%d)", (tl->name ? tl->name : "NULL"), scope_specified, nullability);

  debug_fprintf (stdout, "-- %s\n", where);

  tablequalifier = NULL;	/* divide_tablename doesn't do its job */
  tableowner = NULL;		/* unless these two are NULL when called. */
  tablename = divide_tablename_aux (UCP (tl->name), &scbTableName,
      &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);

  rc = SQLSpecialColumns (stmt,
      ((UWORD) (SQL_BEST_ROWID)),
      UCP (tablequalifier), scbTableQualifier,
      UCP (tableowner), scbTableOwner,
      UCP (tablename), scbTableName, ((UWORD) (scope_specified ? scope_specified : SQL_SCOPE_CURROW)), ((UWORD) nullability));

  if (rc == SQL_SUCCESS)
    {
      SQLBindCol (stmt, 1, SQL_C_SSHORT, &SCOPE, 0, &cbSCOPE);
      SQLBindCol (stmt, 2, SQL_C_CHAR, Column_Name, CHARCOL_LEN, &cbColumnName);
      SQLBindCol (stmt, 8, SQL_C_SSHORT, &PSEUDO_COLUMN, 0, &cbPSEUDO_COLUMN);
/* Here IS_PSEUDO_COLUMN should contain one of the following values:
   (similarly SCOPE should contain one of those values listed in
    the comment before this function).
#define SQL_PC_UNKNOWN                  0
#define SQL_PC_NOT_PSEUDO               1
#define SQL_PC_PSEUDO                   2
 */

      tmp1[0] = '\0';		/* Build a string of column names to global buffer
				   tmp1, I hope that nobody else uses it meanwhile */
      while (TRUE)
	{
	  rc = SQLFetch (stmt);
	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      break;
	    }
	  IF_ERR_GO (stmt, error, rc);

	  count++;
	  {			/* column of it, that has to be concatenated to a string. */

	    if (*tmp1)
	      {
		strcat (tmp1, ",");
	      }
	    strcat (tmp1, escapify (temp, SCP (Column_Name)));
	  }

	}			/* while(TRUE) */

      if (tmp1[0])		/* Got something? */
	{
	  tl->bestrow_columns = chestrdup (tmp1, where);
	}
      else
	{
	  tl->bestrow_columns = NULL;
	}

      debug_fprintf (stdout,
	  "-- get_table_bestrow_columns(\"%s\",%d,%d) -> %s\n",
	  (tl->name ? tl->name : "NULL"), scope_specified, nullability, (tl->bestrow_columns ? tl->bestrow_columns : "NULL"));
    }				/* if(rc == SQL_SUCCESS) */



error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  return (count);
}


/* This doesn't work properly if it is possible to create more than
   one primary key (which is oxymoron), i.e. the index name changes,
   and Seq_In_Index starts running from 1 again.
   Or if columns are not coming in the correct sequence.
   See module wi/sqlext.c for Kubl implementation of SQLPrimaryKeys
 */

int
get_table_primarykey (struct tabledeflist *tl)
{
  UCHAR *tablequalifier, *tableowner, *tablename;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  SQLLEN cbTabQual, cbTabOwn, cbTabName;
  SQLLEN cbSuperTabQual, cbSuperTabOwn, cbSuperTabName;
  SQLLEN cbColumnName;
  SQLLEN cbIndexName;
  SWORD Seq_In_Index;
  SQLLEN cbSeq_In_Index;
  int rc, count = 0;
/* These are for Bind: */
  UCHAR Column_Name[CHARCOL_LEN + 2];
  UCHAR Index_Name[CHARCOL_LEN + 2];
  UCHAR TabQual[CHARCOL_LEN + 2], TabOwn[CHARCOL_LEN + 2];
  UCHAR TabName[CHARCOL_LEN + 2];
  UCHAR SuperTabQual[CHARCOL_LEN + 2], SuperTabOwn[CHARCOL_LEN + 2];
  UCHAR SuperTabName[CHARCOL_LEN + 2];
  char temp[CHARCOL_LEN + 2];
  char where[CHARCOL_LEN + 80];

  sprintf (where, "get_table_primarykey(\"%s\")", (tl->name ? tl->name : "NULL"));

  debug_fprintf (stdout, "-- %s\n", where);

  tablequalifier = NULL;	/* divide_tablename doesn't do its job */
  tableowner = NULL;		/* unless these two are NULL when called. */
/* Was:
    tablename = divide_tablename(UCP(tl->name),&tablequalifier,&tableowner);
 */
  tablename = divide_tablename_aux (UCP (tl->name), &scbTableName,
      &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);

  rc = SQLPrimaryKeys (stmt, tablequalifier, scbTableQualifier, tableowner, scbTableOwner, tablename, scbTableName);

  if (rc == SQL_SUCCESS)
    {
      SQLBindCol (stmt, 1, SQL_C_CHAR, TabQual, CHARCOL_LEN, &cbTabQual);
      SQLBindCol (stmt, 2, SQL_C_CHAR, TabOwn, CHARCOL_LEN, &cbTabOwn);
      SQLBindCol (stmt, 3, SQL_C_CHAR, TabName, CHARCOL_LEN, &cbTabName);
      SQLBindCol (stmt, 4, SQL_C_CHAR, Column_Name, CHARCOL_LEN, &cbColumnName);
      SQLBindCol (stmt, 5, SQL_C_SSHORT, &Seq_In_Index, 0, &cbSeq_In_Index);
      SQLBindCol (stmt, 6, SQL_C_CHAR, Index_Name, CHARCOL_LEN, &cbIndexName);

      if (kubl_mode)		/* The 7th column is a Non-Standard Kubl Extension */
	{
	  SQLBindCol (stmt, 7, SQL_C_CHAR, SuperTabQual, CHARCOL_LEN, &cbSuperTabQual);
	  SQLBindCol (stmt, 8, SQL_C_CHAR, SuperTabOwn, CHARCOL_LEN, &cbSuperTabOwn);
	  SQLBindCol (stmt, 9, SQL_C_CHAR, SuperTabName, CHARCOL_LEN, &cbSuperTabName);
	}

      tmp1[0] = '\0';		/* Build a string of column names to global buffer
				   tmp1, I hope that nobody else uses it meanwhile */
      while (TRUE)
	{
	  rc = SQLFetch (stmt);
	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      break;
	    }
	  IF_ERR_GO (stmt, error, rc);

	  count++;
	  /* If the non-standard Kubl extension is used, and the seventh
	     eight, and ninth columns contain a table name which is
	     different from the first, second and third columns
	     (i.e. tl->name, the table name we are looking for at this
	     time), then this table has been defined as UNDER that
	     table, and has no primary key of its own. */
	  if (kubl_mode && (cbSuperTabName != SQL_NULL_DATA) && (strcmp (SCP (TabName), SCP (SuperTabName)) ||	/* Some of these */
		  strcmp (SCP (TabOwn), SCP (SuperTabOwn)) ||	/* three parts is */
		  strcmp (SCP (TabQual), SCP (SuperTabQual))))	/* different? */
	    {
	      if (tl->super_table == NULL)	/* Insert only once. */
		{
		  if (use_table_prefixes_flag)
		    {
		      tl->super_table = SCP (new_whole_tablename (SuperTabQual, SuperTabOwn, SuperTabName, where));
		    }
		  else
		    {
		      tl->super_table = chestrdup (SCP (SuperTabName), where);
		    }
		}
	    }
	  else			/* It is a table with primary key, and here we have one */
	    {			/* column of it, that has to be concatenated to a string. */

	      if (*tmp1)
		{
		  strcat (tmp1, ",");
		}
	      strcat (tmp1, escapify (temp, SCP (Column_Name)));

	      if ((cbIndexName != SQL_NULL_DATA) && (tl->primary_key_name == NULL))	/* Do this only once. */
		{
		  tl->primary_key_name = chestrdup (SCP (Index_Name), where);
		}
	    }

	}			/* while(TRUE) */

      tl->primary_key_def = chestrdup (tmp1, where);
    }				/* if(rc == SQL_SUCCESS) */



error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  return (count);
}


/* This function reads the real super table names of those
   table names for which get_table_primarykey (e.g. SQLPrimaryKeys)
   indicated to have a supertable. (thus being subtables of
   another table themselves).

   This is needed because Kubl's current SQLPrimaryKeys implementation
   returns incorrect information if table's immediate parent
   is not also its root ancestor. Or correct information if we
   define that it *should* return the name of the ancestor table,
   not one of the immediate parent.

   We have to use our own HSTMT statement handle grs_stmt here,
   because we might call SQLPrimaryKeys at the same time for some of
   new table names, in case the supertable names thus found here
   didn't match to the original tablename specification given by
   the user. So each new table thus encountered needs to be stealthily
   added here to the all_tables_list (actually inserted just to the
   next element of the currently handled one, so that it will be
   handled in the next iteration of loop), and after that
   get_table_primarykey called for also them, so that we see whether
   they got in turn further supertables.

   Returns as the result the number of new supertables added to
   all_tables_list.
 */

/* This is certainly a temporary kludge, until Kubl really implements
   tablequalifier (database) and tableowner parts.
 */
#define KUBL_CONSTANT_TABLE_PREFIXES "db.dba."

/* Yes, this is buggy with current Kubl, needs to be rewritten! */

int
get_real_supertables (struct tabledeflist *tl)
{
  UCHAR *tablequalifier, *tableowner, *tablename;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  SQLLEN cbSuperTabName, cbTableName = SQL_NTS;
  UCHAR *SuperTabNamePtr;	/* Usually points to the start of SuperTabName */
  int rc, count = 0;
  struct tabledeflist *supertl;
  char *where = "get_real_supertables";
  HSTMT grs_stmt;
  UCHAR TableName[CHARCOL_LEN + 2];
  UCHAR SuperTabName[CHARCOL_LEN + sizeof (KUBL_CONSTANT_TABLE_PREFIXES) + 2];

  SQLAllocStmt (hdbc, &grs_stmt);


  strcpy (SCP (TableName), "KIRSIKKA");	/* A test. */

  SuperTabNamePtr = SuperTabName;
  if (use_table_prefixes_flag)
    {
      strcpy (SCP (SuperTabName), KUBL_CONSTANT_TABLE_PREFIXES);
      SuperTabNamePtr += strlen (SCP (KUBL_CONSTANT_TABLE_PREFIXES));
    }

/* We should use name_part here, get those three parts! */
  rc = SQLPrepare (grs_stmt,
      UCP ("select v2.KEY_TABLE from SYS_KEYS v1, SYS_KEY_SUBKEY, SYS_KEYS v2 "
	  "where v1.KEY_TABLE = ? and v1.KEY_IS_MAIN = 1 and SUB = v1.KEY_ID "
	  "and v2.KEY_ID = SUPER and v1.KEY_TABLE <> v2.KEY_TABLE"), SQL_NTS);
  IF_ERR_GO (grs_stmt, error, rc);

  rc = SQLSetParam (grs_stmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, TableName, &cbTableName);
  IF_ERR_GO (grs_stmt, error, rc);

  rc = SQLBindCol (grs_stmt, 1, SQL_C_CHAR, SuperTabNamePtr, CHARCOL_LEN, &cbSuperTabName);
  IF_ERR_GO (grs_stmt, error, rc);

  for (; tl; tl = tl->next, SQLFreeStmt (grs_stmt, SQL_CLOSE))
    {
      if (NULL == tl->super_table)
	{
	  debug_fprintf (stdout, "-- get_real_supertables(%s) skipping...\n", tl->name);
	  continue;
	}
/* Was: strcpy(SCP(TableName),SCP(tl->name)); */
      tablequalifier = NULL;	/* divide_tablename doesn't do its job */
      tableowner = NULL;	/* unless these two are NULL when called. */
/* Was:
       tablename = divide_tablename(UCP(tl->name),&tablequalifier,&tableowner);
 */
      tablename = divide_tablename_aux (UCP (tl->name), &scbTableName,
	  &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);
      strcpy (SCP (TableName), SCP (tablename));

      rc = SQLExecute (grs_stmt);
      IF_ERR_GO (grs_stmt, error, rc);

      if (rc == SQL_SUCCESS)
	{

	  rc = SQLFetch (grs_stmt);
	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      goto not_found;
	    }
	  IF_ERR_GO (grs_stmt, error, rc);

/* Was here: count++; */

	  if (verbose_flag)
	    {
	      fprintf (stdout, "-- get_real_supertable(%s) %s -> %s\n", tl->name, tl->super_table, SuperTabName);
	    }
	  if (0 != strcmp (SCP (SuperTabName), SCP (tl->super_table)))
	    {			/* If changed, then free the old one and alloc new one. */
	      if (tl->super_table)
		{
		  free (tl->super_table);
		}
	      tl->super_table = chestrdup (SCP (SuperTabName), where);
	    }
	}			/* if(rc == SQL_SUCCESS) */
      else
	{
	not_found:
	  fprintf (stdout,
	      "-- get_real_supertables(%s) Strange: No supertable name was found from\n"
	      "-- tables SYS_KEYS and SYS_KEY_SUBKEY, so keeping the old one = %s\n",
	      /* TableName */ tl->name, tl->super_table);
/*        goto error; */
	}

/* This is only circularity check we do at the moment.
   In case someone screws Kubl or the driver's SQLPrimaryKey's
   code really bad.
 */
      if (0 == strcmp (SCP (tl->name), SCP (tl->super_table)))
	{
	  fprintf (stdout,
	      "-- get_real_subtables(%s): Fatal screw-up: subtable and supertable have\n"
	      "-- got the same name: '%s'. Clearing subtable's super_table link to\n"
	      "-- avoid further circularity catastrophes.\n", tl->name, tl->super_table);
	  fflush (stdout);
	  free (tl->super_table);
	  tl->super_table = NULL;
	}
      if (tl->super_table)	/* Certainly this subtable has a super table. */
	{
	  supertl = find_tabledef (tl->super_table, all_tables_list);
	  if (supertl == NULL)
	    {
/* E.g. this might happen if the user dumps selectively some tables
   with a wildcard expression or single name, and (some) parent table(s)
   are not explicitly specified also. */
	      if (verbose_flag)
		{
		  fprintf (stdout,
		      "-- get_real_subtables(%s): Could not find the super table '%s' from\n"
		      "-- the existing table definitions; adding it to the table list\n"
		      "-- and reading its primary key information. Use options -TIC\n"
		      "-- to get its Table definition, Indices and Contents respectively\n"
		      "-- to the output, or include its name explicitly in tablename argument.\n", tl->name, tl->super_table);
		}
	      supertl = new_tabledeflist_node (tl->next,	/* struct tabledeflist *next, */
		  chestrdup (SCP (tl->super_table), where),	/* char *name, */
		  "SuperQual", "SuperOwn", "SuperName",	/* To be replaced! */
/* Should be something like this:
                       ((SQL_NULL_DATA == cbTableQualifier) ? NULL
                         : UCP(chestrdup(SCP(szTableQualifier),where))),
                       ((SQL_NULL_DATA == cbTableOwner) ? NULL
                         : UCP(chestrdup(SCP(szTableOwner),where))),
                       ((SQL_NULL_DATA == cbTableName) ? NULL
                         : UCP(chestrdup(SCP(szTableName),where))),
 */
		  "",		/* char *columns, */
		  NULL,		/* char *all_columns, */
		  NULL,		/* char *primary_key_name, */
		  "",		/* char *primary_key_def, */
		  "",		/* char *primary_key_type, */
		  NULL,		/* char *super_table, */
		  default_insert_mode,	/* char *insert_mode, */
		  1,		/* int  automatically_included, */
		  0,		/* int  contains_blobs, */
		  NULL,		/* struct coldeflist *col_defs, */
		  NULL,		/* struct indexdeflist *index_defs, */
		  NULL,		/* struct tabledeflist *super_tl, */
		  NULL);	/* struct subtablelist *sub_tables */
	      /* Read the primary key information (and with Kubl also
	         the potential, tentative supertable name) of supertl,
	         and then immediately next time in this loop we check supertl's
	         supertable if it has one of its own
	         (whose name get_table_primarykey will in that case set
	         to super_table slot of supertl)
	       */
	      get_table_primarykey (supertl);
	      tl->next = supertl;
	      count++;
	    }
	}
    }				/* for loop */


error:;
  SQLFreeStmt (grs_stmt, SQL_UNBIND);
  SQLFreeStmt (grs_stmt, SQL_RESET_PARAMS);
  SQLFreeStmt (grs_stmt, SQL_CLOSE);	/* Maybe called unnecessarily, maybe not. */
  SQLFreeStmt (grs_stmt, SQL_DROP);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  return (count);
}


/* The following should match with SQL_INDEX_OBJECT_ID_STR defined in
   sqlext.c ! (Now both defined in kublext.h and kublextw.h)
   And of course it should be different from all standard SQL INDEX TYPE
   definitions defined in sqlext.h (Actually, all those values might
   be added to this one, or bit-ored if you think it that way.)
 */
/* #define SQL_INDEX_OBJECT_ID 8 Now defined in kublext(w).h */


int
get_table_indices (struct tabledeflist *tl)
{
  UCHAR *tablequalifier, *tableowner, *tablename;
  SWORD scbTableQualifier = SQL_NTS, scbTableOwner = SQL_NTS, scbTableName = SQL_NTS;
  SQLLEN cbIndexName, cbColumnName;
  SWORD Non_Unique = 555, Seq_In_Index = 666, Type = 777;
  SQLLEN cbNon_Unique, cbSeq_In_Index, cbType;
  int rc;
  int count = 0;
  int this_one_is_primary_key = 0;
  int previous_one_was_primary_key = this_one_is_primary_key;
  struct indexdeflist *il = NULL;
  char *turnipsi_pointteri = NULL;	/* Crazy, isn't it? Lets me sleep. */
  UCHAR Index_Name[CHARCOL_LEN + 2], Column_Name[CHARCOL_LEN + 2];
  char indextype[CHARCOL_LEN + 2];
  char Previous_Index_Name[CHARCOL_LEN + 2], temp[CHARCOL_LEN + 2];
  char where[CHARCOL_LEN + 80];

  sprintf (where, "get_table_indices(\"%s\")", (tl->name ? tl->name : "NULL"));
  debug_fprintf (stdout, "-- %s\n", where);

  tablequalifier = NULL;	/* divide_tablename doesn't do its job */
  tableowner = NULL;		/* unless these two are NULL when called. */
/* Was:
    tablename = divide_tablename(UCP(tl->name),&tablequalifier,&tableowner);
 */
  tablename = divide_tablename_aux (UCP (tl->name), &scbTableName,
      &tablequalifier, &scbTableQualifier, &tableowner, &scbTableOwner);
  rc = SQLStatistics (stmt, tablequalifier, scbTableQualifier,
      tableowner, scbTableOwner, tablename, scbTableName, SQL_INDEX_ALL, SQL_ENSURE);

/* Note from ODBC API Help file:

   SQLStatistics returns information about a single table as
   a standard result set, ordered by NON_UNIQUE, TYPE, INDEX_QUALIFIER,
   INDEX_NAME, and SEQ_IN_INDEX. The result set combines statistics
   information for the table with information about each index.

   If the row in the result set corresponds to a table, the driver sets
   TYPE to SQL_TABLE_STAT and sets NON_UNIQUE, INDEX_QUALIFIER, INDEX_NAME,
   SEQ_IN_INDEX, COLUMN_NAME, and COLLATION  to NULL. If CARDINALITY or
   PAGES are not available from the data source, the driver sets them to
   NULL.

 */

  if (rc == SQL_SUCCESS)
    {
      SQLBindCol (stmt, 4,	/* NON_UNIQUE is SMALLINT: NULL, 0 or 1 */
	  SQL_C_SSHORT, &Non_Unique, 0, &cbNon_Unique);
      SQLBindCol (stmt, 6, SQL_C_CHAR, Index_Name, CHARCOL_LEN, &cbIndexName);
      SQLBindCol (stmt, 7,	/* TYPE is SMALLINT NOT NULL */
	  SQL_C_SSHORT, &Type, 0, &cbType);
      SQLBindCol (stmt, 8,	/* SEQ_IN_INDEX is SMALLINT: NULL, 1, 2, etc. */
	  SQL_C_SSHORT, &Seq_In_Index, 0, &cbSeq_In_Index);
      SQLBindCol (stmt, 9, SQL_C_CHAR, Column_Name, CHARCOL_LEN, &cbColumnName);



/* Note that this code doesn't work correctly in the hypothetical cases,
   where the index has more than one type specified, e.g. something
   like CLUSTERED HASHED. However, now CLUSTERED OBJECT_ID, etc. work.
 */

      for (count = 0, strcpy (Previous_Index_Name, ""), tmp1[0] = '\0';
/* cond */ TRUE;
/* update */ count++, strcpy (SCP (Previous_Index_Name), SCP (Index_Name)),
/* part: */ previous_one_was_primary_key = this_one_is_primary_key)
	{
	  rc = SQLFetch (stmt);
	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      break;
	    }
	  IF_ERR_GO (stmt, error, rc);
	  *indextype = '\0';	/* Clear the string. */
	backwards:
	  switch (Type)
	    {			/* Skip rows for table itself, because other cols are NULLs */
	    case SQL_TABLE_STAT:	/* 0 */
	      {
		continue;
	      }
	    case SQL_INDEX_CLUSTERED:	/* 1 */
	      {
		my_strncat (indextype, " CLUSTERED", CHARCOL_LEN);
		break;
	      }
	    case SQL_INDEX_HASHED:	/* 2 */
	      {
		my_strncat (indextype, " HASHED", CHARCOL_LEN);
		break;
	      }
	    case SQL_INDEX_OTHER:	/* 3 Normal, nothing special */
	      {			/* indextype = ""; */
		break;
	      }			/* Do nothing. */
	    default:
	      {
		if (Type & SQL_INDEX_OBJECT_ID)	/* 8 Kubl extension ? */
		  {
		    my_strncat (indextype, " OBJECT_ID", CHARCOL_LEN);
		    Type &= ~SQL_INDEX_OBJECT_ID;	/* Clear object_id bit */
		    if (Type)
		      goto backwards;	/* And go add rest. */
		  }		/* Type should be never returned as 8. If it is then
				   we might a catch the bug when we get the following warning
				   type concatenated after the keyword OBJECT_ID itself: */
		sprintf (indextype + strlen (indextype), " UNK-INDEX-TYPE(%d)", Type);
	      }
	    }

	  if (strcmp (SCP (Index_Name), SCP (Previous_Index_Name)))
	    {			/* indname changed? */
	      /* Save what has been collected to tmp1 to the right place: */
	      if (previous_one_was_primary_key)
		{
		  tl->primary_key_def = chestrdup (tmp1, where);
		}
	      else if (*tmp1)
		{
		  if (il)
		    {
		      il->index_def = chestrdup (tmp1, where);
		    }
		  else		/* This is the first index, and no index list has been
				   allocated yet, so save it to temp pointer variable
				   so that it can be later stored into the appropriate
				   place, after that place has been allocated. */
		    {
		      turnipsi_pointteri = chestrdup (tmp1, where);
		    }
		}
	      tmp1[0] = '\0';
	    }

	  /* This is for Access. I clear this later.
	   */
	  if (( /* NOT kubl_mode && */ !strcmp (SCP (Index_Name), "PrimaryKey")))
	    {
	      this_one_is_primary_key = 1;

	      if (*tmp1)
		{
		  strcat (tmp1, ",");
		}
	      strcat (tmp1, escapify (temp, SCP (Column_Name)));

	      if ((tl->primary_key_type == NULL) || empty_stringp (tl->primary_key_type))
		{
		  tl->primary_key_type = chestrdup (indextype, where);
		}
	    }

/* In Kubl mode just note the type of the primary key of the table
   encountered here, whose name has been saved to tl->primary_key_name
   when encountered previously with get_table_primarykey.
   This is for strange cases like
    create table ab(a integer, b varchar, primary key(a) clustered);
   We probably don't need to care about things like: primary key(a) unique
   because primary keys are unique anyway.
   Note that the primary key's name is not necessarily same as
   tl->table_name if the table has been later renamed with ALTER TABLE
   tab RENAME command, or if it is a subtable of another table.

   Changed 28-JAN-1998: Now effective also with other DBMS'ses
   than Kubl. However, only with Kubl we note the type of primary
   key index. E.g. with MS SQL Server, Primary Keys are always
   defined as:

   CREATE UNIQUE CLUSTERED INDEX PK__answer__1E8492F7
   ON kublbm.dbo.answer(a_user,a_qn_id,a_nth,a_q_name);

   So we don't print this redundant index anymore with MS SQL
   (as it is already defined in PRIMARY KEY(...) inside table-definition).
   However, we don't define it as PRIMARY KEY(...) CLUSTERED,
   because, as I understand, CLUSTERED has different meaning in
   Kubl and MS SQL.
 */
	  else if ( /* kubl_mode && */ tl->primary_key_name
	      && !strcmp (SCP (Index_Name), SCP (tl->primary_key_name)))
	    {
	      if (kubl_mode && ((tl->primary_key_type == NULL) || empty_stringp (tl->primary_key_type)))
		{
		  tl->primary_key_type = chestrdup (indextype, where);
		}
	    }
	  else			/* It's an index created with CREATE INDEX. */
	    {
	      this_one_is_primary_key = 0;
	      if (strcmp (SCP (Index_Name), SCP (Previous_Index_Name)))
		{		/* indname changed? */
		  if (tl->index_defs == NULL)	/* First index definition? */
		    {
		      il = tl->index_defs = (struct indexdeflist *) chemalloc (sizeof (struct indexdeflist), where);
		      if (turnipsi_pointteri)	/* Something for us? */
			{
			  il->index_def = turnipsi_pointteri;
			}
		    }
		  else
		    {
		      /* Update the next link of the prev node. */
		      il->next = (struct indexdeflist *) chemalloc (sizeof (struct indexdeflist), where);
		      il = il->next;
		    }

		  /* First column for this index? */
		  sprintf (tmp1, "CREATE%s%s INDEX %s ON ",
		      (((cbNon_Unique != SQL_NULL_DATA) && NOT Non_Unique)
			  ? " UNIQUE" : ""), indextype, escapify (temp, SCP (Index_Name)));
		  strcat (tmp1, escapify_and_form_dest_name (temp, (sizeof (temp) - 1), SCP (tl->name)));
		  strcat (tmp1, "(");
		  strcat (tmp1, escapify (temp, SCP (Column_Name)));

		  il->index_name = chestrdup (SCP (Index_Name), where);
		}
	      else		/* The second or further column for this index. */
		{		/* Just add the col name to the end of index definition: */
		  if (*tmp1)
		    {
		      strcat (tmp1, ",");
		    }
		  strcat (tmp1, escapify (temp, SCP (Column_Name)));
		}
	      il->next = NULL;

	    }			/* else it was an index created with CREATE INDEX. */

	}			/* for loop */

/* We still have to save what we have collected to tmp1 on
   the last round of the loop, to the appropriate place */
      if (previous_one_was_primary_key)
	{
	  tl->primary_key_def = chestrdup (tmp1, where);
	}
      else if (il && *tmp1)
	{
	  il->index_def = chestrdup (tmp1, where);
	}

    }				/* if(rc == SQL_SUCCESS) */

error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  return (count);
}

/* ================================================================== */
/*         FUNCTIONS FOR PRINTING OUT THE STUFF COLLECTED ABOVE       */
/* ================================================================== */

void
print_datetime_col (char *timebinstr, SQLLEN collen, int type)
{
  char temp[121];

  if (times_conform_to_odbc_flag)
    {
      if (times_to_strings_flag)
	sprintf (temp, "%*s", (int) collen, timebinstr);
      else if (type == SQL_DATE)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  TIMESTAMP_STRUCT *ts = ((TIMESTAMP_STRUCT *) timebinstr);
	  sprintf (temp, "%04d.%02d.%02d", ts->year, ts->month, ts->day);
	}
      else if (type == SQL_TIMESTAMP)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  TIMESTAMP_STRUCT *ts = ((TIMESTAMP_STRUCT *) timebinstr);
	  sprintf (temp, "%04d.%02d.%02d %02d:%02d.%02d %06ld",
	      ts->year, ts->month, ts->day, ts->hour, ts->minute, ts->second, (long) ts->fraction);
	}
      else if (type == SQL_TIME)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  TIMESTAMP_STRUCT *ts = ((TIMESTAMP_STRUCT *) timebinstr);

	  sprintf (temp, "%02d:%02d.%02d", ts->hour, ts->minute, ts->second);
	}
      else			/* Shouldn't happen! */
	{
	  sprintf (temp, "SHOULD NOT HAPPEN: print_date_col called(collen=%ld,type=%d)", (long int) collen, type);
	}
    }
  else				/* Native KUBL mode. */
    {
      struct tm *tm;
      struct timeval tv;
      time_t now;

      memcpy (&tv, timebinstr, sizeof (struct timeval));
      TV_TO_STRING (&tv);

      tm = localtime (&now);
      tv.tv_sec = (long) now;
      if (tm)
	{
	  sprintf (temp, "%04d.%02d.%02d %02d:%02d.%02d %06ld",
	      tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday, tm->tm_hour, tm->tm_min, tm->tm_sec, tv.tv_usec);
	}
      else			/* localtime returned NULL pointer. */
	{
	  sprintf (temp, "INV-TIME(%ld):%08lx:%08lx", (long) collen, tv.tv_sec, tv.tv_usec);
	}
    }

  switch (type)
    {
    case SQL_DATE:
    case SQL_TIMESTAMP:
      printf ("stringdate('%s')", temp);
      break;
    case SQL_TIME:
      printf ("stringtime('%s')", temp);
      break;
    default:
      printf ("%s", temp);
    }
  fflush (stdout);
}



#define print_string_col(s,len,eflag)\
  print_string_col_aux((s),(len),(eflag), 0, 0, NULL, NULL)

/*
   Prints the string s out, and for every single quote present
   prints two single quotes out, which is the standard SQL way of
   escaping a single quote.

   If flag use_backslash_escapes is present, then escape all
   non-printable characters by prefixing them with a backslash.

   This doesn't print the surrounding single quotes.

   The last four arguments are used solely when printing foreach
   stuff for blobs. There are additional quirks for them.

   Returns as a result the new value of chars_since_newline

   The corresponding unescaping function is unescape_string in isql.c
 */
long
print_string_col_aux (UCHAR * s, size_t length, int use_backslash_escapes,
    int is_foreach_blob, long chars_since_newline, char *end_token, char *blob_token)
{
  for (; length--; s++)
    {
      if ('\n' == *s)
	{
	  chars_since_newline = 0;
	}
      else
	{
	  chars_since_newline++;
	}

      if ((SQL_LONGVARCHAR == is_foreach_blob) && maxlinelength_for_foreach && (chars_since_newline >= maxlinelength_for_foreach))
	{
/* If over the allowed line length, then cut the string with \c cut
   escape sequence, and print a newline after that. (\c forces
   ISQL in turn to ignore the following newline, when it reads
   the stuff in with read_blob_from_input and unescape_string).
 */
	  printf ("\\c\n");
	  chars_since_newline = 0;
	}

#ifdef SQL_LONGVARBINARY
/* With binary blobs (got with type SQL_C_CHAR as hexadecimal dump,
   two hex-digits for each byte), we print a newline after every
   64 characters. This blob will be then read in with ISQL with
   FOREACH HEXADECIMAL BLOB INSERT INTO ... statement.
 */
      if ((SQL_LONGVARBINARY == is_foreach_blob) && (empty_stringp (s) ||	/* Either finished? Or... */
	      (maxhexlength_for_foreach &&	/* time to print a newline? */
		  (chars_since_newline >= maxhexlength_for_foreach))))
	{
	  if (empty_stringp (s))
	    {
	      break;
	    }
	  printf ("\n");
	  chars_since_newline = 0;
/* If hexadecimal digits finished, then break from the loop and return */
	}
#endif

/* If the line happens to begin with the end or blob token, then escape
   its first letter: */
      if ((1 == chars_since_newline) &&
	  ((end_token && !strncmp (SCP (s), end_token, strlen (SCP (end_token))))
	      || (blob_token && !strncmp (SCP (s), blob_token, strlen (SCP (blob_token))))))
	{
	  printf ("\\%o", *s);
	  continue;		/* Skip printing of *s in the end of the loop. */
	}
      if (use_backslash_escapes && ((*s != '\'') || NOT use_singlequote_escape))
	{
	  /* Escape everything that is not pure ascii, */
	  /* as well the backslash itself and the singlequote */
	  /* However, with blobs leave newlines as they are. */
	  if (((*s < 32) && (NOT (is_foreach_blob) || (*s != '\n'))) || (*s > 126) || (*s == '\\') || (*s == '\''))
	    {
/* If user gave more than one -e option, then escape also all
   visible ISO-8859/1 letters between 161-255: */
	      if ((use_backslash_escapes > 1) || (*s < 161))
		{
		  printf ("\\%o", *s);
		  continue;	/* Skip printing of *s in the end of the loop */
		}
	    }			/* if it wasn't escapable character, then we fall through. */
	}
      else			/* In SQL standard, we prefix each quote with another one. */
	{			/* And everything else, Vaya con Dios! */
	  if (*s == '\'')
	    {
	      putchar ('\'');
	    }
	}

      putchar (*s);
    }


  fflush (stdout);
  return (chars_since_newline);
}


#define BLOB_BUFFER_SIZE 4096

/* This should be different from all SQL return codes: */
#define PRINT_BLOB_COL__CALL_ME_AGAIN_RC 12345

/*
   print_blob_col either

   1) Prints out the whole blob column as a string literal, with
      appropriate escaping, depending of the global flag
      use_backslash_escapes_in_strings_flag

   2) or if the use_foreach_for_blobs global flag is on and
      the blob column is the ONLY or FIRST blob column on the row
      (if not, then prints it out just like in case 1)
      then checks whether really_do_it argument is

      A) zero (called first time), in which case just prints out
         the parameter marker ? in the middle of insert ... values(...),
         and returns the "private return code" value CALL_ME_AGAIN
         defined above.

      B) or really_do_it is non-zero (called second time for this column,
         after the whole insert statement has been printed), in which
         case outputs the blob data immediately after FOREACH BLOB INSERT
         statement with appropriate escape characters, regardless of the
         value of the global flag  use_backslash_escapes_in_strings_flag

         See function read_blob_from_input in isql.c how the stuff
         produced by this mode is later read in.

         If really_do_it is greater than 1, then the blob to be output
         is the last blob column, and so the delimiting token should
         be END instead of BLOB.

   Returns return code from the last SQLGetData done, or the kludgous
   value defined above.

 */
int
print_blob_col (UWORD n_col, struct coldeflist *cl, int really_do_it)
{
  UCHAR last_character = '\0';
  UCHAR blob_buffer[BLOB_BUFFER_SIZE + 3];
  size_t got_n_bytes;
  size_t total = 0;
  long chars_since_newline = -1;
  int rc;
  int type = cl->col_type;
  int use_foreach_now = (use_foreach_for_blobs_flag && (0 != cl->col_is_nth_blob));
  char *token_to_use = ((really_do_it > 1) ? foreach_end_token : foreach_blob_token);

  if (NOT really_do_it && use_foreach_now)
    {
      putchar ('?');		/* This time we output just a parameter marker. */
      /* And ask the caller to call us again when the whole INSERT
         statement (all other column literal values) has been printed. */
      return (PRINT_BLOB_COL__CALL_ME_AGAIN_RC);
    }

  if (NOT use_foreach_now)
    {
      putchar ('\'');
    }				/* The beginning single quote. */

  for (;;)
    {
      SQLLEN n_recv;
      rc = SQLGetData (stmt, n_col, SQL_C_CHAR, blob_buffer, ((SQLLEN) BLOB_BUFFER_SIZE), &n_recv);

/* Here we got either SQL_NO_DATA or an error. */
      if (((rc != SQL_SUCCESS) && (rc != SQL_SUCCESS_WITH_INFO)) || (n_recv == SQL_NULL_DATA))
	{			/* This ^ means really a blob of length 0, not real NULL ??? */
	  /* With foreach, just print the END token immediately after the
	     FOREACH BLOB INSERT statement, and ISQL will understand that
	     it is an empty blob: */
/* Tell calling function that everything is still all right, no panic: */
	  if (SQL_NO_DATA_FOUND == rc)
	    {
	      rc = SQL_SUCCESS;
	    }
	  if (use_foreach_now)
	    {
	      printf ("%s\n", token_to_use);
	    }
	  /* Otherwise, it is printed out as a string literal '': */
	  else
	    {
	      fputs ("'", stdout);
	    }			/* The ending quote. */
	  fflush (stdout);
	  return (rc);
	}

/* If we get SQL_NO_TOTAL, then we have to use strlen. This doesn't
    work with true binary data with null bytes in the last part. */
      got_n_bytes = ((rc == SQL_SUCCESS) ? ((n_recv != SQL_NO_TOTAL) ? n_recv : strlen (SCP (blob_buffer))) : BLOB_BUFFER_SIZE - 1);	/* Not the last part. */
/* When inputting binary blobs as hexadecimal dump, this will get the
   real length hexdigit string to be printed: */
#ifdef SQL_LONGVARBINARY
      if (SQL_LONGVARBINARY == type)
	{
	  got_n_bytes = strlen (SCP (blob_buffer));
	}
#endif

      total += got_n_bytes;
      blob_buffer[got_n_bytes] = '\0';	/* Make sure it is terminated. */
      if (got_n_bytes)
	{
	  last_character = blob_buffer[got_n_bytes - 1];
	}

/* Was: fwrite(blob_buffer,got_n_bytes,sizeof(char),stdout); */
/* With string literal blobs, always use the value of
   use_backslash_escapes_in_string_flag
   With foreach blobs use its value if it is not zero (in that case use 1)
 */
      chars_since_newline = print_string_col_aux (UCP (blob_buffer), got_n_bytes, ((use_backslash_escapes_in_strings_flag || NOT (use_foreach_now)) ? use_backslash_escapes_in_strings_flag : 1), (use_foreach_now ? type : 0),	/* is foreach blob? */
	  chars_since_newline, (use_foreach_now ? foreach_end_token : NULL), (use_foreach_now ? foreach_blob_token : NULL));

      if (rc == SQL_SUCCESS)	/* No more data after this one. */
	{
	  if (use_foreach_now)
	    {			/* If there were any stuff, and the last char was not a newline,
				   then print out the magic escape sequence \c (followed
				   by a newline) to cut the last line of blob at that point.
				   See unescape_string in ISQL.c for more information.
				   However, don't print that with binary blobs.
				 */
	      if (total && ('\n' != last_character)
#ifdef SQL_LONGVARBINARY
		  && (SQL_LONGVARBINARY != type)
#endif
		  )
		{
		  printf ("\\c\n");
		}
#ifdef SQL_LONGVARBINARY
/* Print the last newline after hexadecimal dump, if it is necessary: */
	      if ((SQL_LONGVARBINARY == type) && (chars_since_newline > 0))
		{
		  printf ("\n");
		}
#endif
	      printf ("%s\n", token_to_use);
	    }
	  else			/* Has been output as a string literal. */
	    {
	      putchar ('\'');
	    }			/* The ending single quote. */

	  return (rc);
	}
    }				/* for loop */

  return (rc);			/* Never reached */

}



#define MAXBLOBS_IN_ROW 101	/* Uhhuh. */
/* Returns either SQL_SUCCESS or the last return code returned by
   print_blob_col (which calls SQLGetData in the loop.) */
int
print_table_row (struct tabledeflist *tl)
{
  char temp[CHARCOL_LEN + 3];
  UWORD inx;
  struct coldeflist *cl;
/* Was:
  struct coldeflist *blob_column_to_be_printed_out_later = NULL;
  UWORD blob_colindex_to_be_printed_out_later = 0; */
  struct coldeflist *blob_columns_to_be_printed_out_later[MAXBLOBS_IN_ROW + 1];
  UWORD blob_colindexes_to_be_printed_out_later[MAXBLOBS_IN_ROW + 1];
  int n_blobs = 0;
  int rc = SQL_SUCCESS;

  if (use_foreach_for_blobs_flag && tl->contains_blobs)
    {
      printf ("FOREACH %sBLOB ",
#ifdef SQL_LONGVARBINARY
	  ((SQL_LONGVARBINARY == tl->contains_blobs) ? "HEXADECIMAL " : "")
#else
	  ""
#endif
	  );
    }

  printf ("INSERT %s %s(%s)",
      tl->insert_mode,
      escapify_and_form_dest_name (temp, (sizeof (temp) - 1), SCP (tl->name)), (tl->all_columns ? tl->all_columns : tl->columns));

  if (nicer_output_flag)
    {
      fputs ("\n ", stdout);	/* VALUES on its own line, indented */
    }
  else
    {
      putc (' ', stdout);
    }
  fputs ("VALUES(", stdout);

/* We should print a warning here if the length tl->col_defs and n_out_cols
   don't match. */
  for (inx = 0, cl = tl->col_defs; (inx < n_out_cols) && cl; inx++)
    {
      int tp = cl->col_type;
      if (out_cols[inx].o_col_len == SQL_NULL_DATA)
	{
	  fputs ("NULL", stdout);
	  fflush (stdout);
	}
      else
	{
	  switch (tp)
	    {
	    case SQL_NUMERIC:
	    case SQL_DECIMAL:
	    case SQL_DOUBLE:
	    case SQL_FLOAT:
	    case SQL_REAL:
	    case SQL_INTEGER:
	    case SQL_TINYINT:
	    case SQL_SMALLINT:
	    case SQL_BIGINT:
	    case SQL_BIT:
	      {			/* All the numeric types, don't use any single quotes! */
		fputs (out_cols[inx].o_buffer, stdout);
		fflush (stdout);
		break;
	      }
	    case SQL_DATE:
	    case SQL_TIME:
	    case SQL_TIMESTAMP:
	      {
		print_datetime_col (out_cols[inx].o_buffer, out_cols[inx].o_col_len, tp);
		break;
	      }
	    case SQL_LONGVARCHAR:
	    case SQL_LONGVARBINARY:
/* LONGVARBINARY works only if driver converts it into e.g. hexadecimal
   text that doesn't contain any null or other deviant bytes. */
	      {
		if (print_blobs_flag)
		  {		/* Note 0-based indexing here. print_blob_col needs one+ */
		    rc = print_blob_col (((UWORD) (inx + 1)), cl, 0);
		    if (rc == PRINT_BLOB_COL__CALL_ME_AGAIN_RC)
		      {
/*
                   blob_colindex_to_be_printed_out_later = (UWORD)(inx+1);
                   blob_column_to_be_printed_out_later = cl;
 */
			blob_colindexes_to_be_printed_out_later[n_blobs] = (UWORD) (inx + 1);
			blob_columns_to_be_printed_out_later[n_blobs] = cl;
			n_blobs++;
		      }
		    else if (SQL_SUCCESS != rc)
		      {
			return (rc);
		      }
		  }
		else
		  {
		    if (out_cols[inx].o_col_len == SQL_NO_TOTAL)
		      {
			strcpy (temp, "BLOB SQL_NO_TOTAL");
		      }
		    else
		      {
			sprintf (temp, "BLOB %ld b", out_cols[inx].o_col_len);
		      }
		    print_string_col (UCP (temp), strlen (temp), use_backslash_escapes_in_strings_flag);
		  }
		break;
	      }
	    default:
	      {			/* It's SQL_CHAR, SQL_VARCHAR, SQL_BINARY, SQL_VARBINARY
				   or something which needs to be surrounded with quotes. */
		SQLLEN real_len = out_cols[inx].o_col_len;

#ifdef SQL_VARCHAR
/* With SQL_VARCHARs the column length returned by the driver/API function
contains also a terminating zero byte. Let's correct it if it's not zero.
At least this was the case with old erroneous Kubl drivers.
However, with Access, the length doesn't include the terminating zero. */
		if ((SQL_VARCHAR == tp) && real_len && varchar_cols_returned_with_length_plus)	/* With old Kubl */
		  {
		    real_len -= varchar_cols_returned_with_length_plus;
		  }
#endif

		if (!cl->col_unquoted)
		  {
		    putchar ('\'');
		  }
		print_string_col (UCP (out_cols[inx].o_buffer), real_len, use_backslash_escapes_in_strings_flag);
		if (!cl->col_unquoted)
		  {
		    putchar ('\'');
		  }
		break;
	      }
	    }			/* switch */
	}			/* else it was not NULL */
      cl = cl->next;
      if (cl)
	{
	  putc (',', stdout);
	}			/* Not the last one? */
/*   if(inx < (n_out_cols-1)) { putchar(','); }  WAS THIS */
    }				/* for */
  printf (");\n");
  fflush (stdout);

/* This old mechanism allowed only one foreach blob per row:
  if(blob_column_to_be_printed_out_later)
   {
     rc = print_blob_col(blob_colindex_to_be_printed_out_later,
                         blob_column_to_be_printed_out_later,
                         1);
     fflush(stdout);
   }
 */
  if (n_blobs)
    {
      int i;
      for (i = 0; i < n_blobs; i++)
	{
	  rc = print_blob_col (blob_colindexes_to_be_printed_out_later[i], blob_columns_to_be_printed_out_later[i], 1 + (i == (n_blobs - 1)));	/* 2 on last blob. */
	  fflush (stdout);
	  if ((SQL_SUCCESS != rc))
	    {
	      return (rc);
	    }			/* Brutal! */
	}
    }


  return (rc);
}


/* Borrowed from isqlodbc.c REALLY, THESE SHOULD BE FLESHED OUT TO THE
   COMMON SUBMODULE, AS WELL AS N+1 OTHER COMMON OR ALMOST-COMMON
   SUBROUTINES USED BY BOTH DBDUMP.C and ISQLODBC.C
 */
#define not_escaped(C)\
 ( ((((unsigned char)(C))) != '\\') && ((((unsigned char)(C))) != '\'')\
   && (( ((((unsigned char)(C))) > 31) && ((((unsigned char)(C))) < 127) )\
      || ((((unsigned char)(C))) > 160) ) )

/* Was like this, but it is too conservative:
( ((((unsigned char)(C))) < 127) && (isalnum((C)) || ('_' == (C))) )
 */

/* The next two functions, escape_string and count_escaped_length
   should use exactly the same criteria for determining what
   to escape and how.
 */
unsigned char *
escape_string (unsigned char *dest, unsigned char *src)
{
  unsigned char *org_dest = dest;

  for (; *src; src++)
    {
      if ('\\' == *src)
	{
	  *dest++ = '\\';
	  *dest++ = '\\';
	}
      else if (not_escaped (*src))
	{
	  *dest++ = *src;
	}
      else			/* Needs backslash plus 3 octal digits. */
	{
	  sprintf (SCP (dest), "\\%03o", *((unsigned char *) src));
	  dest += 4;
	}
    }

  *dest = '\0';
  return (org_dest);
}



int
do_generic_dest_statement (HSTMT * ptr_to_gen_stmt, HDBC hdbc,	/* Datadest (Kubl) connection */
    HENV henv, char *statement_text)
{
				/*RETCODE */ int rc;
				/* Return Code for SQL operations, signed short */

  rc = SQLExecDirect (*ptr_to_gen_stmt, UCP (statement_text), SQL_NTS);

  IF_ERR_GO (*ptr_to_gen_stmt, error, rc);
error:
  return (rc);
}


/* Of course we should run the arguments through the function
   like escape_string in isqlodbc.c before printing them out
   with printf, in the case the output is really used for later
   feeding with isql(o).
   However, as long as there are no quotes nor newlines nor backslashes
   in datasource names, usernames, password and table names,
   it's all right. But with Access full-length tablenames we have
   backslashes! E.g. we might have "C:\CFUSION\DATABASE\cfexamples30"
   as the table qualifier (= database).

   When the stuff goes directly to the destination database
   with SQLExecute, then it doesn't matter so much, as the
   arguments are passed as string parameters, and may contain
   anything there ever might be.
 */

int
link_generic_operation (HSTMT * ptr_to_link_stmt, HDBC hdbc,	/* Datadest (Kubl) connection */
    HENV henv, char *datasource, char *second_arg, char *third_arg, char *output_template,	/* With 7 %s 's */
    char *statement_template)	/* With 3 ?'s */
{
  static char *last_output_template = NULL;
				/* RETCODE */ int rc;
				/* Return Code for SQL operations, signed short */
  SQLLEN cb_datasource = SQL_NTS, cb_second_arg = SQL_NTS, cb_third_arg = SQL_NTS;
  char tmp1buf[2501], tmp2buf[2501];	/* Enough is enough. */

  tmp1buf[0] = tmp2buf[0] = '\0';

  printf (output_template,
      datasource,
      (second_arg ? "'" : ""),
      (second_arg ? SCP (escape_string (UCP (tmp1buf), UCP (second_arg))) : "NULL"),
      (second_arg ? "'" : ""),
      (third_arg ? "'" : ""), (third_arg ? SCP (escape_string (UCP (tmp2buf), UCP (third_arg))) : "NULL"), (third_arg ? "'" : ""));


/* No connection to data destination allocated, so we exit here,
   after just printing the statement. */
  if (SQL_NULL_HDBC == hdbc)
    {
      return (SQL_SUCCESS);
    }

  if (output_template != last_output_template)	/* Statement changed? (or first time here) */
    {
      last_output_template = output_template;	/* Mark the new one. */

      if (SQL_NULL_HSTMT == *ptr_to_link_stmt)	/* First time here? */
	{
	  SQLAllocStmt (hdbc, ptr_to_link_stmt);	/* Allocate a stmt handle. */
	}

      /* Anyways, prepare the new statement: */
      rc = SQLPrepare (*ptr_to_link_stmt, UCP (statement_template), SQL_NTS);
      IF_ERR_GO (*ptr_to_link_stmt, error, rc);
    }

/* Bind the parameters every time, as they can point to different
   places at different times (although datasource is probably constant)
 */
  if (NULL == datasource)
    {
      cb_datasource = SQL_NULL_DATA;
    }
  rc = SQLBindParameter (*ptr_to_link_stmt,
      ((UWORD) 1), ((SWORD) SQL_PARAM_INPUT),
      ((SWORD) SQL_C_CHAR), ((SWORD) SQL_CHAR),
      ((SQLULEN) 0), ((SWORD) 0), ((PTR) datasource), ((SQLLEN) 0), ((SQLLEN *) & cb_datasource));
  IF_ERR_GO (*ptr_to_link_stmt, error, rc);

  if (NULL == second_arg)
    {
      cb_second_arg = SQL_NULL_DATA;
    }
  rc = SQLBindParameter (*ptr_to_link_stmt,
      ((UWORD) 2), ((SWORD) SQL_PARAM_INPUT),
      ((SWORD) SQL_C_CHAR), ((SWORD) SQL_CHAR),
      ((SQLULEN) 0), ((SWORD) 0), ((PTR) second_arg), ((SQLLEN) 0), ((SQLLEN *) & cb_second_arg));
  IF_ERR_GO (*ptr_to_link_stmt, error, rc);

  if (NULL == third_arg)
    {
      cb_third_arg = SQL_NULL_DATA;
    }
  rc = SQLBindParameter (*ptr_to_link_stmt,
      ((UWORD) 3), ((SWORD) SQL_PARAM_INPUT),
      ((SWORD) SQL_C_CHAR), ((SWORD) SQL_CHAR),
      ((SQLULEN) 0), ((SWORD) 0), ((PTR) third_arg), ((SQLLEN) 0), ((SQLLEN *) & cb_third_arg));
  IF_ERR_GO (*ptr_to_link_stmt, error, rc);

/* Okay, first time or not, now the parameters should have been bound. */

  rc = SQLExecute (*ptr_to_link_stmt);
  IF_ERR_GO (*ptr_to_link_stmt, error, rc);

error:;			/* Or not, here we come. */

  SQLFreeStmt (*ptr_to_link_stmt, SQL_RESET_PARAMS);
  return (rc);
}


int
link_remote_data_source (HSTMT * ptr_to_link_stmt, HDBC hdbc,	/* Datadest (Kubl) connection */
    HENV henv, char *datasource, char *username, char *password)
{
  return (link_generic_operation (ptr_to_link_stmt, hdbc, henv,
	  datasource, username, password,
	  "DB..vd_remote_data_source('%s','',%s%s%s,%s%s%s);\n", "DB..vd_remote_data_source(?,'',?,?)"));
}


int
link_local_and_remote_table (HSTMT * ptr_to_link_stmt, HDBC hdbc,	/* Datadest (Kubl) connection */
    HENV henv, char *datasource, char *local_name, char *remote_name)
{
  return (link_generic_operation (ptr_to_link_stmt, hdbc, henv,
	  datasource, local_name, remote_name,
	  "DB..vd_remote_table('%s',replace(%s%s%s,'\"',''),%s%s%s);\n", "DB..vd_remote_table(?,replace(?,'\"',''),?)"));
}

/*
   replace(?,'\"','') (that nukes the doublequotes)
    is unnecessary on the third argument (the original remote name)
    so we don't use it there.

   replace(NULL,'\"','') produces NULL

 */


char statement_text[65000];
/* For strncpy */
#define STMT_SPACE_REST ((sizeof(statement_text)-(indentation_length+100))-(statement_ptr-statement_text))

/* Note: the overflow checking of statement_text buffer is not yet
         really ready.
 */
int
print_table_definition_banner (struct tabledeflist *tl)
{
  int i, rc, indentation_length = 0;
  struct coldeflist *cl;
  char *statement_ptr;
  char *table_destname, tmp_for_destname[(MAXCOLNAME * 3) + 10];
  char tmp[(MAXCOLNAME * 3) + 10];
  char where[CHARCOL_LEN + 80];

  sprintf (where, "print_table_definition_banner(\"%s\")", (tl->name ? tl->name : "NULL"));

  table_destname = escapify_and_form_dest_name (tmp_for_destname, (sizeof (tmp_for_destname) - 1), SCP (tl->name));

  if (vd_procedures_flag)
    {
      rc = link_local_and_remote_table (&datadest_link_stmt, datadest_hdbc, henv, datasource, (table_destname + ('\\' == *table_destname)), NULL);	/* Unlink the old one. */

/* No success, e.g. there exists a local table with the same name */
      if (SQL_SUCCESS != rc)
	{
	  goto error;
	}
/*   IF_ERR_GO (datadest_link_stmt, error, rc); */
    }

  if (0 == dont_issue_drop_commands_flag)
    {
      sprintf (statement_text, "DROP TABLE %s", table_destname);
      printf ("%s;\n", statement_text);
      if (datadest_hdbc)
	{
	  rc = do_generic_dest_statement (&datadest_gen_stmt, datadest_hdbc, henv, statement_text);
	}
      /* Drop may fail, but we don't care. */
    }

  statement_ptr = statement_text;
  sprintf (statement_ptr, "CREATE TABLE %s(", table_destname);
  indentation_length = (int) strlen (statement_text);
  statement_ptr += indentation_length;


  /* Print column definitions.
     In case the option -P is specified and the table has no supertable,
     no primary key definition and no bestrow columns,
     we have to collect all non-blob columns to global tmp1 buffer
     and use that as a primary key.
     (Nobody else should meanwhile use tmp1 !!!)
   */
  for (tmp1[0] = '\0', cl = tl->col_defs; cl;)
    {
      if (primary_key_by_all_means_flag
	  && NO (tl->super_table)
	  && NO (tl->primary_key_def && *(tl->primary_key_def))
	  && NO (tl->bestrow_columns) && (cl->col_type != SQL_LONGVARCHAR) && (cl->col_type != SQL_LONGVARBINARY))
	{
	  if (*tmp1)
	    {
	      strcat (tmp1, ",");
	    }
	  strcat (tmp1, escapify (tmp, SCP (cl->col_name)));
	}

      /* First the column name: */
      strncpy (statement_ptr, escapify (tmp, cl->col_name), STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      *statement_ptr++ = ' ';

/* Then the datatype possibly with precision and NOT NULL definition. */
      strncpy (statement_ptr,
	  get_sql_col_type_def (cl->col_type, cl->col_precision, cl->col_scale, cl->col_nullable), STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      cl = cl->next;
/* Print a comma, in case this is not the last column, or even if it
   is but there still follows the UNDER supertable
   or a primary key definition for this table. */
      if (cl || tl->super_table || (tl->primary_key_def && *(tl->primary_key_def)) || primary_key_by_all_means_flag)
	{
	  *statement_ptr++ = ',';
	  if (nicer_output_flag)	/* (... && !cl) -> only PK indented. */
	    {
	      *statement_ptr++ = '\n';
	      for (i = 0; i < indentation_length; i++)
		{
		  *statement_ptr++ = ' ';
		}
	    }
	}
    }

  if (tl->super_table)
    {
      strncpy (statement_ptr, "UNDER ", STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      strncpy (statement_ptr, escapify_and_form_dest_name (tmp, (sizeof (tmp) - 1), SCP (tl->super_table)), STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
    }

/* There shouldn't exist any tables with both super table and primary key,
   but in case there are, it is easier to catch the bugs when we leave
   the following clause as if, instead of else if
 */
  if (tl->primary_key_def && *(tl->primary_key_def))
    {
      strncpy (statement_ptr, "PRIMARY KEY(", STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      strncpy (statement_ptr, tl->primary_key_def, STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      *statement_ptr++ = ')';
      strncpy (statement_ptr, tl->primary_key_type, STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
    }
  else if (primary_key_by_all_means_flag && NO (tl->super_table))
    {
      char *pk_cols = NULL;
      struct indexdeflist *first_unique_index = find_first_index_like (tl->index_defs, "CREATE UNIQUE ");
      if (first_unique_index && (NULL != (pk_cols = strchr (first_unique_index->index_def, '('))))
	{
	  pk_cols++;		/* Past the opening parenthesis */
	}
      else if (tl->bestrow_columns)
	{
	  pk_cols = tl->bestrow_columns;
	}
      else
	{
	  pk_cols = tmp1;
	}			/* Collected above, all non-blob columns */

      strncpy (statement_ptr, "PRIMARY KEY(", STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      strncpy (statement_ptr, pk_cols, STMT_SPACE_REST);
      statement_ptr += strlen (statement_ptr);
      *statement_ptr++ = ')';
    }

  *statement_ptr++ = ')';	/* The last parenthesis. */
  *statement_ptr++ = '\0';	/* And the statement text is terminated. */

  fputs (statement_text, stdout);
  fputs (";\n", stdout);

  if (datadest_hdbc)
    {
      rc = do_generic_dest_statement (&datadest_gen_stmt, datadest_hdbc, henv, statement_text);
      if (SQL_SUCCESS != rc)
	{
	  goto error;
	}			/* Create table failed? */
    }

  if (vd_procedures_flag)
    {
      char *remote_name = compose_whole_tablename (tl, tmp, (sizeof (tmp) - 3));

      rc = link_local_and_remote_table (&datadest_link_stmt,
	  datadest_hdbc, henv, datasource, (table_destname + ('\\' == *table_destname)), remote_name);
      if (SQL_SUCCESS != rc)
	{
	  goto error;
	}			/* Linking failed? */
    }

  if (nicer_output_flag)
    {
      putc ('\n', stdout);
    }
  fflush (stdout);
  return (1);
error:
/* Save the error state and message to this table's node,
   so that we can later produce a summary of errors
   (with function check_for_failed_tables):
 */
  tl->last_SQL_state = chestrdup (SQL_error_state, where);
  tl->last_SQL_message = chestrdup (SQL_error_message, where);

  fflush (stdout);
  return (0);

}

/* Returns the number of columns if succeeded, otherwise returns zero. */
/* The second argument, for_contents_flag is non-zero when this
   is called for really dumping the contents of the table out
   (probably second time, if this has been also called for getting
   the columns of the table, with for_contents_flag zero).
 */
int
do_select_for_table (struct tabledeflist *tl, int for_contents_flag)
{
  int rc;
  char tmp[CHARCOL_LEN + 5];

/* Now use the spacious global buffer tmp1 for holding the select
   statement string, as it can grow very long when dumping super-tables
   with many subtables.

   Of course here we should use
    compose_whole_tablename(tl,tmp,(sizeof(tmp)-2))
   to get valid tablename-expressions for all kinds of exotic databases.
 */
  sprintf (tmp1, select_statement_template, (never_escape_tablenames_in_select ? tl->name : escapify (tmp, tl->name)));

/* The third arg was: (use_sql_describe_flag ? "*" : tl->columns), */

  if (for_contents_flag)
    {
      if (tl->sub_tables)
	{
	  size_t length_before = strlen (tmp1);
	  size_t enough_space = make_where_clause_for_table_with_children (tmp1, tl,
	      sizeof (tmp1) - 10);
	  if (NOT enough_space)
	    {
	      struct subtablelist *sl;
	      fprintf (stdout, "-- do_select_for_table: Not enough space (only %ld bytes) to hold:\n-- ", (long) sizeof (tmp1));
	      puts (tmp1);	/* This adds the newline ? Hope so. */
	      fprintf (stdout, "-- Dumping the subtables with the REPLACING option instead.\n");
	      tmp1[length_before] = '\0';	/* Restore original version. */
	      for (sl = tl->sub_tables; sl; sl = sl->next)
		{
		  sl->sub_table->insert_mode = "REPLACING";
		}
	    }
	}
    }

  if (for_contents_flag && verbose_flag)	/* Show the select statement. */
    {
      fprintf (stdout, "-- %s\n", tmp1);
      fflush (stdout);
    }

  rc = SQLExecDirect (stmt, UCP (tmp1), SQL_NTS);

  IF_ERR_GO (stmt, error, rc);
  if (rc == SQL_NO_DATA_FOUND)	/* This shouldn't cause an error, but just */
    {
      goto error;
    }				/* frees the handles and returns zero. */

  rc = SQLNumResultCols (stmt, &n_out_cols);
  IF_ERR_GO (stmt, error, rc);

  if (n_out_cols == 0)
    {
      fprintf (stdout, "-- Table %s has %d columns which is very strange indeed!\n", tl->name, n_out_cols);
      return (0);
    }
  else if (n_out_cols > MAX_COLS)
    {
      fprintf (stdout, "-- Table %s has %d columns > max. %d, truncated!\n", tl->name, n_out_cols, MAX_COLS);
      n_out_cols = MAX_COLS;
    }

  return (n_out_cols);

error:;

/* No! Don't free anything here, because we might get
Error S1010: [Microsoft][ODBC Driver Manager] Function Sequence Error.
   Instead, it is the responsibility of the calling function
   (either get_and_print_table_defition, or print_table_contents)
   to do that when it receives zero as a return value.

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if(SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
   {
     print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
   }
 */

  return (0);
}


int
get_and_print_table_defition (struct tabledeflist *tl, int print_it_also)
{
  int n_cols;

  debug_fprintf (stdout, "-- get_and_print_table_defition(%s,%d)\n", tl->name, print_it_also);
  if (use_sql_describe_flag)
    {
      n_cols = do_select_for_table (tl, 0);
      if (0 == n_cols)
	goto error;
      get_table_columns (tl, n_cols);	/* Get them with SQLDescribeCol */
    }
  else
    {
      n_cols = get_table_columns (tl, 0);
    }				/* Get them with SQLColumns */

  if (print_it_also)
    {
      print_table_definition_banner (tl);
    }

  return (n_cols);

error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
    }

  return (0);
}


/* This should be called immediately after
     get_and_print_table_defition and print_indexdeflist
 */
int
print_table_contents (struct tabledeflist *tl)
{
  SWORD btype;
  UWORD inx;
  int n_rows = 0, n_cols = 0, rc;
  struct coldeflist *cl;

  char where[CHARCOL_LEN + 80];

  sprintf (where, "print_table_contents(\"%s\")", (tl->name ? tl->name : "NULL"));

  debug_fprintf (stdout, "-- %s\n", where);

  if (0 == use_sql_describe_flag)	/* We still have to do select. */
    {
      n_cols = do_select_for_table (tl, 1);
      if (0 == n_cols)
	goto error;		/* Not really an error, just skip printing. */
/* If this is a subtable of another table (tl->super_table is not null)
   then we have to reread the column information, this time including
   all the columns, also the columns of all ancestor tables, which are
   get with SQLDescribeCol (in get_table_columns) after the select *
   statement done above.
   Well, actually we have to do it always, because select * might
   return columns in different order as SQLColumns (at least that is
   the case with Access).
 */
/*   if(tl->super_table)   Always do it anyway */
      {
	tl->contains_blobs = 0;	/* Clear the blob counter/flag. */
	tl->col_defs = NULL;	/* Clear the old column definition list. */
	get_table_columns (tl, n_cols);	/* As we are reading them again. */
      }
    }

  /* First bind the column contents buffers. */
  /* We should print a warning here if the length tl->col_defs and
     n_out_cols don't match. */

  for (inx = 1, cl = tl->col_defs; (inx <= n_out_cols) && cl; inx++, cl = cl->next)
    {
      stmt_out_t *out = &out_cols[inx - 1];

      if (NO out->o_buffer)
	{
	  out->o_buffer = (char *) chemalloc (maxcolumn_width + 2, where);
	}

      if (NO times_to_strings_flag && ((cl->col_type == SQL_TIMESTAMP) || (cl->col_type == SQL_DATE) || (cl->col_type == SQL_TIME)))
	{
	  btype = SQL_C_TIMESTAMP;
	}
      else
	{
	  btype = SQL_C_CHAR;
	}

      if (bind_blobs_flag || ((SQL_LONGVARCHAR != cl->col_type) && (SQL_LONGVARBINARY != cl->col_type)))
	{
	  rc = SQLBindCol (stmt, inx, btype, out->o_buffer, ((SQLLEN) maxcolumn_width), &out->o_col_len);
	  IF_ERR_GO (stmt, error, rc);
	}
    }				/* for loop over column list tl->col_defs. */

  for (;;)
    {
      rc = SQLFetch (stmt);
      if (rc == SQL_NO_DATA_FOUND)
	break;
      IF_ERR_GO (stmt, error, rc);
      n_rows++;
      rc = print_table_row (tl);
      IF_ERR_GO (stmt, error, rc);
    }

error:;

  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
    }

  return (n_rows);
}


int
print_indexdeflist (struct tabledeflist *tl)
{
  struct indexdeflist *il;
  int count = 0;
  char tmp[MAXCOLNAME + 5];

  for (il = tl->index_defs; il; il = il->next)
    {
/* Check if the index name appears in one of the ancestor tables
   of this table (either as primary key name or some other index),
   and if it is so, then skip printing of this index, thus avoiding
   duplicate indices: */
      if (index_has_been_defined_for_supertable (il->index_name, tl))
	{
	  continue;
	}
/* If the user dumps out only index definitions without table definitions,
   then we have to prefix each index definition (in case that -r
   option has not been given) with corresponding DROP INDEX statement.
   But if the table definitions are printed also, then each
   DROP TABLE will drop all of its indices too.
 */
      if (NO only_table_definitions_flag && NO dont_issue_drop_commands_flag)
	{
	  printf ("DROP INDEX %s;\n", escapify (tmp, il->index_name));
	}

/* Here we print the ending parenthesis, semicolon and newline also: */
      printf ("%s);\n", il->index_def);
      count++;
    }
  fflush (stdout);

  return (count);
}

/* Pointer to Function returning int, having one tabledeflist and one int
   as its arguments. */
typedef int (*PFI_TABLEDEFLIST) (struct tabledeflist *, int);

int
output_one_table (struct tabledeflist *this_table, int sublevel)
{
  int rows = 0, indices = 0, cols = 0;
  struct subtablelist *sl;
  int save_only_table_definitions_flag = 0;
  int save_only_index_definitions_flag = 0;
  int save_only_contents_flag = 0;

  /* Implicitly included supertable of some subtable? */
  if (this_table->automatically_included)
    {
      save_only_table_definitions_flag = only_table_definitions_flag;
      save_only_index_definitions_flag = only_index_definitions_flag;
      save_only_contents_flag = only_contents_flag;

      only_table_definitions_flag = auto_only_table_definitions_flag;
      only_index_definitions_flag = auto_only_index_definitions_flag;
      only_contents_flag = auto_only_contents_flag;
    }

  cols = get_and_print_table_defition (this_table,
/* Print it only if this flag is on: */ only_table_definitions_flag);

  if (only_index_definitions_flag)
    {
      indices = print_indexdeflist (this_table);
    }
  debug_fprintf (stdout, "-- Table %s %d columns, %d indices output, level %d.\n", this_table->name, cols, indices, sublevel);
  if (only_contents_flag && cols)
    {
      rows = print_table_contents (this_table);
      if (verbose_flag)
	{
	  fprintf (stdout, "-- Table %s %d rows output.\n", this_table->name, rows);
	}
    }

  if (this_table->automatically_included)	/* Restore the normal settings. */
    {
      only_table_definitions_flag = save_only_table_definitions_flag;
      only_index_definitions_flag = save_only_index_definitions_flag;
      only_contents_flag = save_only_contents_flag;
    }

  /* Print its possible subtables. */
  for (sl = this_table->sub_tables; sl; sl = sl->next)
    {
      output_one_table (sl->sub_table, (sublevel + 1));
    }


  return (1);
}

int
output_tables_with (struct tabledeflist *tl, PFI_TABLEDEFLIST out_fun)
{
  for (; tl; tl = tl->next)
    {
      if (tl->super_table)
	{
	  continue;
	}			/* Skip subtables on top level */
      (out_fun) (tl, 0);
    }

  return (1);
}


int
output_tables (struct tabledeflist *tl)
{
  return (output_tables_with (tl, output_one_table));
}


/* Outputs subtables with indentation, according to sublevel. */
int
output_one_table_as_option (struct tabledeflist *this_table, int sublevel)
{
  int i;
  struct subtablelist *sl;
  char *one_space = "&nbsp;&nbsp;&nbsp;";	/* Actually three, looks better */
  char few_spaces[381];

  for (i = 0; (i < sublevel) && (i < (sizeof (few_spaces) - 1)); i++)
    {
      strcpy (&few_spaces[i], one_space);
      i += (int) (strlen (one_space));
    }
  few_spaces[i] = '\0';

  printf ("<OPTION VALUE=\"%s\">%s%s\n", this_table->name, few_spaces, this_table->name);

  /* And then print its possible subtables. */
  for (sl = this_table->sub_tables; sl; sl = sl->next)
    {
      output_one_table_as_option (sl->sub_table, (sublevel + 1));
    }

  return (1);
}


int
output_tables_as_select_list (struct tabledeflist *tl, int list_size)
{
  int rc;

  printf
      ("<SELECT NAME=\"S_TABLES\" MULTIPLE onchange=\"add_selected_items_to_the_text_elem(this,this.form.tablename)\" SIZE=%d>\n",
      list_size);

  rc = (output_tables_with (tl, output_one_table_as_option));

  printf ("</SELECT>\n");
  fflush (stdout);

  return (1);
}

int
output_tablelist_token (int list_size)
{
  if (flag_get_list_of_tables)
    {
      return (output_tables_as_select_list (all_tables_list, list_size));
    }
  else
    {
      printf ("<INPUT TYPE=SUBMIT NAME=\"RTL\" VALUE=\"Show List\" "
	  " onclick=\"select_option_with_value(this.form.OPCODE,'RTL'); check_radiobutton_with_value(this.form.OPTION_qv,'q')\">\n");
      fflush (stdout);
      return (1);
    }
}


/* ================================================================== */
/*  TWO FUNCTIONS FOR PARSING URL QUERY STRINGS & COMMAND LINE ARGS   */
/* ================================================================== */



/* The following two functions were taken from AK's conjugate software,
   module conjtest.cpp.

 */
UCHAR *
parse_url_value (UCHAR * url_piece)
{
  UCHAR *s, *t;
  UCHAR save_char;
  unsigned int tmp;

  s = t = url_piece;

  while (*s)
    {
      switch (*s)
	{
	case '+':
	  {
	    *t++ = ' ';
	    s++;
	    break;
	  }			/* Plus signs to spaces */
	case '%':
	  {			/* Double %% can be used for escaping a percent sign itself */
	    if (*(s + 1) == '%')
	      {
		*t++ = '%';
		s += 2;
	      }
	    else if (NOT isalnum (*(s + 1)))	/* Not followed by hex digits? */
	      {
		*t++ = *s++;
	      }
	    else if (strlen ((char *) s) >= 3)
	      {
		save_char = *(s + 3);
		*(s + 3) = '\0';
		/* Convert two hex digits to int */
		sscanf (((const char *) s + 1), "%x", &tmp);
		*(s + 3) = save_char;
		*t++ = ((UCHAR) tmp);
		s += 3;
	      }
	    else		/* Copy the trailing percent signs literally. */
	      {
		*t++ = *s++;
	      }
	    break;
	  }
	default:
	  {
	    *t++ = *s++;
	    break;
	  }
	}
    }

  *t = '\0';
  return (url_piece);
}

/* Finds the next delimiter character in the query string. It is currently
   either an ampersand or a slash. If neither of them found returns NULL */
char *
next_delimiter (char *str)
{
  char *dp1, *dp2;

  dp1 = strchr (str, '&');	/* Stupid... */
  dp2 = strchr (str, '/');
  if (dp1 && (NO dp2 || (dp1 <= dp2)))
    {
      return (dp1);
    }
  if (dp2)
    {
      return (dp2);
    }
  return (NULL);
}

/* Appends contents of ptr2 (a URL-encoded string) after the old value
   of item, comma-separated.
   Uses tmp1 as a temporary buffer.
 */
char *
append_to_specval (char *item, char *ptr2, char *where)
{
  if (*ptr2)
    {
      if (item)			/* There are more than one type specifiers, */
	{			/* and this is not the first one. */
	  sprintf (tmp1, "%s,%s", SCP (item), SCP (parse_url_value (UCP (ptr2))));
	  free (item);		/* The old version. */
	  item = chestrdup (SCP (tmp1), where);
	}
      else			/* First item. */
	{
	  item = chestrdup (SCP (parse_url_value ((UCHAR *) (ptr2))), where);
	}
    }
  return (item);
}


/* Returns an error message if something fails, otherwise returns NULL */
char *
parse_url_query_string (char *query_string)	/* input */
{
  char *ptr1, *ptr2, *ptr3;
  char *parse_url_error_message = NULL;
  unsigned int count = 0;
  int convdst;			/* A flag, either 0 or 1. */

  char where[3005];

  strcpy (where, "parse_url_query_string(\"");
  my_strncat (where, (query_string ? query_string : "NULL"), sizeof (where) - 5);
  my_strncat (where, "\")", sizeof (where) - 5);
  where[sizeof (where) - 5] = '\0';

  ptr1 = query_string;
  while (ptr1)
    {
      if (NOT (ptr2 = (strchr (((char *) ptr1), '='))))
	{
	  break;
	}
      if ((ptr3 = (next_delimiter (((char *) ptr2)))))
	{
	  *ptr3++ = '\0';
	}			/* Overwrite the ampersand, and skip past. */
      *ptr2++ = '\0';		/* Overwrite the equal sign, and skip past. */
/* ptr1 points to the beginning of the variable name.
   ptr2 points two characters past the end of the variable name, i.e. one
    past the equal sign (=) which has been overwritten by zero '\0',
    that is to the beginning of the variable value, corresponding to
    variable name where ptr1 points to.
   ptr3 points two characters past the end of variable value, i.e. one
    past the ampersand (&) which has been overwritten by zero, that is
    to the beginning of the next variable name. Or if we have found the
    last name=value pair, then it contains the NULL.
 */
      if (!strcasecmp (((char *) ptr1), "tablequalifier"))
	{			/* Also if ptr2 is an empty string. */
	  if (*ptr2)
	    tablequalifier = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "tableowner"))
	{
	  if (*ptr2)
	    tableowner = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "tablename"))
	{
	  if (*ptr2)
	    tablename = SCP (append_to_specval (tablename, ptr2, where));
/* Was:   if(*ptr2) tablename = SCP(parse_url_value((UCHAR *)(ptr2))); */
	}
      else if (!strcasecmp (((char *) ptr1), "tabletype"))
	{
	  if (*ptr2)
	    tabletype = SCP (append_to_specval (tabletype, ptr2, where));
	}
      else if (!strcasecmp (((char *) ptr1), "new_name"))
	{
	  if (*ptr2)
	    new_name = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "unquoted_columns"))
	{
	  if (*ptr2)
	    unquoted_columns = SCP (append_to_specval (unquoted_columns, ptr2, where));
	}
      else if (!strcasecmp (((char *) ptr1), "username") || !strcasecmp (((char *) ptr1), "s_conuser"))
	{
	  if (*ptr2)
	    username = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "empty_username"))
	{
	  if (*ptr2)
	    {
	      username = "";
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "password") || !strcasecmp (((char *) ptr1), "s_conpass"))
	{
	  if (*ptr2)
	    password = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "empty_password"))
	{
	  if (*ptr2)
	    {
	      password = "";
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "datasource") || !strcasecmp (((char *) ptr1), "s_datasource"))
	{
	  if (*ptr2)
	    datasource = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "datadest") || !strcasecmp (((char *) ptr1), "s_datadest"))
	{
	  if (*ptr2)
	    datadest = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "s_dstuser"))
	{
	  if (*ptr2)
	    dest_username = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "s_empty_dstuser"))
	{
	  if (*ptr2)
	    {
	      dest_username = "";
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "s_dstpass"))
	{
	  if (*ptr2)
	    dest_password = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "s_empty_dstpass"))
	{
	  if (*ptr2)
	    {
	      dest_password = "";
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "insert_mode"))
	{
	  if (*ptr2)
	    default_insert_mode = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "content_type"))
	{
	  if (*ptr2)
	    web_content_type = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (((convdst = 0), !strncasecmp (((char *) ptr1), "convsrc", 7))
	  || ((convdst = 1), !strncasecmp (((char *) ptr1), "convdst", 7)))
	{
	  int n = atoi (ptr1 + 7);
	  if ((n < 1) || (n > MAX_CONVERSIONS))
	    {
	      sprintf (tmp1,
		  "%s-- Conversion option %s is invalid. N must be between 1 and %d!\n",
		  (parse_url_error_message ? parse_url_error_message : ""), ptr1, MAX_CONVERSIONS);
	      if (parse_url_error_message)
		{
		  free (parse_url_error_message);
		}
	      parse_url_error_message = chestrdup (tmp1, where);
	    }
	  else if (*ptr2)
	    {
	      conv_types_table[(2 * n) + convdst] = SCP (parse_url_value (UCP (ptr2)));
	      if (n > n_conv_types)
		{
		  n_conv_types = n;
		}		/* Keeps the max n encountered. */
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "init"))
	{
	  if (*ptr2)
	    init_statement = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "RTL"))
	{
	  if (*ptr2)
	    {
	      flag_get_list_of_tables = 1;
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "RTL2"))
	{
	  if (*ptr2)
	    {
	      flag_get_list_of_tables = 1;
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "OPCODE"))
	{
	  if (!strcasecmp (((char *) ptr2), "RTL"))
	    {
	      flag_get_list_of_tables = 1;
	    }
	}
      else if (!strcasecmp (((char *) ptr1), "select"))
	{			/* User wants to override the default select statement. */
	  /* The template may contain one %s place marker for table name */
	  if (*ptr2)
	    select_statement_template = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "endtoken"))
	{			/* User wants to override the default end token "END" */
	  if (*ptr2)
	    foreach_end_token = SCP (parse_url_value ((UCHAR *) (ptr2)));
	}
      else if (!strcasecmp (((char *) ptr1), "foreach_maxhexlen"))
	{
	  if (*ptr2)
	    maxhexlength_for_foreach = atol (SCP (parse_url_value ((UCHAR *) (ptr2))));
	}
      else if (!strcasecmp (((char *) ptr1), "foreach_maxlinelen"))
	{
	  if (*ptr2)
	    maxlinelength_for_foreach = atol (SCP (parse_url_value ((UCHAR *) (ptr2))));
	}
      else if (!strcasecmp (((char *) ptr1), "maxcolumn_width"))
	{
	  if (*ptr2)
	    maxcolumn_width = atol (SCP (parse_url_value ((UCHAR *) (ptr2))));
	}
/* If there were nothing before an equal sign, then it's probably
   converted from a dash -, i.e. it's an option given from the
   command line. */
      else if (!*ptr1 || !strncasecmp (((char *) ptr1), "option", 6))
	{
	  int oppo = 0;
	  UCHAR *s = parse_url_value ((UCHAR *) (ptr2));
	  if ('+' == *s)
	    {
	      oppo = 1;
	      s++;
	    }
	  for (; *s; s++)
	    {
	      switch (*s)	/* Stupid idea: tolower(*s) */
		{
		case 'D':
		  {
		    dbdump_debug_level++;
		    break;
		  }
		case 'B':
		  {
		    bind_blobs_flag = (1 ^ oppo);
		    break;
		  }
		case 'A':
		  {
		    all_or_nothing_flag++;
		    break;
		  }
		case 'a':
		  {
		    never_escape_tablenames_in_select = (surround_with_flag == 0);
		    surround_with_flag = '"';
		    break;
		  }
		case 'b':
		  {
/* Was like this:
                   backslashify_always_flag++;
                   never_escape_tablenames_in_select
                     = (backslashify_always_flag < 2);
 */
		    never_escape_tablenames_in_select = (prefix_with_flag == 0);
		    prefix_with_flag = '\\';
		    break;
		  }
		case 'd':
		  {
		    use_sql_describe_flag = 1;
		    break;
		  }
		case 'K':
		  {
		    kubl_default_conversions_flag = 1;
		    break;
		  }
		case 'P':
		  {
		    primary_key_by_all_means_flag++;
		    break;
		  }
		case 'U':
		  {
		    universal_transfer_flag++;
		    break;
		  }
		case 'V':
		  {
		    vd_procedures_flag++;
		    break;
		  }
		case 'N':
		  {
		    nicer_output_flag++;
		    break;
		  }
		case 'p':
		  {
		    use_table_prefixes_flag = (0 ^ oppo);
		    use_table_prefixes_flag_given = 1;
		    break;
		  }
		case 't':
		  {
		    only_table_definitions_flag = 1;
		    break;
		  }
		case 'i':
		  {
		    only_index_definitions_flag = 1;
		    break;
		  }
		case 'c':
		  {
		    only_contents_flag = 1;
		    break;
		  }
		case 'T':
		  {
		    auto_only_table_definitions_flag = 1;
		    break;
		  }
		case 'I':
		  {
		    auto_only_index_definitions_flag = 1;
		    break;
		  }
		case 'C':
		  {
		    auto_only_contents_flag = 1;
		    break;
		  }
		case 'q':
		  {
		    verbose_flag = 0;
		    break;
		  }		/* Q as Quiet */
		case 'v':
		  {
		    verbose_flag = 1;
		    break;
		  }		/* V as Verbose */
		case 'l':
		  {
		    list_data_sources_flag = 1;
		    break;
		  }
		case 'h':
		  {
		    dump_html_template_file_flag++;
		    break;
		  }
/* I.e. we can use -ne to force both use_singlequote_escape and
                                     use_backslash_escapes_in_strings on
   so that doubling singlequotes has priority over backslashifying.
   See function print_string_col_aux. */
		case 'e':
		  {
		    use_backslash_escapes_in_strings_flag++;
		    break;
		  }
		case 'n':
		  {
		    use_backslash_escapes_in_strings_flag = 0;
		    use_singlequote_escape = 1;
		    break;
		  }
		case 'r':
		  {
		    dont_issue_drop_commands_flag = 1;
		    break;
		  }
/* -s: Keep all blobs as string literals, don't use foreach contraption: */
		case 's':
		  {
		    use_foreach_for_blobs_flag = 0;
		    break;
		  }
		default:
		  {
		    break;
		  }
		}
	    }
	}

      ptr1 = ptr3;
      count++;
    }

  return (parse_url_error_message);
}

/* ================================================================== */
/*                       MAIN & related                               */
/* ================================================================== */




int
driver_has_necessary_sql_functions ()
{
  UWORD TablesExists = TRUE, ColumnsExists = TRUE, FunctionExists = TRUE;

  fflush (stdout);
  SQLGetFunctions (hdbc, SQL_API_SQLTABLES, &TablesExists);
  if (0 == TablesExists)
    {
      fprintf (stderr, "-- Sorry, this driver doesn't implement SQLTables. Goodbye!\n");
      exit (1);
    }
  SQLGetFunctions (hdbc, SQL_API_SQLCOLUMNS, &ColumnsExists);
  if (0 == ColumnsExists)
    {
      fprintf (stderr, "-- Hmmm, this driver doesn't implement SQLColumns. Trying to use SQLDescribeCol instead.\n");
      use_sql_describe_flag = 1;
    }
  SQLGetFunctions (hdbc, SQL_API_SQLDESCRIBECOL, &FunctionExists);
  if (0 == FunctionExists)
    {
      fprintf (stderr, "-- Haa! this driver doesn't implement SQLDescribeCol either. Goodbye!\n");
      exit (1);
    }
  SQLGetFunctions (hdbc, SQL_API_SQLSTATISTICS, &FunctionExists);
  if (0 == FunctionExists)
    {
      fprintf (stderr, "-- Sorry, this driver doesn't implement SQLStatistics. Can't get index information.\n");
      only_index_definitions_flag = 0;
    }

  fflush (stderr);
  return (1);
}


#if defined(UNIX) && !defined(UNIX_ODBC)	/* && !defined(UDBC) */
#define USE_TEXTFIELD_DATASOURCE
#endif


#ifdef USE_TEXTFIELD_DATASOURCE

/* Neither ODBC nor UDBC, no way to know available data sources in
   this machine. (Probably running in Unix). */
int
list_data_sources (int for_html, char *templatename, char *tagname)
{
  char *selected_datasource = NULL;

  if (!strcmp (templatename, DEFAULT_HTML_TEMPLATE_FILE))	/* Using main template? */
    {
      selected_datasource = datasource;
    }

  if (!strcmp (tagname, DATADEST_TOKEN))
    {
      selected_datasource = "";
    }

  if (for_html)
    {
      printf ("<INPUT NAME=%s TYPE=TEXT VALUE=\"%s\">\n",
	  (!strcmp (tagname, DATADEST_TOKEN) ? "S_DATADEST"
	      : "S_DATASOURCE"), (selected_datasource ? selected_datasource : DEFAULT_DATASOURCE_IN_UNIX));
    }
  else
    {
      printf ("Don't know how to list available data sources in Unix. Try %s or wherever"
	  " your KUBL server is listening.\n", DEFAULT_DATASOURCE_IN_UNIX);
    }

  return 0;
}

#else

#define DRIVDESCMAX 256
#ifndef SQL_MAX_DSN_LENGTH
#define SQL_MAX_DSN_LENGTH 512
#endif

int
list_data_sources (int for_html, char *templatename, char *tagname)
{
  char DSN[SQL_MAX_DSN_LENGTH + 1], DriverDescription[DRIVDESCMAX + 1];
  SWORD pcbDSN, pcbDescription;
  int rc, count;
  char *selected_datasource = NULL;

  strcpy (DSN, "VIRGEN");
  strcpy (DriverDescription, "CERDO");

  if (for_html)
    {
      printf ("<SELECT NAME=");
      if (!strcmp (tagname, DATADEST_TOKEN))
	{
	  printf ("S_DATADEST>");
	  printf ("<OPTION VALUE=\"\">Data Destination for Direct Table Linkage:</OPTION>\n");
	}
      else
	{
	  printf ("S_DATASOURCE");
	  if (!strcmp (templatename, DEFAULT_HTML_TEMPLATE_FILE))	/* Using main template? */
	    {
/* Do not try to get list of tables when in DBDUMP->ISQLO transfer
   template, nether we will use the old datasource as the new destination
   by default:
 */
	      printf (
/*  " onchange=\"this.form.RTL2.value='YES'; this.form.submit();\""); */
/*    " onchange=\"select_option_with_value(this.form.OPCODE,'RTL');\n check_radiobutton_with_value(this.form.OPTION_qv,'q');\n this.form.submit();\""); */
		  " onchange=\"select_option_with_value(this.form.OPCODE,'RTL');\n check_radiobutton_with_value(this.form.OPTION_qv,'q');\"");
	      selected_datasource = datasource;
	    }
	  printf (">\n");
	}
    }


  for (count = 0; 1; count++)
    {
      rc = SQLDataSources (henv,
	  ((UWORD) (count ? SQL_FETCH_NEXT : SQL_FETCH_FIRST)),
	  UCP (DSN), ((SWORD) SQL_MAX_DSN_LENGTH), &pcbDSN, UCP (DriverDescription), ((SWORD) DRIVDESCMAX), &pcbDescription);
      if (rc == SQL_NO_DATA_FOUND)
	{
	  break;
	}
      IF_ERR_GO (stmt, error, rc);

      if (for_html)
	{
	  printf ("<OPTION%s VALUE=\"%s\">%s,   %s</OPTION>\n",
	      ((selected_datasource && !strcmp (DSN, selected_datasource)) ? " SELECTED" : ""), DSN, DSN, DriverDescription);
	}
      else
	{
	  printf ("%-25s %s\n", DSN, DriverDescription);
	}
    }
  if (for_html)
    {
      printf ("</SELECT>\n");
    }
  return (count);
error:
  if (for_html)
    {
      printf ("</SELECT>\n");
    }

  fprintf (stderr, "print_data_sources: SQLDataSources returned status %d, count=%d\n", rc, count);
  fflush (stderr);

  return (0);
}

#endif


void
l_usage (char *progname)
{
  fprintf (stderr, "DBDUMP - DataBase Dump, Version %s\n", DBDUMP_VERSION);
  fprintf (stderr, "Usage: %s datasource [username [password]] spec=val spec=val ... -options\n", progname);
  fprintf (stderr, "The specifiers are:\n"
/* Has to fit into one page! */
      "username       Username to open the database connection with.\n"
      "password       Password to open the database connection with.\n"
      "tablequalifier Default Table Qualifier  by default NULL, i.e. all.\n"
      "tableowner     Default Table Owner      by default NULL, i.e. all.\n"
      "tablename      Table Name Pattern (use %%'s and ?'s as wildcards).\n"
      "               by default this is NULL, i.e. dbdump lists all tables.\n"
      "tablename=a.b.c is equal to tablequalifier=a tableowner=b tablename=c\n"
      "(You can specify more than one pattern or explicit name with tablename, just\n"
      " separate them with commas. E.g. tablename=table1,mytable%%,table3)\n"
      "tabletype      Table Types      by default NULL, all types.\n"
      "               Use tabletype=TABLE to get only user tables.\n"
      "insert_mode    For inserts. By default INTO, could be also REPLACING or SOFT.\n"
      "init=statement SQL statement executed in the start. E.g. \"init=use datab2\"\n"
      "unquoted_columns=tablename1.colname1,tablename1.colname2,tablename2.col1\n"
      "               Use this option to specify which columns in which tables\n"
      "               shall not be quoted, even if they were nominally VARCHAR\n"
      "               columns. Use this for columns containing vector data.\n"
      "convsrcN (where N is between 1 and %d) Source type to convert into a type\n", MAX_CONVERSIONS);

  fprintf (stderr,
      "given with the corresponding convdstN   E.g. use convsrc1=BIT convdst1=INTEGER\n"
      "to convert all columns with the type BIT to columns of type INTEGER.\n"
      "-K             Use Kubl default conversions (in addition to any of your own).\n");

  fprintf (stderr, "More?>");
  getchar ();			/* This is for pause. */
  fprintf (stderr,
      "Options are:\n"
      "-t Only table definitions   -i Only index definitions   -c Only contents\n"
      "There are also corresponding option letters in Uppercase:\n"
      "-T Only table definitions   -I Only index definitions   -C Only contents\n"
      " to control how automatically included supertables are output. By default\n"
      " the tables which are parent tables of some matched subtables, but which\n"
      " themselves are not explicitly specified in/matched to the tablename argument\n"
      " are not shown in dump. Use -TIC to show all information about them also.\n"
      "-q Be brief, no informative output.   -v Be verbose, loquacious.\n"
      "-n Don't escape string literals in C-style. -e Escape diacritic letters too.\n"
      "-ne Escape singlequotes by doubling them, all others in C-style.\n"
      "-N Generate somewhat more human-readable output, more than 1 line/statement.\n"
      "-r Don't issue any DROP TABLE or DROP INDEX commands.\n" "-s Never use FOREACH construct to output blobs.\n");
/* These are obsoleted by new_name specifier:
"-p Use plain tablenames without prefixes, default with Kubl and Access.\n"
"-+p Use prefixed tablenames (e.g. db.dba.tabname1), default with MS SQL.\n"
 */

  fprintf (stderr, "More?>");
  getchar ();			/* This is for pause. */

  fprintf (stderr,
      "More options:\n"
      "-a Surround all column and index names with a doublequote (\")\n"
      "-b Prefix all names (of tables, indices and columns) with a backslash (\\)\n"
      "Use -bb to also escape tablenames when used in select statement.\n"
      "\n"
      "new_name=!Q.!O.!N  Specify a new destination name for the table(s) to be\n"
      "   dumped. Markers !Q, !O and !N refer respectively to Qualifier, Owner and\n"
      "   Name parts of the original name. Use only !N to get non-prefixed names.\n"
      "   In Windows use an expression like new_name=\"\"\"!Q\"\"\".\"\"\"!O\"\"\".\"\"\"!N\"\"\"\n"
      "   and in Unix shell one like new_name='\"!Q\".\"!O\".\"!N\"' to get each part\n"
      "   surrounded with doublequotes. Use this if you use -a option.\n"
      "\n"
      "-P Produce Primary Key by any means if not explicitly present in the source\n"
      "   schema. I.e. either the first Unique Index defined, columns returned\n"
      "   by SQLSpecialColumns with SQL_BEST_ROWID option, or if all else fails,\n"
      "   all non-blob columns of the table together.\n" "-V Produce DB..vd_remote_data_source and DB..vd_remote_table calls.\n");

  fprintf (stderr, "More?>");
  getchar ();			/* This is for pause. */

  fprintf (stderr, "Use    %s -l   to list available datasources.\n", progname);
  fprintf (stderr,
      "E.g. use\n"
      "%s KUBL dba dba -bbq \"tablename=?ala,t%%%%\" tabletype=TABLE convsrc1=BIT convdst1=INTEGER convsrc2=TIMESTAMP convdst2=DATE\n",
      progname);
  fprintf (stderr,
      "  to dump from the datasource KUBL (with username dba and password dba)\n"
      "  all user defined tables with four letter names ending with  'ala'\n"
      "  as well as all tables with names of any length, beginning with letter 't'\n"
      "  (you could also give them separately as \"tablename=?ala\" \"tablename=t*\")\n"
      "  and convert all encountered BIT types to INTEGERs and all TIMESTAMPs to\n"
      "  DATEs in the column definitions,\n"
      "  and use the options -bb and -q (escape names and be brief)\n"
      "  If in Unix, use localhost:1111 as a datasource address instead of Kubl\n"
      "  if you have Kubl server listening at port 1111 in the same machine.\n");

  fprintf (stderr,
      "\nIn the specifier values you can use + for space, %%2B for +, %%26 for &\n"
      "%%%% or %%25 for a percent sign itself, %%3D for =, %%2F for / and %%2D for -\n\n");


  fprintf (stderr,
      "You can copy this executable to your Web server's script directory, and try\n"
      "it with your Web browser, using URL like http://localhost/scripts/dbdump.exe\n"
      "(or something like .../cgi-bin/dbdump or dbdump.cgi with Unix Web servers)\n");
  fprintf (stderr, "Use    %s -h > %s   to dump out the internal HTML template to the\n", progname, DEFAULT_HTML_TEMPLATE_FILE);
  fprintf (stderr, "       default template file, after which you can edit it to suit your taste.\n");
  fprintf (stderr, "Use    %s -hh  to see how the internal template looks after expansion.\n", progname);
  fprintf (stderr, "Please see http://www.kubl.com/ for more information about our products.\n");
  fflush (stderr);
}

int
version_less_than (char *s, int major, int minor)
{
  int tmp;
  while (*s && NOT isdigit (*s))
    {
      s++;
    }				/* Skip non-digits. */
  if (empty_stringp (s))
    {
      return (0);
    }				/* Premature end? */
  tmp = atoi (s);
  if (tmp > major)
    {
      return (0);
    }
  else if (tmp < major)
    {
      return (1);
    }
  /* They are equivalent, we have to check the minor part also. */
  while (*s && (*s != '.'))
    {
      s++;
    }				/* Search a period. */
  if (empty_stringp (s) || empty_stringp (++s))
    {
      return (0);
    }				/* Not found or followed by nothing */
  tmp = atoi (s);
  return (tmp < minor);
}

char dbms[100];
char drv[100];
long ignore;

int
connect_to_datasource_or_dest (HDBC * ptr_to_hdbc, HENV henv, char *datasource, char *username, char *password)
{
  int rc;

  SQLAllocConnect (henv, ptr_to_hdbc);

  /* We could get messages like:
     Error 01000: Changed database context to 'master'
     from MS SQL Server. Don't output any messages for those!
   */
  if ((SQL_SUCCESS != (rc = SQLConnect (*ptr_to_hdbc,
		  (UCHAR *) datasource, SQL_NTS,
		  (UCHAR *) username, SQL_NTS, (UCHAR *) password, SQL_NTS))) && (SQL_SUCCESS_WITH_INFO != rc))
    {
      print_error (SQL_NULL_HENV, *ptr_to_hdbc, SQL_NULL_HSTMT);
      printf ("-- could not connect to \"%s\".\n", datasource);
      if (rc == SQL_ERROR)
	exit (3);
    }

  SQLSetConnectOption (*ptr_to_hdbc, SQL_AUTOCOMMIT, 0);

  SQLGetInfo (*ptr_to_hdbc, SQL_DBMS_NAME, dbms, sizeof (dbms), ((SWORD *) & ignore));
  SQLGetInfo (*ptr_to_hdbc, SQL_DRIVER_VER, drv, sizeof (drv), ((SWORD *) & ignore));
  SQLGetInfo (*ptr_to_hdbc, SQL_GETDATA_EXTENSIONS, &getdata_extensions, ((SWORD) 4), ((SWORD *) & ignore));

  return (rc);
}

/*
   In this function we check if any direct linking of tables
   failed in print_table_definition_banner
 */
int
check_for_failed_tables (struct tabledeflist *tl)
{
  int number_of_failed = 0;

  for (; tl; tl = tl->next)
    {
      if (tl->last_SQL_state)
	{
	  if (0 == number_of_failed)
	    {
	      fprintf (stdout, "-- The linking of the following tables failed for the following reasons:\n");
	    }
	  fprintf (stdout, "-- \"%s\" -> %s: %s\n", tl->name, tl->last_SQL_state, tl->last_SQL_message);
	  number_of_failed++;
	}
    }

  fflush (stdout);
  return (number_of_failed);
}



int
main (int argc, char **argv)
{
  char *query_string;
  char *query_string_error = NULL;

#if 0
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif
#endif

  progname = argv[0];

  maxlinelength_for_foreach = atol (DEFAULT_MAXLINELEN);
  maxhexlength_for_foreach = atol (DEFAULT_MAXHEXLEN);

  SQLAllocEnv (&henv);		/* This might be needed quite soon. */

  if ((query_string = getenv ("QUERY_STRING")) || getenv ("HTTP_HOST") || getenv ("SERVER_PROTOCOL"))	/* Used as a CGI-script? */
    {				/* There is a query string in the environment variable QUERY_STRING */
      /* which means that this is used with the Web browser. */
      web_mode = 1;
      if (query_string)
	{
	  /* The following might override web_content_type */
	  query_string_error = parse_url_query_string (query_string);
	}

      if (flag_get_list_of_tables || (!datasource || universal_transfer_flag))
	{
	  printf ("Content-Type: %s\r\n\r\n", "text/html");
	  fflush (stdout);
	  if (!flag_get_list_of_tables)
	    {
	      output_html_file (universal_transfer_flag ? DEFAULT_TRANSFER_TEMPLATE1 : DEFAULT_HTML_TEMPLATE_FILE);
	      if (!universal_transfer_flag)
		{
		  exit (0);
		}
	    }
	}
      else			/* Ordinary usage. */
	{
	  printf ("Content-Type: %s\r\n\r\n", web_content_type);
	  fflush (stdout);
	}
    }
  else
    {
      int i, nth_non_option;
      for (i = 1, nth_non_option = 0; i < argc; i++)
	{
/* If the argument begins with a dash (-) then overwrite it with an
   equal sign (=) so that it will be interpreted as an option in
   parse_url_query_string. */
	  if (((*(argv[i]) == '-') && (*(argv[i]) = '=')) || strchr (argv[i], '='))	/* There's an equal sign? */
	    {
	      query_string = argv[i];
	      query_string_error = parse_url_query_string (query_string);
	      if (query_string_error)
		{
		  goto arg_error;
		}
	    }
	  else
	    {
	      switch (++nth_non_option)
		{
		case 1:
		  {
		    datasource = argv[i];
		    break;
		  }
		case 2:
		  {
		    username = argv[i];
		    break;
		  }
		case 3:
		  {
		    password = argv[i];
		    break;
		  }
		}
	    }
	}			/* for loop over arguments */
    }				/* else, not used with the Web browser */

  if (list_data_sources_flag)
    {
      list_data_sources (web_mode, "", "");
      exit (0);
    }

  if (dump_html_template_file_flag)
    {
      output_html_file (DEFAULT_HTML_TEMPLATE_FILE);
      exit (0);
    }

  if (query_string_error)
    {
    arg_error:
      fputs (query_string_error, (web_mode ? stdout : stderr));
      exit (1);
    }

  if ((NO datasource) && (0 == web_mode))
    {
      l_usage (*argv);
      exit (0);
    }

/* Note that parse_url_query_string inserts into string pointer arguments
   various substrings of query_string, returned by getenv or taken from
   the command line arg. If I remember right, getenv returns a pointer
   to static string buffer, so if you call getenv second time, its
   result will overwrite the old query_string, and probably also the
   resulting strings you got here.
 */

  if (NO only_table_definitions_flag && NO only_index_definitions_flag && NO only_contents_flag)
    {				/* If ALL these flags has been left OFF, then turn them ALL ON */
      only_table_definitions_flag = only_index_definitions_flag = only_contents_flag = 1;
    }

/* Not done here anymore, instead in get_all_tables for each separate token
  tablename = divide_tablename(tablename,&tablequalifier,&tableowner);
 */

  if (flag_get_list_of_tables)
    {
      tablequalifier = tableowner = tablename = NULL;	/* Everything? */
      verbose_flag = 0;		/* Force it to shut up, in case our JavaScript code fails. */
    }

  if (verbose_flag && datasource)
    {
      fprintf (stdout, "-- %s: dumping datasource \"%s\", username=%s\n", *argv, datasource, username);
      fprintf (stdout,
	  "-- tablequalifier=%s  tableowner=%s  tablename=%s  tabletype=%s\n",
	  (tablequalifier ? tablequalifier : "NULL"),
	  (tableowner ? tableowner : "NULL"), (tablename ? "is given, one or more" /* tablename */ : "NULL"),
	  (tabletype ? tabletype : "NULL"));
    }

  if (kubl_default_conversions_flag)
    {
      conv_types_table = &kubl_default_conv_types[0];	/* "Rewind" to the beginning. */
      n_conv_types += N_KUBL_DEFAULT_CONVERSIONS;	/* We got this many for free! */
    }

  if (verbose_flag && n_conv_types)
    {
      int i;

      fprintf (stdout, "-- Converting %d types\n", n_conv_types);
      for (i = 2; i <= (2 * n_conv_types); i += 2)
	{
	  fprintf (stdout, "-- From %s to %s\n",
	      (conv_types_table[i] ? conv_types_table[i] : "NULL"), (conv_types_table[i + 1] ? conv_types_table[i + 1] : "NULL"));
	}
    }

  fflush (stdout);

  connect_to_datasource_or_dest (&hdbc, henv, datasource, username, password);

  if (verbose_flag)
    {
      fprintf (stdout, "-- Connected to datasource \"%s\", Driver v. %s.\n", dbms, drv);
    }

  if (strstr (dbms, "UBL") || strstr (dbms, "ubl"))
    {
      kubl_mode = 1;
      if (version_less_than (drv, 0, 92))
	{
	  fprintf (stderr, "-- Sorry, you need KUBL ODBC driver version 0.92 or later to run this tool.\n");
	  fprintf (stderr, "-- It is available from http://www.kubl.com\n");
	  exit (1);
	  times_conform_to_odbc_flag = 0;
	  times_to_strings_flag = 1;
	}
      if (version_less_than (drv, 0, 96))
	{
	  varchar_cols_returned_with_length_plus = 1;
	}
      never_escape_tablenames_in_select = 0;	/* Yes, escape them. */
      if (0 == use_table_prefixes_flag_given)
	{			/* Not explicitly specified by the user? Then turn it on because */
	  use_table_prefixes_flag = 1;	/* Prefixes are useful with new Kubl */
	}
    }
  else				/* Some other DBMS, e.g. Access. */
    {
      kubl_mode = 0;
/*   times_conform_to_odbc_flag=1;   Already initialized to these values.
     times_to_strings_flag=0; */
    }
  if (strstr (dbms, "ccess") || strstr (dbms, "CCESS"))
    {
      never_escape_tablenames_in_select = 1;
      if (0 == use_table_prefixes_flag_given)
	{			/* Not explicitly specified by the user? */
	  use_table_prefixes_flag = 0;	/* Prefixes are harmful for Access */
	}
    }
  /* For Microsoft SQL Server */
  else if (strstr (dbms, "SQL Server") || strstr (dbms, "SQL SERVER"))
    {
      never_escape_tablenames_in_select = 1;
      if (0 == use_table_prefixes_flag_given)
	{			/* Not explicitly specified by the user? */
	  use_table_prefixes_flag = 1;	/* Prefixes are useful with MS SQL Server */
	}
    }

/* #endif */

  SQLAllocStmt (hdbc, &stmt);

  if (init_statement)		/* User gave one initialization statement? */
    {				/* e.g. "USE somedatabasename" with MS SQL server */
      IF_ERR_GO (stmt, error, SQLExecDirect (stmt, UCP (init_statement), SQL_NTS));
    error:
      SQLFreeStmt (stmt, SQL_CLOSE);
      if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
	{
	  print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
	  exit (1);
	}
    }


  driver_has_necessary_sql_functions ();	/* Will exit by itself if not. */

  if (datadest)
    {
      connect_to_datasource_or_dest (&datadest_hdbc, henv, datadest, dest_username, dest_password);

      if (verbose_flag)
	{
	  fprintf (stdout, "-- Connected to data destination \"%s\", Driver v. %s.\n", dbms, drv);
	}

      SQLAllocStmt (datadest_hdbc, &datadest_gen_stmt);
    }


  {
    int count = 0;
    int no_sql_primary_keys = 0;
    struct tabledeflist *tl;
    UWORD FunctionExists = TRUE;	/* Unless otherwise proved. */

    tl = all_tables_list = get_all_tables (tablequalifier, tableowner, tablename, tabletype, &count);

    SQLGetFunctions (hdbc, SQL_API_SQLPRIMARYKEYS, &FunctionExists);
    if (FunctionExists)
      {
	while (tl)
	  {
/*        debug_fprintf(stdout,
           "-- Reading primary key information of the table %s\n",tl->name);
 */
	    get_table_primarykey (tl);
	    tl = tl->next;
	  }
	if (kubl_mode)
	  {
	    count += get_real_supertables (all_tables_list);
	  }
      }
    else
      {
	no_sql_primary_keys = 1;
	if (verbose_flag)
	  {
	    fprintf (stdout, "-- SQLPrimaryKeys not implemented. Trying to find primary keys with SQLStatistics.\n");
	  }
	SQLGetFunctions (hdbc, SQL_API_SQLSTATISTICS, &FunctionExists);
	if (NO FunctionExists)
	  {
	    fprintf (stderr, "-- Sorry, SQLStatistics not implemented. Exiting.\n");
	    exit (1);
	  }
      }

    if (flag_get_list_of_tables)
      {
	reorder_subtables (all_tables_list);
	output_html_file (DEFAULT_HTML_TEMPLATE_FILE);
	SQLDisconnect (hdbc);
	exit (0);
      }

    if (primary_key_by_all_means_flag)
      {
	SQLGetFunctions (hdbc, SQL_API_SQLSPECIALCOLUMNS, &FunctionExists);
	if (NO FunctionExists)
	  {
	    fprintf (stderr,
		"-- Sorry, SQLSpecialColumns not implemented. It could be hard to determine\n"
		"-- which columns to use as a Primary Key if nothing else is found.\n");
	  }
	else
	  {
	    tl = all_tables_list;
	    while (tl)
	      {
/* If user gave just one -P option, then use SQL_SCOPE_CURROW (0).
   With -PP use SQL_SCOPE_TRANSACTION (1) and
   with -PPP use SQL_SCOPE_SESSION (2)
 */
		get_table_bestrow_columns (tl, ((UWORD) ((primary_key_by_all_means_flag & 3) - 1)), ((UWORD) SQL_NULLABLE));	/* Or SQL_NO_NULLS */
		tl = tl->next;
	      }
	  }
      }

/* Now always get index-information in, regardless whether it will be
   printed or not. (For example, we might need it for PRIMARY KEYs
   anyway).
    if(no_sql_primary_keys || only_index_definitions_flag)
 */
    {
      for (tl = all_tables_list; tl; tl = tl->next)
	{
/*        debug_fprintf(stdout,
           "-- Reading index information of the table %s\n",tl->name); */
	  get_table_indices (tl);	/* Uses SQLStatistics */
	}
    }

    if (verbose_flag)
      {
	fprintf (stdout, "-- Definitions of %d tables were read in.\n", count);
	fflush (stdout);
      }

    /* This will put all the subtables (their tl nodes) to the
       sub_tables lists of their respective super tables, but still
       keep the sub_table nodes themselves intact in all_tables_list.
     */
    reorder_subtables (all_tables_list);
    if (vd_procedures_flag)
      {
	int rc = link_remote_data_source (&datadest_link_stmt,
	    datadest_hdbc,
	    henv,
	    datasource, username, password);

	if (datadest_hdbc)	/* Better to be ON! in this case. */
	  {
	    auto_only_table_definitions_flag = 1;
	  }

	/* No success, so we failed in start. */
	if (SQL_SUCCESS != rc)
	  {
	    fprintf (stderr,
		"-- Linking remote data source to data destination failed.\n"
		"-- Are you sure your data destination is Kubl Universe DBMS?\n");
	    exit (1);
	  }
      }

    output_tables (all_tables_list);
    if (verbose_flag)
      {
	printf ("EXIT;\n");
      }				/* -- The End is Near -- */
    printf ("\n");

    if (datadest_hdbc)		/* We still need to commit the destination data source? */
      {
	UWORD commit_or_rollback = SQL_COMMIT;	/* Could be SQL_ROLLBACK as well */

	int n_failed = check_for_failed_tables (all_tables_list);

	if (n_failed)
	  {
	    if (all_or_nothing_flag)
	      {
		fprintf (stdout, "-- %d linkages failed, discarding all the linkages done at this time.\n", n_failed);
		commit_or_rollback = SQL_ROLLBACK;
		fflush (stdout);
	      }
	  }

	if (SQL_SUCCESS != SQLTransact (henv, datadest_hdbc, commit_or_rollback))
	  {
	    print_error (SQL_NULL_HENV, datadest_hdbc, SQL_NULL_HSTMT);
	    SQLDisconnect (datadest_hdbc);	/* And have some manners */
	  }

	else if (n_failed)
	  {
	    if ((SQL_COMMIT == commit_or_rollback))
	      {
		fprintf (stdout,
		    "-- %d linkages failed, but %d linkages still succeeded and committed.\n", n_failed, (count - n_failed));
		fflush (stdout);
	      }
	  }
      }

    if (universal_transfer_flag)
      {
	output_html_file (DEFAULT_TRANSFER_TEMPLATE2);
      }
  }


  SQLDisconnect (hdbc);

  exit (0);
}

/* ================================================================== */
/*            FUNCTIONS FOR OUTPUTTING HTML PAGE                      */
/* ================================================================== */

typedef char *(*PFSTR) (char *);
/* Pointer to function returning a char pointer, taking one string as
   its argument. */

FILE *html_infp = NULL;

char *
line_from_html_file (char *templatename)
{
  return (fgets (tmp1, TMP1_LEN, html_infp));
}

/* Return the whole string in one piece. After that return NULL.
   Really Ad Hoc just for quick, quick work.
 */
char *
line_from_html_string (char *templatename)
{
  static char counts_visited = 0;
  static char *last_templatename = "";
  extern char *html_page_string;	/* In the end of this module. */
  extern char *transfer_html_page_string1, *transfer_html_page_string2;

  if ((0 == counts_visited) || (templatename != last_templatename))
    {				/* First time here with this templatename? */
      counts_visited++;
      last_templatename = templatename;

      if (!strcmp (templatename, DEFAULT_TRANSFER_TEMPLATE1))
	{
	  return (transfer_html_page_string1);
	}

      if (!strcmp (templatename, DEFAULT_TRANSFER_TEMPLATE2))
	{
	  return (transfer_html_page_string2);
	}

      if (!strcmp (templatename, DEFAULT_HTML_TEMPLATE_FILE))
	{
	  return (html_page_string);
	}
    }

  return (NULL);
}


/* This contains the crudest kind of a template interpreter. It just checks
   whether the string $INPUT_DATASOURCE is found in the midst of lines.
 */
int
output_html_page (PFSTR sourcefun, char *templatename)
{
  char *line, *ptr, *next;


  while ((line = ((sourcefun) (templatename))) != NULL)	/* Still got something. */
    {
    again:
/* Option -hh prints out with the tokens expanded, but the option -h
   prints the template out in the raw format: */
      if ((dump_html_template_file_flag != 1) && (ptr = strchr (line, '$')))
	{
	  fwrite (line, sizeof (char), (ptr - line), stdout);
	  if ((next = string_begins_with ((ptr + 1), VERSION_TOKEN)) != NULL)
	    {
	      fputs (DBDUMP_VERSION, stdout);
	      line = next;
	    }
	  else if ((next = string_begins_with ((ptr + 1), DATASOURCE_TOKEN)) != NULL)
	    {
	      list_data_sources (1, templatename, DATASOURCE_TOKEN);
	      line = next;
	    }
	  else if ((next = string_begins_with ((ptr + 1), DATADEST_TOKEN)) != NULL)
	    {
	      list_data_sources (1, templatename, DATADEST_TOKEN);
	      line = next;
	    }
	  else if ((next = string_begins_with ((ptr + 1), TABLELIST_TOKEN))
	      || (next = string_begins_with ((ptr + 1), "N_TABLES_OR_MAX")))
	    {
	      int max_value = atoi (next);
	      int n_tables = length_of_tablelist (all_tables_list);

	      if (0 == n_tables)
		{
		  n_tables = 1;
		}
	      if ((0 != max_value) && (max_value < n_tables))
		{
		  n_tables = max_value;
		}

	      if (string_begins_with ((ptr + 1), TABLELIST_TOKEN))
		{
		  output_tablelist_token (n_tables);
		}
	      else
		{
		  printf ("%d", n_tables);
		}

	      while (*next && isdigit (*next))
		{
		  next++;
		}		/* Skip the digits */
	      line = next;
	    }
	  else if ((next = string_begins_with ((ptr + 1), DEFAULT_CONVERSIONS_TOKEN)) != NULL)
	    {
	      int i;
	      for (i = 2; i <= (N_KUBL_DEFAULT_CONVERSIONS * 2); i += 2)
		{
		  printf ("<LI><B>%s</B> <CODE>-&GT;</CODE> <B>%s</B>\n",
		      kubl_default_conv_types[i], kubl_default_conv_types[i + 1]);
		}
	      line = next;
	    }

	  if (*line)		/* And go back to the beginning to print the rest. */
	    {
	      goto again;
	    }			/* (if there's anything left.) */
	}
      else			/* A normal line. */
	{
	  fputs (line, stdout);
	}
    }				/* while */
  return (1);
}

int
output_html_file (char *templatename)
{
/* When using option -h, then take it always from the memory. */
  if (dump_html_template_file_flag || NO (html_infp = fopen (templatename, "r")))
    {
/* Don't whine anymore for this. Use a string given below instead!
       fprintf(stderr,"Cannot open file %s for reading!\n",filename);
       return(0);
 */
      output_html_page (line_from_html_string, templatename);
    }
  else
    {
      output_html_page (line_from_html_file, templatename);
    }
  return (1);
}

/*
  You can dump this out in the unexpanded form with a command DBDUMP -h
  and in the expanded form with a command: DBDUMP -hh
  If there is a filename dbdump.htm in the same directory where the
  dbdump.exe is executed as a CGI-script, then that file is used
  instead of this string.

  Yes, the layout really sucks now.

  Note how the double-choosing of tablenames
  by transferring them from S_TABLES multichoice select/option list
  to tablename multiline textfield with the JavaScript function
  add_selected_items_to_the_text_elem
  (See the C-function output_tables_as_select_list)
  is NOT really necessary.
  We COULD discard with the single/multiline textfield,
  and rename the multichoice select-list to tablename
  (instead of S_TABLES).
  Even then, the user could choose various tables separated from each
  other in the list (by pressing CTRL while dragging the mouse
  over further tablenames).
  However, by having the multiline textfield next to the select-list,
  the user can also enter any wildcard patterns like *.*.*, etc,
  or directly any tablename he knows must exist in the datasource.
 */

char *html_page_string
    =
    "<HTML><HEAD><TITLE>DBDUMP - DataBase Dump, version " DBDUMP_VERSION "</TITLE>\n"
    "<META NAME=DESCRIPTION CONTENT=\"DBDUMP default template for table linking and dumping.\">\n"
    "<SCRIPT LANGUAGE=\"JavaScript\">\n"
    "<!-- Hide the script from old browsers\n"
    "function check_radiobutton_with_value(items,with_value)\n"
    "{\n"
    "   var j, maxval = items.length;\n"
    "   for(j = 0; j < maxval; j++)\n"
    "    {\n"
    "      if(items[j].value == with_value) { items[j].checked = 1; }\n"
    "      else { items[j].checked = 0; }\n"
    "    }\n"
    "   return(j);\n"
    "}\n"
    "\n"
    "function select_option_with_value(items,with_value)\n"
    "{\n"
    "   var j, maxval = items.length;\n"
    "   for(j = 0; j < maxval; j++)\n"
    "    {\n"
    "      if(items[j].value == with_value) { items[j].selected = 1; }\n"
    "      else { items[j].selected = 0; }\n"
    "    }\n"
    "   return(j);\n"
    "}\n"
    "\n"
    "function set_options_according_to_action(form_obj)\n"
    "{\n"
    "    var selected_action = form_obj.OPCODE.options[form_obj.OPCODE.selectedIndex].value;\n"
    "\n" "    form_obj.OPTION_U.checked = 0; // Don't use ISQL-form unless otherwise indicated.\n"
/* "    form_obj.RTL2.value = '';\n" */
    "\n"
    "    if((\"LTD\" == selected_action) // Link tables directly\n"
    "     || (\"LTDAON\" == selected_action) // --- '' --- all or none\n"
    "     || (\"LTI\" == selected_action)) // Link tables via ISQL-form\n"
    "     {\n"
    "       form_obj.OPTION_V.checked = 1; // Produce Linking Calls\n"
    "       form_obj.OPTION_K.checked = 1; // Use Kubl default conversions\n"
    "       form_obj.OPTION_P.checked = 1; // Get Primary Keys by any means\n"
    "       form_obj.OPTION_small_a.checked = 1; // Quote column (and index) names\n"
    "\n"
    "       if(\"LTI\" == selected_action) // via ISQL-form?\n"
    "        {\n"
    "          form_obj.OPTION_U.checked = 1; // Use ISQL-form.\n"
    "        }\n"
    "       else // LTD or LTDAON\n"
    "        {\n"
    "          if(\"LTDAON\" == selected_action)\n"
    "           { form_obj.OPTION_A.checked = 1; } // All or None flag on.\n"
    "          else\n" "           { form_obj.OPTION_A.checked = 0; } // All or None flag off.\n"
#ifdef USE_TEXTFIELD_DATASOURCE
    "          if(0 == form_obj.S_DATADEST.value.length)\n"
#else
    "          if(0 == form_obj.S_DATADEST.selectedIndex)\n"
#endif
    "           {\n"
    "             alert(\"You must set Data Destination to proper Kubl Virtual Database!\");\n"
    "             return(false);\n"
    "           }\n"
    "        }\n"
    "     }\n"
    "    else // Not a \"Link tables\" operation, so it's probably a dump\n"
    "     {\n"
    "       form_obj.OPTION_V.checked = 0; // Do not produce Linking Calls\n"
    "     }\n"
    "\n"
    "    if(\"DUS\" == selected_action) // Dump schema/contents to Screen\n"
    "     {\n"
    "       form_obj.CONTENT_TYPE.checked = 0; // No special content type.\n"
    "     }\n"
    "    else if(\"DUF\" == selected_action) // Dump schema/contents to File\n"
    "     {\n"
    "       form_obj.CONTENT_TYPE.checked = 1; // Special content type.\n"
    "     }\n"
    "    else if(\"DUI\" == selected_action) // Dump schema/contents via ISQL-form\n"
    "     {\n"
    "       form_obj.CONTENT_TYPE.checked = 0; // No special content type.\n"
    "       form_obj.OPTION_U.checked = 1; // Use ISQL-form.\n"
    "     }\n"
    "    else if(\"RTL\" == selected_action) // Reload table list, quietly\n"
    "     {\n" "       check_radiobutton_with_value(form_obj.OPTION_qv,'q');\n" "     }\n" "\n"
/*
"// We cannot produce any comment lines beginning with a double-dash\n"
"// because ISQL cannot yet handle (skip) them when they come from\n"
"// HTML-form. So let's turn verbose-mode off (quiet-mode on)\n"
"// when via ISQL-form is used:\n"
 */
    "    if(form_obj.OPTION_U.checked)\n"
    "     {\n"
    "       check_radiobutton_with_value(form_obj.OPTION_qv,'q');\n"
    "     }\n"
    "\n"
    "    return(true);\n"
    "}\n"
    "\n"
    "\n"
    "function add_selected_items_to_the_text_elem(select_items,text_elem)\n"
    "{\n"
    "   var j, maxval = select_items.length;\n"
    "   text_elem.value=\"\";"
    "   for(j = 0; j < maxval; j++)\n"
    "    {\n"
    "      if(select_items[j].selected)\n"
    "       {\n"
    "         if(text_elem.value.length != 0)\n"
    "          { text_elem.value += '\\r\\n'; }\n"
    "         text_elem.value += select_items[j].value;\n"
    "       }\n" "    }\n" "}\n" "\n" "// -- Stop Hiding Here -->\n" "</SCRIPT>\n" "</HEAD>\n" "<BODY>\n"
/* "<FORM ACTION=\"" DBDUMP_CGI_LOCATION "\" NAME=\"DBDUMP_OPTIONS\" METHOD=GET" */
    "<FORM NAME=\"DBDUMP_OPTIONS\" METHOD=GET" " onsubmit=\"return(set_options_according_to_action(this))\">\n"
/* "<INPUT TYPE=HIDDEN NAME=RTL2 VALUE=\"\">\n" */
    "<TABLE>\n"
    "<TR>\n"
    "<TD VALIGN=CENTER><B>Data Source</B></TD>\n"
    "<TD VALIGN=TOP COLSPAN=2>$" DATASOURCE_TOKEN "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD VALIGN=CENTER><B>Username&nbsp;&amp;&nbsp;Password</B></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=TEXT NAME=username SIZE=10><INPUT TYPE=CHECKBOX NAME=EMPTY_USERNAME VALUE=\"ON\">(empty)</TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=PASSWORD NAME=password SIZE=10><INPUT TYPE=CHECKBOX NAME=EMPTY_PASSWORD VALUE=\"ON\">(empty)</TD>\n"
    "</TR>\n"
    "<TR><TD COLSPAN=3><HR></TD></TR>\n"
    "<TR>\n"
    "<TD VALIGN=CENTER><B>Data&nbsp;Destination</B><BR><I>(Use only with direct linkage)</I></TD>\n"
    "<TD VALIGN=TOP COLSPAN=2>$" DATADEST_TOKEN "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD VALIGN=CENTER><B>Username&nbsp;&amp;&nbsp;Password for Destination</B></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=TEXT NAME=s_dstuser SIZE=10><INPUT TYPE=CHECKBOX NAME=S_EMPTY_DSTUSER VALUE=\"ON\">(empty)</TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=PASSWORD NAME=s_dstpass SIZE=10><INPUT TYPE=CHECKBOX NAME=S_EMPTY_DSTPASS VALUE=\"ON\">(empty)</TD>\n"
    "</TR>\n"
    "<TR><TD COLSPAN=3><HR></TD></TR>\n"
    "<TR>\n"
    "<TD></TD><TD VALIGN=TOP><B>Available Tables</B></TD>\n"
    "<TD VALIGN=TOP NOWRAP><B>Tables to Link/Dump</B> <I>(Leave empty: All)</I></TD>\n"
    "</TR>\n"
    "<TR><TD></TD>\n"
    "<TD COLSPAN=1 VALIGN=TOP>$" TABLELIST_TOKEN "10</TD>\n"
    "<TD VALIGN=TOP><TEXTAREA NAME=tablename ROWS=$N_TABLES_OR_MAX10 COLS=24></TEXTAREA></TD>\n" "</TR>\n"
/*
"<TR>\n"
"<TD VALIGN=TOP></TD>\n"
"<TD VALIGN=TOP><INPUT TYPE=SUBMIT VALUE=DUMP></TD>\n"
"<TD VALIGN=TOP><INPUT TYPE=RESET VALUE=CLEAR></TD>\n"
"</TR>\n"
 */
    "<TR>\n"
    "<TD VALIGN=CENTER><B>Action</B></TD>\n"
    "</TD>\n"
    "\n"
    "<TD VALIGN=TOP COLSPAN=1>\n"
    "<SELECT NAME=OPCODE onchange=\"set_options_according_to_action(this.form)\">\n"
    "<OPTION VALUE=\"LTD\">Link tables directly\n"
    "<OPTION VALUE=\"LTDAON\">Link tables directly, all or none\n"
    "<OPTION VALUE=\"LTI\">Link tables via ISQL-form\n"
    "<OPTION VALUE=\"DUS\">Dump schema/contents to Screen\n"
    "<OPTION VALUE=\"DUF\">Dump schema/contents to File\n"
    "<OPTION VALUE=\"DUI\">Dump schema/contents via ISQL-form\n"
    "<OPTION VALUE=\"RTL\">Reload table list\n"
    "</SELECT>\n"
    "</TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=SUBMIT VALUE=\"Do it\" WIDTH=120></TD>\n" "</TR>\n" "\n" "<TR><TD COLSPAN=3><HR></TD></TR>\n"
/*

"<TR>\n"
"<TD VALIGN=TOP><B>Table Name(s)</B></TD>\n"
"<TD COLSPAN=2>\n"
"<!-- INPUT TYPE=TEXT NAME=tablequalifier -->\n"
"<!-- INPUT TYPE=TEXT NAME=tableowner -->\n"
"<INPUT TYPE=TEXT SIZE=45 NAME=tablename>\n"
"<INPUT TYPE=SUBMIT VALUE=DUMP>\n"
"</TD>\n"
"</TR>\n"
 */
    "<TR>\n"
    "<TD VALIGN=TOP><B>Options</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<TABLE>\n"
    "<TR><TD COLSPAN=1 VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_V VALUE=V CHECKED>"
    " <B>Produce Table Linkage Calls</B>\n"
    "</TD><TD COLSPAN=1 VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_A VALUE=A> <B>Link none if any linkage fails</B>\n"
    "</TD></TR>\n"
    "<!-- The next two work like radiobuttons, turning each other off -->\n"
    "<TR>\n"
    "<TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_U VALUE=U "
    "onclick=\"if(this.checked) { this.form.CONTENT_TYPE.checked=0; }\">\n"
    "<B>Transfer Schema/Data to another DBMS (via HTML-form)</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=CONTENT_TYPE VALUE=\"x-DBDUMP-output-to-text-file\" "
    "onclick=\"if(this.checked) { this.form.OPTION_U.checked=0; }\">\n" "<B>Dump to file instead of screen</B>\n" "</TD></TR>\n"
/* With U be also absolutely quiet (option q), because isql(odbc)
   cannot currently handle comments beginning with double-dash (--)
   coming in S_EXEC argument (in Url). This is done with JavaScript
   event handler onClick, which will toggle the radiobutton OPTION_qv
   (later in this form) to quiet-state, from the default verbose-state.
   Also, use N option (nicer_output_flag), so that PRIMARY KEYs are
   shown on the next line, appropriately indented.
 */
    "<TR>\n"
    "<TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_P VALUE=P CHECKED> <B>Produce Primary Key by any means</B>\n"
    "</TD><TD VALIGN=TOP></TD></TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=t CHECKED> <B>Table definitions only</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=i > <B>Index definitions only</B>\n"
    "</TD></TR><TR><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=c> <B>Contents only</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=d> <B>The -d option (obscure)</B>\n"
    "</TD></TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=T CHECKED> <B>Only supertable table definitions</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=I CHECKED> <B>Only supertable index definitions</B>\n"
    "</TD></TR><TR><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=C> <B>Only supertable contents</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=TIC> <B>All supertable information (-TIC)</B>\n"
    "</TD></TR>\n"
    "<TR><TD COLSPAN=2 VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_small_a CHECKED VALUE=a> <B>Surround all column and index names with doublequotes</B>\n"
    "</TD></TR>\n"
/* These two are semi obsolete: */
    "<TR><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=b> <B>Prefix all names with backslash</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=bb> <B>Like above, but also in select statement</B>\n"
    "</TD></TR>\n"
    "<TR><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=r> <B>No drops<B>\n"
    "</TD><TD VALIGN=TOP>\n" "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=s> <B>Never use foreach<B>\n" "</TD></TR>\n"
/*
"<TR><TD COLSPAN=2>\n"
"<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=p> "
"<B>Use plain tablenames only, no prefixes</B>\n"
"</TD></TR>\n"
 */
/* Neither of these are initially checked (except in Lynx) which
   allows for this program to set the appropriate default mode right
   after the connection, for instance for:
   Access (where prefixing produces incorrect behaviour) and
   Old Kubl (where prefixing is unnecessary), and
   New Kubl and MS SQL Server (where prefixing is usually very useful).
 */
/* Largely obsoleted by new_name option with its !Q.!O.!N markers.
   This just confuses users, commented out.
"<TR><TD VALIGN=TOP>\n"
"<INPUT TYPE=RADIO NAME=OPTIONp VALUE=\"p\"> <B>Plain tablenames,<BR>\n"
"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;no prefixes</B>\n"
"</TD><TD VALIGN=TOP>\n"
"<INPUT TYPE=RADIO NAME=OPTIONp VALUE=\"+p\"> <B>Prefixed tablenames<BR>\n"
"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</B>(e.g. <CODE>db.dba.tabnam</CODE>)\n"
"</TD></TR>\n"
 */
    "<TR><TD VALIGN=TOP>\n" "<INPUT TYPE=RADIO NAME=OPTION_qv VALUE=\"q\" > <B>Brief</B>\n" "</TD><TD VALIGN=TOP>\n" "<INPUT TYPE=RADIO NAME=OPTION_qv CHECKED VALUE=\"v\"> <B>Verbose</B>\n" "</TD></TR>\n" "<TR><TD VALIGN=TOP>\n" "<INPUT TYPE=RADIO CHECKED NAME=OPTION2 VALUE=\"\"> "	/* Was ne */
    "<B>Escape strange chars</B>\n" "</TD><TD VALIGN=TOP>\n" "<INPUT TYPE=RADIO NAME=OPTION2 VALUE=e> "	/* Was nee */
    "<B>Escape also ISO-8859/1</B>\n" "</TD></TR>\n" "<TR><TD COLSPAN=2>\n" "<INPUT TYPE=RADIO NAME=OPTION2 VALUE=n> "	/* Is n */
    "<B>Escape only single quotes by doubling them</B>\n"
    "</TD></TR>\n"
    "<TR><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTION_N VALUE=N CHECKED>"
    " <B>Indented table-definitions</B>\n"
    "</TD><TD VALIGN=TOP>\n"
    "<INPUT TYPE=CHECKBOX NAME=OPTIONS VALUE=D> <B>Debug trace<B>\n"
    "</TD></TR>\n"
    "</TABLE>\n"
    "</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP><B>Convert types</B></TD>"
    "<TD VALIGN=TOP COLSPAN=2><INPUT TYPE=CHECKBOX NAME=OPTION_K VALUE=K> <B>Kubl Default Conversions</B> <I>(Use this when destination is Kubl)</I></TD></TR>\n"
    "<TR><TD VALIGN=TOP><B>as well as</B></TD><TD VALIGN=TOP><B>from</B></TD><TD VALIGN=TOP><B>to</B></TD></TR>\n"
    "<TR><TD VALIGN=TOP></TD>\n"
    "<TD VALIGN=TOP><SELECT NAME=CONVSRC1>\n"
    "<OPTION VALUE=\"\">-\n"
    "<OPTION>CHAR\n"
    "<OPTION>NUMERIC\n"
    "<OPTION>DECIMAL\n"
    "<OPTION>INTEGER\n"
    "<OPTION>SMALLINT\n"
    "<OPTION>FLOAT\n"
    "<OPTION>REAL\n"
    "<OPTION>DOUBLE PRECISION\n"
    "<OPTION>DATE\n"
    "<OPTION>TIME\n"
    "<OPTION>TIMESTAMP\n"
    "<OPTION>VARCHAR\n"
    "<OPTION>BIT\n"
    "<OPTION>BIT VARYING\n"
    "<OPTION>LONG VARCHAR\n"
    "<OPTION>BINARY\n"
    "<OPTION>VARBINARY\n"
    "<OPTION>LONG VARBINARY\n"
    "<OPTION>BIGINT\n"
    "<OPTION>TINYINT\n"
    "</SELECT>\n"
    "</TD>\n"
    "<TD VALIGN=TOP><SELECT NAME=CONVDST1>\n"
    "<OPTION VALUE=\"\">-\n"
    "<OPTION>CHAR\n"
    "<OPTION>NUMERIC\n"
    "<OPTION>DECIMAL\n"
    "<OPTION>INTEGER\n"
    "<OPTION>SMALLINT\n"
    "<OPTION>FLOAT\n"
    "<OPTION>REAL\n"
    "<OPTION>DOUBLE PRECISION\n"
    "<OPTION>DATE\n"
    "<OPTION>TIME\n"
    "<OPTION>TIMESTAMP\n"
    "<OPTION>VARCHAR\n"
    "<OPTION>BIT\n"
    "<OPTION>BIT VARYING\n"
    "<OPTION>LONG VARCHAR\n"
    "<OPTION>BINARY\n"
    "<OPTION>VARBINARY\n"
    "<OPTION>LONG VARBINARY\n"
    "<OPTION>BIGINT\n"
    "<OPTION>TINYINT\n"
    "</SELECT>\n"
    "</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP></TD>\n"
    "<TD VALIGN=TOP><SELECT NAME=CONVSRC2>\n"
    "<OPTION VALUE=\"\">-\n"
    "<OPTION>CHAR\n"
    "<OPTION>NUMERIC\n"
    "<OPTION>DECIMAL\n"
    "<OPTION>INTEGER\n"
    "<OPTION>SMALLINT\n"
    "<OPTION>FLOAT\n"
    "<OPTION>REAL\n"
    "<OPTION>DOUBLE PRECISION\n"
    "<OPTION>DATE\n"
    "<OPTION>TIME\n"
    "<OPTION>TIMESTAMP\n"
    "<OPTION>VARCHAR\n"
    "<OPTION>BIT\n"
    "<OPTION>BIT VARYING\n"
    "<OPTION>LONG VARCHAR\n"
    "<OPTION>BINARY\n"
    "<OPTION>VARBINARY\n"
    "<OPTION>LONG VARBINARY\n"
    "<OPTION>BIGINT\n"
    "<OPTION>TINYINT\n"
    "</SELECT>\n"
    "</TD>\n"
    "<TD VALIGN=TOP><SELECT NAME=CONVDST2>\n"
    "<OPTION VALUE=\"\">-\n"
    "<OPTION>CHAR\n"
    "<OPTION>NUMERIC\n"
    "<OPTION>DECIMAL\n"
    "<OPTION>INTEGER\n"
    "<OPTION>SMALLINT\n"
    "<OPTION>FLOAT\n"
    "<OPTION>REAL\n"
    "<OPTION>DOUBLE PRECISION\n"
    "<OPTION>DATE\n"
    "<OPTION>TIME\n"
    "<OPTION>TIMESTAMP\n"
    "<OPTION>VARCHAR\n"
    "<OPTION>BIT\n"
    "<OPTION>BIT VARYING\n"
    "<OPTION>LONG VARCHAR\n"
    "<OPTION>BINARY\n"
    "<OPTION>VARBINARY\n"
    "<OPTION>LONG VARBINARY\n"
    "<OPTION>BIGINT\n"
    "<OPTION>TINYINT\n"
    "</SELECT>\n"
    "</TD>\n"
    "</TR>\n"
    "<!-- We could have more of these conversion pop-ups, but at least\n"
    "     my Netscape starts behaving very erratically when there are four\n"
    "     pairs of them. -->\n"
    "<TR><TD VALIGN=TOP><B>New Name for Table(s)</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<INPUT TYPE=TEXT SIZE=45 NAME=\"new_name\" VALUE=\"&quot;!D&quot;.&quot;!N&quot;\">\n"
    "</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP><B>Initial Statement</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<INPUT TYPE=TEXT SIZE=45 NAME=init>\n"
    "</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP><B>Select Override</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<INPUT TYPE=TEXT SIZE=45 NAME=select>\n"
    "</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP><B>Unquoted Columns</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<INPUT TYPE=TEXT SIZE=45 NAME=unquoted_columns>\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP><B>Table Type(s)</B></TD>\n"
    "<TD VALIGN=TOP COLSPAN=2>\n"
    "<TABLE>\n"
    "<TR>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"TABLE\" CHECKED>\n"
    "<B>table</B></TD>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"SYSTEM TABLE\">\n"
    "<B>system table</B></TD>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"GLOBAL TEMPORARY\">\n"
    "<B>global temporary</B></TD>\n"
    "</TR><TR>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"VIEW\">\n"
    "<B>view</B></TD>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"SYNONYM\">\n"
    "<B>synonym</B></TD>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"LOCAL TEMPORARY\"> \n"
    "<B>local temporary</B></TD>\n"
    "</TR><TR>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=TABLETYPE VALUE=\"ALIAS\"> \n" "<B>alias</B></TD>\n" "</TR>\n" "</TABLE>\n" "</TD></TR>\n"
/* Quite unnecessary, at least currently.
"<TR><TD><B>Other tabletype(s)</B></TD>\n"
"<TD><INPUT TYPE=TEXT NAME=TABLETYPE></TD>\n"
"<TD>(enter in uppercase, separate with commas)</TD>\n"
"</TR>\n"
 */
    "<TR>\n"
    "<TD VALIGN=TOP><B>Insert Mode</B></TD>\n"
    "<TD COLSPAN=2><SELECT NAME=INSERT_MODE>\n"
    "<OPTION SELECTED>INTO\n" "<OPTION>SOFT\n" "<OPTION>REPLACING\n" "</SELECT>\n" "</TD>\n" "</TR>\n"
/* Quite unnecessary, at least currently.
"<TR>\n"
"<TD VALIGN=TOP><B>End Token</B></TD>\n"
"<TD COLSPAN=2><INPUT TYPE=TEXT NAME=ENDTOKEN VALUE=END>\n"
"</TD>\n"
"</TR>\n"
 */
    "<TR>\n"
    "<TD VALIGN=TOP><B>MaxLine/HexLen</B></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=TEXT NAME=FOREACH_MAXLINELEN VALUE=" DEFAULT_MAXLINELEN
    "></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=TEXT NAME=FOREACH_MAXHEXLEN VALUE=" DEFAULT_MAXHEXLEN
    "></TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=SUBMIT VALUE=DUMP></TD>\n"
    "<TD VALIGN=TOP><INPUT TYPE=RESET VALUE=CLEAR></TD>\n"
    "</TR>\n"
    "</TABLE>\n"
    "</FORM>\n"
    "<HR>\n"
    "<H3>Notes</H3>\n"
    "<UL>\n"
    "<P><LI>\n"
    "DBDUMP has been tested to work with <B>Kubl</B> as well as \n"
    "with <CODE>Microsoft Access, Driver version 3.40.2829.</CODE>\n"
/* "Now it more or less also works with " */
    "and\n"
    "<CODE>Microsoft SQL Server, Driver v. 02.65.0240.</CODE>\n"
    "(Although the BLOB-columns are still problematic).\n"
    "<P><LI>\n"
    "To work with Kubl it needs KUBL ODBC driver, version 0.92\n"
    "or newer, or needs to be linked with the corresponding static library\n"
    "<CODE>libwic.a</CODE> or <CODE>wic.lib</CODE>\n"
    "<P><LI>\n"
    "Only the datasources that have been defined as System DSN's are shown\n"
    "in the <B>Data Source</B> pop-up list given on the top of this form.\n"
    "This is the case when DBDUMP is used with the Microsoft Internet\n"
    "Information Server in Windows NT. When used in Unix you should enter\n"
    "into the textfield the host name and the port where Kubl is listening.\n"
    "The default is <CODE>localhost:1111</CODE>\n"
    "<P><LI>\n"
    "If you leave the <B>Tables to Link/Dump</B> field as empty, then all tables\n"
    "of the given <B>Table Type(s)</B> are listed (by default, all user defined\n"
    "tables). You can give in this field either an exact table name or\n"
    "a wildcard expression like <CODE>t%</CODE> to dump all tables beginning\n"
    "with the letter 't'. If you give a string\n"
    "like <CODE>Qual.Own.Name</CODE> then tablequalifier is set to\n"
    "<CODE>Qual</CODE>, tableowner to <CODE>Own</CODE> and tablename to\n"
    "<CODE>Name</CODE>. You can give multiple such tablename patterns separated\n"
    "with commas.\n"
    "<P><LI>\n"
    "Specify the format you want tablenames appear in <B>New Name for Table(s)</B>\n"
    "field. You can use markers <B><!-- CODE -->!Q<!-- /CODE --></B>, <B><!-- CODE -->!O<!-- /CODE --></B>\n"
    "and <B><!-- CODE -->!N<!-- /CODE --></B> to refer respectively to\n"
    "Qualifier, Owner and Name parts of the original name. The default is\n"
    "<B><!-- CODE -->&quot;!Q&quot;.&quot;!O&quot;.&quot;!N&quot;<!-- /CODE --></B> which will\n"
    "just copy each original tablename\n"
    "as it was, with all of its prefixes, each one surrounded by doublequotes.\n"
    "Use <B>!Q.!O.!N</B> to avoid this surrounding.\n"
    "Use single <B><!-- CODE -->!N<!-- /CODE --></B>\n"
    "to get rid off all but just the name part itself.\n"
    "Use <B><!-- CODE -->!O.!N@!Q<!-- /CODE --></B> to get Oracle-styled table names like\n"
    "ADMIN.EMP@EMPDATA\n"
    "<BR>Somewhat more contrived example:\n"
    "Use <B><!-- CODE -->Fou..Bar!N_!N2<!-- /CODE --></B> to move all dumped tables under\n"
    "qualifier (database) <B><!-- CODE -->Fou<!-- /CODE --></B> in the eventual destination database,\n"
    "and to leave owner unspecified, and to prefix each tablename with prefix\n"
    "<B><!-- CODE -->Bar<!-- /CODE --></B>, and duplicate the original name part itself,\n"
    "so that it will appear twice in the new name, separated by underscore,\n"
    "and followed by the digit&nbsp;2.\n"
    "<BR>E.g. <B><!-- CODE -->something.anything.bar<!-- /CODE --></B> would be converted to\n"
    "<B><!-- CODE -->Fou..Barbar_bar2<!-- /CODE --></B>\n"
    "<P><LI>\n"
    "You can give your own select statement to <B>Select Override</B> field.\n"
    "The default is  <CODE>" SELECT_DEFAULT "</CODE>  that is, dump all\n"
    "rows with all columns. Use <B><!-- CODE -->%s<!-- /CODE --></B> as a marker\n"
    "for the name of each table for which the DBDUMP is applied to, unless you\n"
    "give an explicit table name, in which case you should type that same\n"
    "table name to <B>Table Name</B> field also.\n"
    "<P><LI>\n"
    "In <B>Initial Statement</B> field you can specify one SQL-statement\n"
    "that is executed right after the connection, before any other operations.\n"
/* More crap:
"For example, if you are using <CODE>Microsoft SQL Server</CODE> and\n"
"want to discard all tablequalifier (i.e. database) and tableowner\n"
"information from the output, then check <B>Plain&nbsp;tablenames</B> button\n"
"and enter to this field a statement like <CODE>use&nbsp;pubs</CODE>, where\n"
"<CODE>pubs</CODE> is the name of database where DBDUMP's attention is\n"
"switched to (instead of default <CODE>master</CODE> database).\n"
"<BR>Otherwise, you can give <B>Table&nbsp;Name(s)</B> pattern explicitly as\n"
"<CODE>pubs..</CODE> or <CODE>pubs..%</CODE> to output all tables from <CODE>pubs</CODE> database,\n"
"listed with their full tablequalifier and tableowner prefixes.\n"
"<BR>However, in the latter case you cannot check <B>Plain&nbsp;tablenames</B> button\n"
"(unless you also give <CODE>use&nbsp;pubs</CODE> as init statement), because\n"
"then the <CODE>select</CODE>'s would be done from <CODE>master</CODE> database,\n"
"(which is the default when tablename is given without any prefixes),\n"
"instead of <CODE>pubs</CODE>.\n"
"<BR>With MS SQL Server you could also give in this field a statement\n"
"like <CODE>set&nbsp;rowcount&nbsp;7</CODE> (or even two statements at the same time:\n"
"<CODE>set&nbsp;rowcount&nbsp;7;&nbsp;use&nbsp;pubs</CODE>)\n"
"to effect that no more than 7 rows are listed from no more than 7 tables.\n"
 */
    "<P><LI>\n"
    "In <B>Unquoted Columns</B> field you can enter one or more comma-separated\n"
    "<CODE>tablename.columnname</CODE> pairs whose contents in output will not be enclosed\n"
    "with single quotes <CODE>(' ')</CODE> even if the corresponding nominal column\n"
    "types were VARCHARs. For example, you have to specify here all columns that\n"
    "contain vector data (lvectors, dvectors or fvectors) if you later want\n"
    "correctly import the produced output back to Kubl via Kubl Isql, i.e.\n"
    "so that vectors are kept as vectors, not corrupted to corresponding\n" "strings of their ascii representations.\n"
/* "(which is not very globewise!)\n" Cut the Crap!
"<BR>You may also use this feature for things like converting zip-codes\n"
"from strings to integers, if you are sure that they are always strictly\n"
"numeric in the source data\n"
"(In that case you would have to manually edit the\n"
"respective column type to INTEGER).\n"
 */
/* Obsolete options, notes commented out!
"<BR>Note that if you have <B>Prefixed tablenames</B> on, then you may\n"
"also specify here the tablequalifier and tableowner prefixes,\n"
"e.g. <CODE>db.dba.tabname1.colname1,db.dba.tabname2.colnamex</CODE>,\n"
"although it is not necessary. On the other hand, you don't need to\n"
"specify anything else than just bare column names\n"
"in which case all columns so named, regardless of in which table,\n"
"are thus unquoted.\n"
 */
    "<P><LI>\n"
    "Use <B>escape all names</B> option to prefix all table, index and\n"
    "column names with a backslash (\\), thus avoiding name conflicts with\n"
    "reserved SQL words like DATE and PASSWORD.\n"
    "<P><LI>Check one of the options <B>escape strange chars</B>,\n"
    "<B>escape only single quotes by doubling them</B>, etc to effect how\n"
    "string literals are escaped. Use former for C-like escaping, with a backslash\n"
    "followed upto three octal digits, and the latter for standard SQL-escaping\n"
    "with every single quote replaced by two. Note that the latter doesn't\n"
    "permit any newlines or other special characters in string literals.\n"
    "<P><LI>\n"
    "Use <B>dump to file instead of screen</B> option to send the data\n"
    "with the unknown content type instead of text/plain, thus forcing\n"
    "your browser to ask for a filename where to save the output, instead\n"
    "of showing it on the screen. Use this option if you have megabytes\n" "to dump and don't want to thrash your browser.\n"
/* This is not true anymore, as we now always read index information
   regardless whether it is output or not:
"<P><LI>\n"
"If you have checked the <B>table definitions only</B>, but not\n"
"the <B>index definitions only</B> option you might miss the type\n"
"of the primary key in those rare cases where the primary key is\n"
"defined with an additional index type, for example if originally defined\n"
"as <CODE>primary key(i1) clustered</CODE>, then the keyword\n"
"<CODE>clustered</CODE> is simply omitted from the dump output.\n"
 */
    "<P><LI>\n"
    "Use the <B>-d option</B> to force DBDUMP to use <CODE>select *</CODE>\n"
    "and <CODE>SQLDescribeCol</CODE> to get the columns of the table, instead\n"
    "of using the default <CODE>SQLColumns</CODE>. This might result a \n"
    "different ordering of columns. Don't use this one with Kubl if the\n"
    "database contains subtable (UNDER) definitions.\n"
    "<P><LI>\n"
    "Unless you check the <B>Never use foreach</B> option, DBDUMP will\n"
    "output every row with a column of type <B>LONG VARCHAR</B> or\n"
    "<B>LONG VARBINARY</B> using the parameterized <B>FOREACH BLOB</B> construct,\n"
    "which Kubl Isql will later recognize and parse accordingly.\n"
/* This is changed now?
"Currently, only the first blob column of each row is output in that way,\n"
"all others are output as quote-enclosed string literals.\n"
 */
    "In <B>MaxLine/HexLen</B> fields you can override the default maximum values\n"
    "used when the lines of foreach blobs are printed. If you give them as zero then\n"
    "blob lines got from the driver are never cut.\n"
    "<P><LI>\n"
    "To use DBDUMP in the command shell take the URL query string\n"
    "generated by this form (at the right side of the question mark)\n"
    "and give it as a command line argument, enclosed in doublequotes,\n"
    "or replace all ampersands (&AMP;) with " /* Stupid usage: slashes (/) or */ "spaces.\n"
/*
"<P><LI>\n"
"Use type conversions like <B>BIT -&GT; INTEGER</B> and \n"
"<B>LONG VARBINARY -&GT; LONG VARCHAR</B> if you want to transfer\n"
"data from other DBMS's to Kubl.\n"
 */
    "<P><LI>\n"
    "Use the conversion <B>TIMESTAMP</B> =&GT; <B>DATE</B> if you want to keep\n" "the original dates intact in Kubl.\n" "<P><LI>\n"
/* Very cumbersome hacker-stuff:
"To define more type conversions than those two that can be defined\n"
"with the pop-up menus you can manually add similar arguments\n"
"&AMP;CONVSRC3=type&AMP;CONVDST3=type&AMP;etc. after the end of the\n"
"URL generated by this form.\n"
 */
    "Check <B>Kubl Default Conversions</B> when your Data Destination is Kubl.\n"
    "It will effect the following type conversions to all columns of\n"
    "all tables fetched, in addition to any conversions of your own:\n" "<UL>\n" "$" DEFAULT_CONVERSIONS_TOKEN "\n" "</UL>\n"
/* Doesn't apply anymore, except to blobs that are not the first blob
   column in the row, and when the C-like backslash escaping is not
   used (or receiving DBMS doesn't understand it, or the string literal's
   length grows too big.)

"<P><LI>\n"
"<B>A Known Pitfall:</B>\n"
"Character data, if it contains newlines, whether in VARCHARs or\n"
"LONG VARCHARs (blobs), is printed out without any escape sequences,\n"
"and when the produced dump file is later read in with ISQLO, it will\n"
"blatantly fail.\n"
 */
/* Add this crap to release notes/documentation when that is finally
    written:
"<P><LI>\n"
"<B>Note:</B>\n"
"DBDUMP version 0.973 can now detect OBJECT_ID indices returned by\n"
"the Kubl ODBC driver (WIODBC.DLL version 0.94b or later).\n"
"If you have old databases created with Kubl server previous to version\n"
"0.95b G12d2 where KEY_IS_UNIQUE and KEY_IS_OBJECT_ID\n"
"columns were swapped in SYS_KEYS table, you might get funny\n"
"results, with all the unique indices dumped as they were OBJECT_ID indices.\n"
"You can use your editor to swap the index definitions manually from the\n"
"produced dump file.\n"
 */
    "<P><LI>\n"
    "<B>Warning:</B>\n"
    "If you have any datasources among your System DSN's, which themselves\n"
    "haven't been protected by the username/password checks\n"
    "then you might want to limit the access to this CGI-script with the\n"
    "password, by explicitly configuring your Web server.\n";



/***********************************************************************/
/*                                                                     */
/*   Template for the Transfer Page follows, in two parts.             */
/*   Here we use METHOD=POST and ENCTYPE="multipart/form-data"         */
/*   because that allows the largest amount of data to be passed from  */
/*   this form. Currently this is 65500 bytes per one field            */
/*   (also the TEXTAREA S_EXEC field, which is filled here, and        */
/*    which might now easily overflow)                                 */
/*   but in future isqlodbc.c should modified so that when S_EXEC      */
/*   is encountered in RFC1521/RFC1867 stream, it is not collected     */
/*   to a normal Url-argument, but instead, command reading is started */
/*   from that point of stdin, like the user were interactively        */
/*   feeding those same commands, meaning that indefinitely long       */
/*   series of statements can be transferred.                          */
/*                                                                     */
/*   No, now we don't use even that, just an ordinary Urlencoded POST  */
/*   No, we try it! No, we don't! Now... maybe some day we can decide! */
/***********************************************************************/


char *transfer_html_page_string1 =
    "<HTML><HEAD><TITLE>Kubl DBDUMP (version " DBDUMP_VERSION ") -&gt; ISQLO</TITLE>\n"
    "</HEAD>\n" "<BODY>\n" "<FORM ACTION=\"" TRANSFER_PROGRAM_CGI_LOCATION "\" METHOD=POST ENCTYPE=\"multipart/form-data\">\n"
/* "<FORM ACTION=\"" TRANSFER_PROGRAM_CGI_LOCATION "\" METHOD=POST>\n" */
    "<TABLE>\n"
    "<TR>\n"
    "<TD VALIGN=TOP NOWRAP><B>Data Destination</B></TD>\n"
    "<TD COLSPAN=2>$" DATASOURCE_TOKEN "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP><B>Username&nbsp;&amp;&nbsp;Password</B></TD>\n"
    "<TD><INPUT TYPE=TEXT NAME=S_CONUSER SIZE=10><INPUT TYPE=CHECKBOX NAME=S_EMPTY_USERNAME VALUE=\"ON\">(empty)</TD>\n"
    "<TD><INPUT TYPE=PASSWORD NAME=S_CONPASS SIZE=10><INPUT TYPE=CHECKBOX NAME=S_EMPTY_PASSWORD VALUE=\"ON\">(empty)</TD>\n"
    "</TR>\n"
    "<TR><TD VALIGN=TOP><B>Statements</B></TD>\n"
    "<TD COLSPAN=2>One or more, separated with semicolons (;) <INPUT TYPE=SUBMIT VALUE=\"DO IT!\"></TD></TR>\n"
    "<TR><TD VALIGN=TOP COLSPAN=3><TEXTAREA NAME=\"S_EXEC\" ROWS=17 COLS=60>\n";

/* The output from previous dbdump (presumably the schema, plus
   maybe also contents), is output here, between these two templates.
   Of course it should be also HTMLEscaped, but as long as
   we transfer just schemas, we don't care.
   Only in actual contents might occur few angle brackets <, >, etc.
 */

char *transfer_html_page_string2 =
    "</TEXTAREA></TD></TR>\n"
    "<TR>\n"
    "<TD VALIGN=TOP><B>Options</B></TD>\n"
    "<TD COLSPAN=2>\n"
    "<TABLE>\n"
    "<TR>\n"
    "<TD><INPUT NAME=\"S_MAXROWS\" TYPE=TEXT SIZE=8 VALUE=\"1000\">\n"
    "<!-- B -->Max Rows<!-- /B --></TD>\n"
    "<TD><INPUT NAME=\"S_TIMEOUT\" TYPE=TEXT SIZE=8 VALUE=\"1000\">\n"
    "<!-- B -->Timeout in Seconds<!-- /B --></TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=\"S_READMODE\" VALUE=\"SNAPSHOT\">\n"
    "<!-- B -->Snapshot Readmode<!-- /B --></TD>\n"
    "<TD>\n"
    "<INPUT TYPE=CHECKBOX NAME=\"S_AUTOCOMMIT\" VALUE=\"ON\"> <!-- B -->Autocommitted Execution<!-- /B -->\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD>\n"
    "<INPUT TYPE=CHECKBOX NAME=\"S_BLOBS\" VALUE=\"ON\"> <!-- B -->Show Blobs<!-- /B -->\n"
    "</TD>\n"
    "<TD>\n"
    "<INPUT TYPE=CHECKBOX NAME=\"S_BANNER\" VALUE=\"OFF\"> <!-- B -->No Banner<!-- /B -->\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD>\n"
    "<INPUT TYPE=RADIO NAME=\"S_VERBOSE\" VALUE=\"OFF\"> <!-- B -->Brief<!-- /B -->\n"
    "</TD>\n"
    "<TD>\n"
    "<INPUT TYPE=RADIO CHECKED NAME=\"S_VERBOSE\" VALUE=\"ON\"> <!-- B -->Verbose Output<!-- /B -->\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD>\n"
    "<INPUT CHECKED TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"text/plain\">\n"
    "<!-- B -->Output in raw text format to screen<!-- /B -->\n"
    "</TD>\n"
    "<TD>\n"
    "<INPUT TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"x-isql/plain\">\n"
    "<!-- B -->Output in raw text format to file<!-- /B -->\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD COLSPAN=2>\n"
    "<INPUT TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"text/html\">\n"
    "<!-- B -->Output in HTML format to screen<!-- /B -->\n"
    "</TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD><INPUT CHECKED TYPE=CHECKBOX NAME=\"S_OO_SB\" VALUE=\"&LT;TABLE&#32;BORDER&GT;\">\n"
    "<!-- B -->Use Table Borders<!-- /B --></TD>\n"
    "<TD><INPUT TYPE=CHECKBOX NAME=\"S_OO_ESC\" VALUE=\"OFF\">\n"
    "<!-- B -->No HTML-Escaping<!-- /B --></TD>\n"
    "</TR>\n"
    "<TR>\n"
    "<TD><INPUT TYPE=SUBMIT VALUE=\"Do it\"></TD>\n"
    "<TD><INPUT TYPE=RESET VALUE=\"Reset\"></TD>\n"
    "</TR>\n" "</TABLE>\n" "</TD>\n" "</TR>\n" "</TABLE>\n" "</FORM>\n" "</BODY></HTML>\n";
