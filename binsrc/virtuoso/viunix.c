/*
 *  viunix.c
 *
 *  $Id$
 *
 *  OpenLink Virtuoso VDBMS Server main
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
 *  
*/

#include <libutil.h>
#include "sqlver.h"
#include "wi.h"
#ifdef _RENDEZVOUS
# include "rendezvous.h"
#endif

#ifdef HAVE_PWD_H
#include <pwd.h>
#endif

/*
 *  Values for sigh_action
 *  Handles unix like signals and also shutdown events from
 *  the persistent service runtime
 */
#define SIGH_BLOCK	1	/* block/hold signal - critical operation */
#define SIGH_EXIT	2	/* exit() on signal is OK */
#define SIGH_SHUTDOWN	3	/* signal handler should use semaphore
				   to do a regular shutdown */

/*
 *
 */
#define SHUTRQ_UNDEF	0	/* do not shutdown */
#define SHUTRQ_NORMAL	1	/* normal shutdown (checkpoint) */
#define SHUTRQ_FAST	2	/* fast shutdown (no checkpoint) */
#define SHUTRQ_EMERG	3	/* emergency shutdown (immediate exit) */

int	f_foreground;
char *	f_config_file;
extern char *f_old_dba_pass;
extern char *f_new_dba_pass;
extern char *f_new_dav_pass;
int	f_no_checkpoint;
int	f_checkpoint_only;
int	f_backup_dump;
int	f_crash_dump;
int	f_read_from_rebuilt_database;
int	f_wait;
int	f_debug;
char *	f_mode = "";
char *	f_dump_keys = "";


extern long min_signal_handling;
extern char *c_lock_file;

extern char *f_crash_dump_data_ini;

extern const char* recover_file_prefix;
extern int ob_just_report;
#ifdef V5UPGRADE
extern int32 log_v6_format;
#endif

struct pgm_option options[] =
{
  {"foreground", 'f', ARG_NONE, &f_foreground, "run in the foreground"},

  {"configfile", 'c', ARG_STR, &f_config_file,
    "use alternate configuration file"},

  {"no-checkpoint", 'n', ARG_NONE, &f_no_checkpoint,
    "do not checkpoint on startup"},

  {"checkpoint-only", 'C', ARG_NONE, &f_checkpoint_only,
    "exit as soon as checkpoint on startup is complete"},

  {"backup-dump", 'b', ARG_NONE, &f_backup_dump,
    "dump database into the transaction log, then exit"},

  {"crash-dump", 'D', ARG_NONE, &f_crash_dump,
    "dump inconsistent database into the transaction log, then exit"},

  {"crash-dump-data-ini", 'A', ARG_STR, &f_crash_dump_data_ini,
    "specify the DB ini to use for reading the data to dump"},

  {"restore-crash-dump", 'R', ARG_NONE, &f_read_from_rebuilt_database,
    "restore from a crash-dump"},

  {"wait", 'w', ARG_NONE, &f_wait, "wait for background initialization to complete"},

  {"mode", 'M', ARG_STR, &f_mode,
    "specify mode options for server startup (onbalr)"},

  {"dumpkeys", 'K', ARG_STR, &f_dump_keys,
    "specify key id(s) to dump on crash dump (default : all)"},

  {"restore-backup", 'r', ARG_STR, (char **) &recover_file_prefix,
    "restore from online backup"},

  {"backup-dirs", 'B', ARG_STR, &backup_dirs,
    "default backup directories"},

  {"debug", 'd', ARG_NONE, &f_debug, "Show additional debugging info"},

  {"pwdold", '\0', ARG_STR, &f_old_dba_pass, "Old DBA password"},

  {"pwddba", '\0', ARG_STR, &f_new_dba_pass, "New DBA password"},

  {"pwddav", '\0', ARG_STR, &f_new_dav_pass, "New DAV password"},

#ifdef V5UPGRADE
  {"log6", '\0', ARG_NONE, &log_v6_format, "Backup dump in version 6 format"},
#endif

  {0}
};


struct pgm_info program_info =
{
  NULL,
  "",
  "",
  EXP_RESPONSE,
  options
};


/* Externals from libWi */
extern du_thread_t *the_main_thread;	/* server thread */
extern semaphore_t *background_sem;
extern int main_thread_ready;

extern void (*db_exit_hook) (void);	/* called on shutdown */

extern void (*cfg_replace_log)(char *str);
extern void (*cfg_set_checkpoint_interval)(int32 f);
extern void (*db_read_cfg)(caddr_t *it, char *mode);

