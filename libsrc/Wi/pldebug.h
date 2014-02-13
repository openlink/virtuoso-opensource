/*
 *  pldebug.h
 *
 *  $Id$
 *
 *  PL debugger structures
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef _PLDBG_H
#define _PLDBG_H

#define PD_BREAK 	0 /* set/delete a breakpoint */
#define PD_NEXT  	1 /* next */
#define PD_INFO  	2 /* misc. info */
#define PD_ATTACH	3 /* attach to a client */
#define PD_STEP		4 /* step */
#define PD_LIST		5 /* show a PL procedure definition */
#define PD_WHERE	6 /* show the callstack */
#define PD_CONT		7 /* continue */
#define PD_PRINT	8 /* print a variable */
#define PD_SET		9 /* set a variable */
#define PD_DELETE	10 /* delete a breakpoint */
#define PD_FRAME	11 /* choose a frame */
#define PD_FINISH	12 /* run still exit from current proc */
#define PD_UNTIL	14 /* run still reach a line # */

#define PDI_THRE	0
#define PDI_CLI		1
#define PDI_BREAK	2

typedef struct pldbg_message_s
{
  dk_session_t * ses;
  caddr_t msg;
  int mode;
} pldbg_message_t;

#define PD_NONE 0
#define PD_IN 	1
#define PD_OUT 	2


typedef struct pldbg_cmd_s
{
  const char * pld_name;
  int 	pld_code;
  const char * pld_params;
  const char * pld_descr;
} pldbg_cmd_t;

/* available commands */
pldbg_cmd_t
pld_cmds [] = {
 {"BREAK", 	PD_BREAK, "procedure_name [line number]",
    "Set breakpoint at specified line or PL function"},
 {"NEXT",  	PD_NEXT, NULL,
    "Step program, proceeding through PL subroutine calls."},
 {"INFO",  	PD_INFO, "(THREAD|CLIENT|BREAK)",
    "Generic command for showing things about the program/process being debugged."},
 {"ATTACH", 	PD_ATTACH, "thread_id|client_id",
    "Attach to a running process."},
 {"STEP", 	PD_STEP, NULL,
    "Step PL program until it reaches a different source line."},
 {"LIST", 	PD_LIST, "[procedure name] [line number]",
    "List specified procedure or line."},
 {"WHERE", 	PD_WHERE, NULL,
    "Print backtrace of all stack frames."},
 {"CONTINUE", 	PD_CONT, NULL,
    "Continue PL program being debugged after breakpoint."},
 {"PRINT", 	PD_PRINT, "variable_name",
    "Print value of variables or arguments."},
 {"SET", 	PD_SET, "variable_name new_value",
    "Assign a specified value to a variable."},
 {"DELETE", 	PD_DELETE, "([breakpoint_number]|[procedure_name] [line_number])",
    "Delete some breakpoints."},
 {"FRAME", 	PD_FRAME, "frame_number",
    "Select and print a stack frame."},
 {"FINISH", 	PD_FINISH, NULL,
    "Execute until returns."},
 {"UNTIL", 	PD_UNTIL, "line_number",
    "Execute until the program reaches a source line greater than the current."},
 {NULL, 	0, 		NULL, NULL}
};

/* available infos */
pldbg_cmd_t
pld_infos [] = {
 {"THREADS", 	PDI_THRE,	NULL, "Running threads"},
 {"CLIENTS", 	PDI_CLI,	NULL, "Connected SQL/ODBC clients"},
 {"BREAKPOINTS",PDI_BREAK,	NULL, "Active breakpoints"},
 {NULL    , 	0, 	   	NULL, NULL}
};

#define PLD_LINE_LIMIT 256

caddr_t pldbg_read_resp (void * ses1);
int pldbg_command (void * ses1, char * cmd1);
void * pldbg_connect (char * addr, char * usr, char * pwd1);

#endif
