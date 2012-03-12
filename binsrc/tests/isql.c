/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include <stdlib.h>
#undef MALLOC_DEBUG
#include "Dk.h"
#include "libutil.h"
#include "odbcinc.h"
#include "timeacct.h"

#ifdef WIN32
#include <windows.h>
# include <winsock.h>		/* For struct timeval */
#include <process.h>
#include <conio.h>
#include <locale.h>
#include <time.h>
#else
#include <netdb.h>
#include <netinet/in.h>
#endif

#include "isql_tchar.h"

#if (defined(UNICODE) || defined (_UNICODE)) && !defined (WIN32) && !defined (HAVE_WPRINTF)
#error It appears that your system does not support unicode console input/output. If you happend to be using glibc 2.1, please upgrade to more recent version
#endif


#if defined(WITH_READLINE)
#include <readline/readline.h>
#include <readline/history.h>
#endif

#if defined(WITH_EDITLINE)
#include <editline/readline.h>
#endif

/* Changed from 0.9845b at 07-DEC-1997 */
/* Changed from 0.9846b at 26-JAN-1998 */
/* Changed from 0.9847b at 12-FEB-1998 */
/* Changed from 0.9848b at 18-MAR-1998 */
#define ISQL_VERSION _T("0.9849b")


TCHAR *isql_version = ISQL_VERSION;

/*

ISQL/ISQLODBC  --  Interactive SQL client shell for KUBL DBMS


VERSION HISTORY:

The original bare-boned version (isql.c): Orri Erling

From the version 0.972b (since January 1997) onward developed
by Antti Karttunen.

This program is also used for reading in SQL-files produced
by DBDUMP.

Changes, from January 1997 onward

Version 0.972b: implemented first versions of new features, like

* Printing correctly blob and date/timestamp columns.

* The first rudimental versions of foreach, set, show and load commands.

* Commands TABLES, COLUMNS, PRIMARYKEYS, STATISTICS, etc. calling
the corresponding SQL-API-functions.

* Counting of the bracelevel of procedure definitions.


02-MAR-1997 AK  Corrected print_error.
03-MAR-1997 AK  Added FOREACH TIMESTAMP for testing timestamp params.
Cleaned few help texts (foreach and set).

20-MAR-1997 AK  Version changed from 0.973b to 0.974b
25-MAR-1997 AK  Added gnu readline routine thanks to a
tip from Han Holl. (should be compiled with
HAVE_READLINE defined in Linux)
Added also FOREACH item BETWEEN form
mainly for testing purposes.

26-MAR-1997 AK  Added spawning-possibility, i.e. if the input line
ends with the ampersand (&) instead of the normal
semicolon (;) then an asynchronous subprocess of
this same executable is spawned that should run the
statement(s) specified on that line. The statements
to be executed are given to the new subprocess
with the EXEC= option, and if there are more than
one statement they are separated with semicolons.

ISQL-command WAIT_FOR_CHILDREN will suspend the
execution of the parent process until all spawned
children have finished.

Corrected parse_statement_for_special_parameters
and count_bracelevel to take heed of the new
possibility of escaping singlequotes also with
backslash. Added also semicolon marking to
count_bracelevel to serve the new possibility
of executing multiple statements with one EXEC= option.
(See the note about spawning above.)

28-MAR-1997 AK   Moved read-eval-print loop from the end of main function
to its own function, called rep_loop. Now load command
will call it by default, unless the option -r is specified
in which case the old load_raw routine is used which
can be applied only to procedure definitions.

Also, when reading with rep_loop (interactively from user
or with load command without -r option) and
CREATE PROCEDURE or TRIGGER definition is encountered
which doesn't end with semicolon it is now sent to
server anyway.

New ISQL-commands ECHO and NOP. An empty line followed
by semicolon is also now ignored (not sent to server).
Added get_next_token macros like $RETVAL, $RETVALLEN,
$ROWCNT, $EQU, $NEQ and $IF with which it is possible
to write conditional ISQL-commands, so helping us
to write test-scripts with isql itself.

E.g. a command like following is legal, and will print
"nautajauheliha" followed by newline:

echo $if $equ 3 3 $if $equ 4 5 "sika" "nauta" "mursu" "jauheliha\n";

Also following works:

$IF $NEQ $RETVAL "FOU" EXIT ECHO "Assertion passed RETVAL=" $RETVAL "\n";

But this DOESN'T work:

$IF $EQU $RETVAL "FOU" ECHO "Assertion passed RETVAL=" $RETVAL "\n" EXIT;

(Which means that we need later a real IF-STATEMENT
with THEN, ELSE and FI keywords, as well as few other
real shell features like GOTO, WHILE,
SET EXIT ON ERRORS LIKE "4*", whatever...)

Note that these haven't been documented yet, and their
usage might slightly change later, so use with caution.

15-APR-1997 AK   Corrected the eating of SET PASSWORD and SET USER GROUP
commands, which are now sent to server as they should.

18-APR-1997 AK   New $-macros $STATE and $MESSAGE for SQL error state
checking, and $ARGV[$I] for argument passing from
command line.

19-APR-1997 AK   Made error messages more informative in regard to
in which file, at which line they occurred, with the
new system of load expression and linecount stacks.
(See macro current_linecount() and functions
push_to_loadexpr_stack and drop_from_loadexpr_stack)

It's now possible to overwrite ARGV vector elements
with SET ARGV[n] 'newvalue'  command.
Together with a new $-macro $+ (plus) it can be used
for keeping counts of passes and failings of tests, etc.
(Yes, it's a crude attempt at user variables and
leaks memory a little with each new strdup which is
not currently freed anywhere.) Now (29-APR-97) it is,
see G_argv_touched.

21-APR-1997 AK   Renamed get_next_keyword to get_next_token

24-APR-1997 AK   Version changed to 0.976b because of the following
changes:

Changed isql_exit(-1) to isql_exit (2) when losing
connection, because IF ERRORLEVEL 1 doesn't detect
the exit code -1 in Windows NT MS-DOS shell.
SO! Always use only exit codes 0 (success) and
1 (generic failure), 2 (Lost line, 08S01) or
3 (could not connect to) when exiting from isql !!!
(should be #defined somewhere indeed...)

Added fclose(in_fp) to isql_foreach after statements
like: FOREACH item IN filename
has been executed.

Modified field_print so that it now avoids any
unnecessary padding with blanks on the right side
if the column to be printed is the rightmost one.
Because of that, added inx argument to field_print
and print_datetime_col

Made load_raw (actually do_statement that it calls)
to return more civilized error-message when something
is screwed: instead of showing whole procedure
definition twice it will now show procedure definition
once and then the procedure name if it was specified.
(Well, actually the first procedure definition of
error message is included in the error message
that is got from Kubl server.)

Modified EXIT statement so that EXIT NOT is NO-OP,
allowing statements like:

EXIT $IF $EQU $ARGV[0] 10 $+ 50 $ARGV[0] NOT;

which exits with exit code 60 if $ARGV[0] is ten
(presumably keeping a somekind of failure counter)
but otherwise does nothing special, and continues
from the next statement. (Real IF-statement is
needed again...)

Implemented deadlock retry counter tentatively
(new variables perm_deadlock_retries and
vol_deadlock_retries, ISQL-command SET DEADLOCK_RETRIES
modified print_error function and IF_SEVERE_ERR_GO).
Currently has any effect only with
FOREACH statements if SET DEADLOCK_RETRIES is
explicitly set to non-zero value.

Splicing of EXEC= option created by spawn_to_background
before the -i option (if it is present), so that it
will have any effect in the daughter process.


02-MAY-1997       Started doing a WEB-interface, taking pieces from
old W3SQL, whose Windows version is more or less
in deep freeze now.


03-MAY-1997       Version changed to 0.977b

Added n+1 casts between unsigned char * and char *
(using macros SCP and UCP) to make code C++ compilable.

Added the command SET ACCESSMODE RO/RW.

The $dollar_form substitution implemented in the
function parse_statement_for_special_parameters
which may now destructively modify its string argument.
See comment in the beginning of function exec_one.

Changed spawnv to spawnvp (Windows), and execv to execvp
(Unix), so that spawning commands to background
will find isql from anywhere in the path.

14-MAY-1997       Version changed to 0.978b
IMPORTANT CHANGE: Now the connection is done in the
delayed way, that is, only after a command is
encountered that really needs a database connection.
This allows specifying DSN, USERNAME and
PASSWORD, as well as HTTP content type used with
the commands SET DSN=, SET UID=,
SET PWD=, and SET CONTENT_TYPE= in the beginning
of the loaded ISQL file.
However, if the datasource (possibly together with
username and password) has been given from the
command line in traditional way (that is: not with
equal signs as DSN=Kubl, but just as Kubl)
then the connection is established almost immediately
in the beginning, as was the case before this version,
so this should not break any existing test suites.

Added also LOAD= option, for explicitly specifying
from the command line the file(s) to be loaded.

Wrote isql_exit as its own function (not just as macro)
that will do things like writing command history
(if compiled with HAVE_READLINE in Linux),
SQLShutdown (if connected to server) and
terminating HTML page clearly with proper tags
(if in Web mode, and content_type is "text/html")
before finally exiting.

Expressions like $LAST[$ARGV[$I]] work correctly now,
because of proper counting of nested brackets
with the new function find_closing_point.

Implemented associative array U for User and URL
variables. Additions to get_next_token and
is_set_subcommand.

get_next_token now cuts tokens to first
opening or closing brace/bracket/parenthesis/angle
bracket, as well as to comma, that is, all of the
{ }, [ ], ( ) and < >, will be
returned one token (of one character) per time.

Started major streamlining of get_next_token
by tabulating all more or less regular $ dollar-macros
into the table isql_variables with the macro
add_var_def. Implemented the rest of comparison
macros, $LT, $LTE, $GT and $GTE at the same time.

This streamlining needs to be extended into
is_set_subcommand also, e.g. so that it will
use the same table-scanning function as
get_next_token, both for showing and setting.
(mostly done now).

The return values of get_next_token should be cleansed
e.g. special token_null for NULL's, and token_error
for syntax errors, etc.

Needs to be done: Finishing deadlock retry counter.

Cleaning up the code for C++ compilation.
(Mostly done 3-MAY-1997, by adding SCP and UCP casts).

Dividing this source file to separate modules.

Checking for any minor strdup memory leaks.

Collecting all the global variables into somekind
of a structure (that would passed around in stack),
so as to make code more re-entrant, in anticipation
for the eventual multi-threaded implementation.

BULK-parameters for foreach statement.

And output parameters for procedures, e.g.
call FOU(?,?Oout_param1<2000>)
would allocate a buffer of 2000 plus one bytes,
assign a new (or old???) user variable named out_param1
to it, and bind that as the second, output parameter
of the procedure call to function FOU.
Then it would be possible to say echo $out_param1
Not that way, instead call FOU(?,?>2000U{newout})
or FOU(?,?2000>U{newout}) ? or FOU(?,?2000U{newout}) ?
Anyway, it would allocate a new 2000 bytes long
of user-variable called newout (if one didn't exist
already, in which it would be used instead), and
then bind it as output variable before continuing.

Also, dollar form $:name which were like $name
but would automatically wrap the result in single
quotes unless it evaluates to NULL.

More fancy options for FOREACH (see comments before
isql_foreach) allowing to build all kinds of loops
(e.g. non-?-parameterized version of FOREACH, calling
exec_one each time.)
and for reading in text files formatted in various ways
(e.g. CSV), maybe also something like
FOREACH name, value OF U call something(?,?); ???


Adding more $-macros, like $OR, $AND,
$LIKE and all the sundry others.

Implementing real IF THEN ELSE FI command, GOTO,
SET EXIT ON ERRORLEVEL '2*', and whatever else is
needed.

Substituting of $dollar_forms in SQL-statements
themselves (done now, see above), and/or implementing
?$ -parameters for foreach.
(The whole concept requires rethinking).

Ability to execute multiple statements (lines)
in one transaction. E.g. form like:
TRANSACT { statement1;
statement2;
statement3;
etc;
} -- Transaction ends here.
Or maybe just special commands:
TRX_BEGIN; and TRX_END; ?

Documentation.

Misgivings:       This program seems to become a yet another shell-like
interpreted programming language, of which there
are already more than enough in this world.
Building a really good ODBC-api into some existing
tool language (e.g. Perl, Python, or even gawk, csh
or bash) might be a better idea after all, provided
that language/shell/tool is easily available on all
platforms. But anyway, it's a handy tool (when finally
documented)!

11-JUN-1997  AK   Version now 0.980b
Added options TRAILING_NEWLINES=0 & BINARY_OUTPUT=ON
for the exact outputting of contents of blob columns.
Use them together with options VERBOSE=OFF BANNER=OFF
(possibly also PROMPT=OFF) and of course BLOBS=ON
to fetch a blob column just as it was originally
inserted into the database.

25-JUN-1997  AK   Added call to SQLRowCount in show_results and
exec_for_foreach.
SQLRowCount is now implemented with wiodbc.dll
version 1.05b, Kubl version 0.96b G14d3.
show_results needs a thorough cleaning anyway.
Version changed to 0.981b

09-JUL-1997  AK   Added second argument to push_to_loadexpr_stack
(which is the next current input stream used by load)
effecting that now FOREACH item
without the IN keyword reads the following items
(lines or blobs) always from the same source as
where the FOREACH statement itself was read from,
not stupidly from stdin as was case before.
This form of FOREACH doesn't yet work with
Webgate, when FOREACH statement is in EXEC-option.

21-AUG-1997  AK   Squashed an insidious bug in field_print which
caused numbers in the rightmost fields to be omitted
from the output. (Also, the TMPBUF_SIZE has been
grown to 560 to avoid crashings with certain test
procedures.)

11-SEP-1997  AK   Corrected the sleep command in the Windows version.
Hadn't realized that Sleep requires milliseconds,
not seconds, so now the argument is multiplied by
thousand. Version changed to 0.984b.

12-SEP-1997  AK   Added a spawning-possibility of shell-commands with !
(Added a new function spawn_shell_command).
Added also a Forced Load feature, which checks in
the beginning of main that if this program is started
with a name containing an underscore then the part
after an underscore is used as a filename (suffixed
with .sql) which is automatically loaded in as a
first file. By giving EXIT; as a last command in that
file the administrator can make sure that nothing else
is done with isql than what is specified in that file.
This is an useful feature for allowing certain
specific operations to be run by the public via the Web.

14-NOV-1997  AK   Version 0.9845b
Improved RFC1867 HTML file-upload receiving.
(Still to be extensively checked).
Now correctly escapes singlequotes and all other
problematic characters (e.g. newlines, backslashes)
when doing $-prefixed ISQL-variable substitutions
inside string literals (i.e. singlequotes) in SQL
statements that are to be sent to the server.
Improved function show_results so that it now
will dynamically increase the size of column's
result buffer in case the new precision of column
is greater than the previously allocated size.
Tried to compile the program with SQLCLI headers
(sqlcli.h, sqlicli2.h and odbc2cli.h) instead
of Microsoft's sql.h and sqlext.h. Made some
changes for that.

07-DEC-1997  AK   Version 0.9846b. Doesn't bind blob columns anymore,
unless BLOBS=OFF (print_blobs_flag is zero.)

26-JAN-1998  AK   Version 0.9847b
Added SQL_SCOPE_TRANSACTION and SQL_SCOPE_SESSION
to SpecialColumns commands
(used instead of default SQL_SCOPE_CURROW when
option /t or /s is present with /b).

*/

#ifndef ODBC_ONLY
# define ISQL_TYPE	_T("(Virtuoso)")
# define ISQL_TYPE_N	"(Virtuoso)"
#elif defined (UDBC)
# define ISQL_TYPE	_T("(UDBC)")
# define ISQL_TYPE_N	"(UDBC)"
#else
# define ISQL_TYPE	_T("(ODBC)")
# define ISQL_TYPE_N	"(ODBC)"
#endif

/* The default values for the three first command line arguments.
Have to be global as a few functions need these.
*/
#if defined(ODBC_ONLY)
TCHAR *datasource = _T("Virtuoso");
TCHAR *username = NULL;
TCHAR *password = NULL;

#else
TCHAR *datasource = _T("localhost:1111");
TCHAR *username = _T("dba");
TCHAR *password = NULL;
TCHAR *connect_port = NULL;
TCHAR *encryption = NULL;
TCHAR *ca_list = NULL;
int pwd_cleartext = 0;
#endif

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif


#define NO  !
#define NOT !
#define empty_stringp(X) (!*(X))


#if defined(WITH_READLINE) || defined(WITH_EDITLINE)
/* The following declaration should be located before loading Dk.h */
static void readline_free(void *ptr) { free(ptr); }



TCHAR isqlhist[313] = {'\0'};	/* Path name for readline history file */
#endif

#if 1
/* Was: #define strncasecmp isqlt_tcsncmp */
#define strncasecmp isqlt_tcsnicmp	/* Changed by AK. */
#define strcasecmp  isqlt_tcsicmp
#endif


#ifndef UINT
#define UINT unsigned int
#endif

#if defined (UNICODE) || defined (_UNICODE)
#define UTCHAR TCHAR
#define tspawnvp _wspawnvp
#else
#define UTCHAR unsigned TCHAR
#define tspawnvp _spawnvp
#endif

#define UCP(X) ((UTCHAR *) ((X)))
#define SCP(X) ((TCHAR *) ((X)))

#ifndef SQL_NO_TOTAL
#define SQL_NO_TOTAL (-4)
#endif


#ifdef WIN32
# ifndef get_msec_count
#  define get_msec_count() GetTickCount ()
# endif
# define isql_sleep(S) Sleep(((DWORD)(S))*1000)	/* Wants milliseconds. */
#else
/* In Unix we have real sleep */
# define isql_sleep(S) sleep(S)
#endif


typedef int (*PFI) (TCHAR *);	/* Pointer to Function returning int (K&R C) */

typedef TCHAR *(*PFSTR) (TCHAR *);
/* Pointer to function returning a char pointer, taking one string as
its argument. */

#define NULLFP ((PFI)0)		/* Null function pointer. Don't call this one! */
#define IS_NULLFP(X) ((NULLFP) == ((PFI)(X)))

#define MAX_COL_WIDTH   15

#define MAXFILE_DEPTH 101

/* Stupid: should be in one stack, multiplied of an appropriate structure */
TCHAR *LOAD_loadexpr_stack[MAXFILE_DEPTH + 1] =
{_T("Top-Level"), NULL};
/* First one should be immediately initialized to stdin in the beginning
of main: */
FILE *LOAD_filepointer_stack[MAXFILE_DEPTH + 1] =
{NULL};
unsigned long int LOAD_linecount_stack[MAXFILE_DEPTH + 1] =
{0};
unsigned long int LOAD_lsline_stack[MAXFILE_DEPTH + 1] =
{0};
int loadfile_sp = 0;		/* "Stack Pointer" referencing arrays above */


#define current_loadexpr() LOAD_loadexpr_stack[loadfile_sp]
#define current_input_stream() LOAD_filepointer_stack[loadfile_sp]
#define current_linecount() LOAD_linecount_stack[loadfile_sp]
#define latest_statement_begins_at() LOAD_lsline_stack[loadfile_sp]

TCHAR tmp_SQL_error_state[15] =
{'O', 'K', '\0'};
TCHAR SQL_error_state[15] =
{'O', 'K', '\0'};
#ifdef WIN32
TCHAR tmp_SQL_error_message[1000] =
{'O', 'K', '\0'};
TCHAR SQL_error_message[1000] =
#else
TCHAR tmp_SQL_error_message[10 * SQL_MAX_MESSAGE_LENGTH - 1] =
{'O', 'K', '\0'};
TCHAR SQL_error_message[10 * SQL_MAX_MESSAGE_LENGTH - 1] =
#endif
{'O', 'K', '\0'};

#define clear_SQL_state_and_message()\
(isqlt_tcscpy(SQL_error_state,_T("OK")),isqlt_tcscpy(SQL_error_message,_T("OK")))

/* Set by connect_to_datasource, can referred with $DBMS and $DRIVER
dollar forms, in get_next_token. */
TCHAR info_dbms[100] =
{'\0'};
TCHAR info_driver[100] =
{'\0'};


HDBC hdbc = ((HDBC) 0);		/* Was: NULL; */
HENV henv = ((HENV) 0);		/* Was: NULL; */
HSTMT stmt = ((HSTMT) 0);	/* Was: NULL; */

TCHAR **G_argv;			/* Global versions of argv and argc, used by */
int G_argc, G_argc_i = 0;	/* spawn_to_background for example. */
/* The elements of this vector are switched to non-zeros when the
corresponding elements of G_argv vector are changed to strdupped
strings, so that if they are changed second time, the previous
version can be free'ed. Just to avoid a minor memory leak.
*/
TCHAR G_argv_touched[200] =
{0};				/* Should be all zeros and bytes. */


TCHAR *web_content_type = _T("text/plain");
TCHAR *web_query_string = NULL;	/* from environment variable QUERY_STRING */

#define in_HTML_mode() (!isqlt_tcscmp(web_content_type,_T("text/html")))

int web_mode = 0;		/* Is set to 1 in the beginning of main if used
			       as a cgi-script */
int kubl_mode = 1;		/* Currently affects only how MAXROWS are handled. */
int print_banner_flag = 1, print_types_also = 1, verbose_mode = 1, echo_mode = 0, explain_mode = 0, sparql_translate_mode = 0;
int flag_newlines_at_eor = 1;	/* By default print one nl at the end of row */
long int select_max_rows = 0;	/* By default show them all. */
long int perm_deadlock_retries = 0, vol_deadlock_retries = 0;
int flag_binary_output = 0;	/* Has effect on Windows platforms. */
int commit_mode = 0;		/* Zdravko: for manual autocommit */

int virtuoso_shutdown = 0;
int virtuoso_debug = 0;

#ifdef ODBC_ONLY
int virtext=0;
#else
int virtext=1;
#endif


TCHAR *progname = _T("ISQL");	/* Might be set in main to *argv */
TCHAR *print_prompt = _T("SQL> ");

TCHAR *empty_string = _T("");
/* Overridden with EXEC command line option */
#define MAXEXECS_FROM_CMDLINE 101
int execs_from_cmdline = 0;
TCHAR *execute_these_only[MAXEXECS_FROM_CMDLINE + 1] =
{NULL};

#define MAX_ARGS_FOR_SHELL_PROGRAM MAXEXECS_FROM_CMDLINE

#define MAX_FILES_FROM_COMMAND_LINE 22
TCHAR *files_to_load[MAX_FILES_FROM_COMMAND_LINE + 2] =
{NULL};
int load_n_files = 0;		/* A zero-based index to previous. */

int fully_connected = 0;


#define SYSTEM_VARIABLE_URL_PREFIX _T("S_")

#define DEFAULT_DATASOURCE_IN_UNIX _T("localhost:1111")
#define DEFAULT_HTML_TEMPLATE_FILE _T("isql.htm")
#define DATASOURCE_TOKEN _T("INPUT_DATASOURCE")

TCHAR *form_action = _T("");
TCHAR *get_list_of_datasources (int for_html, TCHAR *dest_buf, int dest_size);
int output_html_file (TCHAR *templatename);

/* Only after fully_connected has been set to non-zero (i.e. after
full connection to data source and statement allocation)
are the settings saved to delayed_settings vector really
executed in function is_set_subcommand
*/
#define MAX_DELAYED_SETTINGS 50
TCHAR *delayed_settings[MAX_DELAYED_SETTINGS + 2] =
{NULL};
int n_delayed_settings = 0;	/* A zero-based index to previous. */

#define MIN_INPUT_SIZE 250000
TCHAR input1[MIN_INPUT_SIZE + 20];
int input_size = MIN_INPUT_SIZE;
TCHAR *input = input1;
#define INPUT_SIZE input_size

#define not_pointing_to_input_buf(PTR)\
(((PTR) < &input[0]) || ((PTR) >= &input[INPUT_SIZE]))


#ifndef TMPBUF_SIZE
#define TMPBUF_SIZE 560
#endif

#define RETVALBUFSIZE 3003
TCHAR retvalbuf[RETVALBUFSIZE + 10] =	/* Referred with $RETVAL */
{'N', 'O', 'T', ' ', 'S', 'E', 'T', '\0'};
SQLLEN cbRetVal = 0;		/* Referred with $RETVALLEN */
SQLLEN sdtmp;
int N_rows = 0;			/* Referred with $ROWCNT */

/* These are now global so that we can refer to this with
get_next_token dollar-macro $LWE (LAST WORD ECHOED).
See functions isql_echo and get_next_token.
However, now that has been much obsoleted by another kludge: $LIF
Now isql_echo_lwe is used more as a flag. If non-null it tells
that echo command has been already used, and in web-mode it is
no use to print ContentType header anymore.
Giving ECHO $LWE as the first command is a stupid thing to do.
*/
#define ISQL_ECHOBUF_SIZE 2001
TCHAR isql_echo_word_buf[ISQL_ECHOBUF_SIZE + 20] =
{'\0'};
TCHAR *isql_echo_lwe = NULL;	/* Was: &isql_echo_word_buf[0]; */

/* Can be changed to stdout by user with ERRORS=STDOUT from commandline */
FILE *error_stream = NULL;	/* Should be immediately assigned to stderr. */

/* If this flag is toggled to non-zero with BLOBS ON command, the blobs
   are printed out in full. */
int print_blobs_flag = 0;
int foreach_err_break = 0;
int bind_blobs_flag = 0;	/* By default, don't do it. */
/* These are swapped automatically in the beginning if we use an
   Old Kubl driver, version less than 0.92: */
int times_conform_to_odbc_flag = 1, times_to_strings_flag = 0;
int clear_hidden_crs_flag = 1;	/* When reading multiline blobs. */
/* If set to 0 then no dollar-substitution is done inside SQL-statements: */
int flag_macro_substitution = 1;
int flag_ignore_params = 0;
int trim_string_result = 0;
int command_text_on_error = 1;

#ifndef ODBC_ONLY
int flag_bind_return_values = 1;
#else /* Doesn't work with the current version of MS Driver Manager. */
int flag_bind_return_values = 0;
#endif

TCHAR * current_file = NULL;

/* These are all for multipart/form-data file upload thing. */
TCHAR *form_filename = NULL;	/* filename from the first Content-Disposition encountered with filename parameter. */
TCHAR *form_filefieldname = NULL;	/* name from the first Content-Disposition encountered with filename parameter. */
TCHAR *form_last_content_type = NULL;	/* Latest Content-Type encountered. */
TCHAR *form_last_encoding = NULL;	/* Latest Content-Transfer-Encoding */
TCHAR *form_boundary = NULL;	/* The boundary string used, with the initial --, but not with the terminating -- */

/* ============================================================== */
/* Output Variables related to HTML output                        */

TCHAR *oo_sb = _T("<TABLE>");	/* Set Begin... */
TCHAR *oo_se = _T("</TABLE>");	/*  and Set End */
TCHAR *oo_rb = _T("<TR>");		/* Row Begin... */
TCHAR *oo_re = _T("</TR>");		/*  and Row End */
TCHAR *oo_hb = _T("<TH>");		/* Heading cell Begin... */
TCHAR *oo_he = _T("</TH>");		/*  and Heading cell End */
TCHAR *oo_db = _T("<TD>");		/* normal Cell Begin... */
TCHAR *oo_de = _T("</TD>");		/*  and normal Cell End */

TCHAR *oo_ob = _T("<PRE>");		/* Other text, Begin. */
TCHAR *oo_oe = _T("</PRE>");		/* Other text, End. */

int oo_esc = 1;			/* Normally escape <, > and & */


/* Necessary quite soon. */
TCHAR *get_next_token (TCHAR **str_ptr, TCHAR *result, int maxsize,
		      TCHAR *input_buffer, int input_size);


void html_print_head_title (FILE * fp, TCHAR *title1, TCHAR *title2, TCHAR *title3);

int flag_head_already_printed = 0;

int
print_http_headers_if_not_already_printed ()
{

  if ((0 == flag_head_already_printed) && web_mode)
    {				/* Print the HTML headers, as this is the last change to do it. */
      flag_head_already_printed = 1;
      {
/* Obsolete: if(NOT isql_echo_lwe)  No output done yet with ECHO command? */

	{
	  isqlt_tprintf (_T("Content-Type: %") PCT_S _T("\r\n\r\n"), web_content_type);
	  if (in_HTML_mode ())
	    {
	      /* Show the statement(s) to be executed in the title: */
	      html_print_head_title (stdout, _T("OpenLink Interactive SQL ") ISQL_TYPE, _T(": "),
				     execute_these_only[0]);
	      isqlt_fputts (oo_ob, stdout);	/* And the Otherness Begins, i.e. <PRE> */
	    }
	  fflush (stdout);
	  return (1);
	}
      }
    }
/* IvAn/IsqlSyncro/000805 If errors are sent into stderr, but
   isql is called like isql exec=... > logfile 2>&1, then error
   messages are printed asynchronously.
   Adding \c fflush() here fix this bug fully,
   but it slows down logging more than necessary: too many fflushes
   in output of every error.. */
  fflush (stdout);
  return (0);
}

#define isql_puts     print_http_headers_if_not_already_printed(), isqlt_putts
#define isql_fputs    print_http_headers_if_not_already_printed(), isqlt_fputts
#define isql_putc     print_http_headers_if_not_already_printed(), isqlt_puttc
#define isql_putchar  print_http_headers_if_not_already_printed(), isqlt_puttchar
#define isql_printf   print_http_headers_if_not_already_printed(), isqlt_tprintf
#define isql_fprintf  print_http_headers_if_not_already_printed(), isqlt_ftprintf

#if defined(__GNUC__) && __GNUC__ == 3 && (__GNUC_MINOR__ == 0 || __GNUC_MINOR__ == 1)
/* When compiling with optimization printf is defined as a macro and
   GNU C versions 3.0.x and 3.1.x don't support preprocessor directives
   inside macro arguments like those used in this file. */
# undef printf
#endif


/* Taken and modified from w3srv.c of w3sql: */

TCHAR *html_escapes[256] =
{NULL};


#define HTML_ESCAPE(c,s) html_escapes [c] = s;
#define html_escapes_has_been_initialized() html_escapes['<']

void
html_init_escapes ()
{
  HTML_ESCAPE ('\0', _T("&#0;"));	/* To catch strange NUL characters. */
  HTML_ESCAPE ('<', _T("&lt;"));
  HTML_ESCAPE ('>', _T("&gt;"));
  HTML_ESCAPE ('&', _T("&amp;"));
}


/* If maxcount is non-zero, then print that many characters from str,
   (Also the '\0' characters between).
   If maxcount is zero, then print the str to the first terminating zero.
 */
void
html_print_escaped_n (TCHAR *str, FILE * fp, int maxcount)
{
  int inx;
  UTCHAR c;

  if (NO html_escapes_has_been_initialized ())
    {
      html_init_escapes ();
    }

  for (inx = 0;
       (c = ((UTCHAR) (str[inx]))),
       (maxcount ? (inx < maxcount) : c);
       inx++)
    {
      TCHAR *esc = html_escapes[c];
      if (esc && oo_esc)
	{
	  isql_fputs (esc, fp);
	  continue;
	}
      else
	{
	  isql_putc (c, fp);
	}
    }
}


#define html_print_escaped(str,fp) html_print_escaped_n ((str),(fp),0)


void
html_print_head_title (FILE * fp, TCHAR *title1, TCHAR *title2, TCHAR *title3)
{
  isqlt_fputts (_T("<HTML><HEAD><TITLE>"), fp);
  html_print_escaped (title1, fp);
  html_print_escaped (title2, fp);
  html_print_escaped (title3, fp);
  isqlt_fputts (_T("</TITLE></HEAD><BODY>\n"), fp);
  fflush (fp);
}


/* ============================================================== */
/*  isql_exit function.                                           */
/* ============================================================== */

void
isql_exit (int status)
{

#if defined(WITH_READLINE) || defined(WITH_EDITLINE)
  if (isqlhist[0])
    {
      write_history (isqlhist);
    }
#endif

  if (fully_connected)
    {
      SQLDisconnect (hdbc);
    }

  if (in_HTML_mode ())		/* These tags not really needed, but it's clean */
    {
      isql_fputs (oo_oe, stdout);	/* Otherness Ends, i.e. </PRE> */
      isql_fputs (_T("</BODY></HTML>"), stdout);	/* Whole document Ends also. */
    }

  exit (status);
}


/* ============================================================== */

int print_error (HENV e1, HDBC e2, HSTMT e3, RETCODE rc);

#define IF_ERR_GO(stmt, tag, foo) \
  if (SQL_ERROR == foo)  \
    { \
      print_error (henv, hdbc, stmt, foo);  \
      goto tag; \
    } \
  else if (SQL_SUCCESS_WITH_INFO == foo) \
    { \
      print_error (henv, hdbc, stmt, foo);  \
    }

/* GK: the deadlock handling works only in manual commit */
#define IF_ERR_OR_DEADLOCK_GO(stmt, tag1, tag2, foo) \
  if (SQL_ERROR == foo) \
    { \
      if(2 == print_error (henv, hdbc, stmt, foo) && commit_mode == 0) \
	 goto tag2; \
      else \
	 goto tag1; \
    } \
  else if (SQL_SUCCESS_WITH_INFO == foo) \
    { \
      print_error (henv, hdbc, stmt, foo);  \
    }

/* It was like this: print_error (stmt, stmt, stmt);  \
   Produced spurious extra error messages now and then.
 */

#if 0 /* GK: this is dangerous : it can lead to endless loops */
/* This is like previous, but in case the error was just something like:
   *** Error 2001: Non unique primary key on torttu
   then don't go to the error tag.
   If the transaction was deadlocked and SET DEADLOCK_RETRIES has been
   set to non-zero (vol_deadlock_retries is still non-zero), then goto
   tag2 instead.
 */
#define IF_SEVERE_ERR_GO(stmt, tag1, tag2, foo) \
  if (SQL_ERROR == foo)  { \
    int tmp_stat = print_error (henv, hdbc, stmt, foo); \
    if(1 == tmp_stat) goto tag1; \
    if(2 == tmp_stat) goto tag2; \
 }
#else
#define IF_SEVERE_ERR_GO(stmt, tag1, tag2, foo) \
  IF_ERR_JUST_PRINT (stmt, foo)
#endif

#define IF_ERR_JUST_PRINT(stmt, foo) \
  if (SQL_ERROR == (foo) || SQL_SUCCESS_WITH_INFO == (foo))  { \
    print_error (henv, hdbc, stmt, foo);  \
 }



#define MAXCOLNAME 60

#define MAXBUFFER 2002

#define MAXCOLS 200

/* Don't try to allocate more than this. */
/* This is 2^24. 2147483647=(2^31)-1, was 150000; */
SQLULEN o_buffer_sanity_check = 16777216;

typedef struct _out
  {
    TCHAR o_title[MAXCOLNAME + 1];
    SQLULEN o_width;		/* The width as by SQLDescribeCol
				   (changed from int to SQLULEN by AK 4-JAN-97) */
    SQLULEN o_allocated_buflen;	/* Usually MAX(MAXBUFFER,o_width) */
    SWORD o_type;
    char *o_buffer;		/* Buffer for SQLBindCol */
    SQLLEN o_col_len;		/* the length of the col on current row */
    SWORD o_nullable;		/* Last parameter returned by SQLDescribeCol, is either
				   SQL_NO_NULLS, SQL_NULLABLE or SQL_NULLABLE_UNKNOWN Added by AK 3-JAN-97 */
  }
stmt_out_t;

int n_out_cols_long;
#define n_out_cols ((SWORD) n_out_cols_long)
stmt_out_t out_cols[MAXCOLS + 1];
TCHAR *coltypetitles[MAXCOLS + 1];



/* ==================================================================== */
/* Checked malloc and strdup, called chemalloc and chestrdup, in case   */
/* that our virtual memory is exhausted...                              */
/* ==================================================================== */


TCHAR *
my_strncat (TCHAR *string1, const TCHAR *string2, size_t count)
{
  int str1len = (int) isqlt_tcslen (string1);
  return (isqlt_tcsncat (string1, string2, (count - str1len)));
}



TCHAR *
chemalloc (size_t size, TCHAR *where)	/* where can be NULL or empty */
{
  TCHAR *result;

  if (NO (result = (TCHAR *) malloc (size * sizeof (TCHAR))))
    {
      TCHAR num[11];
      isqlt_stprintf (num, _T("%lu"), (unsigned long) size);
      isql_putc ('\n', error_stream);
      isql_fputs (progname, error_stream);
      if (where && *where)	/* Not null, not empty. */
	{
	  isql_fputs (_T(" ("), error_stream);
	  isql_fputs (where, error_stream);
	  isql_fputs (_T(")"), error_stream);
	}
      isql_fputs (_T(": chemalloc failed when tried to allocate "),
		  stderr);
      fflush (error_stream);
      isql_fputs (num, error_stream);
      isql_fputs (_T(" bytes\n"), stderr);
      fflush (error_stream);
      isql_exit (1);
      return NULL;
    }
  else
    {
      return (result);
    }
}


TCHAR *
chestrdup (TCHAR *str, TCHAR *where)	/* where can be NULL or empty */
{
  TCHAR *res;

  if (!str)
    return str;
  if (NOT (res = isqlt_tcsdup (str)))
    {
/* Don't use isql_fprintf if memory is on the red! */
      isql_putc ('\n', error_stream);
      isql_fputs (progname, error_stream);
      if (where && *where)	/* Not null, not empty. */
	{
	  isql_fputs (_T(" ("), error_stream);
	  isql_fputs (where, error_stream);
	  isql_fputs (_T(")"), error_stream);
	}
      isql_fputs (_T(": chestrdup failed when tried to make a copy of: "),
		  stderr);
      fflush (error_stream);
      isql_fputs (str, error_stream);
      isql_putc ('\n', error_stream);
      fflush (error_stream);
      isql_exit (1);
      return NULL;
    }
  else
    {
      return (res);
    }
}


/* ==================================================================== */
/* Stuff for creating and accessing generic non-zero-integer lists      */
/* by AK 26-MAR-1997                                                    */
/* ==================================================================== */

typedef struct _intlist
{
  struct _intlist *next;
  int integer;
}
integer_list;


/* Doesn't check whether there is already num in pidlist.
   The first element of pidlist is always unused, "anchoring" node.
   The latest pushed num is stored at the first node after it, at
   intlist->next->integer, and the rest of list is linked to the
   "next" link of that node.
 */
int
push_to_integer_list (int num, integer_list * intlist)
{
  integer_list *next_pt = intlist->next;

  intlist->next = (integer_list *)
    chemalloc (sizeof (integer_list), _T("push_to_integer_list"));

  intlist->next->next = next_pt;
  intlist->next->integer = num;

  return (num);
}

/* Returns the integer from the first node after the anchoring node,
   and frees that node, and makes anchoring node to point to the next
   node after that. If list is empty returns zero. */
int
pop_from_integer_list (integer_list * intlist)
{
  integer_list *next_pt = intlist->next;
  int num;

  if (NO next_pt)
    {
      return (0);
    }				/* An empty list. */
  num = next_pt->integer;
  intlist->next = next_pt->next;
  free (next_pt);
  return (num);
}

/* And similarly for simple associative string pair lists. */

typedef struct _stringpairlist
{
  struct _stringpairlist *next;
  TCHAR *s_name;
  TCHAR *s_value;
}
stringpair_list;


/* Doesn't check whether there is already name in the_list.
   The first element of the_list is always unused, _T("anchoring") node.
   The first set name is stored at the first node after it, at
   the_list->next->name and ->value, and the rest of list is linked
   to the "next" link of that node.
 */
int
push_to_stringpair_list (TCHAR *name, TCHAR *value,
			 stringpair_list * the_list)
{
  TCHAR *me = _T("push_to_stringpair_list");
  stringpair_list *next_pt = the_list->next;

  the_list->next = (stringpair_list *)
    chemalloc (sizeof (stringpair_list), me);

  the_list->next->next = next_pt;
  the_list->next->s_name = chestrdup (name, me);
  the_list->next->s_value = chestrdup (value, me);

  return (1);			/* Something more useful? */
}

/* Returns s_name from the first node after the anchoring node,
   (and sets value to p_value if p_value is NON-null pointer).
   and frees that node, and makes anchoring node to point to the next
   node after that. If list is empty returns NULL.
   Here is a small memory leak:
   Should actually free the strings returned???
   Anyway, this function is not currently used.
 */
TCHAR *
pop_from_stringpair_list (stringpair_list * the_list, TCHAR **p_value)
{
  stringpair_list *next_pt = the_list->next;
  TCHAR *name;

  if (NO next_pt)
    {
      return (NULL);
    }				/* An empty list. */
  name = next_pt->s_name;
  if (NULL != p_value)
    {
      *p_value = next_pt->s_value;
    }
  the_list->next = next_pt->next;
  free (next_pt);
  return (name);
}


stringpair_list *
get_ptr_to_stringpair_list (TCHAR *name,
			    stringpair_list * the_list)
{
  stringpair_list *next_pt = the_list->next;

  for (next_pt = the_list->next; (next_pt != NULL); next_pt = next_pt->next)
    {
      if (next_pt->s_name && !strcasecmp (next_pt->s_name, name))
	{
	  return (next_pt);
	}
    }

  return (NULL);		/* Not found, return NULL. */
}

TCHAR *
assoc_value_from_stringpair_list (TCHAR *name,
				  stringpair_list * the_list)
{
  stringpair_list *lp = get_ptr_to_stringpair_list (name, the_list);

  if (NULL == lp)
    {
      return (NULL);
    }
  else
    {
      return (lp->s_value);
    }
}



/*
   The first element of the_list is always unused, "anchoring" node.
   The first set name is stored at the first node after it, at
   the_list->next->s_name and ->s_value, and the rest of list is linked
   to the "next" link of that node.
   The name comparison is done in case insensitive way.
   E.g. NAKKI=makkara overwrites Nakki=Bratwurst definition.
   However, the s_name stays in its original form as Nakki
   name and value are strdupped by this function, and at the overwrite
   of variable value the previous value is free'ed.
 */
int
set_to_stringpair_list (TCHAR *name, TCHAR *value,
			stringpair_list * the_list)
{
  TCHAR *me = _T("set_to_stringpair_list");
  stringpair_list *next_pt = the_list->next;
  stringpair_list *prev_pt = the_list;

  for (next_pt = the_list->next; (next_pt != NULL);
       prev_pt = next_pt, next_pt = next_pt->next)
    {
      if (next_pt->s_name && !strcasecmp (next_pt->s_name, name))
	{			/* Free the previous value, if it's not NULL: */
	  if (next_pt->s_value)
	    {
	      free (next_pt->s_value);
	    }
	  /* Overwrite the value part. */
	  next_pt->s_value = chestrdup (value, me);
	  return (1);		/* Modified the old one. */
	}
    }

/* Otherwise, no previous value has been set for this name, let's
   allocate a new node to the end of list. */

  prev_pt = prev_pt->next = (stringpair_list *)
    chemalloc (sizeof (stringpair_list), me);

  prev_pt->next = NULL;
  prev_pt->s_name = chestrdup (name, me);
  prev_pt->s_value = chestrdup (value, me);

  return (0);			/* Added new one. */
}

int
dump_stringpair_list (TCHAR *title, stringpair_list * the_list)
{
  stringpair_list *next_pt = the_list->next;
  int count = 0;

  isql_fprintf (stdout, _T("%") PCT_S _T(":"), title);
  for (next_pt = the_list->next; (next_pt != NULL); next_pt = next_pt->next)
    {
      isql_fprintf (stdout, _T(" %") PCT_S _T("="), next_pt->s_name);
      if (NULL == next_pt->s_value)
	{
	  isql_fprintf (stdout, _T("NULL"));
	}
      else
	{
	  isql_fprintf (stdout, _T("\"%") PCT_S _T("\""), next_pt->s_value);
	}
      count++;
    }

  isql_fprintf (stdout, _T("\n"));
  return (count);
}


/* ================================================================== */
/* And here is an application of the previous functions.              */
/* We use them to implement $U{name} variables. $U is an associative  */
/* array containing all non S_ variables from URL line (in Web mode)  */
/* or any generic User-settable variables.                            */
/* If the amount of $U variables or demands for effectiveness grow,   */
/* then we can always implement this later as a hash table or         */
/* something equally fancy.                                           */
/* ================================================================== */


stringpair_list U_vars_space =
{NULL, NULL, NULL};
stringpair_list *U_vars = &U_vars_space;	/* The ->next is NULL. */



#define get_U_variable(name)\
 assoc_value_from_stringpair_list((name),U_vars)


#define set_U_variable(name,value)\
 set_to_stringpair_list((name),(value),U_vars)

#define dump_U_variables() dump_stringpair_list(_T("$U{}"),U_vars)


/* ================================================================== */
/*    And more specific stuff for handling loadexpression stack.      */
/* ================================================================== */


/* Might contain a small memory leak or unchecked strdup, but this
   is anyway used so rarely (for the command line implicit loads)
   that I don't care. Even better, I realize I don't need this one,
   so I comment it out!

   #define change_topmost_of_loadexpr_stack(loadexpr)\
   ((LOAD_loadexpr_stack[loadfile_sp] =\
   (loadfile_sp ? strdup(loadfile_sp) : loadfile_sp)),\
   (LOAD_linecount_stack[loadfile_sp] = 0),\
   (LOAD_lsline_stack[loadfile_sp] = 0))
 */


/*
   If loadexpr stack overflows exits with an error message,
   otherwise pushes the new load expression into stack
   and clears the corresponding line and latest statement begins at
   counts, and then returns the new stack pointer (which will always
   be above zero).
 */
int
push_to_loadexpr_stack (TCHAR *loadexpr, FILE * load_stream)
{
  if (loadfile_sp >= MAXFILE_DEPTH)
    {
      isql_fprintf (error_stream,
		    _T("\n***%") PCT_S _T(": Exceeded loading depth of %d, cannot do anymore: %") PCT_S _T("\nfrom %") PCT_S _T("\n"),
		    progname, MAXFILE_DEPTH, loadexpr, current_loadexpr ());
      isql_exit (1);		/* Could do return(0) also if caller handled this. */
      return 0;
    }
  else
    {
      loadfile_sp++;
      LOAD_loadexpr_stack[loadfile_sp]
	= chestrdup (loadexpr, _T("push_to_loadexpr_stack"));
      current_input_stream () = load_stream;

/* Was like this, but now chestrdup does the checking:
   if(NOT (LOAD_loadexpr_stack[loadfile_sp] = strdup(loadexpr)))
   {
   isql_fputs(
   "\n***Memory allocation failure in push_to_loadexpr_stack(",
   error_stream);
   isql_fputs(loadexpr,error_stream);
   isql_fputs("), exiting.\n",error_stream);
   fflush(error_stream);
   isql_exit(1);
   }
 */
      LOAD_linecount_stack[loadfile_sp] = 0;
      LOAD_lsline_stack[loadfile_sp] = 0;
      return (loadfile_sp);
    }
}


/* If not in error, drop the topmost things from the stack
   (and free the load expression string saved with strdup in
   push_to_loadexpr_stack), and return the new stack pointer.
 */
int
drop_from_loadexpr_stack ()
{
  TCHAR *loadexpr;

  if (loadfile_sp < 1)
    {
      isql_fprintf (error_stream,
	     _T("\n***%") PCT_S _T(": drop_from_loadexpr_stack: loadfile_sp = %d, below 1,")
		    _T(" you should not have dropped this much, good bye!\n"),
		    progname, loadfile_sp);
      isql_exit (1);
      return 0;
    }
  else
    {
      if (NULL != (loadexpr = LOAD_loadexpr_stack[loadfile_sp]))
	{
	  free (loadexpr);
	}
      return (--loadfile_sp);
    }
}



/* ==================================================================== */
/* Stuff for spawning and waiting daughter processes.                   */
/* by AK 26-MAR-1997                                                    */
/* ==================================================================== */

TCHAR *
last_of_argv (TCHAR **argv)
{
  if (!argv)
    {
      return (_T("NULL argv"));
    }
  while (*++argv);
  return (*(argv - 1));
}


#ifdef WIN32

/* I just guess that cwait of Windows NT works like this. At least
   when STATPTR==NULL and OPTIONS==0 it seems to work.
 */

#define waitpid(PID,STATPTR,OPTIONS) cwait((STATPTR),(PID),(OPTIONS))


/* Added 12-SEP-1997 a third argument, wait_for_him, which if non-zero
   forces the parent to wait for its child's exit. */

int
spawn_process (TCHAR *progname, TCHAR **argv, int wait_for_him)
{
  int pid;

  fflush (stdout);
  fflush (stderr);

  pid = (int) tspawnvp ((wait_for_him ? _P_WAIT : _P_NOWAIT), progname, argv);

/* When called with _P_WAIT spawnvp seems to return always 0.
   (But -1 on errors.) */

  if ((wait_for_him && (pid < 0)) || (pid <= 0))
    {
      TCHAR *arg1 = last_of_argv (argv);
      isql_fprintf (error_stream,
		  _T("\n%") PCT_S _T(": spawn_process: spawnvp failed for (pid=%d):\n%s\n"),
		    progname, pid, arg1);
    }

  return (pid);
}


#else /* Some kind of UNIX, we use fork and execl routines. */

#include <sys/wait.h>		/* For waitpid */

int
spawn_process (TCHAR *progname, TCHAR **argv, int wait_for_him)
{
  int pid, ret;

  fflush (stdout);
  fflush (stderr);
  switch ((pid = fork ()))
    {
    case -1:
      {
	TCHAR *arg1 = last_of_argv (argv);
	isql_fprintf (error_stream,
		      _T("\n%") PCT_S _T(": spawn_process: fork failed for:\n%s!\n"),
		      progname, arg1);
	return (pid);
      }
    case 0:			/* In child, do it. */
      {
	ret = isqlt_texecvp (progname, argv);	/* Was execv, but we need a path. */
/*        if(ret < 0) Should continue here only if execl failed. */
	{
	  TCHAR *arg1 = last_of_argv (argv);
	  isqlt_tperror (progname);
	  isql_fprintf (error_stream,
	  _T("\n%") PCT_S _T(": spawn_process in child: execvp (ret=%d) failed for:\n%s\n"),
			progname, ret, arg1);
	  isql_exit (-1);
	}
      }
    default:
      {
	if (wait_for_him)
	  {
	    waitpid (pid, NULL, 0);
	  }			/* Not tested! */
	return (pid);		/* In parent, return pid of child. */
      }
    }

}

#endif


UTCHAR *urlify (UTCHAR * dst, UTCHAR * src);
TCHAR *skip_blankos (TCHAR *str);

int
spawn_to_background (TCHAR *statements, integer_list * pidlist)
{
  TCHAR *exec_option = _T("EXEC=");
  TCHAR **new_argv;
  int exec_len = (int) isqlt_tcslen (exec_option);
  int pid, len, i, j;
  TCHAR *arg1;

  /* First allocate space for the new argument vector. */
  len = ((G_argc + 3) * sizeof (TCHAR *));	/* +3 should suffice. */
  new_argv = ((TCHAR **) chemalloc (len, _T("spawn_to_background")));
/*  if(NOT new_argv) { goto malloc_err; } chemalloc never returns NULL */

  /* When statements text is urlified the result can at max be three
     times longer than original, if every character is to be
     replaced by corresponding percent-hex-escape sequence,
     i.e. if every character is non alphanumeric. */
  len = (int) (3 * isqlt_tcslen (statements)) + exec_len + 1;

  arg1 = (TCHAR *) chemalloc (len, _T("spawn_to_background"));
/* chemalloc never returns NULL.
   if(NOT arg1)
   {
   malloc_err:
   isql_putc('\n',error_stream);
   isql_fputs(progname,error_stream);
   isql_fputs("spawn_to_background failed, cannot malloc ",error_stream);
   fflush(error_stream);
   isql_fprintf(error_stream,"%u",len);
   isql_fputs(" bytes for:\nEXEC=",error_stream);
   isql_fputs(statements,error_stream);
   isql_putc('\n',error_stream); fflush(error_stream);
   return(-1);
   }
   else
 */
  {
    isqlt_tcscpy (arg1, exec_option);
    urlify (UCP (arg1 + exec_len), UCP (statements));
  }


  /* Copy the initial arguments of this process to the new argument
     vector given to child process (until end or -u or -i option is found):
     If there is -i or -u option, then EXEC= has to be spliced before
     them as everything after -u and -i is ignored and has significance
     only as a means of passing information to dollar macros like
     $U{'var1'} or $ARGV[$I]
   */
  for (i = 0; ((NULL != G_argv[i]) && isqlt_tcscmp (G_argv[i], _T("-i"))
	       && isqlt_tcscmp (G_argv[i], _T("-u"))); i++)
    {
      new_argv[i] = G_argv[i];
    }
  j = i;			/* After this j will be one less than i (i.e. points one left) */
  new_argv[i++] = arg1;		/* Splice or add to end our new EXEC argument. */
  for (; (NULL != G_argv[j]); i++, j++)		/* Copy the rest from -i to end */
    {
      new_argv[i] = G_argv[j];
    }
  new_argv[i] = NULL;		/* And terminate the vector with NULL. */

/* The argument arg1 containing the statement itself has to be
   escaped by some means because at least Windows NT will go haywire
   if it sees that there are e.g. spaces. So it is urlified. */

  pid = spawn_process (progname, new_argv, 0);	/* Spawn and don't wait. */

  free (new_argv);
  free (arg1);

  if (pid > 0)
    {
      push_to_integer_list (pid, pidlist);
    }

  return (pid);
}


/* This should spawn some other command than ISQL(ODBC) itself
   to the background (the first token on statements line),
   with the following tokens as its arguments.
 */
int
spawn_shell_command (TCHAR *statements, integer_list * pidlist, int wait_for_it)
{
  TCHAR *new_argv[MAX_ARGS_FOR_SHELL_PROGRAM + 3];
  int pid, i;
  UTCHAR firstchar;	/* The original first char of token. Might be a singlequote. */
  TCHAR *token, *nextptr;
  TCHAR tmp2buf[TMPBUF_SIZE + 2];

  nextptr = skip_blankos (statements);

  /* If user gave nothing after !, then silently do nothing.
     Actually we should start an interactive command shell for
     the user, from the envvar COMSPEC in MS-DOS, and envvar SHELL
     in Unix, and as a default search for cmd.exe or /bin/sh */
  if (!*nextptr)
    {
      return (0);
    }

/* With ordinary ! commands (without trailing &) we use now system
   function which allows for us to give also internal MS-DOS commands
   like DIR, TYPE, SET, etc. */
  if (wait_for_it)
    {
      int stat;

      fflush (stdout);
      fflush (stderr);
      stat = isqlt_tsystem (statements);
      if (stat < 0)
	{
	  isql_fprintf (error_stream,
			_T("\n%") PCT_S _T(": **Call to system failed for shell command \"%") PCT_S _T("\" at line %lu of %") PCT_S _T(". stat=%d, errno=%d, errmsg=%") PCT_S _T("\n"),
			progname, statements,
			latest_statement_begins_at (), current_loadexpr (),
			stat, errno, strerror (errno));
	}
      return (stat);
    }

  i = 0;
  while ((nextptr = skip_blankos (nextptr))
	 && (firstchar = *((UTCHAR *) nextptr))
	 && (token = get_next_token (&nextptr, tmp2buf,
				     TMPBUF_SIZE,
				     NULL, 0)))
    {
      if (i >= MAX_ARGS_FOR_SHELL_PROGRAM)
	{
	  isql_fprintf (error_stream,
			_T("\n%") PCT_S _T(": **Too many (max. %d) arguments for shell command \"%") PCT_S _T("\" at line %lu of %") PCT_S _T(". The rest are ignored.\n"),
			progname, MAX_ARGS_FOR_SHELL_PROGRAM, new_argv[0],
			latest_statement_begins_at (), current_loadexpr ());
	  break;
	}
      new_argv[i++] = chestrdup (token, _T("spawn_shell_command"));
    }

  new_argv[i] = NULL;


  pid = spawn_process (new_argv[0], new_argv, wait_for_it);

  if (wait_for_it && (pid > 0))
    {
      push_to_integer_list (pid, pidlist);
    }

  return (pid);
}



/* Just pop all pids from pidlist and wait for each one with waitpid.
   If waitpid returns -1 or something, e.g. if the child has died already
   it doesn't matter, as the purpose is just to check here that
   no children are running anymore.
 */
int
wait_for_all_children (integer_list * pidlist)
{
  int pid, count = 0;

  while (0 != (pid = pop_from_integer_list (pidlist)))
    {
      waitpid (pid, NULL, 0);
      count++;
    }

  return (count);
}



/* ==================================================================== */
/* Stuff for parsing and manipulating character strings.                */
/* Should be really in a separate module.                               */
/* ==================================================================== */


/* The following function were taken from AK's conjugate software,
   module conjtest.cpp.
 */
UTCHAR *
parse_url_value (UTCHAR * url_piece)
{
  UTCHAR *s, *t;
  UTCHAR save_char;
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
	    else if (isqlt_tcslen ((TCHAR *) s) >= 3)
	      {
		save_char = *(s + 3);
		*(s + 3) = '\0';
		/* Convert two hex digits to int */
		isqlt_stscanf (((const TCHAR *) s + 1), _T("%x"), &tmp);
		*(s + 3) = save_char;
		*t++ = ((UTCHAR) tmp);
		s += 3;
	      }
	    else
	      /* Copy the trailing percent signs literally. */
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

/* This should in principle do the opposite as the function given above,
   i.e. to convert all spaces to plus signs, and all other strange
   characters (here: all non-alphanumeric) to corresponding three-char
   percent-hex-escape sequences, e.g. the plus-signs to %2B 's.
 */
UTCHAR *
urlify (UTCHAR * dst, UTCHAR * src)
{
  UTCHAR *ptr;
  UTCHAR *dstptr;

  for (ptr = src, dstptr = dst; *ptr; ptr++, dstptr++)
    {
      if (' ' == *ptr)
	{
	  *dstptr = '+';
	}
      else if (isalnum (*ptr))
	{
	  *dstptr = *ptr;
	}
      else
	/* Class strange, i.e. everything else, punctuations, etc. */
	{
	  *dstptr++ = '%';
	  isqlt_stprintf (SCP (dstptr), _T("%02x"), *ptr);
	  dstptr++;		/* Skip still one byte. */
	}
    }

  *dstptr = '\0';		/* Termination byte. */
  return (dst);
}



#define isoctdigit(C) (((C) & ~7) == 060)	/* 060 = 0x30 = 48. = '0' */
#define hexdigtoi(C) (isqlt_istdigit(C) ? ((C) - '0') : (toupper(C) - ('A' - 10)))

TCHAR *
skip_blankos (TCHAR *str)
{
  while (*str && isqlt_istspace (*str))
    {
      str++;
    }				/* Skip blankos. */
  return (str);
}

TCHAR *
get_rid_of_trailing_newline (TCHAR *str)
{
  TCHAR *ptr = str + isqlt_tcslen (str) - 1;	/* pointing to the last character */
  if (ptr < str)		/* If an empty string is given, it is given back intact */
    {
      return (str);
    }
  if ('\n' == *ptr)
    {
      *ptr = '\0';
      ptr--;
    }
  /* If there's also a trailing CR, then get rid of that also: */
  if ((ptr >= str) && ('\r' == *ptr))
    {
      *ptr = '\0';
    }
  return (str);
}

SQLLEN
get_rid_of_trailing_newline_and_CR_with_count (TCHAR *str, SQLLEN endpt)
{
  int removed = 0;

  TCHAR *ptr = str + endpt - 1;	/* pointing to the last character */
  if (ptr < str)		/* If an empty string is given, it is given back intact */
    {
      return (0);
    }
  if ('\n' == *ptr)
    {
      *ptr = '\0';
      ptr--;
      removed++;
    }
  /* If there's also a trailing CR, then get rid of that also: */
  if ((ptr >= str) && ('\r' == *ptr))
    {
      *ptr = '\0';
      removed++;
    }
  return (removed);
}

/* To clear any hidden trailing CRS of MS-DOS text files. */
int
get_rid_of_trailing_CRS_with_count (TCHAR *str, int endpt)
{
  int removed = 0;

  TCHAR *ptr = str + endpt - 1;	/* pointing to the last character */

  /* If an empty or one-byte string is given, zero is returned. */
  if (ptr < (str + 1))
    {
      return (0);
    }

/* If the last is newline and the second last is CR, then overwrite
   the CR with newline, and the newline with terminating zero, that is,
   remove the CR, and make a string one character shorter:
   Repeat as long as all hidden CR's before newline have been deleted.
 */
again:
  if ((ptr > str) && /* ('\n' == *ptr) && */ ('\r' == *(ptr - 1)))
    {
      *(ptr - 1) = *ptr;
      *ptr = '\0';
      ptr--;
      removed++;
      goto again;
    }

  return (removed);		/* return the count of removed CR's */
}

/* Not needed now:
   int get_rid_of_trailing_CRS(char *str)
   {
   return(get_rid_of_trailing_CRS_with_count(str,isqlt_tcslen(str)));
   }
 */


/* If there is in the end of string a semicolon (followed optionally
   by CR and/or NL), then CUTS the string at that point and returns 1,
   OTHERWISE returns 0, and DOESN'T MODIFY str */
int
get_rid_of_trailing_semicolon_if_there_is_one (TCHAR *str)
{
  UTCHAR *ptr = UCP (str + isqlt_tcslen (str) - 1);	/* To the last char */

/* Skip past all the white space characters and cr's in the end: */
  while ((ptr >= UCP (str)) && (isqlt_istspace (*ptr) || (*ptr == '\r')))
    {
      ptr--;
    }

/* If there's a trailing semicolon then get rid of that,
   and return non-zero: */
  if ((ptr >= UCP (str)) && (';' == *ptr))
    {
      *ptr-- = '\0';
      return (1);
    }
  return (0);
}


/* If there is in the end of string a semicolon or ampersand
   (followed optionally by CR and/or NL), then CUTS the string
   at that point and returns that character (i.e. ascii value of
   the semicolon or ampersand),
   OTHERWISE returns 0, and DOESN'T MODIFY str */
unsigned int
get_rid_of_trailing_semicolon_or_ampersand (TCHAR *str)
{
  UTCHAR ret;
  UTCHAR *ptr = UCP (str + isqlt_tcslen (str) - 1);	/* to the last char */

/* Skip past all the white space characters and cr's in the end: */
  while ((ptr >= UCP (str)) && (isqlt_istspace (*ptr) || (*ptr == '\r')))
    {
      ptr--;
    }

/* If there's a trailing semicolon or ampersand, then get rid of that,
   and return the character that was gotten rid of: */
  if ((ptr >= UCP (str)) && ((';' == *ptr) || ('&' == *ptr)))
    {
      ret = *ptr;
      *ptr-- = '\0';
      return (ret);
    }
  return (0);
}


unsigned int
hextoi (UTCHAR ** rest_ptr, UTCHAR * string)
{
  register UINT x;

  x = 0;
  while (*string && isxdigit (*string))
    {
      x = ((x << 4) + hexdigtoi (*string));
      string++;
    }
  *rest_ptr = string;
  return (x);
}


unsigned int
octoi (UTCHAR ** rest_ptr, UTCHAR * string)
{
  register UINT o;

  o = 0;
  while (isoctdigit (*string))
    {
      o = ((o << 3) + (*string++ - '0'));
    }
  *rest_ptr = string;
  return (o);
}


/* String should have an even number of hexadecimal digits, possibly
   followed by some whitespace or CR and/or NL, which are ignored.
   The hex-digit pairs are converted to corresponding byte values,
   and stored to the same string. So the real length, which is finally
   returned, will be about half of the original length.
   Note that the new string might contain one or more 0-bytes somewhere.
 */
int
unhex_string (TCHAR * _string)
{
  UTCHAR * string = (UTCHAR *) _string;
  UTCHAR *res_ptr, *next, *org_string = string;
  UTCHAR x;

  for (res_ptr = string; *string && *(next = (string + 1)) &&
       isxdigit (*string) && isxdigit (*next);
       string += 2)
    {
      x = ((UTCHAR) ((hexdigtoi (*string) << 4) + hexdigtoi (*next)));
      *res_ptr++ = x;
    }

  *res_ptr = '\0';		/* Terminating zero. Not actually needed. */
  return (int) (res_ptr - org_string);	/* Return the new length. */
}


/* Converts all backslash-escaped things in the string to their
   unescaped variants (modifying the same string), and returns
   the new length of the string.
   Added 8-FEB-1997 a new 'magical' escape-sequence \c
   which will just abruptly cut the string at that point.
   This fix is used for reading in with read_blob_from_input
   multiline blobs produced by DBDUMP whose last line DOESN'T
   have a trailing newline.

   Check the next function parse_string_literal how to really do it!

   At least now this doesn't interpret two consecutive single quotes
   as one.
 */
int
unescape_string (TCHAR * _string)
{
  UTCHAR *string = (UTCHAR *) _string;
  UTCHAR *res_ptr, *org_string = string;

  for (res_ptr = string; *string;)
    {
      if ('\\' != *string)	/* An ordinary character? */
	{
	  *res_ptr++ = *string++;
	}
      else
	/* Haa! It is an escape character! */
	{

/* New escapes added 23.AUG.1991 \a for bell, and \v for vertical tab
   as specified in ANSI C standard. Also now recognizes hexadecimal
   character constants beginning with \x Note that \e for escape
   doesn't belong to standard.
   Note that if case jumps out with break, then string is incremented
   one more step, but if it jumps out with continue then string is
   not incremented. (I.e. it's already positioned to the next character)
 */
	  switch (*++string)	/* Check the next character. */
	    {
/* If a string anomalously ends with a trailing (single) backslash, then
   leave it dangling there: */
	    case '\0':
	      {
		*res_ptr++ = *(string - 1);
		continue;
	      }
	    case 'a':
	      {
		*res_ptr++ = '\7';
		break;
	      }			/* BEL audible alert */
	    case 'b':
	      {
		*res_ptr++ = '\b';
		break;
	      }			/* BS  backspace */
	    case 'c':
	      {
		goto out;
	      }			/* Cut the crap. Este es la magia. */
	    case 'e':
	      {
		*res_ptr++ = '\033';
		break;
	      }			/* ESC escape */
	    case 'f':
	      {
		*res_ptr++ = '\f';
		break;
	      }			/* FF  form feed */
	    case 'n':
	      {
		*res_ptr++ = '\n';
		break;
	      }			/* NL (LF) newline */
	    case 'r':
	      {
		*res_ptr++ = '\r';
		break;
	      }			/* CR  carriage return */
	    case 't':
	      {
		*res_ptr++ = '\t';
		break;
	      }			/* HT  horizontal tab */
	    case 'v':
	      {
		*res_ptr++ = '\013';
		break;
	      }			/* VT  vertical tab */
	    case 'x':		/* There's a hexadecimal char constant \xhh */
	    case 'X':
	      {			/* Well, we should check that only max 2 digits are parsed */
		*res_ptr++ = ((UTCHAR) hextoi (&string, ++string));
		continue;
	      }
/* The following might conflict with some other usage. Commented out. */
#ifdef AK_EXTENSION_TO_UNESCAPE_STRING
	    case '^':		/* AK's special control-character escapes */
/* E.g. \^A or \^a is CTRL-A (= \1)  and \^? is 63-64 = -1 = 255 */
	      {
		UTCHAR veba;

		veba = *++string;
		if (!veba)	/* String anomalously ended, after \^ */
		  {
		    *res_ptr++ = *(string - 2);
		    *res_ptr++ = *(string - 1);
		    continue;	/* Keep \^ intact in the string. */
		  }
		veba = ((UTCHAR) toupper (veba));
		*res_ptr++ = ((UTCHAR) (veba - ((UTCHAR) 64)));
		break;
	      }
#endif
	    case '0':
	    case '1':
	    case '2':
	    case '3':
	    case '4':
	    case '5':
	    case '6':
	    case '7':
	      {			/* So it's an octal sequence like \033 : */
		unsigned int i = 3, z = 0;
		while (isoctdigit (*string) && (i--))
		  {
		    z = ((z << 3) + (*string++ - '0'));
		  }
		*res_ptr++ = ((UTCHAR) z);
		continue;	/* string already well positioned. */
	      }			/* octal digits */
	    default:		/* String like \END produces END: */
	      {
		*res_ptr++ = *string;
		break;
	      }			/* default */

	    }			/* switch */
	  string++;
	}			/* if there was a backslash */
    }				/* for loop */
out:;
  *res_ptr = '\0';		/* Terminating zero. */
  return (int) (res_ptr - org_string);	/* Return the new length. */
}


/*
   Before the call str_ptr should point to a string which points
   to the beginning quote (actually any character you wish to use
   as a quote), and then string is scanned until corresponding
   ending character is found. string referenced by str_ptr is set
   to point one character after that.
   If result is NULL, then just the length of string is returned,
   otherwise the parsed string literal is copied there.
   Note that str_ptr is modified anyway. See the next function
   get_next_token how to call this one.
 */

int
parse_string_literal (UTCHAR ** str_ptr, UTCHAR * result)
{
  unsigned int i = 0;
  unsigned int q, z;
  UTCHAR *str = *str_ptr;
  UTCHAR beg_quote = *str++;	/* And skip past it. */
  UTCHAR c;

  while (*str)
    {
      switch (*str)
	{
	case '\\':		/* An escaped character follows? */
	  {

/* New escapes added 23.AUG.1991 \a for bell, and \v for vertical tab
   as specified in ANSI C standard. Also now recognizes hexadecimal
   character constants beginning with \x Note that \e for escape
   doesn't belong to standard. (Commented out)
 */
	    switch (*++str)	/* Check the next character. */
	      {
/* If a string anomalously ends with a trailing (single) backslash, then
   leave it dangling there: */
	      case '\0':
		{
		  c = *(str - 1);
		  break;
		}
	      case 'a':
		{
		  c = '\7';
		  break;
		}		/* BEL audible alert */
	      case 'b':
		{
		  c = '\b';
		  break;
		}		/* BS  backspace */
		/*              case 'e': { c = '\033'; break; } *//* ESC escape */
	      case 'f':
		{
		  c = '\f';
		  break;
		}		/* FF  form feed */
	      case 'n':
		{
		  c = '\n';
		  break;
		}		/* NL (LF) newline */
	      case 'r':
		{
		  c = '\r';
		  break;
		}		/* CR  carriage return */
	      case 't':
		{
		  c = '\t';
		  break;
		}		/* HT  horizontal tab */
	      case 'v':
		{
		  c = '\013';
		  break;
		}		/* VT  vertical tab */
	      case 'x':	/* There's a hexadecimal char constant \xhh */
	      case 'X':
		{		/* We should check that only max 2 digits are parsed */
		  q = 2;
		  z = 0;
		  str++;
		  while (*str && isxdigit (*str) && (q--))
		    {
		      z = ((z << 4) + (*str++ - '0'));
		    }
		  c = ((UTCHAR) z);
		  str--;	/* str is incremented soon. */
		  break;
		}
	      case '0':
	      case '1':
	      case '2':
	      case '3':
	      case '4':
	      case '5':
	      case '6':
	      case '7':
		{		/* So it's an octal sequence like \033 : */
		  q = 3;
		  z = 0;
		  while (isoctdigit (*str) && (q--))
		    {
		      z = ((z << 3) + (*str++ - '0'));
		    }
		  c = ((UTCHAR) z);
		  str--;	/* str is incremented soon. */
		  break;
		}		/* octal digits */
	      default:		/* Every other character after backslash produces */
		{		/* that same character, i.e. \\ = \, \' = ', etc. */
		  c = *str;
		  break;
		}		/* default */

	      }			/* inner switch for character after a backslash */
	    if (result)
	      {
		result[i] = c;
	      }
	    i++;
	    str++;
	    break;
	  }			/* case for backslash. */
	default:
	  {
	    if (*str == beg_quote)
	      {
		/* If the next char is a quote also, then this is not yet
		   the terminating quote */
		if (*(str + 1) == beg_quote)
		  {
		    str++;	/* Skip that quote next time. */
		    goto copy_char;
		  }
		else
		  {		/* String is terminated. */
		    goto out;
		  }
	      }
	    else
	      /* Any other character. */
	      {
	      copy_char:
		if (result)
		  {
		    result[i] = *str;
		  }
		i++;
		str++;
		break;
	      }
	  }
	}			/* outer switch */
    }				/* for loop */
out:;
  if (result)
    {
      result[i] = '\0';
    }				/* Put a terminating zero. */
  if (*str)			/* The terminating quote is here. */
    {
      *str_ptr = str + 1;	/* Skip past it. */
    }
  else
    {
      /* The terminating quote is missing, we should produce an error here! */
      *str_ptr = str;		/* But in this version we are tolerant of that. */
    }
  return (i);			/* Return the length. */
}


int LIF_value = 0;		/* Contains the value of latest topmost $IF expression
				   encountered by get_next_token. */

#define INT_VAR     0
#define CHARBUF_VAR 1
#define CHARBUFLEN_VAR 2
#define CHARPTR_VAR 3
#define FILEPTR_VAR 4
#define ASSOC_ARR   5

#define INT_FLAG    6

#define SAM_MACRO   7		/* SQL API Method Macro. */
#define COMP_MACRO  8		/* $equ, $neq, $lt, $lte, $gt, or $gte */

#define macro_needs_connection(INFO) (((INFO)->type) == SAM_MACRO)

#define is_settable_macro_type(INFO) (((INFO)->type) < COMP_MACRO)


/* In this case var_addr is one of the following two,
   and more_info is either DVC_LESS, DVC_GREATER or DVC_MATCH. */
#define CM_SAME     0		/* Use ==    for comparing the result of isqlt_tcscmp */
#define CM_DIFF     1		/* or  !=    with more_info */

#ifndef DVC_LESS
/* Values returned by isqlt_tcscmp, strcasecmp functions. */
#define DVC_LESS -1
#define DVC_MATCH 0
#define DVC_GREATER 1

#endif

/* The elements of the following struct are used very haphazardously
   by the different types of macros. Later I will at least try to
   hide the ugliness behind the macro-accessors like SAM_macros below.
   I am too lazy now to write a proper union structure. Fortunately,
   the cast is powerful.
 */

struct name_var_pair
  {
    TCHAR *name;
    void *var_addr;
    int type;			/* 0 = integer, 1 = char [] buffer, 2 = char * pointer. */
    void *more_info;
    void *more2info;
  };


typedef signed short (SQL_API *SAM_GET) (void *, UWORD, PTR);
typedef signed short (SQL_API *SAM_SET) (void *, UWORD, SQLULEN);
/* For SQLGetInfo: */
typedef signed short (SQL_API *SAM2GET) (void *, UWORD, PTR, SWORD, SWORD *);


struct SAM_info			/* SAM stands for SQL API METHOD (pair) */
  {
    int sql_get_method_type;	/* Oh what a mess! 1 or 2 */
    SAM_GET get_method;
/* Should be:  union { SAM_GET get_method; SAM2GET get2method; }; */
    int sql_api_get_method_num;	/* 0 if not SQL API method. */
    SAM_SET set_method;
    int sql_api_set_method_num;	/* 0 if not SQL API method. */
    PTR *handle_ptr;		/* Usually either a connection or statement handle. */
  };

struct SAM_info SAM_CONNECT_OPTION
=
{1, ((SAM_GET) SQLGetConnectOption), SQL_API_SQLGETCONNECTOPTION,
 ((SAM_SET) SQLSetConnectOption), SQL_API_SQLSETCONNECTOPTION,
 ((PTR *) & hdbc)};

struct SAM_info SAM_STMT_OPTION
=
{1, ((SAM_GET) SQLGetStmtOption), SQL_API_SQLGETSTMTOPTION,
 ((SAM_SET) SQLSetStmtOption), SQL_API_SQLSETSTMTOPTION,
 ((PTR *) & stmt)};

struct SAM_info SAM_GET_INFO
=
{2, ((SAM_GET) ((SAM2GET) SQLGetInfo)), SQL_API_SQLGETINFO,
 ((SAM_SET) NULLFP), 0,
 ((PTR *) & hdbc)};


#define get_macro_SAM_struct(INFO)\
 ((struct SAM_info *)((INFO)->more_info))


#define SAM_get_method_type(INFO)\
 (get_macro_SAM_struct(INFO)->sql_get_method_type)

#define SAM_get_method(INFO) (get_macro_SAM_struct(INFO)->get_method)
#define SAM_get2method(INFO)\
 ((SAM2GET) (get_macro_SAM_struct(INFO)->get_method))
#define SAM_set_method(INFO) (get_macro_SAM_struct(INFO)->set_method)
#define SAM_handle(INFO)   (*(get_macro_SAM_struct(INFO)->handle_ptr))
#define SAM_option_value(INFO) ((UWORD)(int)(ptrlong)((INFO)->var_addr))


#define SAM_call_get_method(INFO, RESPTR)\
 ((SAM_get_method(INFO))\
    (SAM_handle(INFO), SAM_option_value(INFO), (RESPTR)) )

#define SAM_call_get2method(INFO, RESPTR, cbMAX, pcbINFO)\
 ((SAM_get2method(INFO))\
(SAM_handle(INFO), SAM_option_value(INFO), (RESPTR), (cbMAX), (pcbINFO)) )

/* Actually the third argument in prototype should be PTR
   (e.g. void *), not SQLULEN, and the cast should be other way. */
#define SAM_call_set_method(INFO, VALUE)\
 ((SAM_set_method(INFO))\
    (SAM_handle(INFO), SAM_option_value(INFO), ((SQLULEN)(VALUE))) )

#define SAM_choices_list(X) ((TCHAR **) (X)->more2info)	/* Stoopid... */

#define SAM_is_string_valued(X) (STRING_VALUED == SAM_choices_list(X))

#define int_flag_choices_list(X) ((TCHAR **) (X)->more_info)


#define INT_VALUED NULL

TCHAR *STRING_VALUED[] =
{NULL};
TCHAR *OFF_ON[3] =
{_T("OFF"), _T("ON"), NULL};		/* Also for AUTOCOMMIT */
TCHAR *PRESERVED_CLEARED[3] =
{_T("PRESERVED"), _T("CLEARED"), NULL};

TCHAR *PRE_AUTOCOMMIT[4] =
{_T("OFF"), _T("ON"), _T("MANUAL"), NULL};

TCHAR *RW_RO[] =			/* For SQL_ACCESS_MODE, "ACCESSMODE" */
{
  _T("RW"),				/* SQL_MODE_READ_WRITE  0UL */
  _T("RO"),				/* SQL_MODE_READ_ONLY   1UL */
  _T("RO_PERMANENTLY"),		/* SQL_MODE_READ_ONLY_PERMANENTLY 2UL (Kubl ext!) */
  NULL
};

TCHAR *LOCK_MODES[] =		/* For SQL_CONCURRENCY, "READMODE" */
{_T("UNKNOWN"),			/* 0  */
 _T("NORMAL"),			/* 1  SQL_CONCUR_READ_ONLY         old "SET RW" */
 _T("EXCLUSIVE"),			/* 2  SQL_CONCUR_LOCK                       */
 _T("SNAPSHOT"),			/* 3  SQL_CONCUR_ROWVER/_TIMESTAMP old "SET RO" */
 _T("VALUES"),			/* 4  SQL_CONCUR_VALUES                     */
 NULL
};


TCHAR *SET_TO_REST = _T("SET TO REST");

#define is_set_to_rest_macro(INFO) (((INFO)->more_info) == &SET_TO_REST)


/* This macro is useful so that we can define it later as function
   if we want to define isql_variables structures more flexibly,
   offering also possibility for run-time additions,
   e.g. if we implement user-defined associative arrays.
   (other than just default U).

   Really, we should have something more sophisticated here than
   linear search. E.g. a hash table.
 */

#define add_var_def(NAME,VAR_ADDR,TYPE,MORE_INFO)\
{ (NAME), ((void *) (VAR_ADDR)), (TYPE), ((void *)(MORE_INFO)), NULL }

#define add_buf_def(NAME,VAR_ADDR,TYPE)\
{ (NAME), ((void *) (VAR_ADDR)), (TYPE), ((void *)sizeof(VAR_ADDR)), NULL }

#define add_sam_def(NAME,OPTION,METHOD_PAIR,CHOICES)\
{ (NAME), ((void *) (OPTION)), (SAM_MACRO), ((void *)&(METHOD_PAIR)),\
  ((void *)(CHOICES)) }

#define add_empty_def(NAME,VAR_ADDR,TYPE)\
{ (NAME), ((void *) _T("")), (TYPE), ((void *)0), NULL }

/* With choices as NULL sets/shows integer values. */


struct name_var_pair isql_variables[] =
{

/* These are for HTML output. */
  add_var_def (_T("OO_SB"), (&oo_sb), CHARPTR_VAR, &SET_TO_REST),	/* <TABLE> */
  add_var_def (_T("OO_SE"), (&oo_se), CHARPTR_VAR, &SET_TO_REST),	/* </TABLE> */
  add_var_def (_T("OO_RB"), (&oo_rb), CHARPTR_VAR, &SET_TO_REST),	/* <TR> */
  add_var_def (_T("OO_RE"), (&oo_re), CHARPTR_VAR, &SET_TO_REST),	/* </TR> */
  add_var_def (_T("OO_HB"), (&oo_hb), CHARPTR_VAR, &SET_TO_REST),	/* <TH> */
  add_var_def (_T("OO_HE"), (&oo_he), CHARPTR_VAR, &SET_TO_REST),	/* </TH> */
  add_var_def (_T("OO_DB"), (&oo_db), CHARPTR_VAR, &SET_TO_REST),	/* <TD> */
  add_var_def (_T("OO_DE"), (&oo_de), CHARPTR_VAR, &SET_TO_REST),	/* </TD> */
  add_var_def (_T("OO_OB"), (&oo_ob), CHARPTR_VAR, &SET_TO_REST),	/* <PRE> */
  add_var_def (_T("OO_OE"), (&oo_oe), CHARPTR_VAR, &SET_TO_REST),	/* </PRE> */
  add_var_def (_T("OO_ESC"), (&oo_esc), INT_FLAG, OFF_ON),	/* HTML-escaping on? */

  add_var_def (_T("RETVAL"), (retvalbuf), CHARBUFLEN_VAR, (&cbRetVal)),

  add_var_def (_T("RETVALLEN"), (&cbRetVal), INT_VAR, INT_VALUED),
  add_var_def (_T("ROWCNT"), (&N_rows), INT_VAR, INT_VALUED),
  add_var_def (_T("COLCNT"), (&n_out_cols_long), INT_VAR, INT_VALUED),
  add_var_def (_T("ARGC"), (&G_argc), INT_VAR, INT_VALUED),
  add_var_def (_T("I"), (&G_argc_i), INT_VAR, INT_VALUED),
  add_var_def (_T("LIF"), (&LIF_value), INT_VAR, INT_VALUED),

  add_empty_def (_T("INPUTLINE"), (input), CHARBUF_VAR),
  add_buf_def (_T("STATE"), (SQL_error_state), CHARBUF_VAR),
  add_buf_def (_T("SQLSTATE"), (SQL_error_state), CHARBUF_VAR),	/* Synonym. */
  add_buf_def (_T("MESSAGE"), (SQL_error_message), CHARBUF_VAR),
  add_buf_def (_T("DBMSNAME"), (info_dbms), CHARBUF_VAR),	/* Available after */
  add_buf_def (_T("DRIVER"), (info_driver), CHARBUF_VAR),	/* the connection */

  add_var_def (_T("QUERY_STRING"), (&web_query_string), CHARPTR_VAR, NULL),

  add_var_def (_T("FORM_FILENAME"), (&form_filename), CHARPTR_VAR, NULL),
  add_var_def (_T("FORM_FILEFIELDNAME"), (&form_filefieldname), CHARPTR_VAR, NULL),
  add_var_def (_T("FORM_LAST_CONTENT_TYPE"), (&form_last_content_type), CHARPTR_VAR, NULL),
add_var_def (_T("FORM_LAST_ENCODING"), (&form_last_encoding), CHARPTR_VAR, NULL),
  add_var_def (_T("FORM_BOUNDARY"), (&form_boundary), CHARPTR_VAR, NULL),

  add_var_def (_T("LWE"), (&isql_echo_lwe), CHARPTR_VAR, NULL),	/* Shhh... */

  add_var_def (_T("U"), (&U_vars_space), ASSOC_ARR, NULL),


  add_var_def (_T("CONTENT_TYPE"), (&web_content_type), CHARPTR_VAR, NULL),
  add_var_def (_T("DSN"), (&datasource), CHARPTR_VAR, NULL),
  add_var_def (_T("UID"), (&username), CHARPTR_VAR, NULL),
  add_var_def (_T("PWD"), (&password), CHARPTR_VAR, NULL),

  add_var_def (_T("ERRORS"), (&error_stream), FILEPTR_VAR, NULL),
  add_var_def (_T("PROMPT"), (&print_prompt), CHARPTR_VAR, NULL),
  add_var_def (_T("EMPTY"), (&empty_string), CHARPTR_VAR, NULL),
  add_var_def (_T("VERSION"), (&isql_version), CHARPTR_VAR, NULL),
  add_var_def (_T("FORM_ACTION"), (&form_action), CHARPTR_VAR, NULL),

  add_var_def (_T("BLOBS"), (&print_blobs_flag), INT_FLAG, OFF_ON),
  add_var_def (_T("FOREACH_ERR_BREAK"), (&foreach_err_break), INT_FLAG, OFF_ON),
  add_var_def (_T("ECHO"), (&echo_mode), INT_FLAG, OFF_ON),
  add_var_def (_T("EXPLAIN"), (&explain_mode), INT_FLAG, OFF_ON),
  add_var_def (_T("SPARQL_TRANSLATE"), (&sparql_translate_mode), INT_FLAG, OFF_ON),
  add_var_def (_T("HIDDEN_CRS"), (&clear_hidden_crs_flag), INT_FLAG, PRESERVED_CLEARED),
  add_var_def (_T("BINARY_OUTPUT"), (&flag_binary_output), INT_FLAG, OFF_ON),
  add_var_def (_T("BANNER"), (&print_banner_flag), INT_FLAG, OFF_ON),
  add_var_def (_T("TYPES"), (&print_types_also), INT_FLAG, OFF_ON),
  add_var_def (_T("VERBOSE"), (&verbose_mode), INT_FLAG, OFF_ON),
  add_var_def (_T("TRAILING_NEWLINES"), (&flag_newlines_at_eor), INT_FLAG, INT_VALUED),
  add_var_def (_T("TIMES2STRINGS"), (&times_to_strings_flag), INT_FLAG, OFF_ON),
  add_var_def (_T("TS_ODBC"), (&times_conform_to_odbc_flag), INT_FLAG, OFF_ON),
  add_var_def (_T("DEADLOCK_RETRIES"), (&perm_deadlock_retries), INT_VAR, INT_VALUED),
  add_var_def (_T("MACRO_SUBSTITUTION"), (&flag_macro_substitution), INT_FLAG, OFF_ON),
  add_var_def (_T("IGNORE_PARAMS"), (&flag_ignore_params), INT_FLAG, OFF_ON),
  add_var_def (_T("BIND_RETURN_VALUES"), (&flag_bind_return_values), INT_FLAG, OFF_ON),
  add_var_def (_T("TRIM_STRING_RESULT"), (&trim_string_result), INT_FLAG, OFF_ON),
  add_var_def (_T("HEAD_ALREADY_PRINTED"), (&flag_head_already_printed), INT_FLAG, OFF_ON),
  add_var_def (_T("VIRTEXT"), (&virtext), INT_FLAG, OFF_ON),

  add_var_def (_T("AUTOCOMMIT"), (&commit_mode), INT_FLAG, PRE_AUTOCOMMIT),	/* ON */
  add_sam_def (_T("ACCESSMODE"), (SQL_ACCESS_MODE), SAM_CONNECT_OPTION, RW_RO),
  add_sam_def (_T("READMODE"), (SQL_CONCURRENCY), SAM_STMT_OPTION, LOCK_MODES),
  add_sam_def (_T("TIMEOUT"), (SQL_QUERY_TIMEOUT), SAM_STMT_OPTION, INT_VALUED),
  add_sam_def (_T("MAXROWS"), (SQL_MAX_ROWS), SAM_STMT_OPTION, INT_VALUED),
/* The following are mainly for debugging purposes. */
  add_sam_def (_T("CURRENT_QUALIFIER"), (SQL_CURRENT_QUALIFIER), SAM_CONNECT_OPTION, STRING_VALUED),
  add_sam_def (_T("INFO_DATABASE_NAME"), (SQL_DATABASE_NAME), SAM_GET_INFO, STRING_VALUED),
add_sam_def (_T("INFO_USER_NAME"), (SQL_USER_NAME), SAM_GET_INFO, STRING_VALUED),
  add_sam_def (_T("INFO_GETDATA_EXTENSIONS"), (SQL_GETDATA_EXTENSIONS), SAM_GET_INFO, INT_VALUED),

/* After this point only things that cannot be set. If you want to
   protect some variable from being set by user, move its definition
   after these ones. (Not really implemented yet!) */
  add_var_def (_T("LT"), (CM_SAME), COMP_MACRO, DVC_LESS),
  add_var_def (_T("GTE"), (CM_DIFF), COMP_MACRO, DVC_LESS),
  add_var_def (_T("GT"), (CM_SAME), COMP_MACRO, DVC_GREATER),
  add_var_def (_T("LTE"), (CM_DIFF), COMP_MACRO, DVC_GREATER),
  add_var_def (_T("EQU"), (CM_SAME), COMP_MACRO, DVC_MATCH),
  add_var_def (_T("NEQ"), (CM_DIFF), COMP_MACRO, DVC_MATCH),
  add_var_def (_T("COMMAND_TEXT_ON_ERROR"), (&command_text_on_error), INT_FLAG, OFF_ON),

  {NULL}			/* End marker. */
};


/* Case insensitive comparison! */
#define is_macro_name(name1,name2) (0 == strcasecmp((name1),(name2)))


struct name_var_pair *
find_var_info (TCHAR *varname)
{
  struct name_var_pair *structptr = isql_variables;

  while (structptr->name)
    {
      if (is_macro_name (varname, structptr->name))
	{
	  return (structptr);
	}
      structptr++;
    }

  return (NULL);		/* Not found. */
}



#define isopening(C) \
 (NULL != isqlt_tcschr (_T("{[<("), C))
/* ( ((C) == '{') || ((C) == '[') || ((C) == '<') || ((C) == '(') ) */


#define isclosing(C) \
 (NULL != isqlt_tcschr (_T("}]>)"), C))
/* ( ((C) == '}') || ((C) == ']') || ((C) == '>') || ((C) == ')') )*/

/*
   Now tokens are cut for any opening or closing bracket like
   character (see macros above) as well as for commas and equal signs.
   And dollars too!

   In any case, at least tokens should not be cut for a dot (.), for
   a dash (-), for a slash (/), and for a backslash (\),
   so that we don't need to enclose tablenames like qual.own.tablename,
   loaded filenames inside single- or doublequotes, nor options
   like -r for load command.

   10. March, added ampersand (&) and question mark (?) to cut token
   characters, so that we may have forms like VALUE="$YYYYMMDD&#46;log"
   where &#46; stands for a period (.), and we get "19980310&#46;log"
   and eventually "19980310.log"
   And stuff like <A HREF="$FORM_ACTION?S_EXEC=something">

 */

#define cut_token_char(C) \
 (NULL != isqlt_tcschr(_T("$&?,="), C) || isopening(C) || isclosing(C))
/*( ('$' == (C)) || ('&' == (C)) || ('?' == (C)) || (',' == (C)) || ('=' == (C)) || (isopening(C)) || (isclosing(C)) )*/


#define word_ends_at(PTR)\
 ( !(*(PTR)) ||\
 (!isalnum(*(PTR)) && ('_' != (*(PTR))) && ((*((UTCHAR *)PTR)) < 192)))

#define word_follows(TEXT,WORD)\
 (!strncasecmp((TEXT),(WORD),(sizeof(WORD)-1))\
  && word_ends_at((TEXT+sizeof(WORD)-1)))

UTCHAR *find_closing_point (UTCHAR * start_point, UTCHAR opening_char);

#define TOKEN_PREMATURE_END NULL
TCHAR *TOKEN_NULL = _T("NULL");


/* If ind is valid index to alt_ptr returns the corresponding element,
   otherwise returns "UNKNOWN:ind" string copied to result argument.
 */
TCHAR *
find_choice_for_int (TCHAR *name, int ind, TCHAR **alt_ptr,
		     TCHAR *result, int maxsize)
{
  int i;
  TCHAR tmp1buf[101];

  for (i = 0; alt_ptr[i] && (i < ind); i++)
    {
    }
  if (alt_ptr[i])
    {
      return (alt_ptr[i]);
    }
  else
    {
      isqlt_stprintf (tmp1buf, _T("UNKNOWN:%d"), ind);
      isqlt_tcsncpy (result, tmp1buf, maxsize);
      return (result);
    }
}


/* If arg found from alt_ptr returns 0-based index to it,
   otherwise gives a warning message and returns -1
 */
int
find_int_for_choice (TCHAR *name, TCHAR *arg, TCHAR **alt_ptr)
{
  int i;

  for (i = 0; alt_ptr[i]; i++)
    {
      if (!strcasecmp (arg, alt_ptr[i]))
	{
	  return (i);
	}
    }
  /* Else, we didn't find thing we were looking for. */
  {
    isql_fprintf (error_stream,
		  _T("%") PCT_S _T(": macro %") PCT_S _T(" requires one of the following options:"),
		  progname, name);
    for (i = 0; alt_ptr[i]; i++)
      {
	isql_fprintf (error_stream, _T(" %") PCT_S _T(""), alt_ptr[i]);
	if (NULL == alt_ptr[i + 1])
	  {
	    break;
	  }
	if (NULL == alt_ptr[i + 2])
	  {
	    isql_fprintf (error_stream, _T(" or"));
	  }
	else
	  {
	    isql_fprintf (error_stream, _T(","));
	  }
      }
    isql_fprintf (error_stream, _T(". NOT: \"%") PCT_S _T("\". at line %ld of %") PCT_S _T("\n"),
		  arg, latest_statement_begins_at (), current_loadexpr ());
    fflush (error_stream);
    return (-1);
  }
}

TCHAR *get_arg_after_braces (TCHAR *arg, TCHAR *tmp2buf, int bufsize, int get_all_raw);

int
set_value_to_macro (struct name_var_pair *macro_info,
		    TCHAR *arg, TCHAR *argptr, int ending_point)
{
  TCHAR *openptr, *closeptr;
  TCHAR *me = _T("set_value_to_macro");

  TCHAR *macro_name = macro_info->name;

  switch (macro_info->type)
    {
    case SAM_MACRO:
      {
	int i;
	int rc;
	SQLULEN j;
	TCHAR **alt_ptr;

	if (IS_NULLFP (SAM_set_method (macro_info)))
	  {
	    isql_fprintf (error_stream,
			  _T("%") PCT_S _T(": macro %") PCT_S _T(" is not settable!"),
			  progname, macro_name);
	    isql_fprintf (error_stream, _T(" At line %ld of %") PCT_S _T("\n"),
			latest_statement_begins_at (), current_loadexpr ());
	    fflush (error_stream);
	    return (0);
	  }

	if (NOT fully_connected)
	  {
	    isql_fprintf (error_stream,
	    _T("%") PCT_S _T(": macro %") PCT_S _T(" cannot be set before full connection to database."),
			  progname, macro_name);
	    isql_fprintf (error_stream, _T(" At line %ld of %") PCT_S _T("\n"),
			latest_statement_begins_at (), current_loadexpr ());
	    fflush (error_stream);
	    return (0);
	  }


	if (SAM_is_string_valued (macro_info))	/* Not really tested. */
	  {
	    rc = SAM_call_set_method (macro_info, arg);
	  }
	else
	  {
	    alt_ptr = SAM_choices_list (macro_info);

	    if (NULL != alt_ptr)
	      {
		i = find_int_for_choice (macro_name, arg, alt_ptr);
		if (i == -1)
		  {
		    return (0);
		  }
	      }
	    else
	      /* Else it's SAM_macro that wants an ordinary integer */
	      {			/* e.g. TIMEOUT or MAXROWS */
		if (NOT arg || empty_stringp (arg))
		  {
		    return (0);
		  }
		i = isqlt_tstoi (arg);
	      }
	    j = i;
	    rc = SAM_call_set_method (macro_info, j);
	  }
	if (SQL_SUCCESS != rc)
	  {
	    print_error (henv, hdbc, stmt, rc);
	    if (SQL_SUCCESS_WITH_INFO != rc)
	      return (0);
	  }
	return (1);
      }
    case INT_FLAG:
      {
	TCHAR **alt_ptr = int_flag_choices_list (macro_info);
	if (NULL != alt_ptr)
	  {
	    int i = find_int_for_choice (macro_name, arg, alt_ptr);
	    if (i != -1)
	      {
		(*((int *) macro_info->var_addr)) = i;
		if (!strcasecmp (macro_info->name, _T("AUTOCOMMIT")))
		  {
		    if (!strcasecmp (arg, _T("OFF")))
		      {
			commit_mode = 0;
			SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);
		      }
		    else if (!strcasecmp (arg, _T("ON")))
		      {
			commit_mode = 1;
			SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
		      }
		    else if (!strcasecmp (arg, _T("MANUAL")))
		      {
			commit_mode = 2;
		      }
		  }
		return (1);
	      }
	    /* Else, we didn't find thing we were looking for. */
	      {
		return (0);
	      }
	  }
/* If more_info contains NULL, then we fall to the next... */
      }
    case INT_VAR:
      {
	if (arg && NOT empty_stringp (arg))
	  {
	    *((int *) macro_info->var_addr) = isqlt_tstoi (arg);
	    return (1);
	  }
	else
	  return (0);
      }
    case CHARBUF_VAR:
      {
	int buflen = ((int) (ptrlong) macro_info->more_info);
	isqlt_tcsncpy (((TCHAR *) macro_info->var_addr), arg, (buflen - 1));
	return (1);
      }
    case CHARBUFLEN_VAR:
      {				/* Very Ad Hoc: Just copy max. countbyte characters to
				   character buffer, on the assumption that at least that
				   many bytes fit there. (Of course we should have a separate
				   max_size count also saved in macro_info). */
	int buflen = *((int *) macro_info->more_info);
	if (buflen > 0)		/* E.g. not SQL_NULL_DATA */
	  {
	    isqlt_tcsncpy (((TCHAR *) macro_info->var_addr), arg, (buflen - 1));
	  }
	return (1);
      }
    case CHARPTR_VAR:		/* One indirection more than in CHARBUF_VAR. */
      {
	if (is_set_to_rest_macro (macro_info))
	  {
	    *((TCHAR **) macro_info->var_addr) = chestrdup (argptr, me);
	  }
	else if (arg && NOT empty_stringp (arg))
	  {
	    *((TCHAR **) macro_info->var_addr) = chestrdup (arg, me);
	  }
	return (1);
      }
    case FILEPTR_VAR:
      {
	FILE *ptr;
	if (!strcasecmp (arg, _T("STDIN")))
	  {
	    ptr = stdin;
	  }
	else if (!strcasecmp (arg, _T("STDOUT")))
	  {
	    ptr = stdout;
	  }
	else if (!strcasecmp (arg, _T("STDERR")))
	  {
	    ptr = stderr;
	  }
	else
	  {
	    isql_fprintf (error_stream,
			  _T("%") PCT_S _T(": %") PCT_S _T(": STDIN, STDOUT or STDERR required for ")
			  _T(" macro \"%") PCT_S _T("\" at line %ld of %") PCT_S _T("\n"),
			  progname, me, macro_name,
			latest_statement_begins_at (), current_loadexpr ());
	    fflush (error_stream);
	    return (0);		/* Really, we should signal this! */
	  }

	(*((FILE **) macro_info->var_addr)) = ptr;
	return (1);
      }
    case ASSOC_ARR:		/* Associative array ref, e.g. $U{something} */
      {
	if (('{' == *(openptr = skip_blankos (argptr))) &&
	    (closeptr = SCP (find_closing_point (UCP (openptr),
						 ((UTCHAR) * openptr))))
	  )
	  {
	    TCHAR tmp2buf[TMPBUF_SIZE + 2], tmp3buf[TMPBUF_SIZE + 2];
	    TCHAR *indstr;

	    closeptr++;		/* Skip past the closing brace. */

	    openptr++;		/* Past the opening brace. */
	    if (NO (indstr = get_next_token (&openptr, tmp2buf,
					     TMPBUF_SIZE,
					     NULL, 0)))
	      {
		return (0);
	      }			/* Shouldn't really happen! */


	    arg = get_arg_after_braces (closeptr, tmp3buf, TMPBUF_SIZE, ending_point);
	    set_to_stringpair_list (indstr, arg,
				((stringpair_list *) macro_info->var_addr));

	    return (1);
	  }
	else
	  /* No opening brace or no matching closing brace! */
	  {
	    isql_fprintf (error_stream,
		       _T("%") PCT_S _T(": %") PCT_S _T(": Missing or unbalanced braces/brackets after")
			  _T(" macro \"%") PCT_S _T("\" at line %ld of %") PCT_S _T("\n"),
			  progname, me, macro_name,
			latest_statement_begins_at (), current_loadexpr ());
	    fflush (error_stream);
	    return (0);		/* Really, we should signal this! */
	  }
      }				/* case ASSOC_ARR */
    default:			/* Not handled. */
      {
	return (0);
      }

    }				/* switch(macro_info->type) */
}

static int
all_digits (TCHAR *string)
{
  while (*string)
    {
      if ((unsigned)(*string) > 127 || !isqlt_istdigit (*string))
	return 0;
      else
	string++;
    }
  return 1;
}

TCHAR *
convert_macro_to_text (struct name_var_pair *macro_info,
		       TCHAR **str_ptr, TCHAR *result, int maxsize,
		       TCHAR *input_buffer, int input_size,
		       int used_for_show_command)
{
  TCHAR *openptr, *closeptr;
  TCHAR *me = _T("convert_macro_to_text");
  TCHAR *macro_name = macro_info->name;
  TCHAR tmpnumbuf[181];


  switch (macro_info->type)
    {
/* The following is a real mess, and requires cleaning! I'm sorry. */
    case SAM_MACRO:
      {
	int rc, get_method_type;
	SQLULEN intres;
	int is_strres = 0;
	TCHAR *not_set_string = _T("NOT SET");
	SWORD res_len;
	TCHAR **alt_ptr = SAM_choices_list (macro_info);

	if (IS_NULLFP (SAM_get_method (macro_info)))
	  {
	    isqlt_stprintf (tmpnumbuf, _T("macro %") PCT_S _T(" is not gettable!"),
		     macro_name);
	    isqlt_tcsncpy (result, tmpnumbuf, maxsize);
	    return (result);
	  }

	if (NOT fully_connected)
	  {
	    isqlt_stprintf (tmpnumbuf,
		     _T("NOT CONNECTED: %") PCT_S _T(" value unknown"), macro_name);
	    isqlt_tcsncpy (result, tmpnumbuf, maxsize);
	    return (result);
	  }

	get_method_type = SAM_get_method_type (macro_info);
	if (2 == get_method_type)	/* For SQLGetInfo */
	  {
	    if (SAM_is_string_valued (macro_info))
	      {			/* with a string result */
		rc = SAM_call_get2method (macro_info, result,
					  ((SWORD) maxsize),
		/* pcbInfoValue (the last arg) should be SWORD *   */ &res_len);
		is_strres = 1;
	      }
	    else
	      {			/* with an integer result */
		rc = SAM_call_get2method (macro_info, &intres, ((SWORD) 4),
		/* pcbInfoValue (the last arg) should be SWORD *   */ &res_len);
	      }
	  }
	else
	  /* method type is 1 for SQLGetStmt/ConnectOption */
	  {
	    if (SAM_is_string_valued (macro_info))
	      {			/* Last was: &strres */
		isqlt_tcsncpy (result, not_set_string, maxsize);
		rc = SAM_call_get_method (macro_info, result);
		is_strres = 1;
	      }
	    else
	      /* It's with an integer result */
	      {
		rc = SAM_call_get_method (macro_info, &intres);
	      }
	  }

	if (SQL_SUCCESS != rc)
	  {
	    print_error (henv, hdbc, stmt, rc);
	    if (SQL_SUCCESS_WITH_INFO != rc)
	      return (NULL);
	  }

/* Not needed:  if(2 == get_method_type) { return(result); } */
	if (is_strres)
	  {
	    return (result);	/* (strres); */
	  }

	if (NULL != alt_ptr)
	  {
	    return (find_choice_for_int (macro_name, ((int) intres),
					 alt_ptr, result, maxsize));
	  }
	else
	  /* The result is plain integer. */
	  {
	    isqlt_stprintf (tmpnumbuf, _T("%d"), (int) intres);
	    isqlt_tcsncpy (result, tmpnumbuf, maxsize);
	    return (result);
	  }
      }
    case INT_FLAG:
      {
	TCHAR **alt_ptr = int_flag_choices_list (macro_info);

	if (NULL != alt_ptr)
	  {
	    return (find_choice_for_int (macro_name,
				 (*((int *) macro_info->var_addr)), alt_ptr,
					 result, maxsize));
	  }
	/* If more_info contains NULL, then we fall to the next... */
      }
    case INT_VAR:
      {
	isqlt_stprintf (tmpnumbuf, _T("%d"), *((int *) macro_info->var_addr));
	isqlt_tcsncpy (result, tmpnumbuf, maxsize);
	return (result);
      }
    case CHARBUF_VAR:
      {
	return ((TCHAR *) macro_info->var_addr);
      }
    case CHARBUFLEN_VAR:	/* E.g. RETVAL */
      {				/* Like above, but more_info contains the address of
				   corresponding length byte, which should be checked first. */
	if (SQL_NULL_DATA == (*((int *) macro_info->more_info)))
	  {
	    result = NULL;
	  }
	else
	  {
	    result = ((TCHAR *) macro_info->var_addr);
	  }
	return (result);	/* (result ? result : "NULL"); */
      }

    case CHARPTR_VAR:		/* One indirection more than in CHARBUF_VAR. */
      {
	result = (*((TCHAR **) macro_info->var_addr));
	return (result);	/* (result ? result : "NULL"); */
      }
    case FILEPTR_VAR:
      {
	FILE *ptr = (*((FILE **) macro_info->var_addr));
	if (stdin == ptr)
	  {
	    return (_T("STDIN"));
	  }
	if (stdout == ptr)
	  {
	    return (_T("STDOUT"));
	  }
	if (stderr == ptr)
	  {
	    return (_T("STDERR"));
	  }
	else
	  {
	    TCHAR tmp1buf[TMPBUF_SIZE + 2];
	    isqlt_stprintf (tmp1buf, _T("FILEPTR:%08x"),
		     *((int *) macro_info->var_addr));
	    isqlt_tcsncpy (result, tmp1buf, maxsize);
	    return (result);
	  }
      }
    case ASSOC_ARR:		/* Associative array ref, e.g. $U{something} */
      {
	int openf = 0;
	if (('{' == *(openptr = skip_blankos (*str_ptr)))
	    && (openf = 1)
	    &&
	    (closeptr = SCP (find_closing_point (UCP (openptr),
						 ((UTCHAR) * openptr))))
	  )
	  {
	    TCHAR tmp3buf[TMPBUF_SIZE + 2];
	    TCHAR *indstr;

	    *str_ptr = closeptr + 1;	/* Skip past closing brace. */

	    openptr++;		/* Past the opening brace. */
	    if (NO (indstr = get_next_token (&openptr, tmp3buf,
					     TMPBUF_SIZE,
					     input_buffer, input_size)))
	      {
		return (TOKEN_PREMATURE_END);
	      }			/* Shouldn't really happen! */


	    result = assoc_value_from_stringpair_list (indstr,
				((stringpair_list *) macro_info->var_addr));

	    return (result);	/* (result ? result : _T("NULL")); */
	  }
	else
	  /* No opening brace or no matching closing brace! */
	  {			/* The following is kludgous, I admit.
				   If user has given command like show U
				   (without braces) then dump out all of its
				   contents. Good for debugging. */
	    if (used_for_show_command && (NOT openf))
	      {
		int len = dump_stringpair_list (macro_name,
				((stringpair_list *) macro_info->var_addr));
		fflush (stdout);
		isqlt_stprintf (tmpnumbuf, _T("%d"), len);
		isqlt_tcsncpy (result, tmpnumbuf, maxsize);
		return (result);	/* Returns the length of assoclist */
	      }
	    else
	      {
		isql_fprintf (error_stream,
		       _T("%") PCT_S _T(": %") PCT_S _T(": Missing or unbalanced braces/brackets after")
			      _T(" macro \"%") PCT_S _T("\" at line %ld of %") PCT_S _T("\n"),
			      progname, me, macro_name,
			latest_statement_begins_at (), current_loadexpr ());
		fflush (error_stream);
		return (TOKEN_PREMATURE_END);	/* Really, we should signal this! */
	      }
	  }
      }				/* case ASSOC_ARR */
    case COMP_MACRO:		/* $EQU, $NEW, $LT, $LTE, $GT or $GTE */
      {
	int op = ((int) (ptrlong) macro_info->var_addr);
	int compared_to = ((int) (ptrlong) macro_info->more_info);
	int code;		/* -1=DVC_LESS, 0=DVC_MATCH, 1=DVC_GREATER */
	TCHAR *left, *right;
	TCHAR hmp1buf[TMPBUF_SIZE + 2], hmp2buf[TMPBUF_SIZE + 2];

	/* First get the things to be compared. */
	if (NO (left = get_next_token (str_ptr, hmp1buf, TMPBUF_SIZE,
				       input_buffer, input_size)))
	  {
	    return (TOKEN_PREMATURE_END);
	  }
	if (NO (right = get_next_token (str_ptr, hmp2buf, TMPBUF_SIZE,
					input_buffer, input_size)))
	  {
	    return (TOKEN_PREMATURE_END);
	  }

 	if (all_digits (right) && isqlt_tcschr (left, '.'))
	  {
	    TCHAR *dot = isqlt_tcschr (left, '.'), *tmp;
	    int all_zero = 1;
	    tmp = dot;
	    while (tmp && *tmp)
	      {
		tmp++;
		if (*tmp && *tmp != '0')
		  {
		    all_zero = 0;
		    break;
		  }
	      }
	    if (all_zero)
	      *dot = 0;
	    code = (isqlt_tcscmp (left, right));
	    code = code < 0 ? -1 : (code > 0) ? 1 : 0;
	    *dot = '.';
	  }
	else if (trim_string_result)
	  code = (isqlt_tcsncmp (left, right, isqlt_tcslen (right)));
	else
	  code = (isqlt_tcscmp (left, right));
	code = code > 0 ? 1 : ((code < 0) ? -1 : 0);
	code = ((op == CM_SAME) ? (code == compared_to)
	/* else it's CM_DIFF */ : (code != compared_to));

	if (code)
	  {
	    isqlt_tcsncpy (result, _T("1"), maxsize);
	  }
	else
	  {
	    isqlt_tcsncpy (result, _T(""), maxsize);
	  }

	return (result);
      }				/* case COMP_MACRO */

    }				/* switch(macro_info->type) */
  return NULL;
}


int
dump_all_settable_variables (TCHAR *varname_to_match)
{
  struct name_var_pair *structptr = isql_variables;
  TCHAR *argptr, *value;
  TCHAR *dumpty_string = _T("");
  TCHAR tmp1buf[TMPBUF_SIZE + 2];

  while (structptr->name)
    {
      if (is_settable_macro_type (structptr))
	/* && some_matching_function (varname_to_match,structptr->name) */
	{
	  argptr = dumpty_string;
	  value = convert_macro_to_text (structptr, &argptr,
					 tmp1buf, TMPBUF_SIZE,
					 NULL, 0, 1);
	  if (NULL == value)
	    {
	      value = _T("NULL");
	    }
	  isql_fputs (structptr->name, stdout);
	  isql_fputs (_T("\tis "), stdout);
	  if (in_HTML_mode () && oo_esc)
	    {
	      html_print_escaped (value, stdout);
	    }
	  else
	    {
	      isql_fputs (value, stdout);
	    }
	  isql_fputs (_T("\n"), stdout);
	  fflush (stdout);
	}
      structptr++;
    }

  return (1);
}


/* If fourth argument input_buffer is given as NULL, then doesn't
   try to read next line(s) in if the current line is finished.
   (That feature has been never used, so neither it has been tested,
   in current usage the input_buffer is always given as NULL.) */
TCHAR *
get_next_token (TCHAR **str_ptr, TCHAR *result, int maxsize,
		TCHAR *input_buffer, int input_size)
{
  TCHAR *text;
  TCHAR *resptr, *openptr, *closeptr;
  int len, indnum = -1;
  int is_argv = 0;		/* Flag for either LAST or ARGV [index] form */
  TCHAR tmpnumbuf[81];

  text = *str_ptr;
de_nuevo:
  text = skip_blankos (text);
  if (*text)
    {				/* Something following on this line? */
      if (('\'' == *text) || ('"' == *text))	/* Quoted String Literal? */
	{
	  *str_ptr = text;	/* Save the original starting location. */
	  /* Because text will be screwed in this first call: */
	  len = parse_string_literal ((UTCHAR **) & text, NULL);		/* First length */
	  if (len > maxsize)
	    {
	      return (NULL);
	    }
	  parse_string_literal ((UTCHAR **) str_ptr, (UTCHAR *) result);	/* Then the real stuff. */
	  return (result);
	}
      if ((*text == '-') && (*(text + 1) == '-'))	/* If a comment, skip it */
	{
	  while (*text && (*text != '\n'))
	    {
	      text++;
	    }
	  if (*text)
	    {
	      text++;
	    }			/* Skip past the newline. */
	  goto de_nuevo;
	}

      /* Is it one of the special groovy macro-words? */
      if (('$' == *text))	/* && (*(text+1)) && isalnum(*(text+1))) */
	{
	  struct name_var_pair *macro_info;
	  TCHAR *macro_name;
	  TCHAR tmp1buf[TMPBUF_SIZE + 2];

	  *str_ptr = (text + 1);	/* Skip past the first dollar. */
	  if ('$' == text[1])
	    {
	      str_ptr[0] = text + 2;
	      isqlt_tcscpy (result, _T("$"));
	      return result;
	    }

	  /* First get the macro word to be tested. */
	  if (NO (macro_name = get_next_token (str_ptr, tmp1buf, TMPBUF_SIZE,
					       input_buffer, input_size)))
	    {
	      macro_name = _T("NULL");
	    }

	  if (word_follows (text + 1, _T("LOADEXPR")))
	    {
	      *str_ptr = (text + sizeof (_T("LOADEXPR")));
	      return (current_loadexpr ());
	    }

	  else if (word_follows (text + 1, _T("LINENO")))
	    {
	      *str_ptr = (text + sizeof (_T("LINENO")));

	      isqlt_stprintf (tmpnumbuf, _T("%d"), (int) current_linecount ());
	      isqlt_tcsncpy (result, tmpnumbuf, maxsize);

	      return (result);
	    }

	  else if (word_follows (text + 1, _T("YYYYMMDD")))
	    {
	      struct tm *tm;
	      time_t time_now = time (NULL);
	      TCHAR temp[100];

	      *str_ptr = (text + sizeof (_T("YYYYMMDD")));

	      tm = localtime (&time_now);

	      isqlt_stprintf (temp, _T("%04d%02d%02d"),
		       tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday);

	      isqlt_tcsncpy (result, temp, maxsize);
	      return (result);
	    }

	  else if (word_follows (text + 1, _T("HHMMSS")))
	    {
	      struct tm *tm;
	      time_t time_now = time (NULL);
	      TCHAR temp[100];

	      *str_ptr = (text + sizeof (_T("HHMMSS")));

	      tm = localtime (&time_now);

	      isqlt_stprintf (temp, _T("%02d%02d%02d"),
		       tm->tm_hour, tm->tm_min, tm->tm_sec);

	      isqlt_tcsncpy (result, temp, maxsize);
	      return (result);
	    }

	  else if (word_follows (text + 1, _T("DATASOURCES")))
	    {
	      *str_ptr = (text + sizeof (_T("DATASOURCES")));
	      return (get_list_of_datasources (0, result, maxsize));
	    }
	  else if (word_follows (text + 1, DATASOURCE_TOKEN))	/* INPUT_DATASOURCE */
	    {
	      *str_ptr = (text + sizeof (DATASOURCE_TOKEN));
	      return (get_list_of_datasources (1, result, maxsize));
	    }

	  else if (word_follows (text + 1, _T("+")))
	    {			/* Add together the next two elements. */
	      long int leftval = 0, rightval = 0;
	      TCHAR *left, *right;
	      TCHAR tmp1buf[TMPBUF_SIZE + 2], tmp2buf[TMPBUF_SIZE + 2];

	      *str_ptr = (text + sizeof (_T("+")));

	      /* First get the things to be added. */
	      if (NO (left = get_next_token (str_ptr, tmp1buf, TMPBUF_SIZE,
					     input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}
	      if (NO (right = get_next_token (str_ptr, tmp2buf, TMPBUF_SIZE,
					      input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}

	      leftval = isqlt_tstol (left);
	      rightval = isqlt_tstol (right);
	      isqlt_stprintf (tmpnumbuf, _T("%ld"), (leftval + rightval));
	      isqlt_tcsncpy (result, tmpnumbuf, maxsize);

	      return (result);
	    }

	  else if (word_follows (text + 1, _T("-")))
	    {			/* Subtract the next two elements (the second from the first). */
	      long int leftval = 0, rightval = 0;
	      TCHAR *left, *right;
	      TCHAR tmp1buf[TMPBUF_SIZE + 2], tmp2buf[TMPBUF_SIZE + 2];

	      *str_ptr = (text + sizeof (_T("-")));

	      /* First get the things to be subtracted. */
	      if (NO (left = get_next_token (str_ptr, tmp1buf, TMPBUF_SIZE,
					     input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}
	      if (NO (right = get_next_token (str_ptr, tmp2buf, TMPBUF_SIZE,
					      input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}

	      leftval = isqlt_tstol (left);
	      rightval = isqlt_tstol (right);
	      isqlt_stprintf (tmpnumbuf, _T("%ld"), (leftval - rightval));
	      isqlt_tcsncpy (result, tmpnumbuf, maxsize);

	      return (result);
	    }


	  else if (word_follows (text + 1, _T("IF")))
	    {			/* Syntax: $IF $EQU STR1 STR2 THEN_RESULT ELSE_RESULT */
/* A command like following is legal, and will print "nauta-jauheliha"
   followed by NL:
   echo $if $equ 3 3 $if $equ 4 5 "sika" "nauta" "mursu" "-jauheliha\n";

   Also following works, by chance:

   $IF $NEQ $RETVAL "FOU" EXIT ECHO "Assertion passed RETVAL=" $RETVAL "\n";
 */
	      int is_true;
	      TCHAR *cond;
	      TCHAR *left, *right = empty_string;
	      TCHAR tmp1buf[TMPBUF_SIZE + 2];

	      *str_ptr = (text + sizeof (_T("IF")));

	      /* First get the thing to be tested. */
	      if (NO (cond = get_next_token (str_ptr, tmp1buf, TMPBUF_SIZE,
					     input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}

	      /* Length greater than zero? and different from "0" ? */
	      is_true = (*cond &&
			 ((*cond != '0') || (*(cond + 1) != '\0')));

/* Then get the then and else part. (We have to skip them anyway).
   The part we really return as result have to be copied directly
   into the result argument, and the one which is skipped is copied
   into tmp1buf and discarded.
   No dangling references should be returned!

   Important change at 10.March.1998:
   (the line **str_ptr && isspace(*((unsigned char *) *str_ptr)))
   If the then part ends with an immediately following closing
   character, that is, terminating zero '\0', any special character
   like ", ', >, or whatever, actually, anything else except white space,
   then it is understood that there's no else-part at all.
   So from this on, if there is an else-part, there should be always
   at least one blank between then and else parts.

   This is allows now constructs like
   <OPTION VALUE="fin" $IF $EQU $LANG fin SELECTED>Suomi
   or VALUE="$IF $EQU $JOKU $JOTAKIN stuff"
   without need for any cumbersome else-kludges.

 */
	      if (NO (left = get_next_token (str_ptr,
					     (is_true ? result : tmp1buf),
					  (is_true ? maxsize : TMPBUF_SIZE),
					     input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}

	      if (**str_ptr && isqlt_istspace (*((UTCHAR *) *str_ptr))
		  && NO (right = get_next_token (str_ptr,
					       (is_true ? tmp1buf : result),
					  (is_true ? TMPBUF_SIZE : maxsize),
						 input_buffer, input_size)))
		{		/* return(TOKEN_PREMATURE_END); */
		}		/* else-part is optional. */

/* We assign is_true to static LIF_value not until here, after we have
   returned back from recursion, i.e. gone through then and else parts
   which themselves might contain more $if-clauses. For all of them are
   executed too, even on those branches that actually are not valid
   (e.g. sub-ifs that are in else-part although the condition of this if
   indicated to choose then-part, or vice versa), so we decide that
   $LIF -macro refers always to the condition of the latest TOPMOST $IF
   as it is much clearer for a potential test-suite writer (i.e. me).
 */
	      LIF_value = is_true;
	      return (is_true ? left : right);	/* Choose then or else part */
	    }


/* The next one is for LAST or ARGV followed by index in brackets */
/* Should allow also expressions like $LAST[$COLCNT] or $ARGV[$I]
   $LAST[$ARGV[$I]] won't work yet, because of the nested brackets
   (Instead the unbalanced $LAST[$ARGV[I] might work temporarily,
   don't use...)
   14-MAY-1997 this has been fixed as by using the new function
   find_closing_point instead of old isqlt_tcschr(text+1,']'))
 */
	  else if ((word_follows (text + 1, _T("LAST")) ||
		    ((is_argv = 1), word_follows (text + 1, _T("ARGV")))) &&
	      ('[' == *(openptr = skip_blankos (text + sizeof (_T("LAST"))))) &&
		   (closeptr = SCP (find_closing_point (UCP (openptr),
						      ((UTCHAR) * openptr))))
	    )
	    {
	      TCHAR tmp1buf[TMPBUF_SIZE + 2];
	      TCHAR *indstr;

	      *str_ptr = closeptr + 1;	/* Skip past closing bracket. */

	      openptr++;	/* Past the opening bracket. */
	      if (NO (indstr = get_next_token (&openptr, tmp1buf, TMPBUF_SIZE,
					       input_buffer, input_size)))
		{
		  return (TOKEN_PREMATURE_END);
		}		/* Shouldn't really happen! (as there is ]) */

	      /* Old Way:  indnum = isqlt_tstoi(skip_blankos(openptr+1)); */

	      indnum = isqlt_tstoi (indstr);	/* Shouldn't care about closing ] */

	      if (is_argv)
		{
		  if ((indnum < 0) || (indnum > G_argc))
		    {
		      isqlt_stprintf (tmpnumbuf, _T("ARGV[%d]=Out_of_Bounds(%d)"),
			       indnum, n_out_cols);
		      isqlt_tcsncpy (result, tmpnumbuf, maxsize);
		      return (result);
		    }

		  if (NO G_argv[indnum])
		    {
		      return (TOKEN_NULL);
		    }
		  /* Was: { isqlt_tcsncpy(result,"NULL",maxsize); } */
		  else
		    {
		      return (G_argv[indnum]);
		    }
		}
	      else
		/* It's for LAST form. */
		{
		  if ((indnum < 1) || (indnum > n_out_cols))
		    {
		      isqlt_stprintf (tmpnumbuf, _T("LAST[%d]=Out_of_Bounds(%d)"),
			       indnum, n_out_cols);
		      isqlt_tcsncpy (result, tmpnumbuf, maxsize);
		      return (result);
		    }

		  indnum--;	/* One based indexing for columns */
		  if (SQL_NULL_DATA == out_cols[indnum].o_col_len)
		    {
		      return (TOKEN_NULL);
		    }
		  /* Was: { isqlt_tcsncpy(result,"NULL",maxsize); } */
		  else
		    /* Return a direct pointer to column buffer. */
		    {
		      return ((TCHAR *) out_cols[indnum].o_buffer);
		    }
		}

	    }			/* LAST or ARGV with [index] */

/* The rest should be in standard format and should be found with
   find_var_info function. */

	  else if (NO (macro_info = find_var_info (macro_name)))
	    {
	      isql_fprintf (error_stream,
			    _T("%") PCT_S _T(": get_next_token: Unknown macro word \"%") PCT_S _T("\" at line %ld of %") PCT_S _T("\n"),
			    progname, macro_name,
			latest_statement_begins_at (), current_loadexpr ());
	      fflush (error_stream);
	      return (TOKEN_PREMATURE_END);	/* Really, we should signal this! */
	    }

	  result = convert_macro_to_text (macro_info, str_ptr, result,
				      maxsize, input_buffer, input_size, 0);
	  return (result ? result : TOKEN_NULL);

	}			/* Begins with a dollar sign ? */

/* Else, an ordinary keyword. Also all other $-prefixed, unknown things */
/* The ending test was just: *text && !isqlt_istspace(*text)
   but test for singlequote and double quote was needed so that
   unknown $dollar_forms inside quoted strings (see the next function)
   don't screw up parse_statement_for_special_parameters.
   Also we now cut tokens to first opening or closing character, i.e.
   {, }, [, ], ( ) or < and >, as well as for COMMA (,), which is
   later necessary. (For implementing CSV reading, multiple foreach
   formal parameters, etc.)
   so that they will be returned one token (of one character) per time.
   (The last part of proceeding test of for).
   Now also the equal sign (=) so that set macro=value things are parsed
   all right.
   In any case, at least tokens should not be cut for a dot (.), for
   a dash (-), for a slash (/), and for a backslash (\),
   so that we don't need to enclose tablenames like qual.own.tablename,
   loaded filenames inside single- or doublequotes, nor options
   like -r for load command.
 */

      for (resptr = result;
	   *text && NOT isqlt_istspace (*((UTCHAR *) text))
	   && ('\'' != *text) && ('"' != *text)
	   && ((resptr == result) || (NOT cut_token_char (*text)));
	   maxsize--)
	{
	  if (maxsize > 0)
	    {
	      *resptr++ = *text++;
	    }
	}
      *resptr = '\0';
      *str_ptr = (TCHAR *) text;
      return (result);
    }
  else
    {
      if (input_buffer)		/* Have to read the next line in. */
	{
	  if (0 == isqlt_fgetts (input_buffer, input_size, stdin))
	    return (NULL);
	  current_linecount ()++;
	  text = *str_ptr = input;
	  goto de_nuevo;
	}
      else
	{
	  return (NULL);
	}
    }
}


#define not_escaped(C)\
 ( ((((UTCHAR)(C))) < 127) && (isalnum((C)) || ('_' == (C))) )


/* The next two functions, escape_string and count_escaped_length
   should use exactly the same criteria for determining what
   to escape and how.
   Doesn't add the terminating zero, instead, always keeps the
   original character following right after the last copied.
 */
UTCHAR *
escape_string (UTCHAR *dest, UTCHAR *src)
{
  UTCHAR *org_dest = dest;

  for (; *src; src++)
    {
      if (not_escaped (*src))
	{
	  *dest++ = *src;
	}
      else
	/* Needs backslash plus 3 octal digits. */
	{
	  UTCHAR last = *(dest + 4);
	  isqlt_stprintf (SCP (dest), _T("\\%03o"), *((UTCHAR *) src));
	  dest += 4;
	  *dest = last;		/* Restore the original character right after. */
	}
    }

  return (org_dest);
}


int
count_escaped_length (UTCHAR *s)
{
  int len;

  for (len = 0; *s; s++)
    {
      if (not_escaped (*s))
	{
	  len++;
	}
      else
	{
	  len += 4;
	}			/* Backslash plus 3 octal digits. */
    }
  return (len);
}



/* Used by exec_for_foreach to get the count of parameters in
   the statement, as well as to record all "special parameter extensions"
   like ?C, ?R or ?1 into pardescvec.

   Now, 3-MAY-1997 this is used also for substituting $dollar_forms
   into their respective results got with get_next_token.
   Note that because the whole_statement buffer is destructively
   modified in place, and because $dollar_forms may produce longer
   strings than the respective length of the $dollar_form, it is
   important that whole_statement points to a buffer that really
   has some extra space. For this reason, exec_one will check that
   its argument is pointing to input buffer, and if not, it will
   copy it there. (E.g. happens when statements are executed from
   the command line.)
   Note that this doesn't currently check for any kind of an overflow
   of that input buffer, but let's just now cross our fingers and hope
   that the input buffer is big enough (Well, it's almost 65Kb).

   Added possibility to give pardescvec as NULL, so also exec_one can
   call this one for doing just the $-substitutions, giving maxpars as
   zero.
 */

int
parse_statement_for_special_parameters (UTCHAR * whole_statement,
					UTCHAR * pardescvec,
					int maxpars)
{
  int pars_found = 0;
  int inside_string = 0;
  UTCHAR prevchar;
  UTCHAR *str = whole_statement, *p;
  int whole_len = (int) isqlt_tcslen (SCP (whole_statement));
/* whole_len should be updated accordingly wherever the length of
   whole_statement is changed! */
  TCHAR tmp1buf[TMPBUF_SIZE + 2];

  for (prevchar = 0; *str; prevchar = *str, str++)
    {
      switch (*str)
	{

/* A dollar is escaped inside strings with a backslash, e.g.
   'A Jackpot of 1000\$' is sent to server as it is, which in turn
   will convert \$ to just a $.

   but outside of strings it currently cannot be escaped
   except by setting macro_substitution off with the command
   SET MACRO_SUBSTITUTION OFF;
   (E.g. not by doubling the dollars (as before), because double
   dollar now makes sense as a syntactic construct inside isql).

   This makes it possible to write commands like

   foreach integer between 1 1 create table \$ARGV[$I];

   i.e. \ makes sure that the arbitrary tablename got from the command
   line works as a tablename, even although it would be a reserved
   SQL keyword.

 */
	case '$':
	  {
	    if (0 == flag_macro_substitution)
	      {
		break;
	      }
#ifdef FORGET_THIS
	    /* If the next one is a $ also, then it is a real dollar. */
	    if (('$' == *(str + 1)) && (NOT inside_string))
	      {			/* Shift the rest of string one left, overwriting the */
		for (p = str; *p; p++)
		  {
		    *p = *(p + 1);
		  }		/* first dollar */
		whole_len--;
	      }
#endif
	    else
	      /* It's a dollar expression to be substituted. */
	      {			/* Can be done also inside strings. */
		UTCHAR *p1, *p2, *cont;

		cont = str;
		p = UCP (get_next_token (((TCHAR **) &cont), tmp1buf, TMPBUF_SIZE,
					 NULL, 0));
		/* cont points now to the first char after $dollar_form */

		if (NULL == p)	/* If dollar expression produces a null */
		  {		/* We could just squash out the dollar and param name.
				   isqlt_tcscpy(SCP(str),SCP(cont));
				   whole_len -= (cont-str);
				   BUT WE DON'T DO THAT, INSTEAD WE USE STRING "NULL": */
		    p = UCP (_T("NULL"));
		  }
/*          No  else  i.e. fall through in any case. */
		{
		  int oldlen = (int) (cont - str);	/* Length of $dollar_form */
		  int newlen =	(int) /* Length of the new replacement */
		  (inside_string ? count_escaped_length (UCP (p))
		   : isqlt_tcslen (SCP (p)));
		  int delta = (newlen - oldlen);	/* Negative if shortens */

/* First copy the rest of statement to the proper new location, as either
   for making space for the string produced (if longer than $dollar_form)
   or to squash out any extra rubbish characters (if produced string is
   shorter than $dollar_form).
   Note that in the former case isqlt_tcscpy cannot be used.
   We leave the copying out if the produced string is of the same length
   than the $dollar_form which produced it.
 */
		  if (newlen > oldlen)
		    {		/* Copy from right to left making space. */
		      for (p1 = (str + whole_len), p2 = p1 + delta;
			   (p1 >= cont);
			   p1--, p2--)
			{
			  *p2 = *p1;
			}
		    }
		  else if (newlen < oldlen)
		    {		/* Do NOT use isqlt_tcscpy in order to squash out extra characters --- ranges overlap! */
		      for (p1 = cont, p2 = p1 + delta;
			   (p1 <= (str + whole_len));
			   p1++, p2++)
			{
			  *p2 = *p1;
			}
		    }
/* And then copy the produced string itself, starting from the same
   location where the $dollar_form was (but leave the terminating
   zero out this time, so that it does not overwrite the first char
   of "rest": */
		  if (inside_string)
		    {
		      escape_string (UCP (str), UCP (p));
		    }
		  else
		    {
		      memcpy (SCP (str), SCP (p), newlen * sizeof (TCHAR));
		    }
/* Update whole_len. Is equivalent to whole_len -= (oldlen-newlen); */
		  whole_len += delta;
		  str += (newlen - 1);	/* -1 is for str++ in the end of loop */
		}
	      }
	    break;
	  }

	case '-':
	  {			/* If the previous was a dash also, then it is a comment. */
	    if (!inside_string && ('-' == prevchar))
	      {			/* Then skip to the end of this line or whole statement: */
		for (; (*str && (*str != '\n')); str++);
		str--;		/* As there are str++ in the end of for loop. */
	      }
	    break;
	  }
/* Note: '' = "", ''' by itself is syntax error, but ''' fish' = "' fish"
   '''' = "'", '''''' = "''"  See notes below.
 */
	case '\\':		/* Backslash ? */
	  {
	    if (inside_string)	/* Inside string? */
	      {			/* Then skip that next character, whatever it is, also */
		if (*(str + 1))
		  {
		    str++;
		  }		/* another backslash or quote */
	      }			/* Or dollar!!! */
	    break;
	  }
	case '\'':		/* A single quote? */
	  {
	    if (!inside_string)
	      {
		inside_string = 1;
	      }
	    else
	      /* We are inside string already. Then if the next */
	      {			/* char is not a quote, then this is a terminating quote */
		if ('\'' != *(str + 1))
		  {
		    inside_string = 0;
		  }
		else
		  {
		    str++;
		  }		/* Skip that quote next time. */
	      }
	    break;
	  }
/*        case ':': Commented out until I know this for sure. */
	case '?':
	  {
	    if (1 == flag_ignore_params)
	      {
		break;
	      }
	    if (inside_string)
	      {
		break;
	      }			/* Not a true parameter. */
	    if (isalpha (str[1]) || (':' == str[1]))
	      break; /* ?name is SPARQL instruction. */
	    if ('?' == str[1])
	      break; /* This is the first of '??' in SPARQL, the second will be counted. */
	    if (pars_found == maxpars)
	      {
		isql_printf (
			      _T("-- More than %d parameters, ignoring all the rest of the statement %") PCT_S _T("\n"),
			      maxpars, whole_statement);
		if (pardescvec)
		  pardescvec[pars_found++] = '\0';	/* Terminating zero. */
	      }
	    else if (pars_found > maxpars)
	      {
		pars_found++;
	      }
	    else
	      /* pars_found < maxpars */
	      {			/* The older standard allows also colon as a parameter
				   marker? */
/*              if(':' == *str) { *str = '?'; } */

/* If the question mark is followed by an alphanumeric char, or by
   another question mark, then it is our special parameter extension
   like ??  ?C  ?R  or ?1 */
		if (*(str + 1) && (('?' == *(str + 1)) || isalnum (*(str + 1))))
		  {
		    str++;
/* Record the character found, and then copy the rest of statement string
   one left, overwriting just that character, so that DBMS will see just
   normal parameter marker, a question mark without any whistles: */
		    if (pardescvec)
		      {
			pardescvec[pars_found++] = *(str);
		      }
		    for (p = str; *p; p++)
		      {
			*p = *(p + 1);
		      }
		    whole_len--;
		    str--;	/* Because of str++ in the end of for loop */
		  }
		else
		  /* Otherwise, it was followed by space, punctuation */
		  {		/* or maybe a terminating zero. It is a normal par. */
		    /* Sapce is used for marking Nothing special. */
		    if (pardescvec)
		      {
			pardescvec[pars_found++] = ' ';
		      }
		  }
	      }
	    break;
	  }			/* case ? */
	}			/* switch */

    }				/* for loop. */

  if ((pars_found <= maxpars) && pardescvec)
    {
      pardescvec[pars_found] = '\0';
    }
  return (pars_found);
}



/* SQL standard allows also C-like multiline comments like this.
   Maybe we should check for those also?
   Note that this function, as well as the previous,
   parse_statement_for_special_parameters function should be modified
   accordingly, now that Kubl will soon allow
   also backslash escape sequences in strings.
   E.g. with the new system '\'' is "'" and '\\' is "\" is pain in the
   ass. So we have to know which system we are using.
   Not really, implemented 26-MAR-1997 easily by just adding a
   simple case clause for the backslash.
   Added also two more arguments, scivec (semicolon index vector)
   and maxsemicols which is its maximum size.
   scivec will hold the one-based indices to semicolons present in
   the str, or optionally if its is given as NULL pointer, then nothing
   is tried to store there. Indices are one-based so that the end of them
   can be marked with a terminating zero.

   Note the similarity with the previous function which collects
   parameter-markers and has to avoid strings and comments as well.

   Modification 14-MAY-1997: Added two parameters:
   chars_watched which should be a string two characters, e.g. "{}"
   if we are counting braces, or "[]" if brackets, or "()" if parentheses,
   or "<>" if angle brackets.
   and return_index_instead_of_level, which if non-zero, tells this
   function to return, instead of the final bracelevel, the one-based
   index to the point where the corresponding closing character
   of the same level was found (that is, where bracelevel plunged
   back to the zero.) or zero if no matching closing character were
   found.
   The old functionality is accessible with the following macro.
 */


#define count_bracelevel(s,l,vec,maxsemicols, set0atcomment, pinside_string)\
count_bracelevel_or_find_matching_one(UCP(s),(l),(vec),(maxsemicols),\
                                      UCP(_T("{}")),0, set0atcomment, pinside_string)


int count_bracelevel_or_find_matching_one
  (UTCHAR * str, int bracelevel, int *scivec, int maxsemicols,
   UTCHAR * chars_watched, int return_index_instead_of_level,
   int set0atcomment, UTCHAR *pinside_string)
{
  UTCHAR prevchar;
  int semicols_found = 0;
  UTCHAR *whole_line = str;

  if (scivec)
    {
      scivec[semicols_found] = 0;
    }				/* Empty it first. */

  for (prevchar = 0; *str; prevchar = *str, str++)
    {
      switch (*str)
	{
	case '-':
	  {			/* If the previous was a dash also, then it is a comment. */
	    if (!*pinside_string && ('-' == prevchar))
	      {
		if (set0atcomment && (bracelevel == 0) && (str - whole_line) > 0)
		  *(str - 1) = 0;
		if (return_index_instead_of_level)	/* Failed, because */
		  {
		    return (0);
		  }		/* no closing bracket was found. */
		else
		  {
		    return (bracelevel);
		  }
	      }
	    break;
	  }
/* Note: '' = "", ''' by itself is syntax error, but ''' fish' = "' fish"
   '''' = "'", '''''' = "''"
 */
	case '\\':		/* Backslash ? */
	  {
	    if (*pinside_string)	/* Inside string? */
	      {			/* Then skip that next character, whatever it is, also */
		if (*(str + 1))
		  {
		    str++;
		  }		/* another backslash or quote */
	      }
	    break;
	  }
#ifdef OLD_CODE_LEFT_FOR_CLARITYS_SAKE
	case '\'':		/* A single quote? */
	  {
	    if (!*pinside_string)
	      {
		*pinside_string = 1;
	      }
	    else
	      /* We are inside string already. Then if the next */
	      {			/* char is not a quote, then this is a terminating quote */
		if ('\'' != *(str + 1))
		  {
		    *pinside_string = 0;
		  }
		else
		  {
		    str++;
		  }		/* Skip that quote next time. */
	      }
	    break;
	  }
#endif /* Replaced by this: */
	case '\'':
	case '"':		/* A single quote or double quote? */
	  {
	    if (!*pinside_string)	/* Beginning a new string? */
	      {
		*pinside_string = (*str);
	      }			/* Mark the quote type to the flag. */
	    else if (*pinside_string == (*str))	/* Terminating quote? */
	      {			/* (Should be similar to opening quote) */
		/* If we are inside singlequote string then two */
		/* singlequotes in sequence stand for one. */
		if ('\'' == *pinside_string)
		  {
		    if ('\'' != *(str + 1))
		      {
			*pinside_string = 0;
		      }
		    else
		      {
			str++;
		      }		/* Skip that quote next time. */
		  }
		else
		  {
		    *pinside_string = 0;
		  }		/* With doublequotes always terminate. */
	      }
	    break;
	  }
	case ';':		/* A semicolon? */
	  {
	    if (*pinside_string)
	      {
		break;
	      }			/* Ignore semicols in strings */
/* Ignore semicols also inside braces or if scivec is NULL: */
	    if ((bracelevel > 0) || (NULL == scivec))
	      {
		break;
	      }
	    if (semicols_found == maxsemicols)
	      {
		isql_fprintf (error_stream,
			      _T("%") PCT_S _T(": Exiting because there are more than %d semicolons at the line: %") PCT_S _T("\n"),
			      progname, maxsemicols, whole_line);
		fflush (error_stream);
		isql_exit (1);
		scivec[semicols_found++] = 0;	/* Terminating zero. */
	      }
	    else if (semicols_found > maxsemicols)
	      {
		semicols_found++;
	      }
	    else
	      /* semicols_found < maxsemicols */
	      {			/* If it still fits store one-based index to scivec. */
		scivec[semicols_found++] = (int) ((str - whole_line) + 1);
		scivec[semicols_found] = 0;	/* Terminating zero. */
	      }
	    break;
	  }			/* case semicolon */
#ifdef OLD_CODE_COMMENTED_OUT
	case '{':		/* An opening brace? */
	  {
	    if (!*pinside_string)
	      {
		bracelevel++;
	      }
	    break;
	  }
	case '}':		/* A closing brace? */
	  {
	    if (!*pinside_string)
	      {
		--bracelevel;
	      }
	    break;
	  }
#endif /* AS IT IS REPLACED BY THIS: */
	default:
	  {			/* Check if it is an opening brace, bracket, parenthesis? */
	    if ((*str == *chars_watched) && (NOT *pinside_string))
	      {
		bracelevel++;
	      }
	    /* Or corresponding closing one? */
	    else if ((*str == *(chars_watched + 1)) && (NOT *pinside_string))
	      {
		--bracelevel;
		if (return_index_instead_of_level && (0 == bracelevel))
		  {
		    return (int) ((str - whole_line) + 1);
		  }
	      }

	    break;
	  }
	}			/* switch */

    }				/* for loop */

  if (return_index_instead_of_level)
    {
      return (0);
    }				/* Failed, didn't find the closing bracket of same level. */
  else
    {
      return (bracelevel);
    }

}


/* +2 formula works in ASCII for others than parentheses, i.e.
   for [ ], { } and < > */
#define get_closing_char(C) ( ( '(' == (C) ) ? ')' : ((C)+2) )

/* E.g. find_closing_point("$ARGV[$U[$ARGV[$I]]] the rest",'[')
   returns a pointer here ---------------------^
 */
UTCHAR *
find_closing_point (UTCHAR * start_point, UTCHAR opening_char)
{
  UTCHAR char_pair[3];
  int ind;
  UTCHAR inside_string = 0;

  char_pair[0] = opening_char;
  char_pair[1] = ((UTCHAR) get_closing_char (opening_char));
  char_pair[2] = '\0';

  ind = count_bracelevel_or_find_matching_one (UCP (start_point), (0),
					       NULL, 0, char_pair, 1, 0, &inside_string);

  if (0 == ind)
    {
      return (NULL);
    }
  else
    {
      return (start_point + (ind - 1));
    }
}



/* Returns the name of the procedure/function/trigger being declared
   if the line begins a declaration, otherwise returns a NULL.
 */
TCHAR *
is_declaration (TCHAR *line)
{
  int len;
  TCHAR savechar, *ptr, *ptr2, *result;
  ptr = skip_blankos (line);

  if (!strncasecmp (_T("CREATE"), ptr, 6) && *(ptr + 6) && isqlt_istspace (*(ptr + 6)))
    {
      ptr = skip_blankos (ptr + 6);
      if ((!strncasecmp (ptr, _T("PROCEDURE"), (len = 9))
	   ||
	   !strncasecmp (ptr, _T("FUNCTION"), (len = 8))
	   ||
	   !strncasecmp (ptr, _T("MODULE"), (len = 6))
	   ||
	   !strncasecmp (ptr, _T("METHOD"), (len = 6))
	   ||
	   !strncasecmp (ptr, _T("TRIGGER"), (len = 7)))
	  && *(ptr + len) && isqlt_istspace (*(ptr + len)))	/* Followed by space? */
	{
	  ptr = skip_blankos (ptr + len);
	  for (ptr2 = ptr; *ptr2 && !isqlt_istspace (*ptr2) && (*ptr2 != '('); ptr2++);
	  savechar = *ptr2;
	  *ptr2 = '\0';
	  result = chestrdup (ptr, _T("is_declaration"));	/* Make a copy. */
	  *ptr2 = savechar;
	  return (result);
	}
    }
  return (NULL);
}

/* =================================================================== */
/*  SQL - STUFF FOR PRINTING OUT THE COLUMN BANNERS AND CONTENTS, ETC. */
/* =================================================================== */

TCHAR *current_lines_range(void)
{
  long linefrom, lineto;
  static TCHAR lines_range[41];
  linefrom = latest_statement_begins_at ();
  lineto = current_linecount ();
  if (linefrom == lineto)
    isqlt_stprintf (lines_range, _T("at line %ld"), linefrom);
  else
    isqlt_stprintf (lines_range, _T("in lines %ld-%ld"), linefrom, lineto);
  return lines_range;
}

/* Now returns 0 if error is considered so easy that it is safe to
   continue, and 1 if the error is considered severe enough.
 */
int
print_error (HENV e1, HDBC e2, HSTMT e3, RETCODE rc)
/* Was:  (HSTMT e1, HSTMT e2, HSTMT e3) */
{
  int was_deadlock = 0;
  int message_end_is_cr = 0;
  short len;
  int ret = 1;
  TCHAR additional_message[81];


  while (SQL_SUCCESS == SQLError (e1, e2, e3, (UTCHAR *) tmp_SQL_error_state, NULL,
	    (UTCHAR *) tmp_SQL_error_message, sizeof (tmp_SQL_error_message),
	    (SWORD *) & len))
    {
      memcpy (SQL_error_state, tmp_SQL_error_state, sizeof (SQL_error_state));
      memcpy (SQL_error_message, tmp_SQL_error_message, sizeof (SQL_error_message));
      additional_message[0] = '\0';	/* By default, empty. */

      /* The transaction was deadlocked and vol_deadlock_retries is not 0 yet?
	 40001 is the correct status code for deadlock, 4001 is just a fluke
	 which will be done with (until that we just try to cope here).
	 The shortcoming here is that we are not sure that the caller actually
	 wants to retry, so the message (retrying ... times) might be
	 misleading.
       */
#ifndef ODBC_ONLY
      if (0 == isqlt_tcscmp (SQL_error_state, _T("VIRTS")) &&
	  isqlt_tcsstr (SQL_error_message, _T("SR312")))
	{
	  isql_fprintf (error_stream,
	      _T("\nThe server is shutting down\n"));
	  isql_exit (0);
	}
#endif

      if (vol_deadlock_retries &&
	  ((0 == isqlt_tcscmp (SQL_error_state, _T("40001"))) ||
	   (0 == isqlt_tcscmp (SQL_error_state, _T("4001")))))
	{
	  was_deadlock = 2;

	  if (1 == vol_deadlock_retries)	/* Be grammatically correct, gc... */
	    {
	      isqlt_tcscpy (additional_message, _T(" (retrying one more time)"));
	    }
	  else
	    {
	      isqlt_stprintf (additional_message, _T(" (retrying %ld times)"),
		  vol_deadlock_retries);
	    }
	}
      if (('\0' == additional_message[0]) &&
	  ('\n' == SQL_error_message [isqlt_tcslen (SQL_error_message) - 1]) )
	message_end_is_cr = 1;
      isql_fprintf (error_stream,
	  _T("\n%") PCT_S _T(" %") PCT_S _T(": %") PCT_S _T("%") PCT_S _T("%") PCT_S _T("%") PCT_S _T(" of %") PCT_S _T(":\n%") PCT_S _T("\n"),
	  rc == SQL_SUCCESS_WITH_INFO ? _T("Warning") : _T("*** Error"),
	  SQL_error_state, SQL_error_message,
	  additional_message,
	  (message_end_is_cr ? _T("") : _T("\n")),
	  current_lines_range(),
	  current_loadexpr (),
	  command_text_on_error ? input : _T("<not printed>"));

      if (was_deadlock)
	{
	  vol_deadlock_retries--;
	  /* Here we could have later something like:
	     isql_sleep(deadlock_retry_pause);
	   */
	  /* Don't do
	     SQLTransact (henv, hdbc, SQL_ROLLBACK);
	     here, although we could, as Kubl doesn't need it.
	     (Although some other DBMS might need it.) See also notes about
	     SQLTransact and preservation of cursors and prepared statements
	     over Rollback, just before function exec_for_foreach.
	   */
	  return (was_deadlock);
	}

      if (0 == isqlt_tcscmp (SQL_error_state, _T("08S01")))
	{
	  isql_exit (2);
	}


      /* E.g. 01000 General Warning, 01004 Data Truncated,
	 01006 Privilege not revoked, 01S03 No rows updated or deleted,
	 01S04 More than one row updated or deleted.
       */
      if (0 == isqlt_tcsncmp (SQL_error_state, _T("01"), 2))
	{
	  ret = 0;
	  /* this is because warnings will obscure the testsuite $IF $STATE OK tests */
	  SQL_error_state[0] = 'O'; SQL_error_state[1] = 'K'; SQL_error_state[2] = '\0';
	}
      /*
	 2001    Non unique primary key on torttu
	 22003   Numeric value out of range
	 22005   Error in assignment
	 22008   Datetime field overflow
	 22012   Division by zero
	 23000   Integrity constraint violation (e.g. NULL value on NON-NULL)
	 24000   Invalid cursor state (DM)
       */
      if ('2' == SQL_error_state[0])
	{
	  ret = 0;
	}
    }
  return (ret);
}




/* SQL data type codes.
   These were taken from ../sqlcli.h and ../sqlcli2.h header files.
   Added by AK 3-JAN-1997.
 */
TCHAR *
get_sql_type_title (int type)
{
  switch (type)
    {
#ifdef SQL_CHAR
    case SQL_CHAR:
      {
	return (_T("CHAR"));
      }				/*  1 */
#endif
#ifdef SQL_NUMERIC
    case SQL_NUMERIC:
      {
	return (_T("NUMERIC"));
      }				/*  2 */
#endif
#ifdef SQL_DECIMAL
    case SQL_DECIMAL:
      {
	return (_T("DECIMAL"));
      }				/*  3 */
#endif
#ifdef SQL_INTEGER
    case SQL_INTEGER:
      {
	return (_T("INTEGER"));
      }				/*  4 */
#endif
#ifdef SQL_SMALLINT
    case SQL_SMALLINT:
      {
	return (_T("SMALLINT"));
      }				/*  5 */
#endif
#ifdef SQL_FLOAT
    case SQL_FLOAT:
      {
	return (_T("FLOAT"));
      }				/*  6 */
#endif
#ifdef SQL_REAL
    case SQL_REAL:
      {
	return (_T("REAL"));
      }				/*  7 */
#endif
#ifdef SQL_DOUBLE
    case SQL_DOUBLE:
      {
	return (_T("DOUBLE PRECISION"));
      }				/*  8 */
#endif
#ifdef SQL_DATETIME
    case SQL_DATETIME:
      {
	return (_T("DATE"));
      }				/*  9 */
#endif
#if defined  (SQL_DATE) && NOT defined (SQL_DATETIME)
/* Was: #if defined  (SQL_DATE) && defined (ODBC_VER) */
    case SQL_DATE:
      {
	return (_T("DATE"));
      }				/* 9 in sqlext.h */
#endif
#ifdef SQL_TIME
    case SQL_TIME:
      {
	return (_T("TIME"));
      }				/* 10 in sqlext.h */
#endif
#if defined (SQL_INTERVAL) && ((NOT defined (SQL_TIME)) || (SQL_INTERVAL != SQL_TIME))
    case SQL_INTERVAL:
      {
	return (_T("TIME"));
      }				/* 10 */
#endif
#ifdef SQL_TIMESTAMP
    case SQL_TIMESTAMP:
      {
	return (_T("TIMESTAMP"));
      }				/* 11 */
#endif
#ifdef SQL_VARCHAR
    case SQL_VARCHAR:
      {
	return (_T("VARCHAR"));
      }				/* 12 */
#endif
#ifdef SQL_BIT
    case SQL_BIT:
      {
	return (_T("BIT"));
      }				/* 14 */
#endif
#ifdef SQL_BIT_VARYING
    case SQL_BIT_VARYING:
      {
	return (_T("BIT VARYING"));
      }				/* 15 */
#endif
#ifdef SQL_LONGVARCHAR
    case SQL_LONGVARCHAR:
      {
	return (_T("LONG VARCHAR"));
      }				/* (-1) */
#endif
#ifdef SQL_BINARY
    case SQL_BINARY:
      {
	return (_T("BINARY"));
      }				/* (-2) in sqlext.h */
#endif
#ifdef SQL_VARBINARY
    case SQL_VARBINARY:
      {
	return (_T("VARBINARY"));
      }				/* (-3) in sqlext.h */
#endif
#ifdef SQL_LONGVARBINARY
    case SQL_LONGVARBINARY:
      {
	return (_T("LONG VARBINARY"));
      }				/* (-4) */
#endif
#ifdef SQL_BIGINT
    case SQL_BIGINT:
      {
	return (_T("BIGINT"));
      }				/* (-5) in sqlext.h */
#endif
#ifdef SQL_TINYINT
    case SQL_TINYINT:
      {
	return (_T("TINYINT"));
      }				/* (-6) in sqlext.h */
#endif
    case -8:
      {
	return (_T("NCHAR"));
      }				/* (-8) in sqlext.h */
    case -9:
      {
	return (_T("NVARCHAR"));
      }				/* (-9) in sqlext.h */
    case -10:
      {
	return (_T("LONG NVARCHAR"));
      }				/* (-10) in sqlext.h */

    default:
      {
	TCHAR tmp[33];
	isqlt_stprintf (tmp, _T("UNK_TYPE:%d"), type);
	return (chestrdup (tmp, _T("get_sql_type_title")));
      }
    }				/* switch */
}

TCHAR *
get_sql_col_type_def (stmt_out_t * out)
{
/* Check whether we have to add something after a column type: */
  if ((out->o_nullable == SQL_NO_NULLS) || (out->o_type == SQL_CHAR))
    {
      TCHAR result[181];
      isqlt_tcscpy (result, get_sql_type_title (out->o_type));
      if (out->o_type == SQL_CHAR)
	{
	  isqlt_stprintf ((result + isqlt_tcslen (result)), _T("(%d)"), (int) out->o_width);
	}
      if (out->o_nullable == SQL_NO_NULLS)
	{
	  isqlt_tcscat (result, _T(" NOT NULL"));
	}

      return (chestrdup (result, _T("get_sql_col_type_def")));
    }
/* Otherwise, we can use directly the same type string returned by
   get_sql_type_title: */
  else
    {
      return (get_sql_type_title (out->o_type));
    }
}


#define FIELD_WIDTH_SANITY_CHECK 80

void
field_print_normal (TCHAR *str, SQLULEN w, int rightp, int inx)
{
  TCHAR temp[21];
  if ((w > FIELD_WIDTH_SANITY_CHECK) || (w < 1))
    {				/* Added by AK 4-JAN-1997 to catch strange bugs. */
/* Don't clutter our output any more...
   isql_fprintf(error_stream,
   "\n***field_print(\"%s\",%d,%d) called with an outrageous width: %u !\n",
   str,w,rightp,w);
 */
      w = FIELD_WIDTH_SANITY_CHECK;
    }

  if ((n_out_cols - 1) == inx)	/* The rightmost column? */
    {				/* Avoid any unnecessary padding on right side. */
      if (rightp)
	{
	  isql_printf (_T("%*") PCT_S _T(""), (int) w , str);
	}
      else
	{
	  isql_fputs (str, stdout);
	}
    }
  else
    {
      if (rightp)
	{
	  isql_printf (_T("%*") PCT_S _T("  "), (int) w , str);
	}
      else
	{
	  isql_printf (_T("%-*") PCT_S _T("  "), (int) w , str);
	}
    }
}

void
field_print_HTML (TCHAR *str, SQLULEN w, int rightp, int inx)
{
  if (0 == inx)
    {
      isql_fputs (oo_rb, stdout);
    }				/* Leftmost Column, Row begins */
  isql_fputs (oo_db, stdout);	/* Cell Begins. */
  if (oo_esc)
    {
      html_print_escaped (str, stdout);
    }
  else
    {
      isql_fputs (str, stdout);
    }
  isql_fputs (oo_de, stdout);	/* Cell Ends. */
  if ((n_out_cols - 1) == inx)
    {
      isql_fputs (oo_re, stdout);
    }				/* The Row End */
}


void
field_print (TCHAR *str, SQLULEN w, int rightp, int inx)
{
  if (in_HTML_mode ())
    {
      field_print_HTML (str, w, rightp, inx);
    }
  else
    {
      field_print_normal (str, w, rightp, inx);
    }
}


void
print_banner ()
{
  int inx;
  unsigned int len;
  TCHAR *save_oo_db = oo_db;
  TCHAR *save_oo_de = oo_de;

  oo_db = oo_hb;
  oo_de = oo_he;

  if (print_types_also)
    {
      for (inx = 0; inx < n_out_cols; inx++)
	{
	  coltypetitles[inx] = get_sql_col_type_def (&out_cols[inx]);
	  len = (int) isqlt_tcslen (coltypetitles[inx]);
	  if (len > out_cols[inx].o_width)
	    {
	      out_cols[inx].o_width = len;
	    }
	}
    }

  for (inx = 0; inx < n_out_cols; inx++)
    {
      field_print ((out_cols[inx].o_title ? out_cols[inx].o_title : (TCHAR *) _T("NULL")),
		   out_cols[inx].o_width, 0, inx);
    }

  if (print_types_also)
    {
      isql_printf (_T("\n"));
      for (inx = 0; inx < n_out_cols; inx++)
	{
	  field_print (coltypetitles[inx], out_cols[inx].o_width, 0, inx);
	}
    }

  if (NOT in_HTML_mode ())
    {
      isql_fputs (_T("\n_______________________________________________________________________________\n\n"),
		  stdout);
    }
  else
    {
      isql_fputs (_T("\n"), stdout);
    }
  fflush (stdout);

  oo_db = save_oo_db;
  oo_de = save_oo_de;

}

#define BLOB_BUFFER_SIZE 4001

/* Returns return code from the last SQLGetData done. */
int
print_blob_col (HSTMT stmt, UWORD n_col, SQLULEN width, SWORD sql_type)
{
  static TCHAR blob_buffer[BLOB_BUFFER_SIZE + 1];
  int got_n_bytes;
  SQLULEN total = 0;
  int rc;

  if (in_HTML_mode ())
    {
      if (1 == n_col)
	{
	  isql_fputs (oo_rb, stdout);
	}			/* Leftmost Column, Row begins */
      isql_fputs (oo_db, stdout);	/* Cell Begins. */
      isql_fputs (_T("<PRE>"), stdout);
    }

  for (;;)
    {
      SQLLEN n_recv;
      rc = SQLGetData (stmt, n_col,
		       SQL_C_TCHAR,
		       blob_buffer, BLOB_BUFFER_SIZE, &n_recv);
/* Here we got either SQL_NO_DATA or an error. */
      if (((rc != SQL_SUCCESS) && (rc != SQL_SUCCESS_WITH_INFO))
	  || (n_recv == SQL_NULL_DATA))
	{			/* This ^ means really a blob of length 0, not real NULL ??? */
/* Tell calling function that everything is still all right, no panic: */
	  if (SQL_NO_DATA_FOUND == rc)
	    {
	      rc = SQL_SUCCESS;
	    }
	  if (NOT in_HTML_mode ())
	    {
	      field_print (_T(""), width, 0, (n_col - 1));
	    }
	  else
	    {
	      goto print_end_tags;
	    }			/* Oh yes, it's uglier than ever. */
	  return (rc);
	}

/* If we get SQL_NO_TOTAL, then we have to use isqlt_tcslen. This doesn't
   work with true binary data with null bytes in the last part. */
      got_n_bytes = (int)
	((rc == SQL_SUCCESS) ? ((n_recv != SQL_NO_TOTAL) ? n_recv
				: isqlt_tcslen (blob_buffer))
	 : BLOB_BUFFER_SIZE - 1);	/* Not the last part. */
      total += got_n_bytes;

      if (in_HTML_mode () && oo_esc)
	{
	  if (got_n_bytes)
	    {
	      html_print_escaped_n (blob_buffer, stdout, got_n_bytes);
	    }
	}
      else
	{
	  isqlt_fputts (blob_buffer, stdout);
	}

      if (rc == SQL_SUCCESS)	/* No more data after this one. */
	{
	  if (in_HTML_mode ())
	    {
	    print_end_tags:
	      isql_fputs (_T("</PRE>"), stdout);
	      isql_fputs (oo_de, stdout);	/* Cell Ends. */
	      if (n_out_cols == n_col)
		{
		  isql_fputs (oo_re, stdout);
		}		/* The Row End */
	    }
	  else
	    {
	      if (width > total)
		{
		  field_print (_T(""), (width - total), 0, (n_col - 1));
		}
	      else if (n_col < n_out_cols)
		{
		  isql_putchar (' ');
		}
	    }
	  return (rc);
	}
    }

  /* return(rc); *//* Never reached */

}


void
print_datetime_col (TCHAR *timebinstr, SQLULEN width, int rightp,
		    SQLLEN collen, int type, int inx)
{
  TCHAR temp[121];

  if (times_conform_to_odbc_flag)
    {
      if (type == SQL_DATE)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  DATE_STRUCT *ts = ((DATE_STRUCT *) timebinstr);
	  isqlt_stprintf (temp, _T("%d.%d.%d"), ts->year, ts->month, ts->day);
	}
      else if (type == SQL_TIMESTAMP)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  TIMESTAMP_STRUCT *ts = ((TIMESTAMP_STRUCT *) timebinstr);
	  isqlt_stprintf (temp, _T("%d.%d.%d %d:%d.%d %ld"),
		   ts->year, ts->month, ts->day,
		   ts->hour, ts->minute, ts->second,
		   (long) ts->fraction);
	}
      else if (type == SQL_TIME)
	{
	  /* Defined in /odbcsdk/include/sqlext.h */
	  TIME_STRUCT *ts = ((TIME_STRUCT *) timebinstr);

	  isqlt_stprintf (temp, _T("%d:%d.%d"), ts->hour, ts->minute, ts->second);
	}
      else
	/* Shouldn't happen! */
	{
	  isqlt_stprintf (temp,
		   _T("SHOULD NOT HAPPEN: print_date_col called(width=%lu,collen=%ld,type=%d)"),
		   (unsigned long) width, (long) collen, type);
	}
    }
  else
    /* Native KUBL mode. */
    {
      struct tm *tm;
      struct timeval tv;
      time_t tth;

      memcpy (&tv, timebinstr, sizeof (struct timeval));
      TV_TO_STRING (&tv);

      tth = (time_t) tv.tv_sec;
      tm = localtime (&tth);
      if (tm)
	{
	  isqlt_stprintf (temp, _T("%d.%d.%d %d:%d.%d %ld"),
		   tm->tm_year + 1900, tm->tm_mon + 1,
		   tm->tm_mday, tm->tm_hour, tm->tm_min, tm->tm_sec,
		   (long) tv.tv_usec);
	}
      else
	/* localtime returned NULL pointer. */
	{
	  isqlt_stprintf (temp, _T("INV-TIME(%ld):%08lx:%08lx"),
		   collen, (long) tv.tv_sec, (long) tv.tv_usec);
	}
    }

  field_print (temp, width, rightp, inx);
}


/* Returns either SQL_SUCCESS or the last return code returned by
   print_blob_col (which calls SQLGetData in the loop.) */
int
print_row ()
{
  TCHAR temp[30];
  int inx, i;
  int rc = SQL_SUCCESS;

  for (inx = 0; inx < n_out_cols; inx++)
    {
      int rightp = 0;
      int tp = out_cols[inx].o_type;
      if (tp == SQL_NUMERIC || tp == SQL_FLOAT || tp == SQL_DOUBLE
	  || tp == SQL_REAL)
	rightp = 1;
      if (out_cols[inx].o_col_len == SQL_NULL_DATA)
	field_print (_T("NULL"), out_cols[inx].o_width, rightp, inx);
      else if ((out_cols[inx].o_type == SQL_TIMESTAMP) ||
	       (out_cols[inx].o_type == SQL_DATE) ||
	       (out_cols[inx].o_type == SQL_TIME))
	{
	  print_datetime_col ((TCHAR *) out_cols[inx].o_buffer, out_cols[inx].o_width, 0,
			out_cols[inx].o_col_len, out_cols[inx].o_type, inx);
	}
      else if (out_cols[inx].o_type == SQL_LONGVARCHAR ||
	       out_cols[inx].o_type == SQL_LONGVARBINARY ||
	       out_cols[inx].o_type == SQL_WLONGVARCHAR)
	{
	  if (print_blobs_flag)
	    {
	      /* Note zero-based indexing here. print_blob_col needs one+ */
	      if ((rc = print_blob_col (stmt, ((UWORD) (inx + 1)),
					out_cols[inx].o_width, out_cols[inx].o_type))
		  != SQL_SUCCESS)
		{
		  return (rc);
		}
	    }
	  else
	    {
	      if (out_cols[inx].o_col_len == SQL_NO_TOTAL)
		{
		  field_print (_T("BLOB SQL_NO_TOTAL"), (out_cols[inx].o_width), 0, inx);
		}
	      else if (out_cols[inx].o_col_len > 0 && out_cols[inx].o_col_len < 1024 &&
		  (out_cols[inx].o_type == SQL_LONGVARCHAR || out_cols[inx].o_type == SQL_WLONGVARCHAR))
		{
		  field_print ((TCHAR *) out_cols[inx].o_buffer, out_cols[inx].o_width,
		      rightp, inx);
		}
	      else
		{
		  if (out_cols[inx].o_type == SQL_WLONGVARCHAR)
		    isqlt_stprintf (temp, _T("NLOB %ld chars"), (long) (out_cols[inx].o_col_len / sizeof (TCHAR)));
		  else
		    isqlt_stprintf (temp, _T("BLOB %ld chars"), (long) (out_cols[inx].o_col_len / sizeof (TCHAR)));
		  field_print (temp, (out_cols[inx].o_width), 0, inx);
		}
	    }
	}
      else
	field_print ((TCHAR *) out_cols[inx].o_buffer, out_cols[inx].o_width, rightp, inx);
    }

  for (i = flag_newlines_at_eor; i; i--)
    {
      isql_printf (_T("\n"));
    }

  return (rc);
}

/* If this is set to non-zero value, it will override the width values
   got with SQLDescribeCol. */
SQLULEN max_col_width = 0;

/* The following values MUST BE different from SQL_INVALID_HANDLE,
   SQL_ERROR, SQL_SUCCESS, SQL_SUCCESS_WITH_INFO, SQL_NO_DATA_FOUND,
   SQL_STILL_EXECUTING, SQL_NEED_DATA (All between -2 and 100)
 */
#define DO_SQL_API_COMMAND_IS_NOT_COMMAND   12345
#define DO_SQL_API_COMMAND_IS_NOT_AVAILABLE 12346

/* Pointer to SQL_API function returning RETCODE */
/* Was like this, but certain jerked header files don't recognize RETCODE
   typedef RETCODE (*SQL_API_FUNPTR)();
 */
/* So let's use this one: */
typedef signed short (*SQL_API_FUNPTR) (HSTMT, UTCHAR *, SWORD, UTCHAR *, SWORD,
					UTCHAR *, SWORD, UTCHAR *, SWORD);


struct sql_api_cmd
  {
    TCHAR *name;
    UWORD sql_api_num;
    SQL_API_FUNPTR fun;
    int str_args;		/* Number of string arguments. */
  };

struct sql_api_cmd some_sql_api_commands[] =
{
  {_T("Columns"), SQL_API_SQLCOLUMNS,
   ((SQL_API_FUNPTR) SQLColumns), 4},
  {_T("ColumnPrivileges"), SQL_API_SQLCOLUMNPRIVILEGES,
   ((SQL_API_FUNPTR) SQLColumnPrivileges), 4},
  {_T("PrimaryKeys"), SQL_API_SQLPRIMARYKEYS,
   ((SQL_API_FUNPTR) SQLPrimaryKeys), 3},
  {_T("ForeignKeys"), SQL_API_SQLFOREIGNKEYS,
   ((SQL_API_FUNPTR) SQLForeignKeys), 6},
  {_T("Procedures"), SQL_API_SQLPROCEDURES,
   ((SQL_API_FUNPTR) SQLProcedures), 3},
  {_T("ProcedureColumns"), SQL_API_SQLPROCEDURECOLUMNS,
   ((SQL_API_FUNPTR) SQLProcedureColumns), 4},
  {_T("TablePrivileges"), SQL_API_SQLTABLEPRIVILEGES,
   ((SQL_API_FUNPTR) SQLTablePrivileges), 3},
  {_T("Tables"), SQL_API_SQLTABLES,
   ((SQL_API_FUNPTR) SQLTables), 4},
  {NULL}			/* The end */
};
/*

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
 */

UTCHAR *
divide_tablename (UTCHAR * tablename,
		  UTCHAR ** p_tablequalifier, UTCHAR ** p_tableowner)
{
  UTCHAR *ptr, *ptr2;

/* Has any effect only if tablequalifier and tableowner are not given
   elsewhere, i.e. they are still NULL. */
  if (tablename && NO * p_tablequalifier && NO * p_tableowner &&
      (ptr = (UTCHAR *) isqlt_tcschr (SCP (tablename), '.')))
    {
      if (ptr > (tablename))	/* Period not in the beginning of tablename? */
	{
	  *p_tablequalifier = tablename;
	  *ptr = '\0';
	}
      if (NULL != (ptr2 = (UTCHAR *) isqlt_tcschr ((TCHAR *) (ptr + 1), '.')))
	{
	  if (ptr2 > (ptr + 1))	/* Second period not right after first one? */
	    {
	      *p_tableowner = ptr + 1;
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
      else
	/* If only one period found. */
	{
	  *p_tableowner = *p_tablequalifier;
	  *p_tablequalifier = NULL;
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

  return (tablename);
}



int
do_string_argument_sql_api_command (TCHAR *text,
				    TCHAR *command,
				    TCHAR *tablequalifier,
				    TCHAR *tableowner,
				    TCHAR *tablename,
				    TCHAR *usr2arg)
{
  UWORD ThisFunctionExists = TRUE;	/* If SQLGetFunctions does nothing. */
  int rc;
  struct sql_api_cmd *sacptr = some_sql_api_commands;

  while (sacptr->name)
    {
      if (0 == strcasecmp (command, sacptr->name))
	{
#if !(defined(WIN32) && defined(UDBC))
	  SQLGetFunctions (hdbc, sacptr->sql_api_num, &ThisFunctionExists);
#endif
	  if (ThisFunctionExists == FALSE)
	    {
	      isql_fprintf (error_stream,
			 _T("*** This ODBC driver doesn't implement SQL%") PCT_S _T(" !\n"),
			    sacptr->name);
	      return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	    }

	  isql_printf (
			_T("Showing SQL%") PCT_S _T(" of tables like '%") PCT_S _T(".%") PCT_S _T(".%") PCT_S _T("', tabletype/colname like '%") PCT_S _T("'\n"),
			sacptr->name,
			(tablequalifier ? tablequalifier : _T("NULL")),
			(tableowner ? tableowner : _T("NULL")),
			(tablename ? tablename : _T("NULL")),
			(usr2arg ? usr2arg : _T("NULL")));

	  max_col_width = MAX_COL_WIDTH;

	  /* All qualifiers, all owners. */
	  switch (sacptr->sql_api_num)
	    {
	       case SQL_API_SQLTABLES:
		     {
		       rc = SQLTables (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS, UCP (usr2arg), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLCOLUMNS:
		     {
		       rc = SQLColumns (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS, UCP (usr2arg), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLCOLUMNPRIVILEGES:
		     {
		       rc = SQLColumnPrivileges (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS, UCP (usr2arg), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLPRIMARYKEYS:
		     {
		       rc = SQLPrimaryKeys (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLPROCEDURES:
		     {
		       rc = SQLProcedures (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLFOREIGNKEYS:
		     {
		       TCHAR *fk_table_qualifier = NULL, *fk_table_owner = NULL, *fk_table_name = NULL;

		       if (usr2arg)
			 fk_table_name = (TCHAR *) divide_tablename (((UTCHAR *) usr2arg),
			     ((UTCHAR **) & fk_table_qualifier),
			     ((UTCHAR **) & fk_table_owner));
		       rc = SQLForeignKeys (stmt,
			   UCP (tablequalifier), SQL_NTS, UCP (tableowner), SQL_NTS, UCP (tablename), SQL_NTS,
			   UCP (fk_table_qualifier), SQL_NTS, UCP (fk_table_owner), SQL_NTS, UCP (fk_table_name), SQL_NTS
			   );
		       break;
		     }
	       case SQL_API_SQLPROCEDURECOLUMNS:
		     {
		       rc = SQLProcedureColumns (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS, UCP (usr2arg), SQL_NTS);
		       break;
		     }
	       case SQL_API_SQLTABLEPRIVILEGES:
		     {
		       rc = SQLTablePrivileges (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner),
			    SQL_NTS, UCP (tablename), SQL_NTS);
		       break;
		     }
	       default:
		  rc = (sacptr->fun) (stmt, UCP (tablequalifier), SQL_NTS, UCP (tableowner), SQL_NTS,
		                     UCP (tablename), SQL_NTS, UCP (usr2arg), SQL_NTS);
	    }

	  return (rc);
	}			/* if found the name. */
      sacptr++;			/* Otherwise check the next. */
    }				/* while(sacptr->name); */

  return (DO_SQL_API_COMMAND_IS_NOT_COMMAND);	/* Was not found from these. */
}


#define GETTYPEINFO_COMMAND _T("GetTypeInfo")
#define STATS_COMMAND       _T("Statistics")
#define SPECCOL_COMMAND     _T("SpecialColumns")
#define QUALIFIERS_COMMAND	_T("TableQualifiers")
#define OWNERS_COMMAND		_T("TableOwners")
#define TYPES_COMMAND		_T("TableTypes")


int
do_sql_api_command (TCHAR *text)
{
  TCHAR *command;
  TCHAR *tablename;
  TCHAR *tablequalifier = NULL;
  TCHAR *tableowner = NULL;
  TCHAR *opt = NULL;
  TCHAR *ptr = text;
  TCHAR saveslash = 0, *savepoint = NULL;
  TCHAR tmp1buf[TMPBUF_SIZE + 2], tmp2buf[TMPBUF_SIZE + 2];
  TCHAR tmp3buf[TMPBUF_SIZE + 2];
  int rc;

  if (NULL != (opt = isqlt_tcsrchr (text, '/')))	/* Option or 2nd arg? Check the last slash */
    {
      saveslash = *opt;
      savepoint = opt;
      *opt++ = '\0';		/* Cut it from the slash and skip to next. */
/* Was: opt = skip_blankos(opt); */
/* Now use get_next_token instead so that $-macros will work also
   with options of SQL-API functions. But note that now we have to use
   TABLES/'SYSTEM TABLE' instead of just TABLES/SYSTEM TABLE
   if we are connected to non-Kubl database. (Kubl's driver allows
   just a SYSTEM as a tabletype).
   I hope the return value setting is really done after the screwing
   of opt pointer inside the function itself: */
      opt = get_next_token (&opt, tmp3buf, TMPBUF_SIZE, NULL, 0);
    }
  command = get_next_token (&ptr, tmp1buf, TMPBUF_SIZE, NULL, 0);

  if (NO command)
    {
      if (savepoint)
	{
	  *savepoint = saveslash;
	}
      return (DO_SQL_API_COMMAND_IS_NOT_COMMAND);
    }

  tablename = get_next_token (&ptr, tmp2buf, TMPBUF_SIZE, NULL, 0);
  tablename = SCP (divide_tablename (((UTCHAR *) tablename),
				     ((UTCHAR **) & tablequalifier),
				     ((UTCHAR **) & tableowner)));


  rc = do_string_argument_sql_api_command (text, command,
					   tablequalifier, tableowner,
					   tablename, opt);
  if (DO_SQL_API_COMMAND_IS_NOT_COMMAND != rc)
    {
      if (savepoint)
	{
	  *savepoint = saveslash;
	}
      return (rc);
    }

/* Else, check some special cases with strange arguments, if the text was
   not found from the standard list. */
  else if (!strcasecmp (command, GETTYPEINFO_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLGETTYPEINFO, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  isql_fprintf (error_stream,
	       _T("*** This ODBC driver doesn't implement SQLGetTypeInfo !\n"));
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}

      rc = SQLGetTypeInfo (stmt, SQL_ALL_TYPES);
      max_col_width = MAX_COL_WIDTH;
    }

  else if (!strcasecmp (command, STATS_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLSTATISTICS, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  isql_fprintf (error_stream,
		_T("*** This ODBC driver doesn't implement SQLStatistics !\n"));
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}


      isql_printf (_T("Showing SQLStatistics of table(s) '%") PCT_S _T(".%") PCT_S _T(".%") PCT_S _T("'\n"),
		   (tablequalifier ? tablequalifier : _T("NULL")),
		   (tableowner ? tableowner : _T("NULL")),
		   (tablename ? tablename : _T("NULL")));

      rc = SQLStatistics (stmt,
			  UCP (tablequalifier), ((SWORD) SQL_NTS),
			  UCP (tableowner), ((SWORD) SQL_NTS),
			  UCP (tablename), ((SWORD) SQL_NTS),
			  (UWORD) ((opt && isascii (*(opt)) &&
				    (toupper (*(opt)) == 'U'))
				   ? ((UWORD) SQL_INDEX_UNIQUE)
				   : ((UWORD) SQL_INDEX_ALL)),
			  ((UWORD) SQL_ENSURE));
      max_col_width = MAX_COL_WIDTH;
    }

  else if (!strcasecmp (command, SPECCOL_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLSPECIALCOLUMNS, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  isql_fprintf (error_stream,
	    _T("*** This ODBC driver doesn't implement SQLSpecialColumns !\n"));
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}


      isql_printf (_T("Showing SQLSpecialColumns of table(s) '%") PCT_S _T(".%") PCT_S _T(".%") PCT_S _T("'\n"),
		   (tablequalifier ? tablequalifier : _T("NULL")),
		   (tableowner ? tableowner : _T("NULL")),
		   (tablename ? tablename : _T("NULL")));

      rc = SQLSpecialColumns (stmt,
			      ((UWORD) ((opt &&
				   (isqlt_tcschr (opt, 'B') || isqlt_tcschr (opt, 'b')))
					? ((UWORD) SQL_BEST_ROWID)
					: ((UWORD) SQL_ROWVER))),
			      UCP (tablequalifier), ((SWORD) SQL_NTS),
			      UCP (tableowner), ((SWORD) SQL_NTS),
			      UCP (tablename), ((SWORD) SQL_NTS),
			      ((UWORD)
			  ((opt && (isqlt_tcschr (opt, 'S') || isqlt_tcschr (opt, 's')))
			   ? ((UWORD) SQL_SCOPE_SESSION)
			: ((opt && (isqlt_tcschr (opt, 'T') || isqlt_tcschr (opt, 't')))
			   ? ((UWORD) SQL_SCOPE_TRANSACTION)
			   : ((UWORD) SQL_SCOPE_CURROW)))),
			      ((UWORD) ((opt &&
				   (isqlt_tcschr (opt, 'N') || isqlt_tcschr (opt, 'n')))
					? ((UWORD) SQL_NO_NULLS)
					: ((UWORD) SQL_NULLABLE))));
      max_col_width = MAX_COL_WIDTH;
    }

  else if (!strcasecmp (command, QUALIFIERS_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLTABLES, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  isql_fprintf (error_stream, _T ("*** This ODBC driver doesn't implement SQLTABLES !\n"));
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}

      isql_printf (_T ("Showing SQLTables(QUALIFIERS)\n"));
      rc = SQLTables (stmt, UCP ("%"), SQL_NTS, NULL, 0, NULL, 0, NULL, 0);
      max_col_width = MAX_COL_WIDTH;
    }

  else if (!strcasecmp (command, OWNERS_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLTABLES, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  isql_fprintf (error_stream, _T ("*** This ODBC driver doesn't implement SQLTABLES !\n"));
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}

      isql_printf (_T ("Showing SQLTables(OWNERS)\n"));
      rc = SQLTables (stmt, NULL, 0, UCP ("%"), SQL_NTS, NULL, 0, NULL, 0);
      max_col_width = MAX_COL_WIDTH;
    }

  else if (!strcasecmp (command, TYPES_COMMAND))
    {
      UWORD ThisFunctionExists = TRUE;

#if !(defined(WIN32) && defined(UDBC))
      SQLGetFunctions (hdbc, SQL_API_SQLTABLES, &ThisFunctionExists);
#endif
      if (ThisFunctionExists == FALSE)
	{
	  if (savepoint)
	    {
	      *savepoint = saveslash;
	    }
	  isql_fprintf (error_stream, _T ("*** This ODBC driver doesn't implement SQLTABLES !\n"));
	  return (DO_SQL_API_COMMAND_IS_NOT_AVAILABLE);
	}

      isql_printf (_T ("Showing SQLTables(TABLETYPES)\n"));
      rc = SQLTables (stmt, NULL, 0, NULL, 0, NULL, 0, UCP ("%"), SQL_NTS);
      max_col_width = MAX_COL_WIDTH;
    }

  else
    {
      if (savepoint)
	{
	  *savepoint = saveslash;
	}
      return (DO_SQL_API_COMMAND_IS_NOT_COMMAND);
    }

  /* Otherwise inserting string literals with slashes wouldn't work: */
  if (savepoint)
    {
      *savepoint = saveslash;
    }
  return (rc);
}


#ifdef OLD_AND_OBSOLETE_KEPT_HERE_JUST_FOR_REFERENCE
/* Now merged with show_results, a function nipped from old exec_one */

void
isql_procedure_results (int rc, long start)
{
  int nth_set = 1;
  UWORD inx;
  SWORD btype;
  start = start;		/* To avoid warning messages. */
  for (;;)
    {
      int n_rows = 0;
      if (rc == SQL_NO_DATA_FOUND)
	{
	  isql_printf (_T("Set %") PCT_S _T(" No rows.\n"), nth_set);
	}
      else
	{
	  SQLNumResultCols (stmt, &n_out_cols);

	  for (inx = 1; inx <= n_out_cols; inx++)
	    {
	      stmt_out_t *out = &out_cols[inx - 1];
	      SQLDescribeCol (stmt, inx, out->o_title, MAXCOLNAME, NULL,
			      &out->o_type, &out->o_width,
			      NULL, NULL);

	      out->o_width = 12;	/* ???? */
/* Was:
   if (out -> o_buffer) free (out -> o_buffer);
   out -> o_buffer = malloc (out -> o_width + 1);
 */
	      if (!out->o_buffer)
		{
		  out->o_buffer = chemalloc (MAXBUFFER + 2, _T("obsolete function"));
		}


	      switch (out->o_type)
		{
		case SQL_TIMESTAMP: case SQL_DATE:
		  btype = SQL_C_TIMESTAMP;
		  break;
		case SQL_WCHAR: case SQL_WVARCHAR: case SQL_WLONGVARCHAR:
		  btype = SQL_C_TCHAR;
		  break;
	        default:
		  btype = SQL_C_TCHAR;
		}

	      SQLBindCol (stmt, inx, btype, out->o_buffer,
			  MAXBUFFER, &out->o_col_len);

	    }

	  if (!print_banner_flag)
	    {
	      print_banner ();
	    }
	  for (;;)
	    {
	      rc = SQLFetch (stmt);
	      if (rc == SQL_NO_DATA_FOUND)
		break;
	      IF_ERR_GO (stmt, error, rc);
	      n_rows++;
	      rc = print_row ();
	      IF_ERR_GO (stmt, error, rc);
	    }
	  isql_printf (_T("\nSet %d, %d Rows,.\n"), nth_set, n_rows);
	}

      rc = SQLMoreResults (stmt);
      if (rc == SQL_NO_DATA_FOUND)
	break;
      nth_set++;
    }
  isql_printf (_T("%d sets, %ld msec.\n"), nth_set, get_msec_count () - start);

  if (commit_mode != 2)
    {
      RETCODE rc;
      SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, commit_mode);
      if (SQL_SUCCESS != SQLTransact (henv, hdbc, SQL_COMMIT))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0));
	}
    }
  return;
error:
  SQLTransact (henv, hdbc, SQL_ROLLBACK);
}

#endif

static void * debug_session = NULL;

int is_cmd (TCHAR *text, TCHAR *cmd);

#ifdef ODBC_ONLY
#undef PLDBG
#endif

#ifdef PLDBG
void * pldbg_help (FILE * f);
TCHAR * pldbg_read_resp (void * ses1);
int pldbg_command (void * ses1, TCHAR * cmd1);
void * pldbg_connect (TCHAR * addr, TCHAR * usr, TCHAR * pwd1);
TCHAR pld_last_cmd[TMPBUF_SIZE + 2] = _T("");

int
debug_command (TCHAR *text)
{
  caddr_t resp;
  TCHAR *args, *cmd;
  TCHAR tmp0buf[TMPBUF_SIZE + 2];

  text = skip_blankos (text);
  args = text;

  cmd = get_next_token (&args, tmp0buf, TMPBUF_SIZE, NULL, 0);
  if (NULL == cmd)
    {
      if (pld_last_cmd[0] != 0)
	{
	  args = pld_last_cmd;
	  text = pld_last_cmd;
	  cmd = get_next_token (&args, tmp0buf, TMPBUF_SIZE, NULL, 0);
	}
      else
	return (1);
    }				/* Empty commands are NO-OPs */
  else
    isqlt_tcsncpy (pld_last_cmd, text, sizeof (pld_last_cmd));

  if (is_cmd (cmd, _T("QUIT")) || is_cmd (cmd, _T("EXIT")))
      isql_exit (0);
  else if (is_cmd (cmd, _T("HELP")))
    {
      pldbg_help (stdout);
      return (1);
    }

  if (!debug_session)
    {
      isql_fprintf (error_stream, _T("Can't estabilish debug session to the '%") PCT_S _T("'\n"), datasource);
      isql_exit (1);
    }

  if (!pldbg_command (debug_session, text))
    {
      isql_fprintf (error_stream, _T("Debug session to the '%") PCT_S _T("' is broken\n"), datasource);
      isql_exit (1);
    }
  resp = pldbg_read_resp (debug_session);
  if (resp)
    isql_printf (_T("%") PCT_S _T("\n"), resp);
  else
    {
      isql_fprintf (error_stream, _T("Debug session to the '%") PCT_S _T("' is broken\n"), datasource);
      isql_exit (1);
    }
  dk_free_tree (resp);
  return 1;
}
#endif

int show_results (long start, int rc, int nth_set,
		  int loc_print_banner_flag, int loc_verbose_mode);

int is_isql_command (TCHAR *text, integer_list * pidlist);
int connect_to_datasource (TCHAR *datasource, TCHAR *username, TCHAR *password);

void
exec_one (TCHAR *text, integer_list * pidlist)
{
  long start;
  int rc;
  int is_call_statement = 0;
  TCHAR *main_text;

  /* Currently this is only for making sure that there is enough space
     in statement text buffer for function
     parse_statement_for_special_parameters
     to do its destructive modifications (in case there are $dollar_forms
     to be substituted that produce a longer string than the dollar form
     itself). parse_statement_for_special_parameters is called by
     exec_for_foreach, called by isql_foreach, called by is_isql_command.
     Now it is called from here as well, immediately after we know
     that it's neither isql-command nor API-command, but a real
     SQL-command which is sent to the server. Of course we should do
     $-substitutions more consistently for all commands, but at the
     same time avoiding doing them twice.
     Added 3-MAY-1997. Yes, this is getting too ugly and kludgous again,
     to be redesigned and cleaned later.
   */
  if (not_pointing_to_input_buf (text))
    {
      isqlt_tcsncpy (input, text, INPUT_SIZE);
      text = input;
    }

  /* Set volatile deadlock retries to permanent deadlock retries
     which has been set with SET DEADLOCK_RETRIES command. */
  vol_deadlock_retries = perm_deadlock_retries;

#ifdef PLDBG
  if (virtuoso_debug)
    {
      debug_command (text);
      return;
    }
#endif

  main_text = text;
  while ('\0' != main_text[0])
    {
      if ('#' == main_text[0])
	{
	  while (('\0' != main_text[0]) &&
	    ('\r' != main_text[0]) &&
	    ('\n' != main_text[0]) )
	    main_text++;
	  continue;
	}
      while ((' ' == main_text[0]) || ('\t' == main_text[0]))
	main_text++;
      if (('\r' == main_text[0]) || ('\n' == main_text[0]))
	{
	  main_text++;
	  continue;
	}
      if (('-' == main_text[0]) && ('-' == main_text[1]))
	{
	  while (('\0' != main_text[0]) &&
	    ('\r' != main_text[0]) &&
	    ('\n' != main_text[0]) )
	    main_text++;
	  continue;
	}
      break;
    }

  if (is_isql_command (main_text, pidlist))
    {
      return;
    }

/* We should collect all these 'things to be cleared' before the execution
   of next real SQL-statement to one procedure. Also, retval and retvallen
 */
  text = skip_blankos (text);
again_exec:;
  clear_SQL_state_and_message ();
  N_rows = 0;
  n_out_cols_long = 0;

  start = get_msec_count ();


  if ((rc = do_sql_api_command (main_text)) == DO_SQL_API_COMMAND_IS_NOT_COMMAND)
    {

/*
   give pardescvec as NULL and maxpars as zero, so this is just for
   doing the $-substitutions. Also, the function will whine if there
   are any ?-parameter-markers present. (But it still returns and retains
   them there.)
 */
      parse_statement_for_special_parameters (UCP (text), NULL, 0);
      is_call_statement = !strncasecmp (main_text, _T("CALL"), 4);

      /* This thing doesn't work with Windows NT ODBC, because the damn
         MS ODBC Driver Manager whines both about ipar index 0 as well as about
         parameter SQL_RETURN_VALUE, as can be seen from the following:

         *** Error S1093: [Microsoft][ODBC Driver Manager] Invalid parameter number
         *** Error S1105: [Microsoft][ODBC Driver Manager] Invalid parameter type
         So when compiled for ODBC the flag_bind_return_values is by
         default off.
       */
      if (is_call_statement && flag_bind_return_values)
	{
	  rc = SQLBindParameter (	/* Bind the return value parameter. */
				  stmt,
				  ((UWORD) 0),	/* ipar, ignored, but DM wants > 0 */
				  ((SWORD) SQL_RETURN_VALUE),
				  ((SWORD) SQL_C_TCHAR),
				  ((SWORD) SQL_CHAR),
				  0,	/* The precision of the column. SQLULEN */
				  0,	/* The scale of the column. SWORD */
				  ((PTR) retvalbuf),
				  ((SQLLEN) RETVALBUFSIZE),	/* SQLLEN cbValueMax */
				  ((SQLLEN *) & cbRetVal)
	    );

	  IF_ERR_GO (stmt, error, rc);
          rc = SQLExecDirect (stmt, UCP (text), SQL_NTS);
	}
      else if (explain_mode)
        {
	  rc = SQLPrepare (stmt, _T("EXPLAIN(?)"), SQL_NTS);
	  IF_ERR_GO (stmt, error, rc);
	  rc = SQLBindParameter (stmt, 1, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_CHAR, isqlt_tcslen(text), 0, UCP(text), isqlt_tcslen(text), NULL);
	  IF_ERR_GO (stmt, error, rc);
	  rc = SQLExecute (stmt);
	}
      else if (sparql_translate_mode)
        {
          const TCHAR* q = text;
          if (!strncasecmp (text, _T("SPARQL"), isqlt_tcslen(_T("SPARQL"))))
            q = text + isqlt_tcslen(_T("SPARQL"));

          rc = SQLPrepare (stmt, _T("SELECT SPARQL_TO_SQL_TEXT(?)"), SQL_NTS);
          IF_ERR_GO (stmt, error, rc);
          rc = SQLBindParameter (stmt, 1, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_CHAR, isqlt_tcslen(q), 0, UCP(q), isqlt_tcslen(q), NULL);
          IF_ERR_GO (stmt, error, rc);
          rc = SQLExecute (stmt);
        }
      else
        {
	  rc = SQLExecDirect (stmt, UCP (text), SQL_NTS);
	}
    }
  else if (rc == DO_SQL_API_COMMAND_IS_NOT_AVAILABLE)
    {				/* Should we free something? */
      return;
    }

/* This should be here, almost right after SQLExecDirect, before any
   error checking, because it is for example possible to issue an
   update command that updates some of the rows and then fails because
   of let's say uniqueness violation, so we should check it with
   SQLRowCount now.
   But probably the whole transaction will bail out if there is an
   uniqueness violation, so it will be zero anyway in those cases.
   As is the case. And the totalitarian Microsoft driver manager
   won't allow SQLRowCount here in cases where SQLExecDirect produced
   an error. So commented out from here, transferred back to show_results
   *** Error S1010: [Microsoft][ODBC Driver Manager] Function sequence error
   SQLRowCount (stmt, ((SQLLEN *)&N_rows));
 */

  IF_ERR_OR_DEADLOCK_GO (stmt, error, deadlock_exec, rc);
  rc = show_results (start, rc, is_call_statement,
		     print_banner_flag, verbose_mode);
  IF_ERR_OR_DEADLOCK_GO (stmt, error, deadlock_exec, rc);

/* It's important to call the following SQLFreeStmt's in all cases,
   otherwise we start getting very mysterious error messages like:
   *** Error S1010: Statement active at line X
   after we have done select even once, and then try to do something
   with foreach, for example.
 */

error:;
  SQLFreeStmt (stmt, SQL_UNBIND);
  SQLFreeStmt (stmt, SQL_CLOSE);

/* There was thing like this in the end of old isql_procedure_results
   (only statement after the error: label. What shall we do?)
   SQLTransact (henv, hdbc, SQL_ROLLBACK);
 */

  if (commit_mode != 2)
    {
      SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, commit_mode);
      if (SQL_SUCCESS != (rc = SQLTransact (henv, hdbc, SQL_COMMIT)))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	}
    }
  return;

deadlock_exec:;
  if (commit_mode == 0)
    {
      SQLFreeStmt (stmt, SQL_UNBIND);
      SQLFreeStmt (stmt, SQL_CLOSE);
      if (SQL_SUCCESS != (rc = SQLTransact (henv, hdbc, SQL_ROLLBACK)))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	}
      goto again_exec;
    }
  else
    goto error;
}

void
print_no_rows (int nth_set, long start)
{
  if (nth_set)
    {
      isql_printf (_T("Set %d "), nth_set);
    }
  isql_printf (_T("No rows"));
  if (!nth_set)
    {
      isql_printf (_T(" -- %ld msec."), get_msec_count () - start);
    }
  isql_printf (_T("\n"));
}


/*
   This is called from by the previous function (exec_one), with
   start argument being a starting time.
   If nth_set is given as non-zero in call, then we are reading
   data from the multiple result sets. (There was a call keyword)
   This returns the return code of the latest operation as its result.

   This really requires cleaning up!
 */

int
show_results (long start, int rc, int nth_set,
	      int loc_print_banner_flag, int loc_verbose_mode)
{
  int n_rows = 0;
  int HTML_sets_open = 0;	/* Just for helping us to balance tags. */
  SWORD btype;
  UWORD inx;


  /* Currently KUBL doesn't limit by itself the count of rows fetched,
     so we have to do it explicitly here. First take the value set to
     statement options (with the latest SET MAXROWS command, calling
     API-function SQLSetStmtOption). I hope this doesn't last long.
   */
  if (kubl_mode)
    {
      SQLLEN maxrows = 0;
      int rc2 = SQLGetStmtOption (stmt, SQL_MAX_ROWS, &maxrows);
      if (SQL_ERROR == rc2)
	{
	  rc = rc2;
	  IF_ERR_GO (stmt, error, rc2);
	}
      select_max_rows = (long) maxrows;
    }


next_set:

  if (nth_set > 1)
    {				/* We are coming second time here, after first set has been output. */
      rc = SQLMoreResults (stmt);
      IF_ERR_GO (stmt, error, rc);
      if (rc == SQL_NO_DATA_FOUND)	/* Finito, agotado! */
	{
	  if (loc_verbose_mode)
	    {
	      isql_printf (_T("%d sets, %ld msec.\n"), (nth_set - 1),
			   get_msec_count () - start);
	    }
	  goto end;
	}
      n_rows = 0;		/* Else... just zero the rows counter. */
    }

  if (nth_set && (SQL_NO_DATA_FOUND == rc))
    {
      if (loc_verbose_mode)
	{
	  print_no_rows (nth_set, start);
	}
      nth_set++;
      goto next_set;
    }
  else
    /* It's anything else except call of function with no data. */
    {
      SWORD temp;
      SQLNumResultCols (stmt, &temp);	/* Needs a pointer to short. */
      n_out_cols_long = (int) temp;	/* And is then converted to long. */
    }

  if (n_out_cols > MAXCOLS)
    {
      isql_fprintf (error_stream,_T("\n Too many columns (%d) in the resultset. Only the first %d will be displayed.\n\n"), n_out_cols, MAXCOLS);
      fflush (error_stream);
      n_out_cols_long = MAXCOLS;
    }

  if (n_out_cols > 0)		/* I.e. when doing select instead of something else */
    {				/* Could be a result set of called function also, (with some data) */
      if (rc == SQL_NO_DATA_FOUND)
	{
	  if (loc_verbose_mode)
	    {
	      print_no_rows (nth_set, start);
	    }
	}
      else
	{
	  for (inx = 1; inx <= n_out_cols; inx++)
	    {
	      SWORD cbColName;
	      SWORD dummy_digits;
	      stmt_out_t *out = &out_cols[inx - 1];
	      SQLDescribeCol (stmt, inx, UCP (out->o_title), MAXCOLNAME,
			      &cbColName,
			      &out->o_type, &out->o_width,
			      &dummy_digits, &out->o_nullable);

	      if (cbColName == SQL_NULL_DATA)
		{
		  isqlt_tcscpy (out->o_title, _T("NO NAME"));
		}

/* First time in this loop we set o_allocated_buflen element of
   each column to value MAXBUFFER (about 2500).
   Then, if width of column is greater than that (e.g. if explicitly
   specified as VARCHAR(10000)), we overwrite it with that value.

   If the corresponding o_buffer has been previously allocated,
   it is freed and set to NULL that the next if statement knows
   to allocate a bugger chunk of memory.

   Anyway, if o_buffer has not been allocated yet, it is allocated
   with the length of the current value in o_allocated_buflen.

   This buffer stays allocated between different queries,
   and is not freed until a bigger buffer is needed for that same
   column.
 */
	      if (0 == out->o_allocated_buflen)		/* 1st time for this col no. */
		{
		  out->o_allocated_buflen = MAXBUFFER;
		}

	      if (((out->o_width) > out->o_allocated_buflen)
		  && (out->o_width <= o_buffer_sanity_check)
		  && (out->o_type != SQL_LONGVARCHAR)
		  && (out->o_type != SQL_WLONGVARCHAR)
		  && (out->o_type != SQL_LONGVARBINARY))
		{
		  out->o_allocated_buflen = out->o_width + 1;
		  if (out->o_buffer)	/* If previously allocated buffer, */
		    {		/* we have to free it, because this */
		      free (out->o_buffer);	/* one would not fit into it. */
		      out->o_buffer = NULL;	/* Tell next case to malloc it again. */
		    }
		}

	      if (!out->o_buffer)	/* First time or needs a bigger buffer. */
		{
		  out->o_buffer =
		    (char *) chemalloc (out->o_allocated_buflen + 1, _T("show_results"));
		}

	      if (!times_to_strings_flag &&
		  (out->o_type == SQL_TIMESTAMP ||
		   out->o_type == SQL_DATE ||
		   out->o_type == SQL_TIME))
		{
		  btype = SQL_C_TIMESTAMP;
		  if (out->o_type == SQL_TIME)
		    btype = SQL_C_TIME;
		  else if (out->o_type == SQL_DATE)
		    btype = SQL_C_DATE;
		  else
		    btype = SQL_C_TIMESTAMP;
		}
	      else
		{
		  switch (out->o_type)
		    {
		    case SQL_WCHAR: case SQL_WVARCHAR: case SQL_WLONGVARCHAR:
		      btype = SQL_C_TCHAR;
		      break;
	            default:
		      btype = SQL_C_TCHAR;
	 	    }
		}

	      if (bind_blobs_flag || (0 == print_blobs_flag)
		  || ((SQL_LONGVARCHAR != out->o_type)
		      && (SQL_WLONGVARCHAR != out->o_type)
		      && (SQL_LONGVARBINARY != out->o_type)))
		{
		  SQLBindCol (stmt, inx, btype, out->o_buffer,
			      out->o_allocated_buflen,
			      &out->o_col_len);
		}
/* If max_col_width specified, then overwrite the out->o_width value
   we got from SQLDescribeCol with max_col_width if it's less than
   the actual width. */
	      if (max_col_width && (out->o_width > max_col_width))
		{
		  out->o_width = max_col_width;
		}
	    }			/* for loop over column names & types */

	  if (in_HTML_mode ())
	    {
	      HTML_sets_open++;
	      isql_fputs (oo_oe, stdout);	/* Otherness Ends. */
	      isql_fputs (oo_sb, stdout);	/* Set Begins. */
	    }
	  if (loc_print_banner_flag)
	    {
	      print_banner ();
	    }

	  for (;;)
	    {
	      rc = SQLFetch (stmt);
	      if (rc == SQL_NO_DATA_FOUND)
		break;
	      IF_ERR_GO (stmt, error, rc);
	      rc = print_row ();
	      IF_ERR_GO (stmt, error, rc);
	      n_rows++;		/* Rows fetched and printed this far. */
	      if (select_max_rows && (n_rows >= select_max_rows))
		{		/* Are we limiting the amount ot rows? */
		  break;
		}
	    }			/* for fetch loop */
	  if (in_HTML_mode ())
	    {
	      HTML_sets_open--;
	      isql_fputs (oo_se, stdout);	/* Set Ends. */
	      isql_fputs (oo_ob, stdout);	/* Otherness Begins. */
	    }

	  if (loc_verbose_mode)
	    {
	      isql_printf (_T("\n"));
	      if (nth_set)
		{
		  isql_printf (_T("Set %d, "), nth_set);
		}
	      if (select_max_rows)
		{
		  isql_printf (_T("%d Rows of max %d allowed."),
			       n_rows, (int) select_max_rows);
		}
	      else
		{
		  isql_printf (_T("%d Rows."), n_rows);
		}
	      if (!nth_set)
		{
		  isql_printf (_T(" -- %ld msec."), get_msec_count () - start);
		}
	      isql_printf (_T("\n"));
	    }			/* if loc_verbose_mode */
	  fflush (stdout);
	  /* Save the latest row count also to the global var. */
	  N_rows = n_rows;
	}			/* else (data was found, one or more rows) */
    }				/* if(n_out_cols > 0) */
  else
    /* The statement was not a select. */
    {
      SQLRowCount (stmt, ((SQLLEN *) & sdtmp));
      N_rows = (int) sdtmp;

      if (loc_verbose_mode)
	{
	  isql_printf (_T("\n"));
	  if (nth_set)
	    {
	      isql_printf (_T("%d sets? "), nth_set);
	    }
	  isql_printf (_T("Done. -- %ld msec.\n"), get_msec_count () - start);
	  goto end;		/* Fix at 28-MAR-1997 to avoid jumittumista with
				   build in bif-functions like with  call ucase('jymy') */
	}
    }

  if (nth_set)
    {
      nth_set++;
      goto next_set;		/* Back to beginning. */
    }

end:;


  if (flag_bind_return_values)
    {
      if (nth_set)		/* Print out the return value parameter if it was call */
	{
	  if (loc_verbose_mode)
	    {
	      isql_printf (_T("RESULT="));
	    }
	  if (SQL_NULL_DATA == cbRetVal)
	    {
	      isql_fputs (_T("NULL"), stdout);
	    }
	  else
	    {
	      isql_fputs (retvalbuf, stdout);
	    }
	  isql_putchar ('\n');
	  fflush (stdout);
	}
    }

error:;
  if (HTML_sets_open > 0)
    {
      isql_fputs (oo_se, stdout);	/* Missing Set Ends. */
      isql_fputs (oo_ob, stdout);	/* Otherness Begins. */
      fflush (stdout);
    }

  return (rc);			/* It's the responsibility of the calling function
				   to print out the error message and free handles, etc. */
}



/* ================================================================ */
/*            STUFF FOR FOREACH PROCEDURE DEFINITIONS, ETC.         */
/*                                                                  */
/* ================================================================ */


TCHAR *
isql_fgets (TCHAR *inbuf, int maxbytes, FILE * fp, TCHAR *prompt)
{
#if defined(WITH_READLINE) || defined(WITH_EDITLINE)

  static TCHAR *previous_inbuf = NULL;

  if (isatty (fileno (fp)))	/* Never use readline with redirected input! */
    {
      /* For some reason there is SIGALARM signal waiting when we use
         readline. Let's ignore it with this construct.
         (Might it be a somekind of timeout which I should explicitly set
         to a greater value???)
       */
      if (SIG_ERR == signal (SIGALRM, SIG_IGN))
	{
	  isqlt_tperror (progname);
	  isql_exit (1);
	}

      if (SIG_ERR == signal (SIGPIPE, SIG_IGN))
	{
	  isqlt_tperror (progname);
	  isql_exit (1);
	}

      if (NULL != previous_inbuf)	/* Return the previously allocate buffer. */
	{
	  readline_free (previous_inbuf);
	  previous_inbuf = NULL;
	}

      if (empty_stringp (isqlhist))	/* First time here? */
	{			/* Read the old history in */
	  TCHAR *homedir = getenv ("HOME");
	  if (!virtuoso_debug)
	    isqlt_stprintf (isqlhist, _T("%") PCT_S _T("/.isql_history"), (homedir ? homedir : "."));
	  else
	    isqlt_stprintf (isqlhist, _T("%") PCT_S _T("/.isql_pldebug_history"), (homedir ? homedir : "."));
	  read_history (isqlhist);
	}

      return (previous_inbuf = readline ((prompt ? prompt : "")));
    }

#endif

/* Else, either we have no readline routine or we are reading from an
   ordinary (not terminal) file with input redirection, so let's use an
   ordinary isqlt_fgetts.
 */

  if (prompt)
    {
      isql_printf (_T("%") PCT_S, prompt);
      fflush (stdout);
    }

  return (isqlt_fgetts (inbuf, maxbytes, fp));

}

/* When we are using readline it will return a pointer allocated from heap,
   but if using isqlt_fgetts, then it will return the same pointer it was given
   to as an argument, a pointer between start and end of global input
   buffer.
 */
#define using_readline(PTR) not_pointing_to_input_buf(PTR)


/* rep_loop: Read-Eval-Print loop. Called by main & load_file */
int
rep_loop (FILE * infp, TCHAR *new_prompt)
{				/* The Main Loop. */
  TCHAR *declared_name = NULL;
  TCHAR *save_org_prompt;
  int bracelevel = 0, old_bracelevel = 0;
  UTCHAR inside_string = 0;

  integer_list pidlist_space;
  integer_list *pidlist = &pidlist_space;
  pidlist->next = NULL;		/* Initialize the pidlist anchor. */

  save_org_prompt = print_prompt;
  print_prompt = ((new_prompt && strcasecmp (new_prompt, _T("OFF")))
		  ? (new_prompt) : NULL);

/* If prompt has been defined as "OFF", then turn it to NULL (no prompting
   at all). */

  latest_statement_begins_at () = current_linecount () + 1;

#define IN_BATCH 0x4000

  for (;;)
    {
      int nth_line_of_statement = 0;
      int inlen;
      unsigned int edel = 0;	/* End delimiter either semicolon or ampersand */
      TCHAR *tmp_pt;
      TCHAR *inpt = &input[0];
/* When no readline is used inpiece and inpt should always be equal. */
      TCHAR *inpiece = inpt;
      TCHAR promptbuf[256], *promptptr = print_prompt;
      int empty_lines_so_far = 1;
      declared_name = NULL;
      input[0] = 0;		/* Clear the input buffer first. */

      /* if(print_prompt) isql_printf ("%s", print_prompt); fflush (stdout); */
/* This inner loop collects one whole SQL-statement
   (upto the next semicolon terminated line). */
      for (nth_line_of_statement = 0;; nth_line_of_statement++)
	{
	  promptptr = print_prompt;

	  /* Except on certain conditions choose another kind of a prompt */
	  if (print_prompt)
	    {
	      if (declared_name)
		{
		  isqlt_stprintf (promptbuf, _T("%") PCT_S _T("(%d) "), declared_name, bracelevel);
		  promptptr = promptbuf;
		}
	      else if (nth_line_of_statement)
		{
		  if (virtuoso_debug)
		    break;
		  promptptr =
		    _T("Type the rest of statement, end with a semicolon (;)> ");
		}
	    }

	  if (NO (inpiece = isql_fgets (inpiece, IN_BATCH, infp, promptptr)))
	    {
	      goto over;
	    }
	  current_linecount ()++;
	  if (!declared_name && !virtuoso_debug && !inside_string)
	    {
	      TCHAR *inpiece_tail = inpiece;
	      while ((' ' == inpiece_tail[0]) || ('\t' == inpiece_tail[0]))
	        inpiece_tail++;
	      if (empty_lines_so_far)
		{
		  if (('\0' == inpiece_tail[0]) || ('\r' == inpiece_tail[0]) || ('\n' == inpiece_tail[0]))
		    {	/* If it's a blank line on the toplevel then skip it here. */
		      latest_statement_begins_at () = current_linecount () + 1;
		      nth_line_of_statement--;	/* Because of ++ in the for end */
		      continue;		/* The inpt pointer is NOT incremented */
		    }
		}
	    }
	  if (!inside_string)
	    {
	      if (empty_lines_so_far)
		{
		  if (('-' == *inpiece) && ('-' == *(inpiece + 1)) && !declared_name)
		    {			/* If it's a comment on the toplevel then skip it here. */
		      latest_statement_begins_at () = current_linecount () + 1;
		      nth_line_of_statement--;	/* Because of ++ in the for end */
		      continue;		/* The inpt pointer is NOT incremented */
		    }
		}
	      empty_lines_so_far = 0;
	      if (!declared_name && (declared_name = is_declaration (inpiece)))
		{
		  old_bracelevel = bracelevel = 0;
		}
	    }
/*      if(declared_name) */
	  {
	    old_bracelevel = bracelevel;
	    bracelevel = count_bracelevel (inpiece, bracelevel, NULL, 0, 1, &inside_string);
	  }

/* Check statement for execution,
   IF the bracelevel is zero, (i.e. we are not inside procedure definition.)
   or less than zero (in which case it is syntax error),
   AND
   the last non-blank character of the line is semicolon (;) or ampersand (&)
   OR
   there has been a procedure definition (declared_name is not NULL)
   (and bracelevel has just now returned back to zero or less, i.e. there
   really is a closing brace on the line)
   This means that user doesn't have to finish the procedure definitions
   with semicolon, allowing us also to load with load (not just load -r)
   old-fashioned procedure definition files which have no separating
   semicolons.
 */

	  if ((bracelevel <= 0 && !inside_string) &&
	      ((edel = get_rid_of_trailing_semicolon_or_ampersand (inpiece))
	       ||
	       ((NULL != declared_name)		/* Ends procedure/trigger definition? */
		&& (isqlt_tcschr (inpiece, '}')))
	      )
	    )
	    {
	      if (using_readline (inpiece))
		{
		  if (inpt > &input[0])		/* Add blank between if there */
		    {
		      *inpt++ = ' ';
		    }		/* are previous lines */
		  isqlt_tcscpy (inpt, inpiece);	/* Copy the last piece got to input buf */
		}
	      bracelevel = 0;
	      break;
	    }
	  inlen = (int) isqlt_tcslen (inpiece);
	  if ((inpt + inlen) > (input + INPUT_SIZE - IN_BATCH))
	    {
	      isql_fprintf (error_stream,
			    _T("\n%") PCT_S _T(": *** The statement has grown too long on lines %ld - %ld.\n")
			    _T("Already %d bytes read without encountering a semicolon or ampersand\n")
			    _T("in the end of line! Goodbye!\n"),
	      progname, latest_statement_begins_at (), current_linecount (),
			    (int) ((inpt + inlen) - input));
	      isql_exit (1);
	    }

/* With readline we have to copy inpiece to the point of input buffer
   (pointed by inpt) because inpiece is wholly separate buffer allocated
   by readline itself.
 */
	  if (using_readline (inpiece))
	    {
	      if (inpt > &input[0])	/* Add blank between if there */
		{
		  *inpt++ = ' ';
		}		/* are previous lines */
	      isqlt_tcscpy (inpt, inpiece);
	      inpt += inlen;
	    }
/* Without readline inpiece and inpt should point to the same point in
   input buffer, where isqlt_fgetts will write its stuff. No need to add
   blanks between lines because isqlt_fgetts will keep the newline in the end
   of buffer, and get_rid_of_trailing_semicolon_if_there_is_one(inpiece)
   won't nuke it either if there is no semicolon (as we are here there
   is not one). This is getting UGLY, sorry.
 */
	  else
	    {
	      inpiece = inpt += inlen;
	    }


	}			/* End of the inner for loop, collected one statement */
      if (echo_mode)
	{
	  isql_fprintf (stdout, _T("\n-- Line %ld:%c%") PCT_S _T("\n"),
	    latest_statement_begins_at (),
	    ((latest_statement_begins_at () == current_linecount ()) ? ' ' : '\n'),
	    input );
	}
      fflush (stdout);
#if defined(WITH_READLINE) || defined(WITH_EDITLINE)
      if (using_readline (inpiece) && (input[0]))	/* Something read in really? */
	{			/* Then add it to history. */
	  int len = isqlt_tcslen (input);
	  input[len] = edel;	/* Restore the ending delimiter temporarily */
	  input[len + 1] = '\0';
	  add_history (input);	/* before adding input line to history */
	  input[len] = '\0';	/* and then wipe it out again. (kludgous) */
	}
#endif

      if ('!' == *(tmp_pt = skip_blankos (input)))
	{			/* Spawn a command to shell and wait for it if doesn't end with & */
	  spawn_shell_command ((tmp_pt + 1), pidlist, (edel != '&'));
	}
      else
	{
	  if ('&' == edel)	/* Run in background a statement or group of stmts */
	    {
	      if (load_n_files)
		{
		  isql_fprintf (error_stream,
		      _T("ERROR: Can't spawn a child process because there are ")
		      _T("files on the command line, which may cause infinite ")
		      _T("recursion %") PCT_S _T(" of %") PCT_S _T(":\n%") PCT_S _T("\n"),
		      current_lines_range(),
		      current_loadexpr (), input);
		  exit (1);
		}
	      spawn_to_background (input, pidlist);
	    }
	  else
	    /* A normal semicolon terminated statement */
	    {
	      if (virtext &&
		(
	        (latest_statement_begins_at () != current_linecount()) ||
	        is_declaration (input) ) )
		{
		  TCHAR pragma[1024];
		  int pragma_len;
		  isqlt_stprintf (pragma,
		    _T("#line %ld \"%") PCT_S _T("\"\n"),
		    latest_statement_begins_at (),
		    current_file ? current_file : _T("(console)") );
		  pragma_len = (int) isqlt_tcslen (pragma);
		  memmove (input + pragma_len, input, (isqlt_tcslen(input) + 1) * sizeof (TCHAR));
		  memcpy (input, pragma, pragma_len * sizeof (TCHAR));
		}
	      exec_one (input, pidlist);
	    }
	}

      latest_statement_begins_at () = current_linecount () + 1;
    }				/* The outer for loop */
over:;
  if (bracelevel > 0)
    isql_fprintf (error_stream,
	_T("ERROR: Missing closing brace %") PCT_S _T(" of %") PCT_S _T(":\n%") PCT_S _T("\n"),
	current_lines_range(),
	current_loadexpr (), input);

  print_prompt = save_org_prompt;	/* Restore the prompt. */

  return (current_linecount ());
}


void
do_statement (TCHAR *in, TCHAR *procedure_name)
{
  IF_ERR_GO (stmt, err, SQLExecDirect (stmt, UCP (in), SQL_NTS));
  if (commit_mode != 2)
    {
      SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, commit_mode);
      SQLTransact (henv, hdbc, SQL_COMMIT);
    }
  return;
err:
  isql_fprintf (error_stream, _T("###While loading %") PCT_S _T("\n"),
		(procedure_name ? procedure_name : in));
  SQLTransact (henv, hdbc, SQL_ROLLBACK);
}


#define LINE_SIZE 3000

int
load_raw (FILE * f)
{
  TCHAR *procname = NULL;
  int any_in = 0;
  TCHAR line[LINE_SIZE + 3];
  input[0] = 0;

  while (isqlt_fgetts (line, LINE_SIZE, f))
    {
      if (NULL != (procname = is_declaration (line)))
	{
	  if (any_in)		/* Do the previous statement read. */
	    {
	      get_rid_of_trailing_semicolon_if_there_is_one (input);
	      do_statement (input, procname);
	    }
	  input[0] = 0;
	  any_in = 1;
	}
      isqlt_tcscat (input, line);
    }
  if (any_in && procname)
    {
      get_rid_of_trailing_semicolon_if_there_is_one (input);
      do_statement (input, procname);
    }
  return (1);
}


/* Now allows also the executing of the procedure definitions ending with
   a semicolon. Anyway, because this versions allows only the execution
   of the procedure definitions, we have to rewrite this later, like
   is now the brace-level counting main read-eval loop.
   Changed 29-MAR-1997: Added an integer argument raw_load.
   If it is non-zero, then works in old-fashioned way, allowing only
   procedure definitions in the file, but if it is zero, then uses
   rep_loop routine which is also used for interactive input.
 */
int
load_file (TCHAR *name, int raw_load, TCHAR *loadexpr)
{
  FILE *f;

  if (((NULL == name) && (name = _T("NULL")))
      || (!*name) || !(f = isqlt_tfopen (name, _T("r"))))
    {
      isqlt_tperror (progname);
      isql_fprintf (error_stream,
	     _T("%") PCT_S _T(": Cannot open file \"%") PCT_S _T("\" for loading, at line %ld of %") PCT_S _T("\n"),
		    progname, name, latest_statement_begins_at (),
		    current_loadexpr ());
      return (0);
    }
  current_file = name;
  push_to_loadexpr_stack (loadexpr, f);
  if (raw_load)
    {
      load_raw (f);
    }
  else
    {
      rep_loop (f, NULL);
    }				/* Turn prompting off with NULL */
  fclose (f);
  current_file = NULL;
  drop_from_loadexpr_stack ();

  return (1);
}



/* ================================================================ */
/*    STUFF FOR FOREACH METASTATEMENT                               */
/*                                                                  */
/* ================================================================ */


#define PT_LINE 1
#define PT_INTEGER 2
#define PT_BLOB 3
#define PT_TIMESTAMP 4		/* A new one for debugging 3-3-1997 */
#define PT_DATE      5		/* As are these, 1-APR-1997 */
#define PT_TIME      6

/* With TIMESTAMP's we keep the C-type as SQL_C_CHAR, because the
   dates are strings input from the user or from the file, and they
   are converted to timestamps by the driver: */

#define get_proper_c_type(T,C)\
 (((C) || ((T)==PT_INTEGER)) ? SQL_C_SLONG : SQL_C_CHAR)

#define get_proper_sql_type(T,C) (((C) || ((T) == PT_INTEGER))\
 ? SQL_INTEGER : (((T) == PT_BLOB) ? SQL_LONGVARCHAR :\
 (((T) == PT_TIMESTAMP) ? SQL_TIMESTAMP :\
(((T) == PT_DATE) ? SQL_DATE : (((T) == PT_TIME) ? SQL_TIME : SQL_CHAR)))))

#define istermzero_or_space(C) ((!(C)) || isqlt_istspace((C)))

#define token_found(inbuf,token) (token &&\
 !isqlt_tcsncmp(inbuf,token,isqlt_tcslen(token))\
 && istermzero_or_space(inbuf[isqlt_tcslen(token)]))

#define user_input_p(FP) (stdin == (FP))

UTCHAR *
succstr (UTCHAR * str, UTCHAR * alphabet)
{
  signed int len = (int)isqlt_tcslen (SCP (str));
  UTCHAR first_of_alphabet = alphabet[0];
  UTCHAR last_of_alphabet = alphabet[isqlt_tcslen (SCP (alphabet)) - 1];

  /* Change all last_of_alphabets from the end of string
     to the first_of_alphabets */
  while (--len >= 0 && (str[len] == last_of_alphabet))
    {
      str[len] = first_of_alphabet;
    }

  /* If the whole string is composed of last_of_alphabets, then return NULL
     as we cannot find more successors with the same length.
     (Without this it would wrap over to the string composed only of
     first_of_alphabet). */
  if (len < 0)
    {
      return (NULL);
    }
  /* Otherwise increment the last non-end-alphabet char found by one. */
  else
    {
      (str[len])++;
      return (str);
    }
}


UTCHAR *
succelem (UTCHAR * inbuf, int inbuf_size, int type, ULONG intval,
	  UTCHAR * beg_elem, UTCHAR * end_elem)
{
  int is_signed = (('-' == *end_elem) || ('-' == *beg_elem));

  /* If inbuf is already same as end_elem return NULL to mark that
     we should break from the loop. */
  if (!isqlt_tcscmp (SCP (inbuf), SCP (end_elem)))
    {
      return (NULL);
    }

  if (PT_INTEGER == type)
    {
      isqlt_stprintf (SCP (inbuf), (is_signed ? _T("%ld") : _T("%lu")), (intval + 1));
      return (inbuf);
    }
  else
    {
      return (succstr (inbuf, UCP ("az")));
    }

}


int
skip_to_end_token (FILE * in_fp,
		   unsigned long int *ptr_to_linecount,
		   TCHAR *end_token,
		   TCHAR *inbuf, int inbuf_size)
{
  TCHAR *endtoken = (TCHAR *) (end_token ? end_token :
#ifdef WIN32
		    _T("CTRL-Z")
#else				/* It should be Unix. */
		    _T("CTRL-D")
#endif
  );

  for (((print_prompt && user_input_p (in_fp))
    ? isql_printf (_T("foreach waiting for end token \"%") PCT_S _T("\"> "), endtoken) : 0);
       isqlt_fgetts (inbuf, inbuf_size, in_fp);
       ((print_prompt && user_input_p (in_fp))
    ? isql_printf (_T("foreach waiting for end token \"%") PCT_S _T("\"> "), endtoken) : 0))
    {
      if (ptr_to_linecount)
	{
	  ++*ptr_to_linecount;
	}
      if (token_found (inbuf, end_token))
	{
	  return (1);
	}
    }
  return (0);			/* No more input. */
}

/* Returns the retcode of the last SQL-API-call. Arguments are the same
   as for exec_for_foreach (the next function), where this is called from,
   except additional integer pointer *count and *end_found
   reference arguments in the end.

   Here's the catch when reading in line_by_line mode:
   There has to be a possibility to present exactly, by DBDUMP,
   0) a NULL in blob column, i.e. value that is not really a blob at all,
   but NULL is NULL is NULL.
   1) an empty blob (of 0 bytes)
   2) as well as a blob whose last line doesn't end with newline.

   The NULL in the blob column is presented just as
   FOREACH BLOB INSERT INTO BLOBS(BLOB) VALUES(NULL);

   Without the END keyword!

   The empty blob is presented just as
   FOREACH BLOB INSERT INTO BLOBS(BLOB) VALUES(?);
   END

   The blob whose last line doesn't end with a newline is presented as:
   FOREACH BLOB INSERT INTO BLOBS(BLOB) VALUES(?);
   The first line
   \END the second line which just happens to begin with a string END
   The third line, that ends with a period, not a newline.\c
   END

   So we use here a new magical escape sequence \c that just cuts
   the string short at that point, leaving the newline dangling
   in the input buffer out.
   (See function unescape_string)

   In dbdump.c the function print_blob_col (not the one in this source file!)
   produces lines that can be read with this function in line_by_line mode.
 */

int bin_fgets (TCHAR *buffer, int max_size, FILE * infp);

/* Token is expected to be followed by '\n', '\r', ' ' or '\0' */

#define is_mime_boundary_token(ROW,ROWLEN,BTOKEN,BLEN,FINAL_FLAG)\
(((ROWLEN) >= (BLEN)) && !isqlt_tcsncmp((ROW),(BTOKEN),(BLEN))\
  && ((isqlt_istspace(*((ROW)+(BLEN))) || !*((ROW)+(BLEN)))\
  || (('-' == *((ROW)+(BLEN))) && ('-' == *((ROW)+(BLEN)+1))\
       && (isqlt_istspace(*((ROW)+(BLEN)+2)) || !*((ROW)+(BLEN)+2))\
       && (FINAL_FLAG = 1))))


/* C's && is not Lisp's AND, so this would not work as expected:
   #define is_mime_boundary_token(ROW,ROWLEN,BTOKEN,BLEN)\
   ( (((ROWLEN) >= (BLEN)) && !isqlt_tcsncmp((ROW),(BTOKEN),(BLEN))\
   && ((isqlt_istspace(*((ROW)+(BLEN))) || !*((ROW)+(BLEN)))\
   || (('-' == *((ROW)+(BLEN))) && ('-' == *((ROW)+(BLEN)+1))\
   && (isqlt_istspace(*((ROW)+(BLEN)+2)) || !*((ROW)+(BLEN)+2)))))\
   && ( ('-' == *((ROW)+(BLEN))) ? 2 : 1))
 */

#define only_lf_or_crlf(BUF) (  (('\n' == *(BUF)) && !*((BUF)+1) )\
 || (('\r' == *(BUF)) && ('\n' == *((BUF)+1)) && !*((BUF)+2))  )


/* Returns 1 if (BUF+LEN-1) (LEN should be the length of buffer)
   points to a linefeed (dec. 10.) and 2 if the preceding character
   is carriage return (dec. 13.). Otherwise returns 0.
 */
#define ends_with_lf_or_crlf(BUF,LEN)\
 ( ( ((LEN) >= 1) && ('\n' == *((BUF)+(LEN)-1)))\
  ? (1 + (((LEN) >= 2) && ('\r' == *((BUF)+(LEN)-2)))) : 0)


/* More kludgifications at 22.10.1997 by AK. Added an argument
   mime_boundary_token, which when given as non-NULL, overrides
   end_token and separating_token, and additionally changes the
   behaviour so that the last newline (e.g. consisting only of
   LF or CR+LF) before the boundary token itself is not flushed
   to the database, instead it is viewed as a part of the token
   itself.
   See rfc1521 for the details. Mime multipart messages, etc.
 */
int
read_blob_from_input (TCHAR *statement, int has_output, FILE * in_fp,
		      unsigned long int *ptr_to_linecount,	/* incr:ed if not NULL */
		      TCHAR *end_token, TCHAR *separating_token,
		      TCHAR *mime_boundary_token,
		      int *type, PFI unpack_function_ptr,
		      TCHAR *inbuf, int inbuf_size,
		      ULONG * count, int *end_found)
{
  SQLULEN param_num;		/* SQLULEN, not UWORD, to avoid stack corruption. */
  int dummy_tummy = 0;		/* In case param_num overflows. */
  int rc, rc2;
  int got_anything = 0, final_mime_token = 0;	/* Not much used. */
  SQLLEN inbuf_len;
  int blen = 0;
  int line_by_line_input =	/* A flag. */
  (user_input_p (in_fp) || end_token || separating_token
   || (NULLFP != unpack_function_ptr));
  int crlfs = 0, previous_crlfs = 0;	/* 1 or 2 if the last line ended with LF or CR+LF */
  int ind_to_crlfs = 0;

  if (mime_boundary_token)
    {
      blen = (int) isqlt_tcslen (mime_boundary_token);
    }

  dummy_tummy = dummy_tummy + 1;

/* Parameter is a blob? */
  do
    {
      rc = SQLParamData (stmt, ((PTR *) & param_num));
      if (SQL_NEED_DATA == rc)
	{
	  for (;;)
	    {
	      if (line_by_line_input)
		{
		  if (print_prompt)
		    {
		      isql_printf (_T("foreach %ld blob, param %ld> "),
				   *count, (long) param_num);
		    }
/*                 if(!(got_anything = !!isqlt_fgetts(inbuf, inbuf_size, in_fp))) */
		  if (!(got_anything = bin_fgets ((inbuf + previous_crlfs),
					      (inbuf_size - previous_crlfs),
						  in_fp)))
		    {
		      *end_found = 1;
		      break;
		    }
		  if (ptr_to_linecount)
		    {
		      ++*ptr_to_linecount;
		    }
		  if (mime_boundary_token)
		    {
		      if (is_mime_boundary_token ((inbuf + previous_crlfs),
						  got_anything,
			       mime_boundary_token, blen, final_mime_token))
			{
			  *end_found = 1;
			  break;
			}
		    }
		  else
		    {
		      if (token_found ((inbuf + previous_crlfs), end_token))
			{
			  *end_found = 1;
			  break;
			}
		      if (token_found ((inbuf + previous_crlfs),
				       separating_token))
			{
			  break;
			}
		    }

/* NOT TESTED: HOW DO WORK TOGETHER
   HIDDEN_CRS=CLEARED, FOREACH ESCAPED or HEXADECIMAL BLOB . MIME_BOUNDARY ?
 */
		  if (clear_hidden_crs_flag)
		    {
		      got_anything
			-= get_rid_of_trailing_CRS_with_count ((inbuf + previous_crlfs), got_anything);
		    }

		  if (mime_boundary_token)
		    {
		      if (0 != (crlfs = ends_with_lf_or_crlf (inbuf + previous_crlfs, got_anything)))
			{	/* Leave the trailing (CR+)LF for the next time. */
			  got_anything -= crlfs;
			  ind_to_crlfs = got_anything + previous_crlfs;
			}
		    }

/* Here is a bug when using MIME_BOUNDARY together with ESCAPED or HEX */
		  if (NULLFP != unpack_function_ptr)
		    {
		      UTCHAR save_it = 0;
		      if (crlfs)
			{
			  save_it = inbuf[ind_to_crlfs];
			  inbuf[ind_to_crlfs] = '\0';	/* Temp terminator */
			}
/* Assumed to always generate equal length or shorter string: */
		      got_anything =
			((unpack_function_ptr) ((TCHAR *) UCP (inbuf + previous_crlfs)));
		      if (crlfs)
			{
			  inbuf[ind_to_crlfs] = save_it;	/* Restore? */
			}
		    }

		  inbuf_len = got_anything + previous_crlfs;

		}
	      else
		/* Reading in binary format from the file specified */
		{
		  got_anything = (int) fread (inbuf, 1, inbuf_size, in_fp);
		  /*
		     isql_fprintf(error_stream,
		     "read_blob_from_input: fread got %d bytes, feof(in_fp)=%d, ferror(in_fp)=%d\n"
		     "inbuf[0-15]='%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c'\n",
		     got_anything,feof(in_fp),ferror(in_fp),
		     inbuf[0],inbuf[1],inbuf[2],inbuf[3],
		     inbuf[4],inbuf[5],inbuf[6],inbuf[7],
		     inbuf[8],inbuf[9],inbuf[10],inbuf[11],
		     inbuf[12],inbuf[13],inbuf[14],inbuf[15]
		     ); fflush(error_stream);
		   */
		  inbuf_len = got_anything;
		  if (!got_anything)
		    {
		      *end_found = 1;
		      break;
		    }
		}

	      {
		rc2 = SQLPutData (stmt, inbuf, ((SQLLEN) inbuf_len));
		if (SQL_ERROR == rc2)
		  {
		    return (rc2);
		  }
		if (0 != (previous_crlfs = crlfs))	/* Assignment on purpose */
		  {		/* Copy the (CR+)LF in the end of this line to the
				   beginning of next batch to be written to database,
				   unless the next line happens to be the mime boundary. */
		    isqlt_tcsncpy (inbuf, (inbuf + ind_to_crlfs), crlfs);
/*                    inbuf[0] = inbuf[inbuf_len];
   if(crlfs > 1) { inbuf[1] = inbuf[inbuf_len+1]; } */
		  }

		/* Was:   IF_SEVERE_ERR_GO(stmt, error, rc2); */
	      }
	    }			/* for loop */
	}
      else
	{
	  if (SQL_ERROR == rc)
	    return (rc);
	}
      /* Was: { IF_SEVERE_ERR_GO(stmt,error,rc); } */
    }
  while (SQL_NEED_DATA == rc);
/* Parameter was a blob? */

  return (rc);
}


/* An excerpt from ODBC API help file,
   function SQLTransact(henv, hdbc, fType)
   (Affects how we implement deadlock retrying...)

   If fType is SQL_COMMIT, SQLTransact issues a commit request for all
   active operations on any hstmt associated with an affected hdbc.
   If fType is SQL_ROLLBACK, SQLTransact issues a rollback request
   for all active operations on any hstmt associated with an affected hdbc.
   If no transactions are active, SQLTransact returns SQL_SUCCESS with no
   effect on any data sources.

   If the driver is in manual-commit mode (by calling SQLSetConnectOption
   with the SQL_AUTOCOMMIT option set to zero,
   i.e. in ISQL SET AUTOCOMMIT OFF, which is OFF by default), a new
   transaction is implicitly started when an SQL statement that can
   be contained within a transaction is executed against the current data
   source.

   To determine how transaction operations affect cursors, an application
   calls SQLGetInfo with the SQL_CURSOR_ROLLBACK_BEHAVIOR and
   SQL_CURSOR_COMMIT_BEHAVIOR options.

   If the SQL_CURSOR_ROLLBACK_BEHAVIOR or SQL_CURSOR_COMMIT_BEHAVIOR value
   equals SQL_CB_DELETE, SQLTransact closes and deletes all open cursors on
   all hstmts associated with the hdbc and discards all pending results.
   SQLTransact leaves any hstmt present in an allocated (unprepared) state;
   the application can reuse them for subsequent SQL requests or can call
   SQLFreeStmt to deallocate them.

   If the SQL_CURSOR_ROLLBACK_BEHAVIOR or SQL_CURSOR_COMMIT_BEHAVIOR value
   equals SQL_CB_CLOSE, SQLTransact closes all open cursors on all hstmts
   associated with the hdbc. SQLTransact leaves any hstmt present in a
   prepared state; the application can call SQLExecute for an hstmt
   associated with the hdbc without first calling SQLPrepare.

   If the SQL_CURSOR_ROLLBACK_BEHAVIOR or SQL_CURSOR_COMMIT_BEHAVIOR value
   equals SQL_CB_PRESERVE, SQLTransact does not affect open cursors
   associated with the hdbc. Cursors remain at the row they pointed to
   prior to the call to SQLTransact.

   For drivers and data sources that support transactions, calling
   SQLTransact with either SQL_COMMIT or SQL_ROLLBACK when no transaction
   is active will return SQL_SUCCESS (indicating that there is no
   work to be committed or rolled back) and have no effect on the data
   source.

   Drivers or data sources that do not support transactions (SQLGetInfo
   fOption SQL_TXN_CAPABLE is 0) are effectively always in autocommit mode.
   Therefore, calling SQLTransact with SQL_COMMIT will return SQL_SUCCESS.
   However, calling SQLTransact with SQL_ROLLBACK will result in SQLSTATE
   S1C00 (Driver not capable), indicating that a rollback can never be
   performed.

 */


#define MAXPARS (MAXCOLS+20)

/* If between_form is non-zero then separating_token will contain
   the starting point, end_token the ending point and no input is
   read from anywhere, instead inbuf will change from the starting point
   to the ending point (inclusive).
 */
int
exec_for_foreach (TCHAR *statement,	/* Just the first keyword. */
		  TCHAR *whole_statement,	/* Whole SQL-statement.
						   resides in input buffer so it's not very persistent. */
		  int has_output, FILE * in_fp,
		  TCHAR *loadexpr,	/* pushed to stack if not NULL */
		  TCHAR *end_token, TCHAR *separating_token,
		  TCHAR *mime_boundary_token,
		  int *type, PFI unpack_function_ptr,
		  TCHAR *inbuf, int inbuf_size,
		  int between_form)
{
  SQLULEN ipar = 1;		/* Changed from UWORD to SQLULEN to avoid whining. */
  SQLLEN cbInput, cbCount = 0;
  ULONG intpar;
  ULONG count = 1;		/* Count of successful operations (+1) */
  int end_found = 0;		/* Flag to tell that we should stop it! */
  int has_been_pushed = 0;
  int rc;
  int blen = (int) (mime_boundary_token ? isqlt_tcslen (mime_boundary_token) : 0);
  UTCHAR pardescvec[MAXPARS + 1];
  int pars_found = 0;


  if (between_form)
    {
      isqlt_tcsncpy (inbuf, separating_token, inbuf_size);
    }

  pars_found
    = parse_statement_for_special_parameters (UCP (whole_statement),
  /* Stores its stuff here: */ pardescvec,
					      MAXPARS);
/*
   isql_printf(
   "**exec_for_foreach: pardescvec=%s/%d, pars_found=%d, statement:\n%s\n",
   pardescvec,isqlt_tcslen(pardescvec),pars_found,whole_statement);
 */

  /* Do this after parse_statement_for_special_parameters,
     so that references to $STATE and $MESSAGE will be substituted
     with the SQLSTATE and MESSAGE of the last SQL-statement executed,
     instead of "OK" strings to which this macro will clear them: */
  clear_SQL_state_and_message ();

  rc = SQLPrepare (stmt, UCP (whole_statement), SQL_NTS);
  IF_ERR_GO (stmt, error, rc);

  /* No parameters, no stuff following, no need to find END keyword. */
  /* DBDUMP produces rows like
     FOREACH BLOB INSERT INTO taulu(jymy,blobi) VALUES(1,NULL);
     without the END keyword when there are NULL in the blob column.
     So we have to conform here.
     However, things like:
     FOREACH INTEGER BETWEEN 1 100 insert into taulu(txt) values('kala');
     will work as expected, attempting to insert string 'kala' hundred times
     to table taulu. (Presumably there is an auto TIMESTAMP primary key).
   */
  if ((NO pars_found) && (NOT between_form))
    {
      end_found = 1;
      goto execute_statement;	/* And jump right to the middle of loop. */
    }

/* Otherwise, bind the parameters in this primitive little loop: */
/* The Parameter ?R (Repeat previous) will be "implemented" here
   almost gratis. Same with ?1 ?2 refer to first, second, etc,
   because all parameters except ?C will actually point to one and
   same buffer. This needs a thorough revision later.
   For now it will work sufficiently well for our needs.
 */
/* NOTE THAT WE SHOULD IMPLEMENT ALSO BULK INSERTS using an array
   of parameter values and SQLParamOption API-calls !!!
   E.g. syntax like:
   FOREACH BULK OF 1000 LINES IN FILE1 INSERT INTO tab values(?);
   (If number is left out, then tries to insert all lines in the file
   with one call, or maybe there has to be some maximum value for
   length of a parameter vector?)
 */

  for (ipar = 1; ipar <= ((SQLULEN) pars_found); ipar++)
    {
      int iscountparam = 0;
      UTCHAR c;
      if (ipar <= MAXPARS)
	{
	  switch (c = (UTCHAR) toupper ((SCP (pardescvec))[ipar - 1]))
	    {
	    case 'C':
	      {
		iscountparam = 1;
		break;
	      }

#ifdef LEADING_TO_IDIOTIC_USAGE_COMMENTED_OUT
/* The parameter numbers ?1, ?2, etc should always refer to actual
   parameters given after foreach, separated by commas, not to other
   ?-parameters in the statement itself. This means that to the count
   parameter it is only possible to refer as ?C, not by any tricky
   indirect reference.
   But maybe I can later use this piece of code for something useful.
 */
	    case 'R':
	      {
		iscountparam = ((ipar > 1) &&	/* If the previous was? */
				('C' == toupper (pardescvec[ipar - 2])));
		break;
	      }
	    case '1':
	    case '2':
	    case '3':
	    case '4':
	    case '5':
	    case '6':
	    case '7':
	    case '8':
	    case '9':
	      {
		c = c - '0';	/* From digit to number. */
		iscountparam = ((c <= pars_found) &&
				('C' == toupper (pardescvec[c - 1])));
		break;
	      }
#endif
	    default:
	      {
		break;
	      }
	    }			/* switch */
	}			/* if */


      rc = SQLBindParameter (stmt,
			     ((UWORD) ipar),
			     ((SWORD) SQL_PARAM_INPUT),
			  ((SWORD) get_proper_c_type (*type, iscountparam)),
			((SWORD) get_proper_sql_type (*type, iscountparam)),
			     0,	/* The precision of the column. SQLULEN */
			     0,	/* The scale of the column. SWORD */
			     ((PTR) (iscountparam ? ((PTR) & count) :
				 ((*type == PT_INTEGER) ? ((PTR) & intpar) :
/* With blobs give parameter num. */ ((*type == PT_BLOB) ? ((PTR) ipar)
/* With lines give input buffer: */ : ((PTR) inbuf))))),
			     0,	/* SQLLEN cbValueMax */
			     (iscountparam ? &cbCount : &cbInput));

      IF_ERR_GO (stmt, error, rc);
    }

  switch (*type)		/* This should be later inside the loop, with type */
    {				/* scanning over the types given comma-separated */
    case PT_INTEGER:
      {
	cbInput = 0;
	break;
      }
    case PT_BLOB:
      {
	cbInput = SQL_DATA_AT_EXEC;	/* ODBC 1.0 defined as -2 in sql.h */
/* Doesn't work yet with SQL_LEN_DATA_AT_EXEC(0); (of ODBC 2.0)
   which returns -100. Have to fix \wi\cliuti.c, function parm_to_dv !
   (Now it has been fixed for a long time...) */
	break;
      }
    case PT_LINE:
    case PT_TIMESTAMP:
    case PT_TIME:
    case PT_DATE:
      {
	cbInput = SQL_NTS;	/* Just a default value. Overridden elsewhere. */
	break;
      }
    }

  /* Now that the statement has been prepared and parameters bound, the
     loop over parameters themselves (i.e. lines or blobs from file
     or stdin) can begin. */

  if (loadexpr)
    {
      has_been_pushed = push_to_loadexpr_stack (loadexpr, in_fp);
    }

  for (; NOT end_found;)
    {
      if (NOT between_form &&
	  print_prompt && user_input_p (in_fp) && (*type != PT_BLOB))
	{
	  isql_printf (_T("foreach %ld> "), (long) count);
	}

      if (PT_BLOB != *type)
	{
	  if (NOT between_form)
	    {
/* WAS: if(end_found = NOT isqlt_fgetts(inbuf, inbuf_size, in_fp)) { break; } */
	      cbInput = bin_fgets (inbuf, inbuf_size, in_fp);
	      if (0 != (end_found = (0 == cbInput)))
		{
		  break;
		}
	      current_linecount ()++;
	      if (mime_boundary_token)
		{
		  int final_mime_token = 0;	/* Almost unnecessary. */
		  if (is_mime_boundary_token (inbuf, cbInput,
			       mime_boundary_token, blen, final_mime_token))
		    {
		      end_found = 1;
		      break;
		    }
		}
	      else
		{
		  if (token_found (inbuf, end_token))
		    {
		      end_found = 1;
		      break;
		    }
		}
	    }
	  if (PT_INTEGER == *type)
	    {
	      TCHAR *numpt;
	      get_rid_of_trailing_newline (inbuf);
	      numpt = skip_blankos (inbuf);
/* If the user has given FOREACH HEXADECIMAL INTEGER ... */
	      if (unpack_function_ptr == unhex_string)
		{
		  if (!*numpt || (0 == isqlt_stscanf (numpt, _T("%lx"), &intpar)))
		    {
		      isql_printf (_T("Invalid hex number \"%") PCT_S _T("\" "), numpt);
		      continue;
		    }
		}
	      else
		/* Normal, decimal input. */
		{
		  if (!*numpt ||
		  ((*numpt != '+') && (*numpt != '-') && !isqlt_istdigit (*numpt)))
		    {
		      isql_printf (_T("Invalid dec number \"%") PCT_S _T("\" "), numpt);
		      continue;
		    }
		  intpar = isqlt_tstol (numpt);
		}
	    }
	  else if (PT_LINE == *type)
	    {
	      cbInput
		-= get_rid_of_trailing_newline_and_CR_with_count (inbuf, cbInput);

/* If escaped/hexed/uuencoded option specified, then convert a possibly
   escaped/hexed/uuencoded string back to original. It is possible that
   there are escapes like \000 for NULL bytes. So we use the new length
   returned by the function instead of SQL_NTS as the length value of
   cbInput. */
	      if (NULLFP != unpack_function_ptr)
		{
		  cbInput = ((unpack_function_ptr) ((TCHAR *) UCP (inbuf)));
		}
	    }
	}
      else /* GK: there can be only one blob in a file */
	end_found = 1;


    execute_statement:
      rc = SQLExecute (stmt);

      /* Don't break for a small whines, like a duplicate value on the */
      IF_SEVERE_ERR_GO (stmt, error, again, rc);	/* primary key. */
      if (SQL_NEED_DATA == rc)	/* Blob, blob, blob? */
	{
	  rc = read_blob_from_input (statement, has_output, in_fp,
				     &current_linecount (),
				     end_token, separating_token,
				     mime_boundary_token,
				     type, unpack_function_ptr,
				     inbuf, inbuf_size,
				     &count, &end_found);
	  IF_SEVERE_ERR_GO (stmt, error, again, rc);
	}

      if (foreach_err_break && rc != SQL_SUCCESS &&
	  rc != SQL_SUCCESS_WITH_INFO)
	goto error;


      count++;

      SQLRowCount (stmt,  & sdtmp);
      N_rows = (int) sdtmp;

      if (has_output && (rc == SQL_SUCCESS))	/* Is select or call fun */
	{			/* Print the selected rows out without any banners */
	  unsigned long start = get_msec_count ();
	  rc = show_results (start, rc, !strcasecmp (statement, _T("CALL")),
			     0,	/* print_banner_flag */
			     0);	/* verbose_mode */
	  IF_SEVERE_ERR_GO (stmt, error, again, rc);
	  SQLFreeStmt (stmt, SQL_CLOSE);
	}			/* if(rc == SQL_SUCCESS) */
      else
	/* insert, update, delete, function call without call keyword */
	{
	  /* Currently, do nothing. */
	  if (foreach_err_break && rc != SQL_SUCCESS &&
	      rc != SQL_SUCCESS_WITH_INFO)
	    goto error;
	}

      if (between_form)
	{
	  if (NULL == succelem (((UTCHAR *) inbuf), inbuf_size, *type, intpar,
				((UTCHAR *) separating_token),
				((UTCHAR *) end_token)))
	    {
	      end_found = 1;
	      break;
	    }
	}
    }				/* for loop */

error:;

  if (has_been_pushed)
    {
      drop_from_loadexpr_stack ();
    }

  if ((NOT between_form) && (NOT end_found)
  /* && end_token */  && user_input_p (in_fp))
    {				/* No need to scan a possibly megabytes long file to the end.
				   It's only necessary when we are reading from the user input. */
      skip_to_end_token (in_fp, &current_linecount (), end_token,
			 inbuf, inbuf_size);
    }

  SQLFreeStmt (stmt, SQL_RESET_PARAMS);
  SQLFreeStmt (stmt, SQL_CLOSE);	/* Maybe called unnecessarily, maybe not. */

  if (SQL_SUCCESS != (rc = SQLTransact (henv, hdbc, SQL_COMMIT)))
    {
      print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
      if (rc != SQL_SUCCESS_WITH_INFO)
	isql_exit (1);
    }

  return (count - 1);		/* It was one-based. */
}


/*
   The syntax is:

   foreach [HEXADECIMAL/ESCAPED/NONESCAPED] TYPE [FOLLOWING/ IN filename]
   parameterized-sql-statement;
   -- And if following was used, then lines must end with END
   end

   Where TYPE is either a line, integer or blob.
   If the keywords FOLLOWING or IN filename is omitted after type, then
   the following is the default.
   If escaped/nonescaped is omitted, then escaped is the default.
   (except when reading from a file)

   In the future may read comma-separated values (CSV?)

   foreach INTEGER, STRING, FLOAT, INTEGER IN filename insert

   And something like this: (Needs good regexp parser? Or use string.c)

   foreach NONESCAPED BLOB IN mailfile STARTED_BY 'From:* '
   insert into mails(mail_id,from_line,mail) values(?C,?S,?);

   ?S will be a new special parameter referring to the starting line of a
   multiline blob, bound as a normal VARCHAR string. That first line is
   also included in the blob itself. (If using instead the SEPARATED_BY
   keyword, then the line which matched to it, is not included.)

   SEPARATED_BY 'END*' (* default *)


   foreach LINE NOT LIKE '#*' insert ...

   foreach WORD, REST ON LINE NOT LIKE '#*' insert ...

   Other kind of loops also:

   foreach TABLE LIKE 't%' DROP TABLE %s;
   foreach SYSTEM TABLE ...
   foreach VIEW LIKE ...

   foreach DIRECTORY LIKE '*'
   foreach FILE LIKE '%s/ *.blob' -- %s would refer here to directory names
   --                                generated by the first foreach part.
   -- And not until in this last part they would refer to filenames itself:
   foreach BLOB IN %s insert into blobtable(filename,blob) values(%s,?);

   What about, something like:

   foreach integer between $I $- $ARGC 1 create table \$ARGV[?](a integer, etc.);

   Probably we should use a more civilized syntax, something like ?D and ?F
   etc...

 */

#ifndef TMPBUF_SIZE
#define TMPBUF_SIZE 81
#endif

#define w_or_null(X) ((X) ? (X) : _T("NULL"))

int
isql_foreach (TCHAR *text)
{
  unsigned long start = get_msec_count ();
  TCHAR *ptr;
  TCHAR *optionword = NULL, *typeword = NULL, *nextword = NULL, *statement = NULL;
  TCHAR *filename = NULL;
  TCHAR *own_inbuf = input;	/* By default use common buffer. */
  int own_inbuf_size = INPUT_SIZE;	/* And the size of common buffer. */
  FILE *in_fp = current_input_stream ();	/* Was: stdin */
  PFI unpack_function_ptr = unescape_string;
  int following = 1, between_form = 0;
  int type = 0;
  int items_read = 0;
  TCHAR *end_token = _T("END"), *separating_token = _T("BLOB");
  TCHAR *mime_boundary_token = NULL;
  TCHAR tmpbuf[TMPBUF_SIZE + 2], tmp2buf[TMPBUF_SIZE + 2];
  TCHAR tmp3buf[TMPBUF_SIZE + 2], tmp4buf[TMPBUF_SIZE + 2];
  TCHAR tmp5buf[TMPBUF_SIZE + 2], tmp6buf[TMPBUF_SIZE + 2];


  ptr = text;

  /* First, skip the FOREACH command keyword itself. */
  optionword = get_next_token (&ptr, tmpbuf, TMPBUF_SIZE, NULL, 0);
  if (NULL == optionword)
    {
      goto premature_end;
    }

/* Was: ptr = text+(sizeof("FOREACH")-1); */

/*  isql_printf("isql_foreach(%s/%d): ptr=%s\n",text,isqlt_tcslen(text),ptr); */

  optionword = get_next_token (&ptr, tmpbuf, TMPBUF_SIZE, NULL, 0);
  if (NULL == optionword)
    {
      goto premature_end;
    }


  if (!strncasecmp (optionword, _T("ESC"), 3))
    {
      unpack_function_ptr = unescape_string;
    }
  else if (!strncasecmp (optionword, _T("HEX"), 3))
    {
      unpack_function_ptr = unhex_string;
    }
  else if (!strncasecmp (optionword, _T("NON"), 3))
    {
      unpack_function_ptr = NULLFP;
    }
  else
    {
      typeword = optionword;
    }

  if (!typeword)
    {
      typeword = get_next_token (&ptr, tmp2buf, TMPBUF_SIZE, NULL, 0);
      if (NULL == typeword)
	{
	  goto premature_end;
	}
    }

  if (!strcasecmp (typeword, _T("LINE")))
    {
      type = PT_LINE;
    }
  else if (!strcasecmp (typeword, _T("INTEGER")))
    {
      type = PT_INTEGER;
    }
  else if (!strcasecmp (typeword, _T("BLOB")))
    {
      type = PT_BLOB;
    }
  else if (!strcasecmp (typeword, _T("TIMESTAMP")))
    {
      type = PT_TIMESTAMP;
    }
  else if (!strcasecmp (typeword, _T("TIME")))
    {
      type = PT_TIME;
    }
  else if (!strcasecmp (typeword, _T("DATE")))
    {
      type = PT_DATE;
    }
  else
    {
      isql_fprintf (error_stream,
		    _T("\n*** Error: unrecognized type \"%") PCT_S _T("\" for foreach at line %ld of %") PCT_S _T(": %") PCT_S _T("\n"),
	       typeword, latest_statement_begins_at (), current_loadexpr (),
		    input);
      /* skip to the end ? */
      return (0);		/* isql_exit(1); */
    }

  nextword = get_next_token (&ptr, tmp3buf, TMPBUF_SIZE, NULL, 0);
  if (NULL == nextword)
    {
      goto premature_end;
    }

  else if (!strcasecmp (nextword, _T("FOLLOWING")))
    {
      following = 1;
    }
  else if (!strcasecmp (nextword, _T("IN")))
    {
      int might_be_stdin = 0;
      following = 0;
/* If no ESCAPED/NONESCAPED were specified when inputting stuff from
   file, then use NONESCAPED as a default: */
      if (typeword == optionword)
	{
	  unpack_function_ptr = NULLFP;
	}
      end_token = NULL;
      separating_token = NULL;

/* If IN is followed by - or -b (but not in quotes as '-')
   then read the stuff from stdin. */
      ptr = skip_blankos (ptr);
      if (*ptr == '-')
	{
	  might_be_stdin = 1;
	}

      filename = get_next_token (&ptr, tmp4buf, TMPBUF_SIZE, NULL, 0);
      if (NULL == filename)
	{
	  goto premature_end;
	}
      if (might_be_stdin &&
	  (!strcasecmp (filename, _T("-")) ||
	   (might_be_stdin++ && !strcasecmp (filename, _T("-B")))))
	{
	  in_fp = stdin;
#ifdef WIN32
	  /* Currently this is not undone anywhere...
	     (E.g. after END token is encountered). */
	  if (might_be_stdin > 1)	/* User used -b or -B */
	    {
	      setmode (fileno (stdin), _O_BINARY);	/* _O_TEXT */
	    }
#endif
	}

      else if (!(in_fp = isqlt_tfopen (filename,
#ifdef WIN32
				_T("rb")	/* Use binary mode in Windows. */
#else
				_T("r")	/* Unix is Unix is Unix is Good. */
#endif
		 )))
	{
	  isqlt_tperror (progname);
	  isql_fprintf (error_stream,
			_T("\n*** Error: can't open file \"%") PCT_S _T("\" for foreach at line %ld of %") PCT_S _T(": %") PCT_S _T("\n"),
	       filename, latest_statement_begins_at (), current_loadexpr (),
			input);
	  /* skip the statement itself ? */
	  goto error;
	}
    }
  else if (!strcasecmp (nextword, _T("BETWEEN")))
    {
      int len1, len2;
      following = 0;
      between_form = 1;
      separating_token = get_next_token (&ptr, tmp4buf, TMPBUF_SIZE, NULL, 0);
      if (NULL == separating_token)
	{
	  goto premature_end;
	}
      end_token = get_next_token (&ptr, tmp6buf, TMPBUF_SIZE, NULL, 0);
      if (NULL == end_token)
	{
	  goto premature_end;
	}
      len1 = (int) isqlt_tcslen (separating_token);
      len2 = (int) isqlt_tcslen (end_token);
      if (len2 > len1)
	{
	  len1 = len2;
	}			/* Get the max length of start, end */
      len1 += 20;		/* And little bit more to be sure. */
      own_inbuf_size = len1;
      own_inbuf = (TCHAR *) chemalloc (own_inbuf_size + 1, _T("isql_foreach"));
/* chemalloc never returns NULL.
   if(NULL == own_inbuf)
   {
   isql_fprintf (error_stream,
   "\n*** Error: foreach cannot allocate buffer of size %u at line %ld of %s: %s\n",
   (own_inbuf_size+1),latest_statement_begins_at(),
   current_loadexpr(), input);
   goto error;
   }
 */
      if (type != PT_INTEGER)
	{
	  isql_fprintf (error_stream,
	      _T("\n*** Error: foreach ... between does support integers only at line %ld of %") PCT_S _T(": %") PCT_S _T("\n"),
	      latest_statement_begins_at (), current_loadexpr (),
	      input);
	  /* skip to the end ? */
	  return (0);		/* isql_exit(1); */
	}
    }
  else
    {
      statement = nextword;
      goto do_it;
    }


  statement = get_next_token (&ptr, tmp5buf, TMPBUF_SIZE, NULL, 0);
  if (NULL == statement)
    {
      goto premature_end;
    }

do_it:;

/* If no BETWEEN is used, then statement may be preceded by the
   optional MIME_BOUNDARY 'TOKEN' pair. */
  if (!between_form && !strcasecmp (statement, _T("MIME_BOUNDARY")))
    {
      if (!(mime_boundary_token
	    = get_next_token (&ptr, tmp5buf, TMPBUF_SIZE, NULL, 0)))
	{
	  goto premature_end;
	}
      if (!(statement
	    = get_next_token (&ptr, tmp6buf, TMPBUF_SIZE, NULL, 0)))
	{
	  goto premature_end;
	}
    }

/* Then get the rest of the parameterized statement itself
   (upto the overwritten semicolon ; ). */
/* Just rewind ptr back to the beginning of statement: */
  ptr -= isqlt_tcslen (statement);

/*
   isql_printf(
   "optionword=%s,typeword=%s,nextword=%s,statement=%s,filename=%s,escaped=%d\n",
   w_or_null(optionword),w_or_null(typeword),w_or_null(nextword),
   w_or_null(statement),w_or_null(filename),escaped);
   fflush(stdout);
 */
  items_read =
    exec_for_foreach (statement,	/* 1st word: select, insert, etc. */
		      ptr,	/* The whole SQL-statement in input buffer */
		      (!strcasecmp (statement, _T("SELECT")) ||
		       !strcasecmp (statement, _T("CALL"))),	/* Has output? */
		      in_fp,	/* Is by default current_input_stream() */
		      (filename ? text : NULL),		/* As loadexpr */
		      end_token,	/* end token */
		      separating_token,		/* separating token */
		      mime_boundary_token,	/* Overrides above ones if given. */
		      &type,	/* pointer to type */
		      unpack_function_ptr,
		      own_inbuf,	/* Was: input, */
		      own_inbuf_size,	/* Was: INPUT_SIZE, */
		      between_form);

  if (verbose_mode)
    {
      isql_fprintf (stdout,
		    _T("-- foreach: %") PCT_S _T("%") PCT_S _T(" %d %") PCT_S _T("s %") PCT_S _T("%") PCT_S _T(" in %ld msec.\n"),
		    statement,
	      ((*(statement + isqlt_tcslen (statement) - 1) == 'e') ? _T("d") : _T("ed")),
		    items_read, typeword,
		    (filename ? _T("in ") : _T("")),
		    (filename ? filename : _T("")),
		    (((unsigned long int) get_msec_count ()) - start));
      fflush (stdout);
    }

  if (own_inbuf != input)	/* if(between_form) */
    {
      free (own_inbuf);
    }
  if (filename && (in_fp != stdin))
    {
      fclose (in_fp);
    }				/* Using IN */

  return (items_read);

premature_end:;

  isql_fprintf (error_stream,
   _T("\n*** Error: Input prematurely cut for foreach at line %ld of %") PCT_S _T(": %") PCT_S _T("\n"),
		latest_statement_begins_at (), current_loadexpr (), input);
error:
  if (following)		/* I.e. not reading from file */
    {
      skip_to_end_token (in_fp, &current_linecount (), end_token, input, INPUT_SIZE);
    }
  if (in_fp && (in_fp != stdin))
    {
      fclose (in_fp);
    }				/* Using IN */
  return (1);
}


int
isql_echo (TCHAR *text)
{
  int echoln = 0;		/* Is newline printed at the end? */
  int raw_mode = 0;		/* If 1, then never print it with HTTP-headers. (I.e. we are printing with it our own headers) */
  FILE *out_fp = stdout;	/* By default. */
  TCHAR *ptr, *word;
  TCHAR tmpbuf[TMPBUF_SIZE + 2];

  ptr = text;

  /* First, skip the ECHO command itself. */
  word = get_next_token (&ptr, tmpbuf, TMPBUF_SIZE, NULL, 0);
  if (NULL == word)
    {
      goto premature_end;
    }
  if (0 == strncasecmp (word, _T("ECHOLN"), (sizeof (_T("ECHOLN")) - 1)))
    {
      echoln = 1;
    }

  if (0 == strncasecmp ((word + isqlt_tcslen (word) - 3), _T("RAW"), 3))
    {
      raw_mode = 1;
    }

  /* If the next word begins with single or double quotes then
     output to stdout in any case.
   */

  ptr = skip_blankos (ptr);
  if (('"' == *ptr) || ('\'' == *ptr))
    {
      goto loop_start;
    }

  word = get_next_token (&ptr, tmpbuf, TMPBUF_SIZE, NULL, 0);
  if (NULL == word)
    {
      goto premature_end;
    }

  if (!strcasecmp (word, _T("stderr")))
    {
      out_fp = stderr;
    }
  else if (!strcasecmp (word, _T("stdout")))
    {
      out_fp = stdout;
    }
  else if (!strcasecmp (word, _T("error_stream")))
    {
      out_fp = error_stream;
    }
  else if (!strcasecmp (word, _T("both")))
    {
      out_fp = NULL;
    }
  else
    {
      isqlt_tcsncpy (isql_echo_word_buf, word, ISQL_ECHOBUF_SIZE);
      isql_echo_lwe = isql_echo_word_buf;
      goto right_in;
    }

loop_start:
  while (NULL != (word =
	 get_next_token (&ptr, isql_echo_word_buf, TMPBUF_SIZE, NULL, 0)))
    {
      isql_echo_lwe = word;
    right_in:
      if (NULL == out_fp)	/* I.e. echo to BOTH streams. */
	{
	  if (raw_mode)
	    {
	      isqlt_fputts (isql_echo_lwe, stdout);
	      isqlt_fputts (isql_echo_lwe, stderr);
	    }
	  else
	    {
	      isql_fputs (isql_echo_lwe, stdout);
	      isql_fputs (isql_echo_lwe, stderr);
	    }
	}
      else
	{
	  if (raw_mode)
	    {
	      isqlt_fputts (isql_echo_lwe, out_fp);
	    }
	  else
	    {
	      isql_fputs (isql_echo_lwe, out_fp);
	    }
	}
    }

  if (echoln)
    {
      TCHAR *newline = _T("\n");
      if (NULL == out_fp)	/* I.e. echo to BOTH streams. */
	{
	  if (raw_mode)
	    {
	      isqlt_fputts (newline, stdout);
	      isqlt_fputts (newline, stderr);
	    }
	  else
	    {
	      isql_fputs (newline, stdout);
	      isql_fputs (newline, stderr);
	    }
	}
      else
	{
	  if (raw_mode)
	    {
	      isqlt_fputts (newline, out_fp);
	    }
	  else
	    {
	      isql_fputs (newline, out_fp);
	    }
	}
    }

  if (NULL == out_fp)
    {
      fflush (stdout);
      fflush (stderr);
    }
  else
    {
      fflush (out_fp);
    }
premature_end:;
  return (1);
}


/* ================================================================ */
/*     STUFF FOR HELP AND PARSING ISQL COMMANDS, AND RELATED        */
/* ================================================================ */

/* Returns non-zero if text begins with cmd, and the next character
   is either a terminating zero (i.e. it also ends with cmd), or
   at least is something non-alpha-numeric, e.g. a white space.
   Note: old version uese !isalnum but load_xxx is the case
         tried to use isqlt_istspace instead of !isalnum
 */
int
is_cmd (TCHAR *text, TCHAR *cmd)
{
  int len = (int) isqlt_tcslen (cmd);
  return ((0 == strncasecmp (text, cmd, len))
	  &&
	  (empty_stringp (text + len) || isqlt_istspace (*(text + len)))
    );
}


#define is_arg is_cmd

void
isql_help (TCHAR *text)
{

  if (is_cmd (text, _T("SET")))
    {
      isql_printf (
_T("SET TIMEOUT sec       to set transaction timeout to sec seconds\n")
_T("    AUTOCOMMIT ON/OFF/MANUAL to set whether to autocommit or not.\n")
_T("                      Default is OFF\n")
_T("    READMODE SNAPSHOT or NORMAL to switch between non-locking and normal read\n")
/* Deprecated, replaced by READMODE above.
_T("    RO                to switch to non-locking historical (versioned) read\n")
_T("    RW                to switch to normal shared locking\n")
*/
_T("    ACCESSMODE RO or RW to switch between read-only and read-write connection\n")
_T("    MAXROWS num       to set the max. limit of rows printed with select.\n")
_T("                      Use the value zero to print always all rows.\n")
_T("    DEADLOCK_RETRIES num  to set the max. limit of deadlock retries.\n")
_T("    BLOBS ON or OFF   to control whether LONG VARCHAR columns are printed\n")
_T("    TIMES2STRINGS ON or OFF to control how timestamps are printed\n")
_T("    BANNER ON or OFF  to control whether the banner is shown with select\n")
_T("    TYPES ON or OFF   to control whether column types are shown in banner\n")
_T("    VERBOSE ON or OFF to control whether information about execution times,\n")
_T("                      etc, are printed.\n")
_T("    PROMPT New Prompt> or OFF to set the new prompt or turn off prompting\n")
_T("    HIDDEN_CRS CLEARED or PRESERVED to control whether trailing CRs of MS-DOS\n")
_T("                   files are cleared from foreach blobs. Note that all explicit\n")
_T("                   \\15 escape-sequences are always kept in the content.\n")
_T("    ERRORS STDOUT or STDERR to control where error messages are directed.\n")
_T("    ECHO ON or OFF    to control whether statements are echoed.\n")
_T("Use SHOW to show the current values of these parameters.\n"));

      if (print_prompt)
	{
	  isql_printf (_T("Help more?>"));
	  getchar ();
	}

      isql_printf (
_T("You can specify these options on the command line also, for example\n")
_T("%") PCT_S _T(" VERBOSE=OFF BANNER=OFF PROMPT=OFF BLOBS=ON ERRORS=STDOUT\n")
_T("You can also run one or more ISQL-commands directly from the command line with\n")
_T("EXEC=statement option. E.g. \"EXEC=select * from fyyl\" The statement(s)\n")
_T("are executed and no further input is asked, unless foreach statement is used.\n"),
progname
	);
    }

  else if (is_cmd (text, _T("FOREACH")))
    {
      isql_printf (
_T("FOREACH [HEXADECIMAL/ESCAPED/NONESCAPED] INTEGER/LINE/BLOB [IN <filename>]\n")
_T(" <sql statement with one parameter, and one or more special parameters>\n")
_T("\n")
_T("If  IN <filename>  part is omitted then data is read from standard input\n")
_T("until a line beginning with the keyword END is encountered.\n")
_T("To insert in this mode a line beginning with END into a string or a blob\n")
_T("you have to prefix it with the escape character backslash (e.g. \\END)\n")
_T("Also you can use in line or blob data all standard C-like escapes:\n")
_T("\\n for newline, \\ooo for any octal byte ooo, even \\0 for a null byte,\n")
_T("unless you explicitly turn the backslash parsing off with NONESCAPED option.\n")
_T("\n")
_T("If  IN <filename>  is present, then data is read from the file <filename>\n")
_T("and by default, unless ESCAPED option is explicitly specified, there is no\n")
_T("checking either for any escape characters or the END keyword, instead\n")
_T("the data is read in just as it occurs, upto the end of that file.\n")
_T("\n")
_T("Except the standard ? you can use the following 'special parameters' in the\n")
_T("statement: ?R for repeating the previous parameter, ?1, ?2 for using the first,\n")
_T("second, nth parameter. ?C is the special parameter bound to consecutive\n")
_T("integers from 1 onward, which is the count of successful operations so far,\n")
_T("e.g. you can use it in INSERT to generate unique values for the primary key.\n")
	);
      if (print_prompt)
	{
	  isql_printf (_T("Help more?>"));
	  getchar ();
	}

      isql_printf (
_T("Examples:\n\n")
_T("FOREACH LINE IN words.lst INSERT INTO wordtable(word,len) VALUES(?,length(?1));\n")
_T("  Inserts each line from the file words.lst (with the trailing newline removed)\n")
_T("  into the table wordtable, whose column named word should be of type VARCHAR,\n")
_T("  and defined as a primary key. At the same time, then length of the word is\n")
_T("  put into column len. If there are any duplicate lines in words.lst then a\n")
_T("  warning message is printed for them, but the execution still continues.\n")
_T("\n")
_T("FOREACH INTEGER SELECT humpty FROM pumpkin WHERE dumpty = ?;\n")
_T("  Inputs numbers from user, and selects from the table pumpkin those humpties\n")
_T("  whose dumpty is in the values given by the user. Doesn't output any banners.\n")
_T("\n")
_T("FOREACH HEXADECIMAL INTEGER dbg_printf('%%d times %%d is %%d',?,?C,?C*?1);\n")
_T("  Inputs hexadecimal numbers from user (until stopped with END) and shows on\n")
_T("  the console of server what their product is with a line count.\n")
_T("\n")
_T("FOREACH BLOB IN picture1.gif INSERT INTO pictures(pid,pictdata) VALUES(1,?);\n")
_T("  Insert the file picture1.gif as a blob into the table pictures, with\n")
_T("  a primary key pid set to one. Column pictdata should have been defined as of\n")
_T("  type LONG VARCHAR. When reading blobs from files this way, it is not\n")
_T("  possible to read more than one blob from one file. Instead, the whole file\n")
_T("  is inserted as one blob, in the exact binary format.\n")
	);
    }

  else
    {
      isql_printf (
_T("OpenLink Interactive SQL ") ISQL_TYPE _T(".\n")
_T("Type a SQL statement followed by a ';'.\n")
_T("\n")
_T("Database and Table information:\n")
_T("    TABLEQUALIFIERS                  Show all qualifiers\n")
_T("    TABLEOWNERS                      Show all owners\n")
_T("    TABLETYPES                       Show all table types\n")
_T("    TABLES [tablename_pattern] [/table_type]  Show tables in the database.\n")
_T("    e.g: TABLES a%%/TABLE; (Show all ordinary tables beginning with 'a')\n")
_T("    COLUMNS [tablename] [/colname]   COLUMNPRIVILEGES tablename [/colnamepat]\n")
_T("    PROCEDURES [procname_pattern]    TABLEPRIVILEGES [tablename_pattern]\n")
_T("    PRIMARYKEYS [tablename]          STATISTICS [tablename] (show indices)\n")
_T("    SPECIALCOLUMNS [tablename][/B]   GETTYPEINFO\n")
_T("    FOREIGNKEYS [tablename][/tablename]\n")
_T("\n")
#ifndef ODBC_ONLY
_T("Server Management:\n")
_T("    SHUTDOWN [log];    Shut server.\n")
_T("                       If [log] is given, preserve old log and make [log]\n")
_T("                       new transaction log file.\n")
_T("    CHECKPOINT [log];  Make a checkpoint.\n")
_T("                       If [log] is given, preserve old log and make [log]\n")
_T("                       new transaction log file.\n")
_T("    status()           Display database server status.\n")
#endif
_T("\n")
_T("Other commands:\n")
_T("    FOREACH   Execute parameterized statement multiple times. See HELP FOREACH\n")
_T("    CALL <procedure> (<argument>...)   Call the procedure and display\n")
_T("        result sets. Result sets are not shown if the CALL keyword is omitted.\n")
_T("    SET          Set various parameters. Type HELP SET to see them.\n")
_T("    SHOW         Show current values of various parameters.\n")
_T("    LOAD <file>  Load and execute statements from <file>.\n")
_T("    HELP         Show this help text. HELP topic  Show help on some topics.\n")
_T("    EXIT         Exit %") PCT_S _T("\n"), progname);
    }
  fflush (stdout);
}


int
add_file_to_be_loaded (TCHAR *filename)
{
  if (load_n_files < MAX_FILES_FROM_COMMAND_LINE)
    {
      files_to_load[load_n_files++]
	= chestrdup (filename, _T("add_file_to_be_loaded"));
      return (load_n_files);
    }
  else if (load_n_files == MAX_FILES_FROM_COMMAND_LINE)
    {
      isql_fprintf (error_stream,
		    _T("%") PCT_S _T(": Max. %d files can be specified at the command line, ignoring all\n")
		    _T("files from %") PCT_S _T(" onward.\n"),
		    progname, MAX_FILES_FROM_COMMAND_LINE, filename);
      load_n_files++;
    }
  else
    {				/* Do nothing, just skip the filenames. */
    }

  return (0);			/* Doesn't fit into vector anymore, return zero as status */
}


TCHAR *
get_arg_after_braces (TCHAR *arg, TCHAR *tmp2buf, int bufsize, int get_all_raw)
{				/* Arg should be pointing to the closing brace or bracket or paren. */

  /* Search for the first point after a closing bracket: */
  for (; *arg && !isqlt_istspace (*((UTCHAR *) arg)) && (*arg != '='); arg++)
    {
    }
  arg = skip_blankos (arg);	/* And now to = or value itself. */
  if ('=' == *arg)		/* A command line option or var=val syntax? */
    {
      arg++;			/* Skip past the equal sign to the value itself. */
    }

/* Then run arg through get_next_token so that $-macros are handled right */
  if (0 == get_all_raw)
    {
      arg = get_next_token (&arg, tmp2buf, bufsize, NULL, 0);
    }
  /* if(NULL == arg) { } *//* Nothing following, set it to NULL */

  return (arg);
}



/* This might later contain a matching function: */
#define show_this_one(A) (show_instead_of_set && !*(A))

#define set_or_show_this_one(A)\
 ((is_macro_name (macro_name,(A)) && (just_this_one=1)) ||\
  ( (just_this_one=0), show_this_one((macro_name)) ) )

/* Might be called from is_isql_command (with the text
   argument being a pointer to after SET or SHOW word)
   or from the main with text argument being something
   like BLOBS=ON
   (Now also for HTTP URL-variables if used in web_mode)

   Returns 0 if text is not recognizable ISQL command,
   e.g. if it is just a syntax error, or real SQL-command
   like SET PASSWORD or SET USER GROUP that needs to be sent
   to the server.
   Returns 1 if text is a valid ISQL command.
   Returns 2 if text is a valid ISQL command that would require
   a full connection to the datasource, but we have not
   connected yet. In that case the text is saved to delayed_settings
   vector and 2 is returned.

 */

#define is_url_option(command_line_option) (2 == command_line_option)

#define is_set_subcommand(T,S,C) is_set_subcommand_aux((T),(S),(C),0)

/* If ending_point is non-zero, then this is called from
   handle_multipart_form and no urldecoding should be used.
   Check and clear this later!
 */
int
is_set_subcommand_aux (TCHAR *text, int show_instead_of_set,
		       int command_line_option,
		       int ending_point)
{
  int just_this_one = 0;
  TCHAR *argptr, *arg;
  TCHAR *fun = _T("is_set_subcommand");
  struct name_var_pair *macro_info;
  TCHAR *macro_name;
  TCHAR tmp0buf[TMPBUF_SIZE + 2], tmp1buf[TMPBUF_SIZE + 8];

/*  char *str_ptr = text; */

  /* The following is probably unnecessary but let's be absolutely sure
     that text points to the beginning of macro/option name to be set/shown: */
  text = skip_blankos (text);
  argptr = text;

/*
   isql_fprintf(error_stream,"is_set_subcommand_aux: argptr=%s, ending_point=%d\n",argptr,ending_point);
   fflush(error_stream);
 */

  /* First get the macro word to be set/shown: */
  if (NO (macro_name = get_next_token (&argptr, tmp0buf, TMPBUF_SIZE,
				       NULL, 0)))
    {
/* There was nothing following the SET or SHOW command. Let's
   return just zero for SET, to tell the calling function to send the
   command to the server instead, which presumably will give a
   syntax error, and for empty SHOW we dump all the settable macros
   out. */
      if (show_instead_of_set)	/* For empty SHOW commands */
	{
	  dump_all_settable_variables (macro_name);	/* Arg not used now. */
	  return (1);
	}
      else
	{
	  return (0);
	}
    }

  if (is_url_option (command_line_option))
    {
      int len = (int) isqlt_tcslen (SYSTEM_VARIABLE_URL_PREFIX);
      if (0 == isqlt_tcsncmp (macro_name, SYSTEM_VARIABLE_URL_PREFIX, len))
	{
	  macro_name += len;	/* If there's a prefix, then skip it. */
	  text += len;		/* Also the text itself, if it is saved for later
				   consumption. */
	}
      else
	/* No prefix, wrap it inside U{' and '} */
	{			/* Where U stands for User/URL variables. */
	  /* This only happens when we are called for command line
	     or URL options, so input buffer should be free.
	     When called from handle_multipart_form input is used,
	     but in that case there is enough space reserved for
	     this operation...
	     (This is much too kludgous now...)
	   */
	  argptr = skip_blankos (argptr);
	  isqlt_stprintf (input, _T("{'%") PCT_S _T("'}"), macro_name);
	  my_strncat (input, argptr, INPUT_SIZE);
	  argptr = input;
	  macro_name = _T("U");
	}
    }

/*
   isql_fprintf(error_stream,"is_set_subcommand_aux: macro_name=%s, argptr=%s\n",
   macro_name,argptr);
   fflush(error_stream);
 */

  /* argptr now points to the first char after macro name. */
  argptr = skip_blankos (argptr);	/* And now to = or value itself. */
  if ('=' == *argptr)		/* A command line option or SET VAR=VAL syntax. */
    {
      argptr++;			/* Skip past the equal sign to the value itself. */
    }

/* Special: Set the SQL-command to be executed from the command line.
   Run this before taking arg from argptr with get_next_token,
   if this makes it any better...
   Because sometimes it would crash isql if it were run after the
   call to get_next_token and text were long enough and/or contained
   something peculiar...
   (happens e.g. with spawning in tconcur2.sql test).
   Probably this indicates a presence of a nasty bug in get_next_token
   that awaits to be corrected...
 */
  if (NO show_instead_of_set && is_macro_name (macro_name, _T("EXEC")))
    {
      if (execs_from_cmdline >= MAXEXECS_FROM_CMDLINE)
	{
	  isql_fprintf (error_stream,
			_T("\n%") PCT_S _T(": **Too many EXECs from command line. Max. %d allowed. (%") PCT_S _T(" is %dth)\n"),
	   progname, MAXEXECS_FROM_CMDLINE, text, (execs_from_cmdline + 1));
	  isql_exit (1);
	}
      execute_these_only[execs_from_cmdline++]
	= (ending_point ? chestrdup (argptr, fun) : ((TCHAR *) parse_url_value ((UTCHAR *) argptr)));
/* We always need apply parse_url_value here whether this is used
   via Web or not, as spawning syntax (lines ended with &,
   see function spawn_to_background) gives its EXEC=option to a new
   spawned subprocess of isql as URL-percent-encoded, done with
   the function urlify (to avoid all stupidities with single and
   doublequotes) */
      return 1;
    }

  /* In web-mode we always run args through unurlify process,
     unless the data comes from multi-part form.
     Note that parse_url_value does a conversion in place, producing
     possibly a shorter string than original (i.e. if there were any
     percent-escapes used).
   */
  if (web_mode && command_line_option && !ending_point)
    {
      parse_url_value (UCP (argptr));
    }

/* Then run arg through get_next_token so that $-macros are handled right,
   and leave argptr to point to the beginning of arg, in raw mode.
   (In case of $U{stuff} and $ARGV  [index] it will first point to the
   opening brace or bracket.)
 */
  arg = argptr;

/*
   Before the version "0.9849b" the condition was like this:
   (which is quite illogical, as it applies only to multipart-forms)

   if(!ending_point) ...

   Replaced by this:
 */
  if (!command_line_option	/* Given with explicit SET from ISQL-prompt? */
/*    ||  Or begins with a dollar, if from command-line, URL or multipart-form?
   ('$' == *arg)   but commented out also! See below. */
    )
    {
      arg = get_next_token (&arg, tmp1buf, TMPBUF_SIZE, NULL, 0);
    }
  if (NULL == arg)
    {
      arg = _T("");
    }				/* Nothing following. */


/* Problem:
   How the user can give text beginning with dollars via Web-forms?

   Why the dollar is not instead in the end of the variable to be set?

   So, instead of:
   <INPUT TYPE=TEXT NAME=BKFILE SIZE=20 VALUE="&#36;YYYYMMDD&#46;log">
   we would have:

   <INPUT TYPE=TEXT NAME="BKFILE&#36;" SIZE=20 VALUE="YYYYMMDD&#46;log">

   Balderash! Currently, we won't need that. If there's an input-field
   beginning with a dollar, coming from HTML-form or command-line arg,
   then it's handled literally, as a piece of text beginning with a
   dollar.
   User can still embed dollar-forms in statements given with S_EXEC
   from HTML-forms, and they will have their normal effect.
 */

/* Ignore all empty URL input variables like
   &AUTOCOMMIT=&READMODE=&TIMEOUT= etc... in web mode,
   as well as all empty settings from command line, e.g.
   like in case isql TIMEOUT=%1  where %1 is not given,
   that is, keep their default values.
 */
  if (NOT show_instead_of_set && command_line_option &&
      ((NOT arg) || empty_stringp (arg)))
    {
      return (1);
    }


  if ((macro_info = find_var_info (macro_name)) &&
      (show_instead_of_set || is_settable_macro_type (macro_info)))
    {				/* It's a standard macro found from the list isql_variables */
      int stat;
      TCHAR *value;

      if (show_instead_of_set)
	{
	  value = convert_macro_to_text (macro_info, &argptr,
					 tmp1buf, TMPBUF_SIZE,
					 NULL, 0, 1);
	  if (NULL == value)
	    {
	      value = _T("NULL");
	    }
	  isql_fputs (macro_info->name, stdout);
	  isql_fputs (_T("\tis "), stdout);
	  if (in_HTML_mode () && oo_esc)
	    {
	      html_print_escaped (value, stdout);
	    }
	  else
	    {
	      isql_fputs (value, stdout);
	    }
	  isql_fputs (_T("\n"), stdout);
	  fflush (stdout);
/* WAS: isql_printf("%s\tis %s\n",macro_info->name,(value ? value : "NULL")); */
	}
      else
	{
/* All SAM_macros (like AUTOCOMMIT, READMODE, TIMEOUT) need a
   connection to be established and a statement handle to be
   allocated, so if we are not yet fully connected, then we
   just save the setting text (e.g. AUTOCOMMIT=ON or TIMEOUT=86400)
   to the delayed_settings vector, which is then later, after the
   connection has been made, passed through, with this function
   (is_set_subcommand) called once again for each element. Note
   that this means that parse_url_value is called twice for these
   delayed settings, but currently it doesn't matter, as all the
   arguments of these should be simple strings like ON, OFF, RO,
   RW, numbers like 1000, etc.
   (Even "+1234" is corrupted only slightly, to " 1234", which is
   effectively the same number).
 */

	  if (command_line_option && (NOT fully_connected) &&
	      macro_needs_connection (macro_info))
	    {
	      if (n_delayed_settings >= MAX_DELAYED_SETTINGS)
		{
		  isql_fprintf (error_stream,
				_T("\n%") PCT_S _T(": **Too many delayed settings from command line. Max. %d allowed. (%") PCT_S _T(" is %dth)\n"),
				progname, MAX_DELAYED_SETTINGS, text, n_delayed_settings + 1);
		  isql_exit (1);
		}
	      else
		{
		  delayed_settings[n_delayed_settings++]
		    = (ending_point ? chestrdup (text, fun) : text);
		}
	      return (2);	/* Was 1. */
	    }
	  else
	    /* Normal usage. Just set it. */
	    {
#ifdef WIN32
	      int old_flag_binary_output = flag_binary_output;
#endif
	      stat = set_value_to_macro (macro_info, arg, argptr, ending_point);
#ifdef WIN32
/* BINARY_OUTPUT=ON is a Windows kludge for avoiding that
   NL's are converted to CR+LF's in output. Needed for the exact
   fetching of blobs (Use together with TRAILING_NEWLINE=0).
   On Unix platforms BINARY_OUTPUT is NO-OP.
 */
	      if (flag_binary_output != old_flag_binary_output)
		{
		  setmode (fileno (stdout),
			   (flag_binary_output ? _O_BINARY : _O_TEXT));
		}
#endif
	    }
	}

      return (1);
    }				/* macro_info for this name was found. */


/* If not found from the standard macro list, then it might be one of
   the remaining special options, LOAD, ARGV */

/* Difference between LOAD=filename and plain filename (given as
   fourth or later non-option command line argument) is that
   in web_mode with LOAD= the filename is passed through parse_url_value.
 */
  if (NO show_instead_of_set && is_macro_name (macro_name, _T("LOAD")))
    {
      add_file_to_be_loaded (arg);
      return 1;
    }

  if (set_or_show_this_one (_T("ARGV")))	/* Mainly for debugging */
    {
      int i;
      if (show_instead_of_set)	/* !command_line_option */
	{
	  isql_printf (_T("ARGC=%d, ARGV="), G_argc);
	  fflush (stdout);
	  for (i = 0; i < G_argc /* G_argv[i] */ ; i++)
	    {
	      if (i > 0)
		{
		  isql_putchar (' ');
		}
	      isql_fputs ((G_argv[i] ? G_argv[i] : _T("NULL")), stdout);
	    }
	  isql_putchar ('\n');
	  fflush (stdout);
	}
/* Overriding of ARGV[ind] values added by AK 19-APR-1997 for the needs
   of test procedures. This allows a kludgous way of having at least few
   user-modifiable variables on the client side. I hope that argv vector
   is not defined strictly constant in any of our platforms. In that
   case we would have to make a copy of the original argv to G_argv.
 */
      if (NOT show_instead_of_set)
	{
	  TCHAR *openptr, *closeptr;
	  int indnum = -1;

/* if(('[' == *(openptr = skip_blankos(text+sizeof("ARGV")-1))) && */
	  if (('[' == *(openptr = skip_blankos (argptr))) &&
/* Was: (closeptr = isqlt_tcschr(text+1,']')) replaced by this: */
	      (closeptr = SCP (find_closing_point (UCP (openptr),
						   ((UTCHAR) * openptr))))
	    )
	    {
	      TCHAR tmp2buf[TMPBUF_SIZE + 2];
	      TCHAR *indstr;

	      closeptr++;	/* Skip past the closing bracket. */

	      openptr++;	/* Past the opening bracket. */
	      if (NO (indstr = get_next_token (&openptr, tmp2buf, TMPBUF_SIZE,
					       NULL, 0)))
		{
		  goto ertzu;
		}		/* Shouldn't really happen! (as there is ]) */

	      indnum = isqlt_tstoi (indstr);	/* Shouldn't care about closing ] */

	      if ((indnum < 0) || (indnum > G_argc))
		{
		  goto ertzu;
		}

	      arg = get_arg_after_braces (closeptr, tmp2buf, TMPBUF_SIZE, ending_point);

	      if ((indnum < sizeof (G_argv_touched)) &&
		  G_argv_touched[indnum] && G_argv[indnum])
		{
		  free (G_argv[indnum]);
		}		/* Not virginal, not NULL. */
	      G_argv[indnum] = (arg ? chestrdup (arg, text) : arg);
/* Mark changed argv vector elements, so that we can next time free
   those strdupped strings:
   (We should not free the original virgin elements!) */
	      if (indnum < sizeof (G_argv_touched))
		{
		  G_argv_touched[indnum] = 1;
		}
	      return (1);
	    }
	ertzu:
	  isql_fprintf (stdout,
			_T("Use set ARGV[ind] newelem   to override the old value of $ARGV[ind]\n"));
	  isql_fprintf (stdout,
		      _T("ind must be between 0 and %d, inclusive.\n"), G_argc);
	  return 1;
	}			/* if(NOT show_instead_of_set) */
      if (just_this_one)
	{
	  return 1;
	}
    }

/* These two are deprecated features, kept here just for the backward
   complicity's sake, please use the new READMODE=SNAPSHOT and
   READMODE=NORMAL options instead. */
  if (is_macro_name (macro_name, _T("RO")))
    {
      isql_fprintf (error_stream,
		    _T("%") PCT_S _T(": Warning: SET RO is deprecated feature, please use SET READMODE=SNAPSHOT instead!\n"),
		    progname);
      fflush (error_stream);
      if ((NOT fully_connected))	/* Requires connection. */
	{
	  connect_to_datasource (datasource, username, password);
	}

      /* Was: SQL_CONCUR_ROWVER but SQL_CONCUR_TIMESTAMP is same */
      SQLSetStmtOption (stmt, SQL_CONCURRENCY, SQL_CONCUR_TIMESTAMP);
      /* versioned read */
      return 1;
    }
  if (is_macro_name (macro_name, _T("RW")))
    {
      isql_fprintf (error_stream,
		    _T("%") PCT_S _T(": Warning: SET RW is deprecated feature, please use SET READMODE=NORMAL instead!\n"),
		    progname);
      fflush (error_stream);
      if ((NOT fully_connected))	/* Requires connection. */
	{
	  connect_to_datasource (datasource, username, password);
	}
      SQLSetStmtOption (stmt, SQL_CONCURRENCY, SQL_CONCUR_READ_ONLY);
      /* Normal shared locking */
      return 1;
    }

  else if (NOT show_instead_of_set)
/* If nothing (of the above ones) was after SET then ... */
/* Send the command to the server, as it might be SET PASSWORD, etc,
   unless this is called for command_line (or url) option, in which
   case print a warning message. */
    {
      if (command_line_option)
	{
	  isql_fprintf (error_stream,
			_T("%") PCT_S _T(": Warning: \"%") PCT_S _T("\" is unknown option, ignored!\n"),
			progname, macro_name);
	  fflush (error_stream);
	}
      return (0);
    }

  return (1);
}


int
is_isql_command (TCHAR *text, integer_list * pidlist)
{
  TCHAR *args, *arg1, *cmd, *next;
  int is_show = 0;
  TCHAR tmp0buf[TMPBUF_SIZE + 2], tmp1buf[TMPBUF_SIZE + 2];

/*  get_rid_of_trailing_newline(text);  Not necessary anymore? */

  text = skip_blankos (text);
  args = text;

  if ('!' == *text)
    {				/* Spawn a command to shell and wait for it if doesn't end with & */
      TCHAR edel = ';';
      spawn_shell_command ((text + 1), pidlist, (edel != '&'));
      return (1);
    }

  cmd = get_next_token (&args, tmp0buf, TMPBUF_SIZE, NULL, 0);
  if (NULL == cmd)
    {
      return (1);
    }				/* Empty commands are NO-OPs */


  args = skip_blankos (args);

/* SET and SHOW might or might not need a connection.
   If is_set_subcommand returns zero, it means there was a command
   it didn't recognize, e.g. SET PASSWORD or SET USER GROUP, which is a
   SQL command that should be sent to the server.
   If the return code is 1, then the command was ISQL set or show
   command executed all right, and requiring no further action.
   If the return code is 2, then the command was ISQL set command
   like SET AUTOCOMMIT=ON, that requires a full connection to be
   established, and we have not connected yet.

   Call is_set_subcommand here, before the following get_next_token
   to avoid double-call for the same macro-name (get_next_token
   is also called in is_set_subcommand).
 */

  if (((is_show = 0), is_cmd (cmd, _T("SET")))
      || ((is_show = 1), is_cmd (cmd, _T("SHOW"))))
    {
      int stat = is_set_subcommand (args, is_show, 0);
      if ((1 != stat) && (NOT fully_connected))
	{
	  /* This function also executes all the delayed settings: */
	  connect_to_datasource (datasource, username, password);
	}
      return (stat);
    }

  next = args;			/* because get_next_token will change its first argument. */

  /* arg1 can be set also to NULL, if there is nothing following the command */
  arg1 = get_next_token (&next, tmp1buf, TMPBUF_SIZE, NULL, 0);

  /* Now: text = points to beginning of command,
     args = pointer to beginning of arguments.
     cmd  = command word,
     arg1 = first argument
   */

  if (is_cmd (cmd, _T("NOP")))	/* Do nothing, just a NOP. */
    {
      return (1);
    }

  if (is_cmd (cmd, _T("ECHO")) || is_cmd (cmd, _T("ECHOLN"))
      || is_cmd (cmd, _T("ECHORAW")) || is_cmd (cmd, _T("ECHOLNRAW")))
    {
      isql_echo (text);
      return (1);
    }

  if (is_cmd (cmd, _T("WAIT_FOR_CHILDREN")))
    {
      wait_for_all_children (pidlist);
      return (1);
    }

  if (is_cmd (cmd, _T("LOAD")))
    {
      int rawload = 0;

      if (args && arg1 && ('"' != *args) && !strcasecmp (arg1, _T("-r")))
	{			/* If user gave the -r option (not in quotes!), then we use
				   raw_load, and have to get the filename following the option. */
	  rawload = 1;
	  arg1 = get_next_token (&next, tmp1buf, TMPBUF_SIZE, NULL, 0);
	}
      load_file (arg1, rawload, text);
      return (1);
    }

  if (is_cmd (cmd, _T("HELP")))
    {
      isql_help (args);
      return 1;
    }

  if (is_cmd (cmd, _T("EXIT")) || is_cmd (cmd, _T("QUIT")))
    {
      int status;
      /* EXIT NOT is NO-OP, allowing statements like:
         EXIT $IF $EQU $ARGV[0] 10 $ARGV[0] NOT;
         which exits with exit code 10 if $ARGV[0] is ten
         (presumably keeping a somekind of failure counter)
         but otherwise does nothing special, and continues
         from the next statement.
       */
      if (arg1 && (0 == strcasecmp (arg1, _T("NOT"))))
	{
	  return (1);
	}
      status = (arg1 ? isqlt_tstoi (arg1) : 0);
      isql_exit (status);
    }

  if (is_cmd (cmd, _T("SLEEP")))
    {
      int seconds = (arg1 ? isqlt_tstoi (arg1) : 0);
      isql_sleep (seconds);
      return (1);
    }


/* Without arguments forces the connection to be made with an ordinary
   way with SQLConnect. With an argument uses SQLDriverConnect, giving
   that argument as a connection string (e.g. "DSN=Kubl;UID=DBA,PWD=DBA")
   If we are already connected, then is just NO-OP which is silently
   ignored.
 */

  if (!debug_session && is_cmd (cmd, _T("CONNECT")))
    {
      if ((NOT fully_connected))
	{
	  if (arg1)
	    {
	      connect_to_datasource (arg1, NULL, NULL);
	    }
	  else
	    {
	      connect_to_datasource (datasource, username, password);
	    }
	}
      return (1);
    }


  if (!debug_session && is_cmd (cmd, _T("RECONNECT")))
    {
      if (fully_connected)
	{
	  SQLFreeStmt (stmt, SQL_DROP);
	  SQLDisconnect (hdbc);
	  SQLFreeConnect (hdbc); /* iodbc needs the realloc */
	  SQLAllocConnect (henv, &hdbc);
	  fully_connected = 0;
	}
      if ((NOT fully_connected))
	{
	  if (arg1)
	    {
	      connect_to_datasource (datasource, arg1, NULL);
	    }
	  else
	    {
	      connect_to_datasource (datasource, username, password);
	    }
	}
      return (1);
    }

/* All the rest need the connection to be established, also all
   the commands that are not matched here, e.g. all SQL CLI/ODBC
   Catalog API commands like TABLES, PRIMARYKEYS, etc, and everything
   else that by definition should be sent to the server. */

  if ((NOT fully_connected))
    {
      connect_to_datasource (datasource, username, password);
    }

  if (is_cmd (cmd, _T("FOREACH")))
    {
      isql_foreach (text);
      return (1);
    }

#ifndef ODBC_ONLY
  if (is_cmd (cmd, _T("SHUTDOWN")))
    {
      SQLExecDirect (stmt, UCP (cmd), SQL_NTS);
      isql_exit (0);
    }
#endif
  return 0;
}



int
version_less_than (TCHAR *s, int major, int minor)
{
  int tmp;
  while (*s && NOT isqlt_istdigit (*s))
    {
      s++;
    }				/* Skip non-digits. */
  if (empty_stringp (s))
    {
      return (0);
    }				/* Premature end? */
  tmp = isqlt_tstoi (s);
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
  tmp = isqlt_tstoi (s);
  return (tmp < minor);
}

#if defined (WIN32)
#define _PASSWORD_LEN 128
#define ENTER_CODE 0x0D
/* because the M$ doesn't have a getpass, so let's implement it */
TCHAR *
isqlt_tgetpass(const TCHAR *szPrompt)
{
  static TCHAR szPassword[_PASSWORD_LEN];
  TCHAR *szCurrent = szPassword;

  isqlt_tcprintf(_T("%") PCT_S, szPrompt);
  while (szCurrent - szPassword < _PASSWORD_LEN - 2 && ENTER_CODE != (*szCurrent = _getch()))
    szCurrent++;
  *szCurrent = 0;
  isqlt_tcprintf(_T("\n"));
  return (szPassword);
}
#elif defined (HPUX_10) || defined (HPUX_11)
#include <termios.h>
#define _PASSWORD_LEN 128
#define ENTER_CODE '\n'
/* because the HP/UXes getpass() truncates to 8 chars, so let's implement it */
TCHAR *
isqlt_tgetpass(const TCHAR *szPrompt)
{
  static TCHAR szPassword[_PASSWORD_LEN];
  TCHAR *szCurrent = szPassword;
  struct termios old, new;

  isql_printf(_T("%") PCT_S, szPrompt);
  tcgetattr (fileno (stdin), &old);
  new = old;
  new.c_lflag &= ~ECHO;
  tcsetattr (fileno (stdin), TCSAFLUSH, &new);

  while (szCurrent - szPassword < _PASSWORD_LEN - 2 && ENTER_CODE != (*szCurrent = getchar()))
    szCurrent++;

  tcsetattr (fileno (stdin), TCSAFLUSH, &old);
  *szCurrent = 0;
  isql_printf(_T("\n"));
  return (szPassword);
}
#endif

/* If username is given as NULL pointer, then calls SQLDriverConnect
   (with datasource argument as a whole connection string)
   instead of SQLConnect. No dialogues are prompted for, as no windows
   are used.
 */
int
connect_to_datasource (TCHAR *datasource, TCHAR *username, TCHAR *password)
{
  long ignore;
  int rc;
  int retries = 0;

#ifdef COMMENTED_OUT
/* (see function print_http_headers_if_not_already_printed) */
  if (web_mode)
    {				/* Print the HTML headers, as this is the last change to do it. */
      {
	if (NOT isql_echo_lwe)	/* No output done yet with ECHO command? */
	  {
	    isql_printf (_T("Content-Type: %") PCT_S _T("\r\n\r\n"), web_content_type);
	    if (in_HTML_mode ())
	      {
		/* Show the statement(s) to be executed in the title: */
		html_print_head_title (stdout, _T("Virtuoso ISQL"), _T(": "),
				       execute_these_only[0]);
		isql_fputs (oo_ob, stdout);	/* And the Otherness Begins, i.e. <PRE> */
	      }
	    fflush (stdout);
	  }
      }
    }
#endif

  if (NULL == username)
    {
#if defined (NO_DRIVER_CONNECT)
      isql_fprintf (error_stream,
		    "%") PCT_S _T(": SQLDriverConnect not available on this platform. Please use SET DSN, UID and PWD commands before CONNECT command without arguments to connect. Connection string was: \"%s\"\n",
		    progname, datasource);
      isql_exit (1);
#else
      SWORD conn_str_length;
      TCHAR completed_conn_string[1001];

#ifdef ODBC_ONLY
      TCHAR dsn2[512];
      if (isqlt_tcsncmp (datasource, _T("DSN="), 4))
	{
	  isqlt_stprintf (dsn2, _T("DSN=%") PCT_S, datasource);
	  datasource = dsn2;
	}
#endif

      isqlt_tcscpy (completed_conn_string, _T("NOT SET"));

      if (SQL_SUCCESS !=
	  (rc = SQLDriverConnect (hdbc, NULL,	/* No window handle */
				  (UTCHAR *) datasource, SQL_NTS,
				  ((UTCHAR *) completed_conn_string),
				  (sizeof (completed_conn_string) - 2),
				  &conn_str_length,
				  SQL_DRIVER_COMPLETE)))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	  isql_fprintf (error_stream,
			_T("%") PCT_S _T("connect with connection string \"%") PCT_S _T("\". Completed as: \"%") PCT_S _T("\", length=%d\n"),
			((SQL_ERROR == rc) ? _T("could not ") : _T("")),
			datasource, completed_conn_string, conn_str_length);
	  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	    isql_exit (3);
	}
      else if (verbose_mode)	/* A success */
	{
	  isql_fprintf (error_stream,
			_T("connected with connection string \"%") PCT_S _T("\". Completed as: \"%") PCT_S _T("\", length=%d.\n"),
			datasource, completed_conn_string, conn_str_length);
	}
#endif
    }
  else
    /* if(username) Normal usage. */
    {
#ifndef ODBC_ONLY
      SQLSetConnectOption (hdbc, SQL_ENCRYPT_CONNECTION, (SQLULEN)encryption);
      SQLSetConnectOption (hdbc, SQL_SERVER_CERT, (SQLULEN)ca_list);
      SQLSetConnectOption (hdbc, SQL_PWD_CLEARTEXT, (SQLULEN)pwd_cleartext);
      SQLSetConnectOption (hdbc, SQL_SHUTDOWN_ON_CONNECT, (SQLULEN)virtuoso_shutdown);
#endif
      if (!password)
        {
	  password = username;
again:
	  rc = SQLConnect (hdbc, (UTCHAR *) datasource, SQL_NTS,
			    (UTCHAR *) username, SQL_NTS,
			    (UTCHAR *) password, SQL_NTS);
	  if (SQL_SUCCESS != rc && SQL_SUCCESS_WITH_INFO != rc)
	    {
	      TCHAR szPrompt[256];

	      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT, rc);

	      if (!isqlt_tcscmp (_T("28000"), SQL_error_state))
		{
		  if (++retries > 3)
		    {
		      isql_exit (3);
		    }
		  isqlt_stprintf(szPrompt, _T("\nEnter password for %") PCT_S _T(" :"), username);
#if defined (SOLARIS)
		  password = getpassphrase(szPrompt);
#else
		  password = isqlt_tgetpass(szPrompt);
#endif
#if 0 		 /* bug #4882 */
		  if (!*password)
		    isql_exit(3);
#endif
		  goto again;
		}
	      else
		isql_exit(3);
	    }
	  else
	    {
	      if (SQL_SUCCESS_WITH_INFO == rc)
		print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	      goto connected;
	    }
	}
      if (SQL_SUCCESS !=
	  (rc = SQLConnect (hdbc, (UTCHAR *) datasource, SQL_NTS,
			    (UTCHAR *) username, SQL_NTS,
			    (UTCHAR *) password, SQL_NTS)))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	    isql_exit (3);
	}
connected:
      ;
    }

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);
/* Stupid ifdef #ifndef SQLCLI */
  SQLGetInfo (hdbc, SQL_DBMS_NAME, info_dbms,
	      sizeof (info_dbms), ((SWORD *) & ignore));
  SQLGetInfo (hdbc, SQL_DRIVER_VER, info_driver,
	      sizeof (info_driver), ((SWORD *) & ignore));

  if (verbose_mode)
    {
      isql_printf (_T("Connected to %") PCT_S _T("\nDriver: %") PCT_S _T("\n"), info_dbms, info_driver);
    }

  if (isqlt_tcsstr (info_dbms, _T("Virtuoso")) ||
      isqlt_tcsstr (info_dbms, _T("UBL")) || isqlt_tcsstr (info_dbms, _T("ubl")))
    {
      kubl_mode = 1;
      if (version_less_than (info_driver, 0, 92))
	{
/*
   isql_fprintf(stderr,
   "-- Sorry, you need KUBL ODBC driver version 0.92 or later to run this tool.\n");
   isql_fprintf(stderr,
   "-- It is available from http://www.kubl.com\n");
   isql_exit(1);
 */
	  times_conform_to_odbc_flag = 0;
	  times_to_strings_flag = 1;
	}
    }
  else
    /* Some other DBMS, e.g. Access. */
    {
      kubl_mode = 0;
    }


/* #endif */

  SQLAllocStmt (hdbc, &stmt);
  fully_connected = 1;

  if (n_delayed_settings)
    {
      int i;
      for (i = 0; delayed_settings[i]; i++)
	{
	  if (!is_set_subcommand (delayed_settings[i], 0, 1))
	    {			/* isql_exit(1); */
	    }
	}
    }

  return (1);

}


int
handle_query_string (TCHAR *query_string)
{
  TCHAR *ptr1, *ptr2;
  int i = 1;

/* Call is_set_subcommand for each ampersand-delimited piece:
   query_string is corrupted, but web_query_string is left to point
   to an intact copy of the percent-escaped original, so that
   it can be later referenced with $QUERY_STRING dollar form
   (see get_next_token).
   Call with the third argument as 2, tell is_set_subcommand
   to look for prefix S_ and if it is found, to skip it, and if
   not then to wrap set name inside U{' and '} so as to set
   all other stuff to User/URL associative array U.
 */

  for (ptr1 = query_string; NULL != (ptr2 = isqlt_tcschr (ptr1, '&'));
       ptr1 = (ptr2 + 1), i++)
    {
      *ptr2 = '\0';		/* Wipe the ampersand. */
      if (!is_set_subcommand (ptr1, 0, 2))
	{			/* isql_exit(1); */
	}
/*         *ptr2 = '&';   Don't restore the ampersand! */
    }

/* Still have to handle the last piece of web_query_string,
   (or the one and only one if there were no ampersands at all): */
  if (!is_set_subcommand (ptr1, 0, 2))
    {				/* isql_exit(1); */
    }

  return (i);
}

/* Like isqlt_fgetts, but doesn't get confused about null bytes '\0',
   just stores them into buffer as any other characters.
   Stops at the first '\n' (newline) which is also stored into buffer.
   Returns as a result the number of bytes read, 0 if EOF encountered.
 */
int
bin_fgets (TCHAR *buffer, int max_size, FILE * infp)
{
  int i, c = 0;

  if (ferror (infp) || feof (infp))
    {
      return (0);
    }
  for (i = 0; (c != '\n') && (i < (max_size - 1)) && ((c = getc (infp)) != EOF); i++)
    {
      ((UTCHAR *) buffer)[i] = ((UTCHAR) c);
    }
  ((UTCHAR *) buffer)[i] = '\0';		/* And add terminating zero. */

  return (i);
}

/* Note from rfc1521.html (MIME)

   It must be noted that Content-Type values, subtypes, and parameter
   names as defined in this document are case-insensitive.  However,
   parameter values are case-sensitive unless otherwise specified for
   the specific parameter.

   So this means that in many cases we really should use nc_strstr
   (defined in ../string.c) instead of isqlt_tcsstr !!!

   It is possible to completely screw up the input to CGI-script with
   HTML-constructs like this, which at least Netscape version 2.02E
   will send without any escaping...

   <INPUT TYPE=HIDDEN NAME="LUMIKÄÄRME&#34;Lismake&LT;=&GT;kima&#59;ra&AMP;lahna" VALUE="Suikkaboksi ääliömäisesti huikkaa!">
   <INPUT TYPE=CHECKBOX NAME="sikaniska-NAME=lumiukko filename=pena" VALUE=RASTITTU>

   like these:
   Content-Disposition: form-data; name="LUMIKÄÄRME"Lismake<=>kima;ra&lahna"
   Content-Disposition: form-data; name="sikaniska-NAME=lumiukko filename=pena"

   A line with real filename= parameter should look like this:

   Content-Disposition: form-data; name="KUVA1"; filename="D:\InetPub\wwwroot\imagemap\soyombo.gif"

   So we assume that the users won't write forms with doublequotes
   in parameter names, and neither they should use spaces.

 */

#define starts_with(buf,str) (!strncasecmp((buf),(str),(sizeof(str)-1)))
#define is_contained_in(str1,str2) (isqlt_tcsstr((str1),(str2)))

/* Tries to be liberal, e.g. doublequotes are optional. */
TCHAR *
extract_from_doublequotes (TCHAR *src)
{
  size_t len;
  TCHAR *dest;
  TCHAR *pt1;
  if ('"' == *(src))
    {
      src++;
    }				/* Skip the beginning doublequote if there is one. */

  if ((pt1 = isqlt_tcschr (src, '"'))	/* Ending Doublequote? */
      || (pt1 = isqlt_tcschr (src, ';'))	/* Or semicolon ? */
      || (pt1 = isqlt_tcschr (src, ' '))	/* Space ? */
      || (pt1 = isqlt_tcschr (src, '\r'))	/* CR ? */
      || (pt1 = isqlt_tcschr (src, '\n'))	/* NL ? */
      || (pt1 = ((src) + isqlt_tcslen (src))))	/* The last always matches. */
    {
      len = (pt1 - src);
      dest = (TCHAR *) chemalloc ((len + 1), _T("extract_from_doublequotes"));
      isqlt_tcsncpy (dest, src, len);
      dest[len] = '\0';		/* Make sure it is terminated. */
/*
   isql_fprintf(error_stream,"extract_from_doublequotes: src=%s, dest=%s\n",src,dest);
   fflush(error_stream);
 */
      return (dest);
    }
  return NULL;
}

/* #define IN_BATCH 2000 */

/* Returns 1 if there is a file to read, 0 otherwise */
/* Call is_set_subcommand for each boundary delimited piece
   read from infp (e.g. stdin, stuff coming from the browser.)
   Call with the third argument as 2, tell is_set_subcommand
   to look for prefix S_ and if it is found, to skip it, and if
   not then to wrap set name inside U{' and '} so as to set
   all other stuff to User/URL associative array U.
   Also, don't try to do urldecoding for data after =
 */
int
handle_multipart_form (TCHAR *boundary, FILE * in_fp)
{
  TCHAR *me = _T("handle_multipart_form");
  TCHAR *tp1, *name = NULL;
  TCHAR *inpoint = &input[0];
  int blen = (int) isqlt_tcslen (boundary);
  int got_anything = 0, final_line = 0, state = 0;
  /* state is either:
     0 = waiting for the first boundary, 1 = reading headers,
     2 = reading stuff itself, 3 = reading headers of uploaded file, after
     they have been all read, return 1 to caller.
     4 = stuff reading truncated, scanning for the next boundary.
   */

/*
   isql_fprintf(error_stream,"handle_multipart_form(\"%s\") called\n",boundary);
   fflush(error_stream);
 */

  form_boundary = chestrdup (boundary, me);

  while (0 != (got_anything = bin_fgets (inpoint, IN_BATCH, in_fp)))
    {
/*
   isql_fprintf(error_stream,"handle_multipart_form: blen=%d, got_anything=%d, inpoint=%s, *(inpoint+blen)=%d.,%c\n",
   blen,got_anything,inpoint,
   *(((unsigned char *)inpoint+blen)),*(((unsigned char *)inpoint)+blen));
   fflush(error_stream);
 */
/* This slightly erroneous code
   if((got_anything >= blen) && !isqlt_tcsncmp(inpoint,boundary,blen)
   && ((isqlt_istspace(*(inpoint+blen)) || !*(inpoint+blen))
   || (('-' == inpoint[blen+1])
   && ('-' == inpoint[blen+2])
   && (isqlt_istspace(inpoint[blen+3]) || !inpoint[blen+3])
   && (final_line = 1))))
   Replaced by this outwardly neat macro:
 */
      if (is_mime_boundary_token (inpoint, got_anything, boundary, blen, final_line))
	{
	  if ((2 == state) || (4 == state))	/* Has been collecting stuff? */
	    {
	      /* Take the last CR+LF away from the end: */
	      if ((inpoint >= input) && ('\n' == *(inpoint - 1)))
		{
		  --inpoint;
		}
	      if ((inpoint >= input) && ('\r' == *(inpoint - 1)))
		{
		  --inpoint;
		}
	      *inpoint = '\0';
/* And terminate the thing as is_set_subcommand_aux still doesn't do
   much with its fourth argument. */
	      is_set_subcommand_aux (input, 0, 2, (int) (inpoint - input));
	    }
	  if (final_line)
	    {
	      return (0);
	    }
	  else
	    {
	      state = 1;
	    }
	  inpoint = &input[0];
	}
      else if ((1 == state) || (3 == state))	/* Reading headers ? */
	{
	  if (starts_with (input, _T("Content-Disposition:")))
	    {
	      if ((tp1 = is_contained_in (input, _T(" name="))))
		{
		  name = extract_from_doublequotes (tp1 + sizeof (_T(" name=")) - 1);
		}
	      if ((tp1 = is_contained_in (input, _T(" filename="))))
		{
		  form_filename = extract_from_doublequotes (tp1 + sizeof (_T(" filename=")) - 1);
		  form_filefieldname = name;
		  state = 3;
		}
	    }
	  else if (starts_with (input, _T("Content-Type:")))
	    {
	      form_last_content_type
		= chestrdup (get_rid_of_trailing_newline (skip_blankos (input + sizeof (_T("Content-Type:")) - 1)), me);
	    }
	  else if (starts_with (input, _T("Content-Transfer-Encoding:")))
	    {
	      form_last_encoding
		= chestrdup (get_rid_of_trailing_newline (skip_blankos (input + sizeof (_T("Content-Transfer-Encoding:")) - 1)), me);
	    }
	  else if (('\r' == *input) || ('\n' == *input))
	    {
	      if (3 == state)
		{
		  return (1);
		}		/* The contents of file start here. */
	      isqlt_tcscpy (input, name);
	      isqlt_tcscat (input, _T("             ="));		/* Space for {'thing'} */
	      inpoint = input + isqlt_tcslen (input);
	      state = 2;	/* Start reading the stuff itself. */
	    }
	}			/* if((1 == state) || (3 == state)) i.e. reading headers */
      else if ((2 == state))
	{
	  if ((inpoint + got_anything) > (input + INPUT_SIZE - IN_BATCH))
	    {
	      if (2 == state)
		{
		  isql_fprintf (error_stream,
				_T("\n%") PCT_S _T(": *** The multiline value in multipart form has grown too long on lines %ld - %ld.\n")
				_T("Already %d bytes read without encountering a boundary string: %") PCT_S _T("\n")
			     _T("in the end of line! Ignoring all the rest.\n"),
				progname, latest_statement_begins_at (), current_linecount (),
			(int)((inpoint + got_anything) - input), form_boundary);
		  state = 4;
		  /*           isql_exit(1); */
		}
	    }
	  else
	    {
	      inpoint += got_anything;
	    }
	}
    }				/* while loop. */

/* We should not come here if the input contains a valid
   terminating boundary separator. */
  return (0);

}


int isql_main (int argc, TCHAR **argv, PFSTR url_info_fun);

int __cdecl
_tmain (int argc, TCHAR **argv)
{
#if defined (WIN32) && (defined (UNICODE) || defined (_UNICODE))
  char *locale = setlocale (LC_ALL, "");
  if (locale)
    printf ("Locale=%s\n", setlocale (LC_ALL, ""));
  else
    printf ("Can't apply the system locale. "
	"Possibly wrong setting for LANG environment variable. "
	"Using the C locale instead.\n");
#endif
#ifdef WIN32
  setmode (fileno (stdin), _O_BINARY);
#endif
#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif
  isql_exit (isql_main (argc, argv, (PFSTR) isqlt_tgetenv));
  return 0;
}


int
isql_main (int argc,
	   TCHAR **argv,
	   PFSTR url_info_fun)	/* Usually getenv */
{
  int i;
  int nth_non_option = 0;	/* If set to non-zero then we know that this
				   is used in the traditional way, and connection
				   should be done quite soon in the beginning. */
  int shortcuts_used = 0;
  int host_shortcut = 0;
/*  char *last_underscore = NULL, *last_slash_or_backslash = NULL, *last_something = NULL; */
  TCHAR *query_string = NULL, *req_method = NULL, *content_type = NULL;
  struct name_var_pair *buf_nfo;

  progname = *argv;
  error_stream = stderr;
  current_input_stream () = stdin;
  G_argv = argv;
  G_argc = argc;

  SQLAllocEnv (&henv);		/* This might be needed quite soon. */
  SQLAllocConnect (henv, &hdbc);

#if 0
  last_slash_or_backslash = isqlt_tcsrchr (progname, '/');
#ifdef _WINDOWS
  last_something = isqlt_tcsrchr (progname, '\\');
  if (last_something &&
    (!last_slash_or_backslash || (last_something > last_slash_or_backslash))
    )
    {
      last_slash_or_backslash = last_something;
    }
#endif

  form_action = (last_slash_or_backslash ? (last_slash_or_backslash + 1)
		 : progname);

  /* Actually not the last, but the first after slash/backslash or
     the very first in program name. */
  last_underscore =
    isqlt_tcschr ((last_slash_or_backslash ? last_slash_or_backslash : progname),
	    '_');

  if (last_underscore &&
  (!last_slash_or_backslash || (last_underscore > last_slash_or_backslash)))
    {				/* A forced load. */
      int len;
      char tmpbuf[TMPBUF_SIZE + 1];

      last_something = isqlt_tcsrchr (progname, '.');		/* This time a last period. */
      if (!last_something)	/* Or pointing to the end. */
	{
	  last_something = (progname + isqlt_tcslen (progname));
	}

      len = (last_something - last_underscore) - 1;	/* Excluding the terminating zero */

      if (len > TMPBUF_SIZE)
	{
	  len = TMPBUF_SIZE;
	}			/* Silent cut, not probable. */

      isqlt_tcsncpy (tmpbuf, (last_underscore + 1), len);
      tmpbuf[len] = '\0';
      my_strncat (tmpbuf, ".sql", TMPBUF_SIZE);
      add_file_to_be_loaded (tmpbuf);
    }
#endif
  /* Is this used as a CGI-script? */
  if ((query_string = (url_info_fun) (_T("QUERY_STRING"))) ||
      (req_method = (url_info_fun) (_T("REQUEST_METHOD"))) ||
      (url_info_fun) (_T("SERVER_PROTOCOL")))
    {				/* There is a query string in the environment variable QUERY_STRING */
      /* which means that this is used with the Web browser. */
      /* Note: If we ever refer to other environment variables after
         these ones we have to make a copy of the web_query_string,
         as (url_info_fun) (i.e. getenv) returns pointers to its own
         static buffer. (Well, it's done now.)
       */
      input = chemalloc (input_size+20, _T("isql_main"));
      input[0] = 0;
      buf_nfo = find_var_info (_T("INPUTLINE"));
      buf_nfo->var_addr = (void *) input;
      buf_nfo->more_info = (void *) (ptrlong) input_size;
      web_mode = 1;
      error_stream = stdout;
      print_prompt = NULL;	/* Disable prompting also in cases like HELP SET */

      if (query_string && *query_string)
	{
	  web_query_string
	    = chestrdup (query_string, _T("main (web_query_string)"));
	  handle_query_string (query_string);
	}			/* if(query_string) */

      if (!req_method)
	{
	  req_method = (url_info_fun) (_T("REQUEST_METHOD"));
	}

      if (req_method && !isqlt_tcscmp (req_method, _T("POST")))
	{
	  if (NULL != (content_type = (url_info_fun) (_T("CONTENT_TYPE"))))
	    {
/*
   multipart/form-data; boundary=---------------------------243953132224834
   application/x-www-form-urlencoded
 */
	      if (starts_with (content_type, _T("multipart/form-data")))
		{
		  TCHAR *boundary;
		  TCHAR tmp1buf[TMPBUF_SIZE + 2];

		  if (NULL != (boundary = is_contained_in (content_type, _T("boundary="))))
		    {
		      boundary += (sizeof (_T("boundary=")) - 1);
		      isqlt_tcscpy (tmp1buf, _T("--"));
		      isqlt_tcscat (tmp1buf, boundary);
		      boundary = tmp1buf;
		      handle_multipart_form (boundary, stdin);
		    }
		  else
		    /* No boundary= part in CONTENT_TYPE ? */
		    {
		      /* Give an ugly error message... */
		      /* And/Or EXIT: return(1); */
		    }
		}
	      else
		/* It is normally x-www-form-urlencoded, so read the first */
		{		/* line from stdin and handle it as a normal query string. */
		  if (NULL != (query_string = isqlt_fgetts (input, INPUT_SIZE, stdin)))
		    {
		      web_query_string
			= chestrdup (query_string, _T("main (web_query_string)"));
		      handle_query_string (query_string);
		    }
		  else
		    /* END of stdin encountered prematurely... */
		    {
		      /* Give an ugly error message... */
		      /* And/Or EXIT: return(1); */
		    }
		}
	    }
	}			/* REQUEST_METHOD=POST ? */
    }
  else
    /* Normal usage from shell. */
    /* Parse command line arguments in this little loop. */
    {				/* This part taken from dbdump.c. Web-interface implemented above */
      int i, u_encountered = 0;
      for (i = 1, nth_non_option = 0; i < argc; i++)
	{
	  if (!isqlt_tcsncmp (argv[i], _T("-?"), 2) || !isqlt_tcsncmp (argv[i], _T("/?"), 2) || !isqlt_tcsncmp (argv[i], _T("--help"), 6))
	    {
	      isqlt_ftprintf (stdout,
		  _T("OpenLink Interactive SQL ") ISQL_TYPE _T(", version %") PCT_S _T(".\n"),
		  ISQL_VERSION);
	      isqlt_ftprintf (stdout,
		_T("\n   Usage :\n")
#ifndef ODBC_ONLY
		_T("isql <HOST>[:<PORT>] <UID> <PWD> file1 file2 ...\n")
		_T("\n")
		_T("isql -H <server_IP> [-S <server_port>] [-U <UID>] [-P <PWD>]\n")
		_T("     [-E] [-X <pkcs12_file>] [-K] [-C <num>] [-b <num>]\n")
		_T("     [-u <name>=<val>]* [-i <param1> <param2>]\n")
#else
		_T("isql <DSN> <UID> <PWD> file1 file2 ...\n\n")
		_T("\n")
		_T("isql -H datasource [-U <UID>] [-P <PWD>] [-u <name>=<val>]* [-i <param1> <param2>]\n")
		_T("\n")
#endif
		_T("     isql -?")
		_T("\n")
		_T("Connection options:\n")
		_T("\n")
		_T("  -?                  - This help message\n")
		_T("  -U username         - Specifies the login user ID\n")
		_T("  -P password         - Specifies the login password\n")
#ifndef ODBC_ONLY
		_T("  -H server_addr      - Specifies the Server address (IP)\n")
		_T("  -S server port      - Specifies the TCP port to connect to\n")
		_T("  -E                  - Specifies that encryption will be used\n")
                _T("  -C                  - Specifies that password will be sent in cleartext\n")
		_T("  -X pkcs12_file      - Specifies that encryption & X509 certificates will\n")
		_T("                        be used\n")
		_T("  -T server_cert      - Specifies that CA certificate file to be used\n")
                _T("  -b size             - Specifies that large command buffer to be used\n")
		_T("                        (in KBytes)\n")
		_T("  -K                  - Shuts down the virtuoso on connecting to it\n")
#else
		_T("  -H datasource       - Specifies the data source name (DSN)\n")
#endif
		_T("\n")
		_T("Parameter passing options:\n")
		_T("\n")
		_T("  -u name1=val1... - Everything after -u is stored to associative array U,\n")
		_T("                        until -i is encountered. If no equal sign then value\n")
		_T("                        is NULL\n")
		_T("  -i                  - Ignore everything after the -i option, after which \n")
		_T("                        comes arbitrary input parameter(s) for isql procedure,\n")
		_T("                        which can be referenced with $ARGV[$I] by the\n")
		_T("                        ISQL-commands.\n")
		_T("  <OPT>=<value>       - Sets the ISQL options\n\n")
		_T("  Note that if none of the above matches then the non-options go as \n")
#ifndef ODBC_ONLY
		_T("  <HOST>[:<PORT>] <UID> <PWD> file1 file2 ...\n\n")
#else
		_T("  <DSN> <UID> <PWD> file1 file2 ...\n\n")
#endif
		  );
	      exit (0);
	    }
	  if (!isqlt_tcsncmp (argv[i], _T("-U"), 2) && i+1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		username = argv[i] + 2;
	      else
		{
		  i++;
		  username = argv[i];
		}
	      shortcuts_used++;
	      continue;
	    }

	  if (!isqlt_tcsncmp (argv[i], _T("-P"), 2) && i+1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		password = argv[i] + 2;
	      else
		{
		  i++;
		  password = argv[i];
		}
	      shortcuts_used++;
	      continue;
	    }
	  if (!isqlt_tcsncmp (argv[i], _T("-H"), 2) && i+1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		datasource = argv[i] + 2;
	      else
		{
		  i++;
		  datasource = argv[i];
		}
	      shortcuts_used++;
	      host_shortcut++;
	      continue;
	    }
#ifndef ODBC_ONLY
	  if (!isqlt_tcsncmp (argv[i], _T("-E"), 2))
	    {
	      encryption = _T("1");
	      continue;
	    }
	  if (!isqlt_tcsncmp (argv[i], _T("-C"), 2) && i + 1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		pwd_cleartext = isqlt_tstoi (argv[i]) + 2;
              else
                {
		  i++;
		  pwd_cleartext = isqlt_tstoi (argv[i]);
		}
	      continue;
	    }
	  if (!isqlt_tcsncmp (argv[i], _T("-X"), 2) && i + 1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		encryption = argv[i] + 2;
	      else
		{
		  i++;
		  encryption = argv[i];
		}
	      continue;
	    }
	  if (!isqlt_tcsncmp (argv[i], _T("-T"), 2) && i + 1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		ca_list = argv[i] + 2;
	      else
		{
		  i++;
		  ca_list = argv[i];
		}
	      continue;
	    }

	  if (!isqlt_tcsncmp (argv[i], _T("-S"), 2) && i+1 < argc)
	    {
	      static TCHAR port[10];
	      struct servent *pserv;
	      if (isqlt_tcslen (argv[i]) > 2)
		connect_port = argv[i] + 2;
	      else
		{
		  i++;
		  connect_port = argv[i];
		}
	      pserv = getservbyname (connect_port, _T("tcp"));
	      if (pserv)
		{
		  isqlt_stprintf (port, _T("%d"), ntohs (pserv->s_port));
		  connect_port = port;
		}
	      shortcuts_used++;
	      continue;
	    }

	  if (!isqlt_tcsncmp (argv[i], _T("-b"), 2) && i + 1 < argc)
	    {
	      if (isqlt_tcslen (argv[i]) > 2)
		input_size = isqlt_tstoi (argv[i]+2) * 1024;
              else
                {
		  i++;
		  input_size = isqlt_tstoi (argv[i]) * 1024;
		}
	      if (input_size < MIN_INPUT_SIZE)
		input_size = MIN_INPUT_SIZE;
	      continue;
	    }

	  if (!isqlt_tcsncmp (argv[i], _T("-K"), 2))
	    {
	      virtuoso_shutdown = 1;
	      u_encountered = 1;
	    }
#ifdef PLDBG
	  if (!isqlt_tcsncmp (argv[i], _T("-D"), 2))
	    {
	      virtuoso_debug = 1;
	    }
#endif
#endif

	  if (!isqlt_tcscmp (argv[i], _T("-u")))	/* Everything after -u is stored to */
	    {			/* associative array U, until -i is */
	      u_encountered = 1;
	      continue;		/* encountered */
	    }

	  if (!isqlt_tcscmp (argv[i], _T("-i")))
	    {
/* Ignore everything after the -i option, after which comes arbitrary
   input parameter(s) for isql procedure, which can be referenced
   with $ARGV[$I] by the ISQL-commands. */
	      G_argc_i = i + 1;
	      break;
	    }

	  if (u_encountered)
	    {
	      if (!is_set_subcommand (argv[i], 0, 2))
		{		/* return(1); */
		}
	    }
	  else if (isqlt_tcschr (argv[i], '='))	/* There's an equal sign? */
	    {
	      if (!is_set_subcommand (argv[i], 0, 1))
		{		/* return(1); */
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
		default:	/* 4th or later. */
		  {
		    add_file_to_be_loaded (argv[i]);
		    break;
		  }
		}
	    }
	}			/* for loop over arguments */
    }

  /* alloc the input buffer */
  if (input == input1)
    {
      input = chemalloc (input_size+20, _T("isql_main"));
      input[0] = 0;
      buf_nfo = find_var_info (_T("INPUTLINE"));
      buf_nfo->var_addr = (void *) input;
      buf_nfo->more_info = (void *) (ptrlong) input_size;
    }
/* If we are in web_mode, and there was neither statement(s) to be
   executed given, nor any files to be loaded, then we should
   dump the default form for the user.
 */
  if (web_mode)
    {
      if ((NOT execs_from_cmdline) && (NOT load_n_files))
	{

/* (see function print_http_headers_if_not_already_printed) */
	  flag_head_already_printed = 1;
	  isqlt_tprintf (_T("Content-Type: %") PCT_S _T("\r\n\r\n"), _T("text/html"));
	  fflush (stdout);

	  output_html_file (DEFAULT_HTML_TEMPLATE_FILE);
	  return (0);
	}
    }
#ifdef PLDBG
  if (virtuoso_debug)
    {
      debug_session = pldbg_connect (datasource, username, password);

      if (!debug_session)
	{
	  isql_fprintf (error_stream, _T("Can't estabilish debug session to the '%") PCT_S _T("'\n"), datasource);
	  isql_exit (1);
	}
      if (verbose_mode)
	{
	  isql_printf (_T("OpenLink Interactive PL Debugger (Virtuoso).\nType EXIT to exit, HELP for help\n"));
	  isql_printf (_T("Debug session estabilished to %") PCT_S _T("\n"), datasource);
	}
      print_prompt = _T("DEBUG> ");
      rep_loop (stdin, print_prompt);
      return 0;
    }
#endif
  if (nth_non_option || shortcuts_used)		/* Used in the traditional way, with datasource,
				   and possibly username and password given from
				   the command line? */
    {				/* Connect now, do not wait. As this is done before the loading
				   of filenames saved to files_to_load vector, the datasource,
				   username and password specified at the command line override
				   the possible definitions for them given with SET DSN,
				   SET UID and SET PWD commands in the beginning of the
				   file to be loaded. Otherwise, if DSN, UID or PWD
				   were given from command line or URL with explicit
				   DSN=dsn, UID=user or PWD=pass options/URL input
				   variables, the settings in the loaded file will still win
				   (simply because they are executed later),
				   thus disabling the possibility of tweaking these from URL
				   in cases where customers are only allowed access to certain
				   things.
				 */
#ifndef ODBC_ONLY
      if (host_shortcut || connect_port)
	{
	  static TCHAR szData[2048];
	  isqlt_stprintf (szData, _T("%") PCT_S _T(":%") PCT_S,
	      host_shortcut ? datasource : _T("localhost"),
	      connect_port ? connect_port : _T("1111"));
	  datasource = szData;
	}
#endif
      connect_to_datasource (datasource, username, password);
    }

  if (load_n_files)
    {
#define MAX_LOAD_EXPR 1001
      TCHAR loadexpr[MAX_LOAD_EXPR + 3];
      for (i = 0; files_to_load[i]; i++)
	{
	  isqlt_tcscpy (loadexpr, _T("Command-Line-Load "));
	  my_strncat (loadexpr, files_to_load[i], MAX_LOAD_EXPR);
	  if (0 == load_file (files_to_load[i], 0, loadexpr))
	    {			/* 0 = normal load, 1 = raw load */
	      if (commit_mode == 2 && fully_connected)
		{
		  RETCODE rc;
		  if (SQL_SUCCESS != (rc = SQLTransact (henv, hdbc, SQL_ROLLBACK)))
		    {
		      print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
		    }
		}
	      return (1);	/* Exit with an error code 1 if file not found. */
	    }
	}
/* Exit now if no statements given with EXEC=option(s) */
      if (0 == execs_from_cmdline)
	{
	  goto done;
	}
    }

  if (verbose_mode && (NOT web_mode))
    {
      isql_printf (
	  _T("OpenLink Interactive SQL ") ISQL_TYPE
	  _T(", version %") PCT_S _T(".\nType HELP; for help and EXIT; to exit.\n"),
	  ISQL_VERSION);
    }

/* Check if the user has given one or more statements to be executed
   from the command line with EXEC option: */
  if (execs_from_cmdline)
    {
#define MAXSEMICOLS_IN_LINE 50
      int scivec[MAXSEMICOLS_IN_LINE + 1];
      int *sciptr;
      TCHAR *exec_piece;
      integer_list pidlist_space;
      integer_list *pidlist = &pidlist_space;
      pidlist->next = NULL;	/* Initialize the pidlist anchor. */

      for (i = 0; i < execs_from_cmdline; i++)
	{
	  UTCHAR inside_string = 0;
/* The following has nothing to do with braces but semicolons. User can
   give more than one statement to be executed in ONE and SINGLE
   EXEC-option, just by separating them with semicolons.
   Note that count_bracelevel doesn't count as semicolons the semicolons
   found inside strings, after comments -- or inside block statements
   (i.e. if bracelevel > 0). We don't check here that bracelevel returned
   by count_bracelevel is zero, because the user has to have a right to
   give incorrect statements to Kubl server (and we can't be 100% sure
   here what is syntactically correct statement and what is not...)
 */
	  count_bracelevel (execute_these_only[i], 0,
			    scivec, MAXSEMICOLS_IN_LINE, 0, &inside_string);
	  for (exec_piece = execute_these_only[i], sciptr = scivec;
	       *sciptr;
	       sciptr++)
	    {			/* Wipe the next semicolon. Note the one-based indexing: */
	      *((execute_these_only[i]) + ((*sciptr) - 1)) = '\0';
	      exec_one (exec_piece, pidlist);	/* Execute the piece at the left side */
	      /* Restore the semicolon: (for cosmetic & debugging reasons) */
	      *((execute_these_only[i]) + ((*sciptr) - 1)) = ';';
	      exec_piece = (execute_these_only[i] + (*sciptr));
	    }			/* And then skip exec_piece past that semicolon. */

/* Still have to execute the last piece of execute_these_only[i],
   or one and the only one if there were no semicolons at all: */
	  exec_one (exec_piece, pidlist);
	}
      goto done;
    }

  rep_loop (stdin, print_prompt);

done:
  if (commit_mode == 2 && fully_connected)
    {
      RETCODE rc;
      if (SQL_SUCCESS != (rc = SQLTransact (henv, hdbc, SQL_ROLLBACK)))
	{
	  print_error (((HENV) 0), hdbc, ((HSTMT) 0), rc);
	}
    }
  return (0);
}


/* ================================================================== */
/*            FUNCTIONS FOR OUTPUTTING HTML PAGE                      */
/* ================================================================== */

TCHAR *
get_list_of_datasources (int for_html, TCHAR *dest_buf, int dest_size)
{
#if !defined(ODBC_ONLY)
  dest_buf[dest_size - 1] = '\0';
  if (for_html)
    {
      isqlt_tcsncpy (dest_buf, _T("<INPUT NAME=S_DATASOURCE TYPE=TEXT VALUE=\""), dest_size);
      my_strncat (dest_buf, DEFAULT_DATASOURCE_IN_UNIX, dest_size);
      my_strncat (dest_buf, "\">", dest_size);
    }
  else
    {
      isqlt_tcsncpy (dest_buf,
	       _T("Don't know how to list available data sources in Unix. Try "),
	       dest_size);
      my_strncat (dest_buf, DEFAULT_DATASOURCE_IN_UNIX, dest_size);
      my_strncat (dest_buf, _T(" or wherever your Virtuoso server is listening."), dest_size);
    }

#else

#define DRIVDESCMAX 256
#ifndef SQL_MAX_DSN_LENGTH
#define SQL_MAX_DSN_LENGTH 512
#endif

  TCHAR DSN[SQL_MAX_DSN_LENGTH + 1], DriverDescription[DRIVDESCMAX + 1];
  SWORD pcbDSN, pcbDescription;
  int rc, count;

  dest_buf[0] = '\0';
  dest_buf[dest_size] = '\0';

  isqlt_tcscpy (DSN, _T("VIRGEN"));
  isqlt_tcscpy (DriverDescription, _T("CERDO"));

  if (for_html)
    {
      isqlt_tcsncpy (dest_buf, _T("<SELECT NAME=S_DATASOURCE>"), dest_size);
    }

  for (count = 0; 1; count++)
    {
      rc = SQLDataSources (henv,
		       ((UWORD) (count ? SQL_FETCH_NEXT : SQL_FETCH_FIRST)),
			   UCP (DSN),
			   ((SWORD) SQL_MAX_DSN_LENGTH),
			   &pcbDSN,
			   UCP (DriverDescription),
			   ((SWORD) DRIVDESCMAX),
			   &pcbDescription);
      if (rc == SQL_NO_DATA_FOUND)
	{
	  break;
	}
      IF_ERR_GO (stmt, error, rc);

      if (for_html)
	{
	  my_strncat (dest_buf, _T("<OPTION VALUE=\""), dest_size);
	  my_strncat (dest_buf, DSN, dest_size);
	  my_strncat (dest_buf, _T("\">"), dest_size);
	  my_strncat (dest_buf, DSN, dest_size);
	  my_strncat (dest_buf, _T(",   "), dest_size);
	  my_strncat (dest_buf, DriverDescription, dest_size);
	  my_strncat (dest_buf, _T("\n"), dest_size);
	}
      else
	{
	  my_strncat (dest_buf, DSN, dest_size);
	  my_strncat (dest_buf, _T(",   "), dest_size);
	  my_strncat (dest_buf, DriverDescription, dest_size);
	  my_strncat (dest_buf, _T("\n"), dest_size);
	}
    }
error:
  if (for_html)
    {
      my_strncat (dest_buf, _T("</SELECT>"), dest_size);
      if (SQL_ERROR == rc)
	{
	  TCHAR numbuf[80];
	  isql_fprintf (stderr,
			_T("get_list_of_datasources: SQLDataSources returned status %d, count=%d\n"),
			rc, count);
	  fflush (stderr);
	  my_strncat (dest_buf, _T(" **Error: SQLDataSources returned status "), dest_size);
	  isqlt_stprintf (numbuf, _T("%d, count=%d"), rc, count);
	  my_strncat (dest_buf, numbuf, dest_size);
	}
    }

#endif

  return (dest_buf);

}




/*
   A dollar ($) can be escaped in a HTML-template as: &#36;
   except in URLs, where it can be escaped with %24
 */

int
output_line_of_template_with_parameters (UTCHAR * piece_of_template)
{
  UTCHAR *str = piece_of_template, *start_of_this_piece = str, *p;
/*  int whole_len = isqlt_tcslen(SCP(piece_of_template)); */
  int use_html_escapes = 0;
  TCHAR tmp1buf[5005];		/* Big enough. E.g. $DATASOURCES might get long */

  for (; *str;)
    {
      switch (*str)
	{
	case '$':
	  {
/*           if(0 == flag_macro_substitution) { str++; break; } */
/*           else */
	    {
	      UTCHAR *cont;

	      if (str != start_of_this_piece)
		{
		  UTCHAR saved = start_of_this_piece [str - start_of_this_piece];
		  start_of_this_piece [str - start_of_this_piece] = 0;
		  isql_fputs ((TCHAR *) start_of_this_piece, stdout);
		  start_of_this_piece [str - start_of_this_piece] = saved;
		}
	      cont = str;
	      p = UCP (get_next_token (((TCHAR **) &cont),
				       tmp1buf, (sizeof (tmp1buf) - 1),
				       NULL, 0));

	      /* cont points now to the first char after $dollar_form */
	      start_of_this_piece = str = cont;

	      if (NULL != p)	/* Print nothing for nulls */
		{
		  if (use_html_escapes)
		    {
		      html_print_escaped_n (SCP (p), stdout, 0);
		    }
		  else
		    {
		      isql_fputs (SCP (p), stdout);
		    }
		}
	    }
	    break;
	  }			/* case '$' */
	default:
	  {
	    str++;
	    break;
	  }
	}			/* switch */

    }				/* for loop. */

  if (str != start_of_this_piece)	/* print the last remaining piece */
    {
      UTCHAR saved = start_of_this_piece [str - start_of_this_piece];
      start_of_this_piece [str - start_of_this_piece] = 0;
      isql_fputs ((TCHAR *) start_of_this_piece, stdout);
      start_of_this_piece [str - start_of_this_piece] = saved;
    }

  return (1);			/* Something. */
}




FILE *html_infp = NULL;

TCHAR *
line_from_html_file (TCHAR *templatename)
{
  TCHAR tmp1[2002];

  return (isqlt_fgetts (tmp1, (sizeof (tmp1) - 1), html_infp));
}

/* Return the whole string in one piece. After that return NULL.
   Really Ad Hoc just for quick, quick work.
 */
TCHAR *
line_from_html_string (TCHAR *templatename)
{
  static TCHAR counts_visited = 0;
  static TCHAR *last_templatename = _T("");
  extern TCHAR *html_page_string;	/* In the end of this module. */

  if ((0 == counts_visited) || (templatename != last_templatename))
    {				/* First time here with this templatename? */
      counts_visited++;
      last_templatename = templatename;

      if (!isqlt_tcscmp (templatename, DEFAULT_HTML_TEMPLATE_FILE))
	{
	  return (html_page_string);
	}
    }
  else
    {
      return (NULL);
    }
  return NULL;
}


int
output_html_page (PFSTR sourcefun, TCHAR *templatename)
{
  TCHAR *line;


  while (NULL != (line = ((sourcefun) (templatename))))
    {
      output_line_of_template_with_parameters (UCP (line));
    }
  return (1);
}

int
output_html_file (TCHAR *templatename)
{
/* When using option -h, then take it always from the memory. */
  if (				/* dump_html_template_file_flag
				   || */
       NO (html_infp = isqlt_tfopen (templatename, _T("r"))))
    {
      output_html_page (line_from_html_string, templatename);
    }
  else
    {
      output_html_page (line_from_html_file, templatename);
    }
  return (1);
}


/*
   The layout is still very crude. See dbump.c for some improvements.
 */
TCHAR *html_page_string
=

_T("<HTML><HEAD><TITLE>Virtuoso ISQL (webface), Version $VERSION</TITLE>\n")
_T("</HEAD>\n")
_T("<BODY>\n")
_T("<H3>Virtuoso Isql Web-Interface Default Form</H3>\n")
_T("<FORM >\n")
_T("<TABLE>\n")
_T("<TR>\n")
_T("<TD><B>Data&nbsp;Source</B></TD>\n")
_T("<TD COLSPAN=2>$") DATASOURCE_TOKEN _T("</TD></TR>\n")
_T("<TR><TD VALIGN=TOP><B>Statements</B><BR>\n")
_T("<BR><CENTER><INPUT TYPE=SUBMIT VALUE=\"DO IT\"></CENTER>\n")
_T("</TD>\n")

_T("<TD COLSPAN=2>\n")
_T("One or more, separated with semicolons (;)<BR>\n")

_T("<TEXTAREA NAME=\"S_EXEC\" ROWS=3 COLS=60></TEXTAREA>\n")

_T("<TR><TD VALIGN=TOP><B>Options</B></TD>\n")

_T("<TD COLSPAN=2>\n")

_T("<TABLE>\n")

_T("<TR>\n")
_T("<TD><INPUT NAME=\"S_CONUSER\" TYPE=TEXT SIZE=8>\n")
_T("<!-- B -->Username<!-- /B --></TD>\n")

_T("<TD><INPUT NAME=\"S_CONPASS\" TYPE=PASSWORD SIZE=8>\n")
_T("<!-- B -->Password<!-- /B --></TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD><INPUT NAME=\"S_MAXROWS\" TYPE=TEXT SIZE=8 VALUE=\"1000\">\n")
_T("<!-- B -->Max Rows<!-- /B --></TD>\n")

_T("<TD><INPUT NAME=\"S_TIMEOUT\" TYPE=TEXT SIZE=8 VALUE=\"1000\">\n")
_T("<!-- B -->Timeout in Seconds<!-- /B --></TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD><INPUT TYPE=CHECKBOX NAME=\"S_READMODE\" VALUE=\"SNAPSHOT\">\n")
_T("<!-- B -->Snapshot Readmode<!-- /B --></TD>\n")

_T("<TD>\n")
_T("<INPUT TYPE=CHECKBOX NAME=\"S_AUTOCOMMIT\" VALUE=\"ON\"> <!-- B -->Autocommitted Execution<!-- /B -->\n")
_T("</TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD>\n")
_T("<INPUT TYPE=CHECKBOX NAME=\"S_BLOBS\" VALUE=\"ON\"> <!-- B -->Show Blobs<!-- /B -->\n")
_T("</TD>\n")
_T("<TD>\n")
_T("<INPUT TYPE=CHECKBOX NAME=\"S_BANNER\" VALUE=\"OFF\"> <!-- B -->No Banner<!-- /B -->\n")
_T("</TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD>\n")
_T("<INPUT TYPE=RADIO NAME=\"S_VERBOSE\" VALUE=\"OFF\"> <!-- B -->Brief<!-- /B -->\n")
_T("</TD>\n")
_T("<TD>\n")
_T("<INPUT TYPE=RADIO CHECKED NAME=\"S_VERBOSE\" VALUE=\"ON\"> <!-- B -->Verbose Output<!-- /B -->\n")
_T("</TD>\n")
_T("</TR>\n")


_T("<TR>\n")
_T("<TD>\n")
_T("<INPUT TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"text/plain\">\n")
_T("<!-- B -->Dump in raw text format to screen<!-- /B -->\n")
_T("</TD>\n")

_T("<TD>\n")
_T("<INPUT TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"x-isql/plain\">\n")

_T("<!-- B -->Dump in raw text format to file<!-- /B -->\n")

_T("</TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD COLSPAN=2>\n")
_T("<INPUT CHECKED TYPE=RADIO NAME=\"S_CONTENT_TYPE\" VALUE=\"text/html\">\n")

_T("<!-- B -->Dump in HTML format to screen<!-- /B -->\n")

_T("</TD>\n")
_T("</TR>\n")

_T("<TR>\n")

_T("<TD><INPUT CHECKED TYPE=CHECKBOX NAME=\"S_OO_SB\" VALUE=\"&LT;TABLE&#32;BORDER&GT;\">\n")

_T("<!-- B -->Use Table Borders<!-- /B --></TD>\n")

_T("<TD><INPUT TYPE=CHECKBOX NAME=\"S_OO_ESC\" VALUE=\"OFF\">\n")

_T("<!-- B -->No HTML-Escaping<!-- /B --></TD>\n")

_T("</TR>\n")


_T("<TR>\n")
_T("<TD><INPUT TYPE=SUBMIT VALUE=\"Do it\"></TD>\n")

_T("<TD><INPUT TYPE=RESET VALUE=\"Reset\"></TD>\n")
_T("</TR>\n")

_T("</TABLE>\n")

_T("</TD>\n")
_T("</TR>\n")

_T("</TR>\n")


_T("</TABLE>\n")

_T("</FORM>\n")

_T("<H3>Administration</H3>\n")

_T("<UL>\n")
_T("<LI><A HREF=\"$FORM_ACTION?S_EXEC=status\">Database Status</A>\n")
_T("<LI><A HREF=\"$FORM_ACTION?S_CONTENT_TYPE=text/plain&S_EXEC=help\">Help</A>\n")
_T("</UL>\n")

_T("<TABLE>\n")
_T("<TR>\n")
_T("<TD><FORM METHOD=GET $IF $FORM_ACTION 'ACTION=\"'$FORM_ACTION$IF $FORM_ACTION '\"'>\n")
_T("<INPUT TYPE=HIDDEN NAME=S_READMODE VALUE=SNAPSHOT>\n")
_T("<INPUT TYPE=HIDDEN NAME=S_EXEC VALUE=\"backup('&#36;U{BKFILE}')\">\n")
_T("Make a backup, to file: </TD>\n")
_T("<TD><INPUT TYPE=TEXT NAME=BKFILE SIZE=20 VALUE=\"$YYYYMMDD&#46;log\"></TD>\n")
_T("<TD><INPUT TYPE=SUBMIT VALUE=\"DO IT\"></FORM></TD>\n")
_T("</TR>\n")

_T("<TR>\n")
_T("<TD><FORM METHOD=GET $IF $FORM_ACTION 'ACTION=\"'$FORM_ACTION$IF $FORM_ACTION '\"'>\n")
_T("<INPUT TYPE=HIDDEN NAME=S_EXEC VALUE=\"checkpoint &#36;U{NEWLOG}\">\n")
_T("Make a checkpoint, new log: </TD>\n")
_T("<TD><INPUT TYPE=TEXT NAME=NEWLOG SIZE=20></TD>\n")
_T("<TD><INPUT TYPE=SUBMIT VALUE=\"DO IT\"></FORM></TD>\n")
_T("</TR>\n")
_T("<TR>\n")
_T("<TD><FORM METHOD=GET $IF $FORM_ACTION 'ACTION=\"'$FORM_ACTION$IF $FORM_ACTION '\"'>\n")
_T("<INPUT TYPE=HIDDEN NAME=S_EXEC VALUE=\"shutdown &#36;U{NEWLOG}\">\n")
_T("Shutdown server, new log: </TD>\n")
_T("<TD><INPUT TYPE=TEXT NAME=NEWLOG SIZE=20></TD>\n")
_T("<TD><INPUT TYPE=SUBMIT VALUE=\"DO IT\"></FORM></TD>\n")
_T("</TR>\n")
_T("</TABLE>\n")

_T("<HR>\n")

_T("<H3>Some Notes</H3>\n")
_T("<UL><LI>\n")

_T("Use <B>dump to file instead of screen</B> option to send the data\n")
_T("with the unknown content type instead of text/plain, thus forcing\n")
_T("your browser to ask for a filename where to save the output, instead\n")
_T("of showing it on the screen. Use this option if you have megabytes\n")
_T("to output and don't want to thrash your browser.\n")

_T("<P><LI>\n")

_T("<B>Warning:</B>\n")

_T("Leaving this utility unprotected without password in a public Web-server\n")
_T("constitutes a clear security risk to your machine.\n")
_T("Not only it can be used to gain access\n")
_T("to all <B>Unprotected System DSN's</B>, but it can be used for\n")
_T("gaining access to <B>the underlying operating system</B> as well, via\n")
_T("a shell-escape mechanism.\n")
_T("<BR>So you are strongly suggested either to set a password for this\n")
_T("cgi-bin script (by configuring your Web-server),\n")
/* Very leaky protection: that "secret" URL can be easily found from
   caches, etc.
   _T("or to hide it with such a name into your script-directory or subdirectory\n")
   _T("that it cannot be guessed by outsiders,\n")
 */
_T("or to totally deny any public access to your local Web server.\n")

_T("<P><LI>\n")

_T("</UL>\n")
_T("<HR>\n")
_T("</BODY></HTML>\n");
