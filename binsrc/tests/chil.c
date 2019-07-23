/*
 *  chil.c
 *
 *  $Id$
 *
 *  Server main
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

/*
   CHANGES

   27. - 29. May 1997  AK  Added -W option for changing working directory
   and in Windows NT, the options -I, -J, -S and -U
   for Installing, Starting and Uninstalling
   the Kubl Server as Windows NT service.
   For this created new module wiservic.c
   with the corresponding header file wiservic.h

   04. June. 1997 AK       Added main_the_rest loop for autocheckpointing.
 */

#include <sqlnode.h>
#include "wiservic.h"		/* Needed also in Unix builds. Includes wi.h. */
#include "sqlver.h"
#include "wi.h"

#if defined(__GNUC__) && __GNUC__ == 3 && (__GNUC_MINOR__ == 0 || __GNUC_MINOR__ == 1)
/* When compiling with optimization printf is defined as a macro and
   GNU C versions 3.0.x and 3.1.x don't support preprocessor directives
   inside macro arguments like those used in this file. */
# undef printf
#endif


#define KUBL_DEFAULT_PORT "1111"	/* For listening. */

char *f_config_file = "wi.cfg";
char *f_license_file = NULL;
PCONFIG pconfig = NULL;
int f_read_from_rebuilt_database = 0;
dk_session_t *listening;
extern unsigned long int cfg_autocheckpoint;	/* Defined in disk.c */


void
pause_if_necessary (char *prompt)	/* If output not redirected. */
{
/*
   Note the MS Visual C idiocy:
   The _isatty function determines whether handle is associated with a
   character device (a terminal, console, printer, or serial port).
   So wi -help > LPT1:  will still need a few strokes of enter.
 */
  if (!is_started_as_service () && isatty (fileno (stdout)))
    {
      if (prompt)
	puts (prompt);
      getchar ();
    }
}


