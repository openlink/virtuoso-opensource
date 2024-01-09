/*
 *  pldbgcli.c
 *
 *  $Id$
 *
 *  PL debugger client API
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

#include "CLI.h"
#include "multibyte.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "libutil.h"
#include "pldebug.h"

pldbg_cmd_t pld_cmds[] =
{
  { "BREAK", PD_BREAK, "procedure_name [line number]", "Set breakpoint at specified line or PL function"} ,
  { "NEXT", PD_NEXT, NULL, "Step program, proceeding through PL subroutine calls."} ,
  { "INFO", PD_INFO, "(THREAD|CLIENT|BREAK)", "Generic command for showing things about the program/process being debugged."} ,
  { "ATTACH", PD_ATTACH, "thread_id|client_id", "Attach to a running process."} ,
  { "STEP", PD_STEP, NULL, "Step PL program until it reaches a different source line."} ,
  { "LIST", PD_LIST, "[procedure name] [line number]", "List specified procedure or line."} ,
  { "WHERE", PD_WHERE, NULL, "Print backtrace of all stack frames."} ,
  { "CONTINUE", PD_CONT, NULL, "Continue PL program being debugged after breakpoint."} ,
  { "PRINT", PD_PRINT, "variable_name", "Print value of variables or arguments."} ,
  { "SET", PD_SET, "variable_name new_value", "Assign a specified value to a variable."} ,
  { "DELETE", PD_DELETE, "([breakpoint_number]|[procedure_name] [line_number])", "Delete some breakpoints."} ,
  { "FRAME", PD_FRAME, "frame_number", "Select and print a stack frame."} ,
  { "UP", PD_UP, NULL, "Select one frame up."} ,
  { "DOWN", PD_DOWN, NULL, "Select one frame down."} ,
  { "FINISH", PD_FINISH, NULL, "Execute until returns."} ,
  { "UNTIL", PD_UNTIL, "line_number", "Execute until the program reaches a source line greater than the current."} ,
  { "GLOBALS", PD_GLOBALS, NULL, "Print global variables on attached connection."} ,
  { NULL, 0, NULL, NULL}
};

/* available infos */
pldbg_cmd_t pld_infos[] =
{
  { "THREADS", PDI_THRE, NULL, "Running threads"} ,
  { "CLIENTS", PDI_CLI, NULL, "Connected SQL/ODBC clients"} ,
  { "BREAKPOINTS", PDI_BREAK, NULL, "Active breakpoints"} ,
  { NULL, 0, NULL, NULL}
};

/* PL Debugger API */
void *
pldbg_connect (char *addr, char *usr, char *pwd1)
{
  char pwd[17];
  caddr_t result;
  dk_session_t *ses = NULL;
  if (!usr || !pwd1)
    return NULL;
  ses = PrpcConnect (addr, SESCLASS_TCPIP);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      if (ses)
	PrpcSessionFree (ses);
      return NULL;
    }
  else
    {
      if (!_thread_sched_preempt)
	ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  memset (pwd, 0, sizeof (pwd));
  sec_login_digest (ses->dks_own_name, usr, pwd1, (unsigned char *) pwd);
  result = PrpcSync (PrpcFuture (ses, &s_pl_debug, usr, pwd));
  if (!result)
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return NULL;
    }
  return (caddr_t) ses;
}

int
pldbg_command (void *ses1, char *cmd1)
{
  dk_session_t *ses = (dk_session_t *) ses1;
  caddr_t cmd = box_dv_short_string (cmd1);
  char *tok, *toks = NULL;
  dk_set_t set = NULL, set1;
  int i = 0, do_cmd = -1;

  if (NULL != cmd)
    do
      {
	pldbg_cmd_t *tmp;

	if (!i)
	  tok = strtok_r (cmd, " \r\n", &toks);
	else
	  tok = strtok_r (NULL, " \r\n", &toks);

	if (tok)
	  {

	    while (tok && toks && isspace (*toks))
	      toks++;

	    if (!i)
	      {
		for (tmp = pld_cmds; tmp->pld_name; tmp++)
		  {
		    if (!strnicmp (tmp->pld_name, tok, strlen (tok)))
		      {
			dk_set_push (&set, box_num (tmp->pld_code));
			do_cmd = tmp->pld_code;
			break;
		      }
		  }
		if (do_cmd < 0)
		  {
		    dk_set_push (&set, box_num (do_cmd));
		    dk_set_push (&set, box_dv_short_string (tok));
		    break;
		  }
	      }
	    else if (i == 1)
	      {
		if (do_cmd == PD_INFO)
		  {
		    for (tmp = pld_infos; tmp->pld_name; tmp++)
		      if (!strnicmp (tmp->pld_name, tok, strlen (tok)))
			{
			  dk_set_push (&set, box_num (tmp->pld_code));
			  break;
			}
		  }
		else if (do_cmd == PD_FRAME)
		  dk_set_push (&set, box_num (atoi (tok)));
		else
		  dk_set_push (&set, box_dv_short_string (tok));
	      }
	    else if (i == 2)
	      {
		if (do_cmd != PD_SET)
		  {
		    long numb = atoi (tok);
		    dk_set_push (&set, box_num (numb));
		  }
		else
		  dk_set_push (&set, box_dv_short_string (tok));
	      }
	    else
	      {
		dk_set_push (&set, box_dv_short_string (tok));
	      }
	    i++;
	  }
      }
    while (tok);

  dk_free_box (cmd);
  set1 = dk_set_nreverse (set);
  cmd = (caddr_t) dk_set_to_array (set1);
  dk_set_free (set);

  PrpcWriteObject (ses, cmd);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return 0;
    }
  return 1;
}

caddr_t
pldbg_read_resp (void *ses1)
{
  dk_session_t *ses = (dk_session_t *) ses1;
  caddr_t res = (caddr_t) PrpcReadObject (ses);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return NULL;
    }
  return res;
}

#define EOL "\n"
void
pldbg_help (FILE * f)
{
  pldbg_cmd_t *cmd = pld_cmds, *nfo = pld_infos;
  fprintf (f, "OpenLink Interactive PL Debugger (Virtuoso).\n" "\n" "Available commands:\n");
  for (; cmd->pld_name; cmd++)
    {
      fprintf (f, "   %s %s - %s\n", cmd->pld_name, cmd->pld_params ? cmd->pld_params : "", cmd->pld_descr);
      if (cmd->pld_code == PD_INFO)
	{
	  for (; nfo->pld_name; nfo++)
	    {
	      fprintf (f, "       %s - %s\n", nfo->pld_name, nfo->pld_descr);
	    }
	}
    }
}
