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
 *  Copyright (C) 1998-2024 OpenLink Software
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

#define PD_BREAK 	0	/* set/delete a breakpoint */
#define PD_NEXT  	1	/* next */
#define PD_INFO  	2	/* misc. info */
#define PD_ATTACH	3	/* attach to a client */
#define PD_STEP		4	/* step */
#define PD_LIST		5	/* show a PL procedure definition */
#define PD_WHERE	6	/* show the callstack */
#define PD_CONT		7	/* continue */
#define PD_PRINT	8	/* print a variable */
#define PD_SET		9	/* set a variable */
#define PD_DELETE	10	/* delete a breakpoint */
#define PD_FRAME	11	/* choose a frame */
#define PD_FINISH	12	/* run still exit from current proc */
#define PD_UNTIL	14	/* run still reach a line # */
#define PD_GLOBALS 	15	/* print client globals */
#define PD_UP           16
#define PD_DOWN         17

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
extern pldbg_cmd_t pld_cmds[];
extern pldbg_cmd_t pld_infos[];

#define PLD_LINE_LIMIT 256

extern caddr_t pldbg_read_resp (void *ses1);
extern int pldbg_command (void *ses1, char *cmd1);
extern void *pldbg_connect (char *addr, char *usr, char *pwd1);
extern void pldbg_help (FILE * f);

#endif