void
chil_usage (char **argv)
{
  char *prompt = "\n-- More --";

  printf (
/* 345678901234567890123456789012345678901234567890123456789012345678901234567890 */
    DBMS_SRV_NAME " accepts the following arguments and options.\n"
    "\n"
    " portnum Use an integer portnum as a TCP/IP port number for listening to\n"
    "         incoming client requests, instead of the default " KUBL_DEFAULT_PORT ".\n"
#ifdef WIN32
    "         This is the same port number as in Host:Port field of Kubl ODBC Setup\n"
    "         dialog. You can use 32-bit ODBC Administrator to define alternative\n"
    "         KUBL data sources with different port numbers, and then install and\n"
    "         start as a service one or more KUBL servers with those same port\n"
    "         numbers.\n"
#endif
    "\n"
    " -W working_directory_as_an_absolute_pathname\n"
    "         Use the string following as a working directory, instead of the\n"
    "         directory where the server is started. \"Working Directory\" means the\n"
    "         directory where the server will expect to find " CFG_FILE " configuration\n"
    "         file and where it will log error messages to wi.err file. Also, the\n"
    "         definitions  database_file:  and  log_file:  in " CFG_FILE " are interpreted\n"
    "         as relative to the working directory.\n"
    "         If -W is not specified, the working directory will be the directory\n"
    "         where the server is started, unless it is started as a Windows NT\n"
    "         service in which case the default working directory is the same\n"
    "         directory where the executable itself resides.\n");

  pause_if_necessary (prompt);

  printf (
    "\n"
    " -d      Dump database into the log file specified in " CFG_FILE " and exit.\n"
    "\n"
    " -D[an]  [keynum1 [keynum2 [... [keynumN]]]]\n"
    "         Recover a corrupted database and dump it into the log file\n"
    "         specified in " CFG_FILE " and exit.\n"
    "         With  n  leaves out the initialization of the system tables.\n"
    "         With  a  leaves out the initialization of replication, users,\n"
    "         compilation of stored and system procedures, as well as the\n"
    "         caching of the grants.\n"
    "         The log file constructed can be later replayed with -R option.\n"
    "         The -D has to be given as the last option on the command line,\n"
    "         as all the rest of command line arguments, right of it, are\n"
    "         interpreted as recovery keys.\n"
    "\n"
    " -R      Read transaction account levels from rebuilt database, instead\n"
    "         of the log file. The -R switch is relevant only if replication\n"
    "         is being used.\n");

#ifdef WIN32
  pause_if_necessary (prompt);

  printf (
    "\n"
    " -I[name] Install Kubl Server as an autostartable Windows NT Service.\n"
    "          If optional name is given (right after -I, no space between) then\n"
    "          use it as a service name instead of the default \"" WISVC_DEFAULT_SERVICE_NAME "\".\n"
    "          The same command line can contain -S option which also starts the\n"
    "          installed service immediately. (-S, if present, must come after -I)\n"
    "          All other arguments and options on the command line are transferred\n"
    "          to the service, which it will then interpret normally each time\n"
    "          it is started.\n"
    "\n"
    " -J[name] Like -I[name] but doesn't make service autostartable.\n"
    "\n"
/* 345678901234567890123456789012345678901234567890123456789012345678901234567890 */
    " -S[name] Start the Kubl Server service, that is either installed at the same\n"
    "          time with -I (or -J) option, or has been already installed to the\n"
    "          system.\n"
    "          If -S is used to start an already installed service, then any other\n"
    "          options and arguments on the same command line, if present, will\n"
    "          override the original command line arguments used at the time of\n"
    "          installation of the service. However, the new arguments will remain\n"
    "          in effect only to the next boot-up time of the system.\n"
    "          The original arguments given with -I stay in effect if only the\n"
    "          -S option (possibly with service name), and nothing else is given.\n"
    "\n");
  pause_if_necessary (prompt);

  printf (
    "\n"
    "Notes:    Installing the service with autostart option means only that it will\n"
    "          be automatically started at the boot-up time of Windows NT.\n"
    "          To ensure that Kubl service is also started immediately at the\n"
    "          installation time use -I option followed by -S. E.g.:\n"
    "\n"
    " %s -IKubl2 -S 2222 -WE:\\Databases\\Kubl2\n"
    "\n"
    "          installs and starts Kubl Server as a service named \"Kubl2\",\n"
    "          using E:\\Databases\\Kubl2 as a working directory, listening to\n"
    "          client requests at the port 2222.\n"
    "\n"
    "          If -S is used without -I it will wait for the service to have fully\n"
    "          started up (i.e. initialized itself and rolled the log forward)\n"
    "          before telling that service was successfully started, otherwise\n"
    "          it does that almost immediately, and then it's your responsibility\n"
    "          to check that service was really started, from the services icon of\n"
    "          the Control Panel.\n"
    "\n", argv[0]
    );

  pause_if_necessary (prompt);

  printf (
    "\n"
    " -U[name] Uninstall Kubl server from services. If optional name is given, then\n"
    "          uninstall a service with that name, instead of default \"" WISVC_DEFAULT_SERVICE_NAME "\".\n"
    "          Note that uninstalling the service by itself doesn't stop the server,\n"
    "          that is, it may still continue to receive and process requests from\n"
    "          clients after the uninstallation. To really stop the server, you have\n"
    "          to send shutdown or raw_exit() to it with a client like ISQL/ISQLODBC.\n"
    );
#endif
/* 345678901234567890123456789012345678901234567890123456789012345678901234567890 */
}


extern int wisvc_Main_G_argc;
extern char **wisvc_Main_G_argv;
extern du_thread_t *the_main_thread;

static int db_shutdown;


#ifndef WIN32
void
sig_catcher (int sig)
{
  signal (SIGINT, SIG_IGN);
  signal (SIGTERM, SIG_IGN);
  signal (SIGHUP, SIG_IGN);
  signal (SIGQUIT, SIG_IGN);
  signal (SIGPIPE, SIG_IGN);
  log_info ("Caught signal %d, shutting down", sig);
  db_shutdown = 1;
  semaphore_leave (background_sem);
}
#endif