extern void (*process_exit_hook) (int state);

/* externals from sqlsrv.c */
extern caddr_t sf_make_new_main_log_name(void);
extern unsigned long autocheckpoint_log_size;

/* externals from repldb.c */
void repl_read_db_levels (void);

/* Externals from viconfig.c */
extern char *c_serverport;		/* port to use */
extern unsigned long cfg_autocheckpoint;

extern int in_crash_dump;

int db_check_in_use (void);
void new_cfg_replace_log (char *new_log);
void new_cfg_set_checkpoint_interval (int32 f);
void new_db_read_cfg (caddr_t *it, char *mode);
void new_dbs_read_cfg (caddr_t *it, char *mode);
dk_set_t new_cfg_read_storages (caddr_t **temp_storage);

extern LOG *startup_log;
LOG *cfg_open_syslog (int level, char *facility);

/* Globals for virtuoso */
PCONFIG pconfig = NULL;			/* configuration file */

/* Locals */
extern LOG *stderr_log;
static int db_shutdown;
static int is_in_use;			/* .lck file created */


#define SIGNOTHING	(-1)

static int sigh_pending_signal = SIGNOTHING;
static int sigh_mode;


/*
 *  Returns priority of a signal
 *  ^C is less important than a SIGQUIT
 */
static int
sigh_priority (int sig)
{
  switch (sig)
    {
    case SIGNOTHING:
      return SHUTRQ_UNDEF;

    case SIGINT:
      return SHUTRQ_NORMAL;

    /*
     *  Ignore SIGHUP in background mode, just in case
     */
    case SIGHUP:
      return f_foreground ? SHUTRQ_FAST : SHUTRQ_UNDEF;

    default:
      return SHUTRQ_FAST;
    }
}


void
viunix_terminate (int);

/*
 *  Respond to pending signal
 */
static void
sigh_do_action (int is_asynchronous)
{
  if (sigh_pending_signal == SIGNOTHING)
    return;

  switch (sigh_mode)
    {
    case SIGH_EXIT:
      viunix_terminate (1);

    case SIGH_BLOCK:
      log_info ("Server shutdown is pending", sigh_pending_signal);
      return;

    case SIGH_SHUTDOWN:
      db_shutdown = sigh_priority (sigh_pending_signal);
      semaphore_leave (background_sem);
    }
}


/*
 *  Asynchronous signal catcher
 */
static void
sigh_catcher (int sig)
{
  /* Don't catch the same signal twice */
  signal (sig, SIG_IGN);

  log_info ("Server received signal %d", sig);

  /* If higher priority signal pending, ignore lower signal */
  if (sigh_priority (sig) < sigh_priority (sigh_pending_signal))
    return;

  sigh_pending_signal = sig;
  sigh_do_action (1);
}

void
virtuoso_restore_sig_handlers (void)
{
  /* TODO: implement */
}


static void
sigh_report_and_forget (int sig)
{
  /* Don't catch the same signal twice */
  signal (sig, SIG_IGN);

  log_info ("Server received signal %d. Continuing with the default action for that signal.", sig);

  signal (sig, SIG_DFL);
  raise (sig);
}

#define MAX_SIGNALS 128

#ifndef SHARED_OBJECT
static void
sigh_set_notifiers ()
{
  int i;
  if (min_signal_handling)
    return;
  for (i = 1; i < MAX_SIGNALS; i++)
    {
      if (i != SIGKILL && /* unix not allowed */
	  i != SIGSTOP &&
	  i != SIGINT && /* virtuoso otherwise handled */
	  i != SIGTERM &&
	  i != SIGHUP  &&
	  i != SIGQUIT &&
	  i != SIGPIPE &&
          i != SIGSEGV) /* if we handle SIGSEGV, then crash backtrace
                           will point to us instead of to the real
                           crash place */
	{
	  if (SIG_ERR == signal (i, sigh_report_and_forget))
	    {
#if 0
#ifndef NDEBUG
	      log_error ("error setting signal %d : %m", i);
#endif
#endif
	      return;
	    }
	}
    }
}
#endif