#define DWORD long

int kubl_main (int argc, char **argv, int called_as_service, DWORD * errptr);


int
main (int argc, char **argv)
{
#ifdef WIN32			/* Check if started as Service ? */
  int argv0len = strlen (argv[0]);
  int extlen = (sizeof (WISVC_EXE_EXTENSION_FOR_SERVICE) - 1);	/* 4 */

#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif

  if ((argv0len > extlen) &&
   !strcmp ((argv[0] + argv0len - extlen), WISVC_EXE_EXTENSION_FOR_SERVICE))
    /*  if(strstr(argv[0],WISVC_EXE_EXTENSION_FOR_SERVICE)) */
    {
      wisvc_Main_G_argc = argc;
      wisvc_Main_G_argv = argv;

      wisvc_start_kubl_service_dispatcher (argc, argv);
    }
  else
#endif
    {
#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif
      return (kubl_main (argc, argv, 0, NULL));
    }
}


/* kubl_main_exit is a macro defined in wiservic.h It needs
   variable called_as_service to decide whether to return or exit. */
/* Global. AIX cc will fuck up if this is local. */
int is_db_to_log = 0;
#ifdef DBG_BLOB_PAGES_ACCOUNT
int f_backup_dump = 0;
#endif



extern const char* recover_file_prefix;
extern int ob_just_report;

int
kubl_main (int argc, char **argv, int called_as_service, DWORD * errptr)
{
  int i, exit_after_options = 0, started_with_itself = 0;
  int read_from_rebuilt_database = 0;	/* For -R option. */
  int dump_for_recovery = 0;	/* For -D option. */
  char *empty = "";
  char *mode = empty;
  char *addr = KUBL_DEFAULT_PORT;
  char *service_name = (called_as_service ? argv[0] : NULL);
  char *s;

#ifdef PMN_LOG
  log_open_fp (stderr, LOG_DEBUG, L_MASK_ALL, L_STYLE_GROUP|L_STYLE_TIME);

  log_open_file ("wi.err", LOG_DEBUG, L_MASK_ALL, L_STYLE_GROUP | L_STYLE_TIME);
#endif

  /* If not overridden with any arguments specified with StartService,
     (i.e. either there are no args at all, or there is just -S)
     then use the permanent arguments (saved into wisvc_Main_G_argv)
     got from the original BinaryPath constructed in
     wisvc_Handle_I_and_J_options
   */
  if (called_as_service &&
      (((argc == 2) && !strncmp (argv[1], "-S", 2)) || (argc < 2))
    )
    {
      if (argc == 2)
	{
	  started_with_itself = 1;
	}
      argc = wisvc_Main_G_argc;
      argv = wisvc_Main_G_argv;
    }

  /* For debugging
     log_error (
     "kubl_main called with argc=%d, argv[0]=%s, argv[1]=%s, called_as_service=%d pid=%d",
     argc, argv[0], ((argc > 1) ? argv[1] : "NULL"),
     called_as_service, getpid());
   */

  /* If coming from KublServiceStart then argv vector seems to be NOT
     terminated by NULL (contrary to what MS documentation claims),
     so let's check that i stays smaller than argc. */
  for (i = 1; i < argc; i++)
    {
      s = argv[i];
      if ('-' == *s)
	{
	  if (mode == empty)
	    {
	      mode = s;
	    }
	  switch (*(s + 1))
	    {
#ifdef WIN32
	    case 'I':
	    case 'J':		/* Install to services. I =with autostart */
	      {
		int stat;
		if (mode == s)
		  {
		    mode = empty;
		  }
		if (called_as_service)
		  {
		    break;
		  }		/* Ignore in service. */
		stat = wisvc_Handle_I_and_J_options (argc, argv, s, i,
						     ('I' == *(s + 1)));
		kubl_main_exit (stat);
	      }
	    case 'S':		/* Start a previously installed service. */
	      {			/* Might be on the same command line as -J (or -I) */
		/* in which case Handle_I_and_J_options has the
		   responsibility to start it, directly from
		   CreateKublServices */
		int j, stat;
		char *service_name =
		(*(s + 2) ? (s + 2) : WISVC_DEFAULT_SERVICE_NAME);
		SC_HANDLE schandle;

		if (mode == s)
		  {
		    mode = empty;
		  }
		if (called_as_service)
		  {
		    started_with_itself = 1;
		    break;
		  }		/* Ignore in service. */

		/* We COULD copy the rest of argv vector one left, squashing -S
		   itself out of the existence, but we DON'T do it, as
		   -S option is an important signal to the started server
		   that it was started with wi.exe itself, not by clicking
		   the start button in services icon of Control Panel.
		   The difference is that with the latter starting way
		   the service is reported to be successfully started almost
		   immediately (before the initializations and log roll forward)
		   while the wi -S way of starting ensures that after the wi -S
		   command exits we know that the service is really started
		   all the way up and listening. This feature is needed in few
		   test scripts that turn Kubl server on and off, on and off. */
		/* for(j=i; j < argc; j++) { argv[j] = argv[j+1]; } argc--; */

		schandle = wisvc_OpenKublService (argv, service_name, "start",
					  (GENERIC_EXECUTE | GENERIC_READ));

		/* Returns 1 if started for sure, 0 if failed or unsure. */
		stat = wisvc_StartKublService (argc, argv, schandle,
					       service_name, argv[0], 0);

		/* Returns exit status 0 (= success) if certainly started, */
		kubl_main_exit (!stat);		/* otherwise 1 (= failure). */
		break;
	      }
	    case 'U':		/* Uninstall from Services. */
	      {
		char *service_name =
		(*(s + 2) ? (s + 2) : WISVC_DEFAULT_SERVICE_NAME);

		if (mode == s)
		  {
		    mode = empty;
		  }

		wisvc_UninstallKublService (argv, service_name);

		exit_after_options = 1;
		break;
	      }
#endif
	    case 'd':
#ifdef DBG_BLOB_PAGES_ACCOUNT
	      f_backup_dump = 1;
#endif
	      is_db_to_log = 1;
	      break;
	    case 'D':
	      {
		dump_for_recovery = (i + 1);
		goto out;
	      }
	    case 'R':
	      {
		read_from_rebuilt_database = 1;
		f_read_from_rebuilt_database = 1;
		break;
	      }
	    case 'j':
	      ob_just_report = 1;
	      /* fall to the next */
	    case 'r':
	      {
		if (i < argc - 1)
		  recover_file_prefix = argv[i+1];
		i++;
		break;
	      }
	    case 'B':
	      {
		if (i < argc - 1)
		  backup_dirs = argv[i+1];
		goto out;
	      }
	    case 'W':		/* Change working directory. */
	      {
		int stat;

		if (mode == s)
		  {
		    mode = empty;
		  }
		stat = wisvc_Handle_W_option (argc, argv, s, &i, called_as_service);
		if (stat)
		  {
		    kubl_main_exit (stat);
		  }
		break;
	      }
	    default:		/* E.g. everything else like -? -H or -h for help. */
	      {
		chil_usage (argv);
		kubl_main_exit (0);
	      }
	    }
	}
      else if (isdigit (*s))
	{
	  addr = s;
	}
      else
	{
	  dbg_printf (("%s: Don't know what to do with command line argument \"%s\". Read this:\n",
	      argv[0], s));
	  chil_usage (argv);
	  kubl_main_exit (1);
	}
    }				/* For loop over arguments. */
out:;

  if (exit_after_options)
    {
      kubl_main_exit (0);
    }

  /* If called as service and this was not started with wi -S
     (The -S option was not present in command line arguments)
     then this presumably is started with a start button from
     services manager of Control Panel. In that case, send
     SERVICE_RUNNING status immediately, so that it won't start waiting
     for memory initializations and log roll forwards, as its patience
     would not be enough for it, and it would instead falsely claim
     that:
     "Could not start the Kubl service on \\ARTAUD. Error 2186:
     The service is not responding to the control function."
   */

  if (called_as_service && !started_with_itself)
    {
      wisvc_send_service_running_status ();
    }

#ifndef WIN32
  signal (SIGPIPE, SIG_IGN);
#endif
  srv_global_init (mode);

  if (recover_file_prefix)
    {
      kubl_main_exit (0);
    }

  if (read_from_rebuilt_database)
    {
      kubl_main_exit (0);
    }


  if (is_db_to_log)
    {
      db_to_log ();
      kubl_main_exit (0);
    }

  /* If there was -D option, then dump_for_recovery is set to
     an index of argv one right to it, where might be one or more
     recovery keys. */
  if (dump_for_recovery)
    {
      for (i = dump_for_recovery; i < argc; i++)
	{
	  int k = atoi (argv[i]);
	  if (k)
	    db_recover_key (k, k);
	}
      db_crash_to_log (mode);
      kubl_main_exit (0);
    }

  tcpses_set_reuse_address (1);
  listening = PrpcListen (addr, SESCLASS_TCPIP);
  server_port = tcpses_get_port (listening->dks_session);
  if (!DKSESSTAT_ISSET (listening, SST_LISTENING))
    {
      kubl_main_exit (1);
    }
  if (service_name)		/* Started as a Windows NT service? */
    {
      log_info ("Server started at %s as service %s, pid=%d",
	  addr, service_name, getpid ());
    }
  else
    {
      log_info ("Server started at %s, pid=%d", addr, getpid ());
    }
  virtuoso_server_initialized = 1;


  if (!strchr (mode, 'b'))
    http_init_part_two ();
#ifdef REPLICATION
  if (read_from_rebuilt_database)	/* if booting from crash log, */
    {				/* go read the account levels from db */
      repl_read_db_levels ();
    }

  repl_sync_server (NULL, NULL);
#endif

  /* If called as Windows NT service, return now back to
     wisvc_KublServiceStart which in turn will call main_the_rest
     after it has set */
  if (called_as_service)
    {
      return (0);
    }				/* 0 = NO_ERROR */

#ifndef WIN32
  signal (SIGINT, sig_catcher);
  signal (SIGTERM, sig_catcher);
  signal (SIGHUP, sig_catcher);
  signal (SIGQUIT, sig_catcher);
#endif

  main_the_rest ();
  return 0;
}