static void
sigh_action (int mode)
{
  if (sigh_pending_signal == SIGNOTHING)
    {
      signal (SIGINT, sigh_catcher);
      signal (SIGTERM, sigh_catcher);
      signal (SIGHUP, sigh_catcher);
      signal (SIGQUIT, sigh_catcher);
      signal (SIGPIPE, SIG_IGN);
#if (!defined (__GLIBC__) || (__GLIBC__ > 2) || (__GLIBC__ == 2 && __GLIBC_MINOR__ <= 1))
/* GK: signals don't work with glibc 2.1 */
#ifndef SHARED_OBJECT
      sigh_set_notifiers ();
#endif
#endif
    }

  /* respond to pending signals with new operation mode */
  sigh_mode = mode;
  sigh_do_action (0);
}


static int bg_pipe[2];

enum notify_
  {
    VI_NOTIFY_UNSPEC,
    VI_NOTIFY_OPEN_DB,
    VI_NOTIFY_ROLL_FORWARD,
    VI_NOTIFY_CHECKPOINTING,
    VI_NOTIFY_NETWORK,
    VI_NOTIFY_ONLINE
  };

static char *notify_stage[] =
{
  "starting up",
  "opening the database",
  "rolling forward",
  "checkpointing",
  "initializing network connections",
  ""
};


static void
wait_for_init_done (void)
{
  unsigned char sts = VI_NOTIFY_UNSPEC;

  for (;;)
    {
      if (read (bg_pipe[0], &sts, 1) != 1)
	break;
      if (sts == VI_NOTIFY_ONLINE)
	return;
    }

  fprintf (stderr,
      "The VDBMS server process terminated prematurely\nafter %s.\n",
      notify_stage[sts]);
  exit (100 + sts);
}


static void
os_background (void)
{
  if (!f_foreground)
    {
      RETSIGTYPE (*usr1)();

      if (f_wait && pipe (bg_pipe) == -1)
	{
	  log_error ("unable to create a pipe");
	  viunix_terminate (1);
	}

      if (stderr_log)
	log_close (stderr_log);
      /*
       *  On some systems, the fork() system call resets some of the
       *  signal handler, so save them here.
       *  Esp. linux uses SIGUSR1 in the pthread library.
       */
      usr1 = signal (SIGUSR1, SIG_IGN);
      switch (fork ())
	{
	case -1:
	  log_error ("unable to fork (%m)");
	  viunix_terminate (1);
	case 0:
	  if (f_wait)
	    close (bg_pipe[0]);
	  close (0);
	  close (1);
	  close (2);
	  open ("/dev/null", O_RDWR);
	  dup2 (0, 1);
	  dup2 (0, 2);
	  if (setsid () == -1)
	    {
	      log_error ("unable to setsid (%m)");
	      viunix_terminate (1);
	    }
	  signal (SIGUSR1, usr1);
	  break;
	default:
	  if (f_wait)
	    {
	      close (bg_pipe[1]);
	      wait_for_init_done ();
	    }
	  exit (0);
	}
    }
}


static void
viunix_parent_notify (unsigned int status)
{
  if (!f_foreground)
    {
      unsigned char b = (unsigned char) status;
      if (write (bg_pipe[1], &b, 1) != 1 || status == VI_NOTIFY_ONLINE)
	close (bg_pipe[1]);
    }
}


#ifndef PACKAGE_NAME

/* Virtuoso */
# define PACKAGE_NAME		DBMS_SRV_NAME

# ifdef OEM_BUILD
#  define PACKAGE_FIBER		"(OEM Lite Edition)"
#  define PACKAGE_THREAD	"(OEM Enterprise Edition)"
# else 
#  define PACKAGE_FIBER		"(Lite Edition)"
#  define PACKAGE_THREAD	"(Enterprise Edition)"
# endif

#else

/* VOS */
#define PACKAGE_FIBER		"(fibers)"
#define PACKAGE_THREAD		"(multi threaded)"

#endif


void
usage (void)
{
  char version[400];
  char line[200];
  char *p;

  sprintf (line, "%s %s\n", PACKAGE_NAME,
	build_thread_model[0] == '-' && build_thread_model[1] == 'f' ?
	PACKAGE_FIBER : PACKAGE_THREAD);
  p = stpcpy (version, line);

  sprintf (line, "Version %s.%s%s%s as of %s\n",
      PACKAGE_VERSION, DBMS_SRV_GEN_MAJOR, DBMS_SRV_GEN_MINOR, build_thread_model, build_date);
  p = stpcpy (p, line);

  sprintf (line, "Compiled for %s (%s)\n", build_opsys_id, build_host_id);
  p = stpcpy (p, line);


  if (build_special_server_model && strlen(build_special_server_model) > 1)
    {
      sprintf (line, "Hosted Runtime Environments: %s\n", build_special_server_model);
      p = stpcpy (p, line);
    }

  sprintf (line, "%s\n", PRODUCT_COPYRIGHT);
  p = stpcpy (p, line);

  program_info.program_version = version;
  default_usage ();


  call_exit (1);
}