extern int main_thread_ready;

/* Here we either do nothing (letting other threads to answer incoming
   connections and do their work), or just periodically do a checkpoint
   (if cfg_autocheckpoint is defined in wi.cfg) when the_grim_lock_reaper
   (in lock.c) periodically releases the semaphore for this thread.
 */
extern semaphore_t * background_sem;

int
main_the_rest (void)
{
  while (1)
    {
      main_thread_ready = 1;
      semaphore_enter (background_sem);
      if (db_shutdown)
	{
	  sf_shutdown (NULL, NULL);
	}
      else
	{
	  if (main_continuation_reason == MAIN_CONTINUE_ON_SCHEDULER &&
	      cfg_scheduler_period > 0)
	    {
	      sched_do_round ();
	    }
	  else if (cfg_autocheckpoint)
	    {
	      sf_make_auto_cp ();	/* Use the one and same old log file. */
	    }
	  else
	    /* Should not happen! */
	    {
	      GPF_T1 ("Initial thread continued, "
		  "although autocheckpointing is not used.");
	    }
	  main_continuation_reason = MAIN_CONTINUE_ON_CHECKPOINT;
	}
    }
  return 0;
}

#ifdef WIN32
#include <libutil.h>
#ifndef PERSISTENT_SERVICE
struct pgm_info program_info =
{
  NULL,
  "",
  "",
  EXP_RESPONSE,
  NULL
};
#endif
#endif

void
virtuoso_restore_sig_handlers (void)
{
  /* TODO: implement */
}

int cfg_setup (void)
{
  return 0;
}