void db_not_in_use (void);

void
viunix_terminate (int exit_code)
{
  if (is_in_use)
    {
      if (virtuoso_server_initialized)
	log_info ("Server shutdown complete");
      else
	log_info ("Server exiting");

      db_not_in_use ();
    }

  exit (exit_code);
}


/*
 *  Called when the entire DBMS has shut down
 */
static void
server_is_down (void)
{
  viunix_terminate (0);
}


#ifdef SHARED_OBJECT

void (*so_initf) (void) = NULL;
void
VirtuosoServerSetInitHook (void (*initf) (void))
{
  so_initf = initf;
}

int
VirtuosoServerMain (int argc, char **argv)
#else
int
main (int argc, char **argv)
#endif
{
  dk_session_t *listening;

#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif
  if (!startup_log)
    startup_log = cfg_open_syslog (LOG_DEBUG, "default");

  process_exit_hook = viunix_terminate;

  thread_initial (50000);
  if (!background_sem)
    background_sem = semaphore_allocate (0);

  srv_set_cfg(new_cfg_replace_log, new_cfg_set_checkpoint_interval, new_db_read_cfg, new_dbs_read_cfg, new_cfg_read_storages);

  initialize_program (&argc, &argv);

  /* all of the below means foreground ! */
  if (f_backup_dump || recover_file_prefix || f_crash_dump)
    f_foreground = 1;
#ifdef V5UPGRADE
  if (!f_backup_dump && !f_read_from_rebuilt_database)
    log_v6_format = 0;
#endif

  /* put ourselves in the background */
  os_background ();

  if (f_foreground)
    stderr_log = log_open_fp (stderr, LOG_DEBUG, L_MASK_ALL,
            f_debug ?
                L_STYLE_LEVEL | L_STYLE_GROUP | L_STYLE_TIME :
		L_STYLE_GROUP | L_STYLE_TIME);

  dk_box_initialize (); /* This should happen before cfg_setup() because loading plugins may result in calls of bif_define() and thus calls of box_dv_uname_string() and the like */

  /* parse configuration file */
  if (cfg_setup () == -1)
    viunix_terminate (1);

  /* make sure database is not in use */
  if (db_check_in_use () == -1)
    viunix_terminate (1);

  /* mark .lck file for removal */
  is_in_use = 1;

  /* cleanup on exit */
  db_exit_hook = server_is_down;

#ifdef SHARED_OBJECT
  if (so_initf)
    {
      extern int c_case_mode;

      case_mode = c_case_mode;
      so_initf ();
    }
#endif

  /* Started for backup dump */
  if (f_backup_dump)
    {
      sigh_action (SIGH_BLOCK);
      srv_global_init (f_mode);
      sigh_action (SIGH_EXIT);
      db_to_log ();
      viunix_terminate (0);
    }

  if (recover_file_prefix)
    {
      sigh_action (SIGH_BLOCK);
      srv_global_init (f_mode);
      sigh_action (SIGH_EXIT);
      viunix_terminate (0);
    }

  if (f_crash_dump)
    {
      char *old_lck_file = c_lock_file;
      sigh_action (SIGH_BLOCK);
      in_crash_dump = 1;
      {
	char mode2[20];
	sprintf (mode2, "D%10s", f_mode);
	srv_global_init (box_string (mode2));
      }
      sigh_action (SIGH_EXIT);
      db_recover_keys (f_dump_keys);
      log_info ("Using mode \'%s\'", f_mode);
      db_crash_to_log (f_mode);
      if (f_crash_dump_data_ini)
	{
	  c_lock_file = old_lck_file;
	}
      viunix_terminate (0);
    }

  /* begin normal server operation */

  /* open database, do roll forward */
  viunix_parent_notify (VI_NOTIFY_OPEN_DB);
  sigh_action (SIGH_BLOCK);
  srv_global_init (f_mode);

  /* roll forward can be lengthy - act on pending signals */
  viunix_parent_notify (VI_NOTIFY_ROLL_FORWARD);
  sigh_action (SIGH_EXIT);

  /* make a checkpoint on startup */
  if (!f_no_checkpoint)
    {
      sigh_action (SIGH_BLOCK);
      viunix_parent_notify (VI_NOTIFY_CHECKPOINTING);
      sf_makecp (sf_make_new_main_log_name(), NULL, 0, 0);
    }

  /* quit after checkpoint on startup? */
  if (f_checkpoint_only)
    sf_fastdown (NULL);

  /* quit after crash-dump restore? */
  if (f_read_from_rebuilt_database)
    sf_fastdown (NULL);

  /* create listener endpoint */
  viunix_parent_notify (VI_NOTIFY_NETWORK);
  PrpcInitialize ();
  tcpses_set_reuse_address (1);
  listening = PrpcListen (c_serverport, SESCLASS_TCPIP);
  server_port = tcpses_get_port (listening->dks_session);
  if (!DKSESSTAT_ISSET (listening, SST_LISTENING))
    {
      if (listening->dks_session->ses_class == SESCLASS_UNIX)
	log_error ("Failed to start listening at the unix domain socket for tcp port '%s'", c_serverport);
      else
	log_error ("Failed to start listening at SQL port '%s'", c_serverport);
      viunix_terminate (1);
    }

  ssl_server_listen ();
  if (!strchr (f_mode, 'b'))
    {
      http_init_part_two ();
    }
#ifdef _RENDEZVOUS
  start_rendezvous ();
#endif
  /* Set the uid if specified */
#if defined (HAVE_GETPWNAM) && defined (HAVE_SETUID)
  if (run_as_os_uname)
    {
      uid_t uid;
      struct passwd *u_info = NULL;
      u_info = getpwnam (run_as_os_uname);
      if (!u_info)
	{
	  log_error ("Invalid user name %.200s specified in RunAs INI option. Exiting",
	      run_as_os_uname);
	  viunix_terminate (1);
	}
      uid = u_info->pw_uid;
      if (0 != setuid (uid))
	{
	  log_error ("Unable to set the user id %.200s specified in RunAs INI option : %m",
	      run_as_os_uname);
	  viunix_terminate (1);
	}
      log_info ("Using OS identity %.200s", run_as_os_uname);
    }
#else
  if (run_as_os_uname)
    {
      log_error (
	  "A user id %.200s specified in RunAs INI option, but setuid not supported on this platform.",
	  run_as_os_uname);
      viunix_terminate (1);
    }
#endif

  viunix_parent_notify (VI_NOTIFY_ONLINE);
  log_info ("Server online at %s (pid %d)", c_serverport, getpid ());

  /* Now we are ready to block on the semaphore */
  sigh_action (SIGH_SHUTDOWN);
  virtuoso_server_initialized = 1;
  sched_run_at_start ();

  for (;;)
    {
      /* wait for shutdown event */
      sched_set_thread_count();
      main_thread_ready = 1;
      semaphore_enter (background_sem);

      if (db_shutdown == SHUTRQ_FAST)
	{
	  /* fast shutdown - no checkpoint */
#ifdef MALLOC_DEBUG
	  log_info ("Memory dump\n");
	  dbg_dump_mem();
#endif
	  log_info ("Initiating quick shutdown");
#ifdef _RENDEZVOUS
	  stop_rendezvous ();
#endif
	  sf_fastdown (NULL);
	}
      else if (db_shutdown == SHUTRQ_NORMAL)
	{
	  /* normal shutdown - make a checkpoint */
	  /* sf_shutdown calls sf_fastdown after the checkpoint,
	     which then invokes the db_exit_hook */
#ifdef MALLOC_DEBUG
	  log_info ("Memory dump\n");
	  dbg_dump_mem();
#endif
	  log_info ("Initiating normal shutdown");
#ifdef _RENDEZVOUS
	  stop_rendezvous ();
#endif
	  sf_shutdown (sf_make_new_main_log_name(), NULL);
	}
      else
	{
	  if (main_continuation_reason == MAIN_CONTINUE_ON_SCHEDULER &&
	      cfg_scheduler_period > 0)
	    {
	      /* called from background task.
	       * It's time to do a scheduler loop
	       */
	      sched_do_round ();
	    }
	  else if (cfg_autocheckpoint || autocheckpoint_log_size)
	    {
	      /*
	       *  Called from background task (the_grim_lock_reaper)
	       *  It's time to autocheckpoint
	       *  Make a checkpoint reusing the current log
	       */
	      sf_make_auto_cp();
	    }
	  else
	    {
	      /* Initial thread continued although autocheckpointing is not used */
	      GPF_T;
	    }
	  /* reset back the reason flag to the default */
	  main_continuation_reason = MAIN_CONTINUE_ON_CHECKPOINT;
	}
    }
}

