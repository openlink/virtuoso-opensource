/*
 *  viwin32.c
 *
 *  $Id$
 *
 *  OpenLink Virtuoso DBMS Server
 *  Main code for Win32
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

#ifndef IN_LIBUTIL
#define IN_LIBUTIL
#endif

#include "libutil.h"
#include "sqlver.h"
#include "wi.h"
#ifdef _RENDEZVOUS
# include "rendezvous.h"
#endif

/*
 *  Service parameters
 */
#define SERVICE_NAME	"Virtuoso"
#define DISPLAY_NAME	"OpenLink Virtuoso Server"
#define SERVICE_TYPE	SERVICE_WIN32_OWN_PROCESS

/*
 *  Values for f_cmd
 */
#define CMD_NONE	0	/* No +service command was specified */
#define CMD_START	1	/* +service start */
#define CMD_STOP	2	/* +service stop */
#define CMD_CREATE	3	/* +service create */
#define CMD_DELETE	4	/* +service delete */
#define CMD_LIST	5	/* +service list */
#define CMD_SAFECREATE	6	/* +service screate */


/*
 *  Values for os_sigh_action
 *  Handles unix like signals and also shutdown events from
 *  the persistent service runtime
 */
#define SIGH_BLOCK	1	/* block/hold signal - critical operation */
#define SIGH_EXIT	2	/* exit() on signal is OK */
#define SIGH_SHUTDOWN	3	/* signal handler should use semaphore
				   to do a regular shutdown */

/*
 *  signal priorities / shutdown mode
 */
#define SHUTRQ_UNDEF	0	/* do not shutdown */
#define SHUTRQ_NORMAL	1	/* normal shutdown (checkpoint) */
#define SHUTRQ_FAST	2	/* fast shutdown (no checkpoint) */

/* Undefined value for pending signals */
#define SIGNOTHING	(-1)

/* Values for RegisterServiceProcess() */
#define RSP_UNREGISTER_SERVICE	0x00000000
#define RSP_SIMPLE_SERVICE	0x00000001

#define log		logit

struct service_command
{
  char *	cmdName;
  int		cmdValue;
  char *	cmdHelp;
};

/*
 *  Externals from libWi
 */
extern semaphore_t *background_sem;
extern int main_thread_ready;
extern void (*db_exit_hook) (void);	/* called on shutdown */
extern void (*process_exit_hook) (int state);

/* externals from sqlsrv.c */
extern caddr_t sf_make_new_main_log_name (void);
extern unsigned long autocheckpoint_log_size;

/*
 *  Externals from viconfig.c
 */
extern char *c_serverport;		/* port to use */
extern unsigned long cfg_autocheckpoint;

extern int in_crash_dump;

void new_cfg_replace_log (char *new_log);
void new_cfg_set_checkpoint_interval (int32 f);
void new_db_read_cfg (caddr_t *it, char *mode);
void new_dbs_read_cfg (caddr_t *it, char *mode);
dk_set_t new_cfg_read_storages (caddr_t **temp_storage);
void sf_make_auto_cp (void);
void srv_set_cfg (void (*replace_log)(char *str), void (*set_checkpoint_interval)(int32 f),
      		 void (*read_cfg)(caddr_t * it, char *mode), void (*s_read_cfg)(caddr_t * it, char *mode),
    		 dk_set_t (*read_storages)(caddr_t **temp_file));

void srv_global_init (char *mode);
void db_to_log (void);
void db_crash_to_log (char *mode);
void repl_read_db_levels (void);
void db_not_in_use (void);
int http_init_part_two ();
void ssl_server_listen ();

/*
 *  Command line globals
 */
int	f_foreground;			/* foreground mode */
int	f_debug;			/* debug mode */
char *	f_config_file;			/* config file to use */
extern char *f_old_dba_pass;
extern char *f_new_dba_pass;
extern char *f_new_dav_pass;
int	f_cmd;				/* +service command to execute */
int	f_no_checkpoint;
int	f_checkpoint_only;
int	f_backup_dump;
int	f_crash_dump;
int	f_read_from_rebuilt_database;
int	f_debug;
char *	f_mode = "";
char *	f_instance = SERVICE_NAME;
char *	f_dump_keys = "";
int 	f_service_manual;              	/* designate to create service in manual mode */

extern char *f_crash_dump_data_ini;

extern const char* recover_file_prefix;
extern int ob_just_report;

/*
 *  Globals for virtuoso
 */
PCONFIG	pconfig = NULL;			/* configuration file */

/*
 *  Module locals
 */
extern LOG *stderr_log;
static int db_shutdown;
static int is_in_use;			/* .lck file created */

/* Current service status for UpdateRunningServiceStatus */
static SERVICE_STATUS		dbmsSrvStatus;

/* Status handle to pass the dbmsSrvStatus to the OS */
static SERVICE_STATUS_HANDLE	hDbmsSrvStatus;

/* Set if this is the service instance */
static BOOL			serviceFlag;

/* Set if a console needs to be allocated */
static BOOL			debugFlag;

/* Pending signal */
static int sigh_pending_signal = SIGNOTHING;

/* Signal handling mode */
static int sigh_mode;

/* Global instance */
static HINSTANCE hInstance;


/*
 *  Prototypes
 */
int		ApplicationMain (int argc, char **argv);
void		EndNTApplication (void);
static void	f_service (struct pgm_option *opt);
int		cfg_setup (void);
int		db_check_in_use (void);
static void	sigh_do_action (int is_asynchronous);
static int	set_virtuoso_dir (void);

/* Program options */
struct pgm_option options[] =
{
  {"foreground", 'f', ARG_NONE, &f_foreground, "run in the foreground"},

  {"configfile", 'c', ARG_STR, &f_config_file,
    "specify an alternate configuration file to use,\n"
    "\t\t\tor a directory where virtuoso.ini can be found"},

  {"no-checkpoint", 'n', ARG_NONE, &f_no_checkpoint,
    "do not checkpoint on startup"},

  {"checkpoint-only", 'C', ARG_NONE, &f_checkpoint_only,
    "exit as soon as checkpoint on startup is complete"},

  {"backup-dump", 'b', ARG_NONE, &f_backup_dump,
    "dump database into the transaction log, then exit"},

  {"crash-dump", 'D', ARG_NONE, &f_crash_dump,
    "dump inconsistent database into the transaction log,\n"
    "\t\t\tthen exit"},

  {"crash-dump-data-ini", 'A', ARG_STR, &f_crash_dump_data_ini,
    "specify the DB ini to use for reading the data to dump"},

  {"restore-crash-dump", 'R', ARG_NONE, &f_read_from_rebuilt_database,
    "restore from a crash-dump"},

  {"mode", 'M', ARG_STR, &f_mode,
    "specify mode options for server startup (onbalr)"},

  {"dumpkeys", 'K', ARG_STR, &f_dump_keys,
    "specify key id(s) to dump on crash dump (default : all)"},

  {"restore-backup", 'r', ARG_STR, (char **) &recover_file_prefix,
    "restore from online backup"},

  {"backup-dirs", 'B', ARG_STR, &backup_dirs,
    "default backup directories"},

  {"debug", 'd', ARG_NONE, &f_debug, "allocate a debugging console"},

  {"pwdold", '\0', ARG_STR, &f_old_dba_pass, "Old DBA password"},

  {"pwddba", '\0', ARG_STR, &f_new_dba_pass, "New DBA password"},

  {"pwddav", '\0', ARG_STR, &f_new_dav_pass, "New DAV password"},

  {"service", 'S', ARG_FUNC, f_service, "specify a service action to perform"},

  {"instance", 'I', ARG_STR, &f_instance,
    "specify a service instance to start/stop/create/delete"},

  {"manual", 'm', ARG_NONE, &f_service_manual,
    "when creating a service, disable automatic startup"},

  {0}
};


/* Program information */
struct pgm_info program_info =
{
  NULL,
  "",
  "",
  EXP_RESPONSE,
  options
};


/* Service commands */
static struct service_command service_commands[] =
{
  {"start",	CMD_START,	"start a service instance"},
  {"stop",	CMD_STOP,	"stop a service instance"},
  {"create",	CMD_CREATE,	"create a service instance"},
  {"screate",	CMD_SAFECREATE,	"create a service instance without deleting the existing one"},
  {"delete",	CMD_DELETE,	"delete a service instance"},
  {"list",	CMD_LIST,	"list all service instances"},
  {0}
};


/*
 *  Handles the +service argument
 */
static void
f_service (struct pgm_option *opt)
{
  struct service_command *pCmd;

  if (f_cmd != CMD_NONE)
    usage ();

  for (pCmd = service_commands; pCmd->cmdName; pCmd++)
    {
      if (!stricmp (pCmd->cmdName, optarg))
	{
	  f_cmd = pCmd->cmdValue;
	  break;
	}
    }
  if (f_cmd == CMD_NONE)
    usage ();
}


static void
logwinerr (DWORD err)
{
  char *msgBuf;

  if (FormatMessage (
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
      NULL, err, 0, (LPTSTR) &msgBuf, 1, NULL) != 0)
    {
      log (L_ERR, "%s", msgBuf);
      LocalFree (msgBuf);
    }
}


/*
 *  Display a service related error message
 */
static void
service_error (char *action)
{
  DWORD err;

  err = GetLastError ();
  log (L_ERR, "Unable to %s the %s service (%d)", action, f_instance, err);
  logwinerr (err);
}


/*
 *  Is this service the default (Virtuoso) instance
 */
static int
is_default_instance (void)
{
  return strcmp (f_instance, SERVICE_NAME) == 0;
}


/*
 *  Handle the service action
 *  Cmd must be one of the CMD_xxx constants
 */
static int
service_action (SC_HANDLE hSCManager, int cmd)
{
  SERVICE_DESCRIPTION servDesc;
  SERVICE_STATUS servStatus;
  SC_HANDLE hService;
  LPTSTR binaryPath;
  LPTSTR displayName;
  LPTSTR commandLine;
  char instanceName[128];
  DWORD startType;
  DWORD err;
  char *cp;

  if (is_default_instance ())
    strcpy (instanceName, SERVICE_NAME);
  else
    sprintf (instanceName, "%s_%s", SERVICE_NAME, f_instance);

  switch (cmd)
    {
    /*
     *  Handle +service create
     */
    case CMD_CREATE:
    case CMD_SAFECREATE:
      /*
       *  Silently delete any existing service with the same name
       */
      if ((hService = OpenService (hSCManager, instanceName,
          SERVICE_QUERY_STATUS|DELETE)) != NULL)
	{
	  /*
	   *  Is the service running now?
	   */
	  if (QueryServiceStatus (hService, &servStatus))
	    {
	      if (servStatus.dwCurrentState != SERVICE_STOPPED)
	        {
		  SetLastError (ERROR_SERVICE_ALREADY_RUNNING);
		  service_error ("create");
		  return -1;
		}
	    }
	  if (cmd == CMD_CREATE)
	    DeleteService (hService);
	  CloseServiceHandle (hService);
	}

      /*
       *  Get the full binary path
       */
      binaryPath = salloc (1024, CHAR);
      if (GetModuleFileName (NULL, binaryPath, 1024) == 0)
	{
	  log (L_ERR, "unable to find %s (%d)", MYNAME, GetLastError ());
	  free (binaryPath);
	  return -1;
	}
      strlwr (binaryPath);

      displayName = salloc (256, CHAR);
      if (is_default_instance ())
        strcpy (displayName, DISPLAY_NAME);
      else
	sprintf (displayName, "%s [%s]", DISPLAY_NAME, f_instance);

      commandLine = salloc (2048, CHAR);

      /* Check config file exist. This also changes the current directory */
      if (set_virtuoso_dir () == -1)
        goto failed;

      startType = SERVICE_AUTO_START;
      if (f_service_manual)
	startType = SERVICE_DEMAND_START;

      /* Make sure that the service can access the configuration file */
      switch (GetDriveType (NULL))
	{
	case DRIVE_UNKNOWN: // benefit of the doubt
	case DRIVE_FIXED:
	  break;

	/*
	 *  When drive may not be on-line during system startup,
	 *  disable the auto start feature
	 */
	case DRIVE_REMOVABLE:
	case DRIVE_CDROM:
	case DRIVE_RAMDISK:	/* huh? */
	  if (startType == SERVICE_AUTO_START)
	    {
	      log (L_WARNING,
	          "The configuration file %s is on a removable medium",
		  f_config_file);
	      log (L_WARNING,
	          "Disabling auto-start for service %s", instanceName);
	      startType = SERVICE_DEMAND_START;
	    }
	  break;

	/*
	 *  For security reasons, services cannot access network resources
	 *  from the LocalSystem account. This can be solved with
	 *  Impersonation, but managing shares and security is really a bit
	 *  too much for now.
	 */
	//case DRIVE_REMOTE:
	//case DRIVE_NO_ROOT_DIR:
	default:
	  log (L_ERR,
	      "The configuration file %s should be on a local harddisk",
	      f_config_file);
	  log (L_ERR,
	      "Cannot create a service. "
	      "Please start with +foreground (-f) instead");
	  goto failed;
	}

      if (f_debug && startType == SERVICE_AUTO_START)
	{
	  log (L_DEBUG, "[Debugging console - auto-start disabled]");
	  startType = SERVICE_DEMAND_START;
	}

      /* Now complete all command line arguments */
      cp = stpcpy (commandLine, binaryPath);
      if (!is_default_instance ())
        {
	  cp = stpcpy (cp, " -I \"");
	  cp = stpcpy (cp, instanceName);
	  *cp++ = '"';
	}

      cp = stpcpy (cp, " -c \"");
      cp = stpcpy (cp, f_config_file);
      cp = stpcpy (cp, "\"");

      if (f_debug)
        cp = stpcpy (cp, " -d");

      if (f_no_checkpoint)
        cp = stpcpy (cp, " -n");

      if (f_read_from_rebuilt_database)
        cp = stpcpy (cp, " -R");

      /*
       *  Create a service for this executable
       */
      hService = CreateService (
	  hSCManager,		// Handle of service control manager database
	  instanceName,		// Address of name of service to start
	  displayName,		// Address of display name
	  SERVICE_ALL_ACCESS,	// Type of access to service
	  SERVICE_TYPE,		// Type of service
	  startType,		// When to start service
	  SERVICE_ERROR_NORMAL,	// Severity when service fails to start
	  commandLine,		// Address of name of binary file
	  NULL,			// Address of name of load ordering group
	  NULL,			// Address of variable to get tag identifier
	  "rpcss\0\0",		// Generic TCP/IP dependency
	  NULL,			// Address of account name of service
	  NULL);		// Address of password for service account
      if (hService == NULL)
	{
	  service_error ("create");
	failed:
	  free (binaryPath);
	  free (displayName);
	  free (commandLine);
	  return -1;
	}

      sprintf (commandLine, "Virtuoso %s instance",
	  is_default_instance () ? "default" : f_instance);
      servDesc.lpDescription = commandLine;
      ChangeServiceConfig2 (hService, SERVICE_CONFIG_DESCRIPTION, &servDesc);

      log (L_INFO, "The %s service has been registered", instanceName);
      log (L_INFO, "  and is associated with the executable %s", binaryPath);

      CloseServiceHandle (hService);
      free (binaryPath);
      free (displayName);
      free (commandLine);
      break;

    /*
     *  Handle +service delete
     */
    case CMD_DELETE:
      hService = OpenService (hSCManager, instanceName, DELETE);
      if (hService == NULL)
	{
	  service_error ("open");
	  return -1;
	}
      if (!DeleteService (hService))
	{
	  service_error ("delete");
	  CloseServiceHandle (hService);
	  return -1;
	}
      log (L_INFO, "The removal of the %s service registration was successful",
          instanceName);
      break;

    /*
     *  Handle +service start
     */
    case CMD_START:
      hService = OpenService (hSCManager, instanceName, SERVICE_START);
      if (hService == NULL)
	{
	  service_error ("open");
	  return -1;
	}
      if (!StartService (hService, 0, NULL))
	{
	  service_error ("start");
	  CloseServiceHandle (hService);
	  return -1;
	}
      CloseServiceHandle (hService);
      log (L_INFO, "The %s service is being started\n", instanceName);
      break;

    /*
     *  Handle +service stop
     */
    case CMD_STOP:
      hService = OpenService (hSCManager, instanceName, SERVICE_STOP);
      if (hService == NULL)
	{
	  service_error ("open");
	  return -1;
	}
      if (!ControlService (hService, SERVICE_CONTROL_STOP, &servStatus))
	{
	  service_error ("stop");
	  CloseServiceHandle (hService);
	  return -1;
	}
      CloseServiceHandle (hService);
      log (L_INFO, "The %s service is being shut down\n", instanceName);
      break;

    /*
     *  Handle +service list
     */
    case CMD_LIST:
      hService = OpenSCManager (NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
      if (hService == NULL)
	{
	  err = GetLastError ();
	  log (L_ERR, "Unable to open the service manager");
	  logwinerr (err);
	  return -1;
	}
      else
	{
	  LPENUM_SERVICE_STATUS pStatus, pItem;
	  DWORD dwServiceCount;
	  DWORD dwBytesNeeded;
	  DWORD dwState;
	  BOOL bAnyFound;
	  DWORD i;
	  BOOL ok;
	  char *name;
	  char *desc;

	  dwState = 0;
	  pStatus = (LPENUM_SERVICE_STATUS) salloc (1024, char);
	  bAnyFound = FALSE;

	  for (;;)
	    {
	      ok = EnumServicesStatus (hService,
		  SERVICE_WIN32, SERVICE_STATE_ALL,
		  pStatus, 1024,
		  &dwBytesNeeded, &dwServiceCount, &dwState);

	      err = GetLastError ();

	      if (!ok && err != ERROR_MORE_DATA)
		{
		  logwinerr (err);
		  break;
		}

	      pItem = pStatus;
	      for (i = 0; i < dwServiceCount; i++)
		{
		  if (!memcmp (pItem->lpServiceName, SERVICE_NAME,
		      sizeof (SERVICE_NAME) - 1))
		    {
		      bAnyFound = TRUE;
		      switch (pItem->ServiceStatus.dwCurrentState)
			{
			case SERVICE_STOPPED:
			  desc = "Stopped";
			  break;
			case SERVICE_START_PENDING:
			  desc = "Starting";
			  break;
			case SERVICE_STOP_PENDING:
			  desc = "Shutting down";
			  break;
			case SERVICE_RUNNING:
			  desc = "Running";
			  break;
			// case SERVICE_CONTINUE_PENDING:
			// case SERVICE_PAUSE_PENDING:
			// case SERVICE_PAUSED:
			default:
			  desc = "?";
			  break;
			}
		      name = pItem->lpServiceName;
		      if (name[sizeof (SERVICE_NAME)] == 0)
			name = "(Default Instance)";
		      else
			name += sizeof (SERVICE_NAME);
		      fprintf (stderr, "%-20s %s\n", name, desc);
		    }
		  pItem++;
		}
	      if (ok || err != ERROR_MORE_DATA)
		break;
	    }
	  free (pStatus);
	  CloseServiceHandle (hService);
	  if (!bAnyFound)
	    fprintf (stderr,  "No " SERVICE_NAME " services are installed\n");
	}
      break;

    default:
      log (L_ERR, "unimplemented command");
      return -1;
    }

  return 0;
}


/*
 *  This function is called to execute service manager database
 *  specific commands. (Start, stop, create, delete, etc)
 */
static int
ServiceCtrlMain (int cmd)
{
  SC_HANDLE hSCManager;
  int sts;

  if ((hSCManager = OpenSCManager (NULL, NULL, SC_MANAGER_ALL_ACCESS)) == NULL)
    {
      log (L_ERR, "unable to open the service control manager (%d)",
	  GetLastError ());
      return -1;
    }

  sts = service_action (hSCManager, cmd);

  CloseServiceHandle (hSCManager);

  return sts;
}


/*
 *  Creates a console for the debugging output of the service.
 *  Reroutes the standard file descriptors to the new console.
 */
DWORD
CreateApplicationConsole (void)
{
  if (debugFlag && AllocConsole ())
    {
      SetConsoleTitle (DISPLAY_NAME);

      fclose (stderr);
      fclose (stdin);
      fclose (stdout);

      stdout->_file = stderr->_file = _open_osfhandle (
	  (intptr_t) GetStdHandle (STD_ERROR_HANDLE), _O_TEXT);
      stdin->_file = _open_osfhandle (
	  (intptr_t) GetStdHandle (STD_INPUT_HANDLE), _O_TEXT);
    }

  return NO_ERROR;
}


/*
 *  Get the service configuration.
 *  Sets debugFlag to TRUE if this is an interactive service and manually
 *  started.
 */
DWORD
GetServiceConfig (void)
{
  QUERY_SERVICE_CONFIG *pConfig;
  SC_HANDLE hSCManager;
  SC_HANDLE hService;
  DWORD nBytes;
  DWORD status;
  char *buffer;

  hSCManager = OpenSCManager (NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
  if (hSCManager == NULL)
    {
      status = GetLastError ();
      log (L_ERR, "unable to open the service control manager (%d)", status);
      return status;
    }

  hService = OpenService (hSCManager, f_instance, SERVICE_QUERY_CONFIG);
  if (hService == NULL)
    {
      status = GetLastError ();
      log (L_ERR, "unable to open the %s service (%d)", f_instance, status);
      CloseHandle (hSCManager);
      return status;
    }

  buffer = salloc (2000, CHAR);
  pConfig = (LPQUERY_SERVICE_CONFIG) buffer;
  if (!QueryServiceConfig (hService, pConfig, 2000, &nBytes))
    {
      status = GetLastError ();
      log (L_ERR, "unable to get service configuration for the %s service (%d)",
	  f_instance, status);
      CloseServiceHandle (hService);
      CloseServiceHandle (hSCManager);
      free (buffer);
      return status;
    }

  if (pConfig->dwServiceType & SERVICE_INTERACTIVE_PROCESS)
    debugFlag = 1;

#if 0
  log (L_DEBUG, "Executable: %s", pConfig->lpBinaryPathName);
  log (L_DEBUG, "Display name: %s", pConfig->lpDisplayName);
  log (L_DEBUG, "ServiceType: %08X", pConfig->dwServiceType);
  log (L_DEBUG, "StartType: %08X", pConfig->dwStartType);
  log (L_DEBUG, "StartName: %s", pConfig->lpServiceStartName);
#endif

  free (buffer);
  CloseServiceHandle (hService);
  CloseServiceHandle (hSCManager);

  return NO_ERROR;
}


/*
 *  Pass the status of the service to the operating system
 */
int
UpdateRunningServiceStatus (DWORD code, int status)
{
  dbmsSrvStatus.dwCurrentState = code;
  dbmsSrvStatus.dwWaitHint = 0;
  dbmsSrvStatus.dwCheckPoint = 0;
  if (code == SERVICE_STOP_PENDING || code == SERVICE_START_PENDING)
    dbmsSrvStatus.dwWaitHint = 3600000;

  if (status >= 0)
    {
      dbmsSrvStatus.dwWin32ExitCode = status;
      dbmsSrvStatus.dwServiceSpecificExitCode = 0;
    }
  else
    {
      dbmsSrvStatus.dwWin32ExitCode = ERROR_SERVICE_SPECIFIC_ERROR;
      dbmsSrvStatus.dwServiceSpecificExitCode = -status;
    }

  if (!SetServiceStatus (hDbmsSrvStatus, &dbmsSrvStatus))
    {
      log (L_ERR, "SetServiceStatus() failed (%d)", GetLastError ());
      return -1;
    }
  return 0;
}


/*
 *  Called by the service manager to pass control commands
 *  to the service
 */
VOID WINAPI
ServiceCtrlProc (DWORD opCode)
{
  DWORD status;

  switch (opCode)
    {
    case SERVICE_CONTROL_STOP:
      sigh_pending_signal = CTRL_CLOSE_EVENT;
      sigh_do_action (1);
      UpdateRunningServiceStatus (SERVICE_STOP_PENDING, 0);
      break;

    case SERVICE_CONTROL_SHUTDOWN:
      sigh_pending_signal = CTRL_SHUTDOWN_EVENT;
      sigh_do_action (1);
      break;

    case SERVICE_CONTROL_INTERROGATE:
      break;

    default:
      log (L_ERR, "ServiceCtrlProc: unrecognized opcode %d", opCode);
      break;
    }

  // Send current status.
  status = dbmsSrvStatus.dwCurrentState;
  UpdateRunningServiceStatus (status, 0);
}


/*
 *  This procedure is invoked when this executable is
 *  started as a service. It's task is to register the
 *  service control procedure and report the new running
 *  status.
 */
void WINAPI
ServiceStartupProc (DWORD argc, LPTSTR *argv)
{
  DWORD status;

  if (!f_debug && !f_foreground)
    debugFlag = 0;	/* Do not create a console */

  /*
   *  Setup a running status structure
   */
  memset (&dbmsSrvStatus, 0, sizeof (dbmsSrvStatus));
  dbmsSrvStatus.dwServiceType = SERVICE_TYPE;
  dbmsSrvStatus.dwControlsAccepted =
      SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN;

  /*
   *  Get a handle to report this structure back to the OS
   */
  hDbmsSrvStatus = RegisterServiceCtrlHandler (f_instance, ServiceCtrlProc);
  if (hDbmsSrvStatus == (SERVICE_STATUS_HANDLE) 0)
    {
      log (L_ERR, "RegisterServiceCtrlHandler() failed (%d)", GetLastError ());
      return;
    }

  /*
   *  Ok, now tell them we're ready to start up
   */
  serviceFlag = TRUE;
  UpdateRunningServiceStatus (SERVICE_START_PENDING, 0);

  /*
   *  Determine debugFlag
   */
  if ((status = GetServiceConfig ()) != NO_ERROR)
    {
      UpdateRunningServiceStatus (SERVICE_STOPPED, status);
      return;
    }

  /*
   *  Create a console & connect standard handles
   */
  if ((status = CreateApplicationConsole ()) != NO_ERROR)
    {
      UpdateRunningServiceStatus (SERVICE_STOPPED, status);
      return;
    }

  /*
   *  This should do it. Start the service
   */
  status = ApplicationMain (argc, argv);
  UpdateRunningServiceStatus (SERVICE_STOPPED, status);
}


/*
 *  This procedure is called when this executable is
 *  started as a service. Attempt to link up with the
 *  service control manager to install the service.
 */
static int
ServiceMain (void)
{
  SERVICE_TABLE_ENTRY dispatchTable[2];

  memset (dispatchTable, 0, sizeof (dispatchTable));
  dispatchTable[0].lpServiceName = f_instance;
  dispatchTable[0].lpServiceProc = ServiceStartupProc;

  if (!StartServiceCtrlDispatcher (dispatchTable))
    {
      log (L_ERR, "unable to start the %s service dispatcher (%d)",
	  f_instance, GetLastError ());
      return 1;
    }

  return 0;
}


#ifdef SHARED_OBJECT


void (*so_initf) (void) = NULL;
typedef void (*exit_hook_t) (void);

void
VirtuosoServerSetInitHook (void (*initf) (void))
{
  so_initf = initf;
}

exit_hook_t
VirtuosoServerSetExitHook (exit_hook_t exitf)
{
  exit_hook_t old_hook = db_exit_hook;
  db_exit_hook = exitf;
  return old_hook;
}

int
VirtuosoServerMain (int argc, char **argv)
#else
int
main (int argc, char **argv)
#endif
{
  int sts;
  OSVERSIONINFO vInfo;

#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif

  process_exit_hook = terminate;

  srv_set_cfg (new_cfg_replace_log, new_cfg_set_checkpoint_interval, new_db_read_cfg, new_dbs_read_cfg, new_cfg_read_storages);

  vInfo.dwOSVersionInfoSize = sizeof (vInfo);
  if (!GetVersionEx (&vInfo))
    vInfo.dwPlatformId = VER_PLATFORM_WIN32s; // surely fails

  /*
   *  Parse the commandline
   */
  initialize_program (&argc, &argv);


  /*
   *  Is this process started as a service?
   */
  if (FILE_TYPE_UNKNOWN == GetFileType (GetStdHandle (STD_ERROR_HANDLE)))
    {
      ServiceMain ();
      return 0;
    }

  /*
   *  Don't execute maintenance commands running as a service
   */
  if (f_backup_dump || f_crash_dump)
    {
      f_cmd = CMD_NONE;
      f_foreground = 1;
    }

  /*
   *  Is there a +service command to execute?
   */
  if (f_cmd != CMD_NONE)
    sts = ServiceCtrlMain (f_cmd);
  else
    {
      /*
       *  No +service command
       */
      if (f_foreground)
	{
          /* Directly execute the code */
	  sts = ApplicationMain (argc, argv);
	}
      else
        {
	  /* Windows NT needs to start the service */
	   ServiceCtrlMain (CMD_START);
	}
    }

  if (sts)
    {
      EndNTApplication ();
      return 1;
    }

  return 0;
}


/*
 *  Returns priority of a signal
 */
static int
sigh_priority (int sig)
{
  switch (sig)
    {
    case SIGNOTHING:
      return SHUTRQ_UNDEF;

    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
      return SHUTRQ_NORMAL;

    // case CTRL_LOGOFF_EVENT:
    // case CTRL_SHUTDOWN_EVENT:
    default:
      return SHUTRQ_FAST;
    }
}


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
      terminate (1);

    case SIGH_BLOCK:
      log_info ("Server shutdown pending", sigh_pending_signal);
      return;

    case SIGH_SHUTDOWN:
      db_shutdown = sigh_priority (sigh_pending_signal);
      semaphore_leave (background_sem);
    }
}


static void
os_sigh_action (int mode)
{
  /* respond to pending signals with new operation mode */
  sigh_mode = mode;
  sigh_do_action (0);
}


/*
 *  This will receive the special events for the
 *  associated console (if any)
 */
static WINAPI
CtrlEventHandler (DWORD sig)
{
  switch (sig)
    {
    case CTRL_C_EVENT:
      log (L_DEBUG, "<ctrl-C>");
      break;
    case CTRL_BREAK_EVENT:
      log (L_DEBUG, "<ctrl-Break>");
      break;
    case CTRL_CLOSE_EVENT:
      log (L_DEBUG, "foreground window closed");
      break;
    case CTRL_LOGOFF_EVENT:
      log (L_DEBUG, "user logging off");
      return TRUE;
    case CTRL_SHUTDOWN_EVENT:
      log (L_DEBUG, "received system shutdown request");
      break;
    default:
      log (L_INFO, "got signal %ld", sig);
      break;
    }

  /* If higher priority signal pending, ignore lower signal */
  if (sigh_priority (sig) >= sigh_priority (sigh_pending_signal))
    {
      sigh_pending_signal = sig;
      sigh_do_action (1);
    }

  return TRUE;
}


/*
 *  Take the necessary action to shutdown this application
 */
void
terminate (int n)
{
  if (is_in_use)
    {
      if (virtuoso_server_initialized)
	log (L_INFO, "Server shutdown complete");
      else
	log (L_INFO, "Server exiting");

      fflush (stderr);
      db_not_in_use ();
    }

  if (serviceFlag)
    UpdateRunningServiceStatus (SERVICE_STOPPED, 0);

  else if (n && (f_foreground || f_debug))
    EndNTApplication ();

  exit (n);
}


/*
 *  Called when the entire DBMS has shut down
 */
static void
server_is_down (void)
{
  terminate (0);
}


unsigned long
wisvc_send_wait_hint (unsigned long every_n_msec, unsigned long wait_n_secs)
{
  return 0;
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



/*
 *  Display the normal commandline usage and
 *  the +service usage; then dies
 */
void
usage (void)
{
  struct service_command *pCmd;
  char version[400];
  char line[200];
  char *p;
#if LICENSE
  int lic;
#endif

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

  fprintf (stderr, "\n"
    "The argument to the +service option can be one of the following options:\n");

      for (pCmd = service_commands; pCmd->cmdName; pCmd++)
	fprintf (stderr, "  %-14.14s%s\n", pCmd->cmdName, pCmd->cmdHelp);

  fprintf (stderr, "\n"
    "To create a windows service 'MyService' using the configuration file "
    "c:\\database\\virtuoso.ini:\n"
	  "  %s +service create +instance MyService +configfile c:\\database\\virtuoso.ini\n"
    "\n"
    "To start this service, use 'sc start MyService' or:\n"
    "  %s +service start +instance MyService\n",
    program_info.program_name, program_info.program_name);

  terminate (1);
}


/*
 *  Change the process directory to where the executable is
 */
static int
set_virtuoso_dir (void)
{
  char virtuosoDir[1024];
  char *partName;
  char *cfgFile;
  char *cp;
  DWORD err;
  HANDLE hFind;
  WIN32_FIND_DATA findInfo;

  /* Change directory to where the executable is */
  if (GetModuleFileName (NULL, virtuosoDir, 1024) == 0)
    {
      err = GetLastError ();
      log (L_ERR, "GetModuleFileName failed (%d)", err);
      logwinerr (err);
      return -1;
    }

  /* Get our own hInstance to the executable */
  hInstance = LoadLibrary (virtuosoDir);

  /*
   *  If there is a configuration file specified, try to go to the
   *  directory where the config file is
   */
  if (f_config_file == NULL)
    f_config_file = "virtuoso";
  else
    {
      hFind = FindFirstFile (f_config_file, &findInfo);
      if (hFind != INVALID_HANDLE_VALUE)
        {
	  FindClose (hFind);
	  if (findInfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
	    {
	      sprintf (virtuosoDir, "%s\\virtuoso", f_config_file);
	      f_config_file = virtuosoDir;
	    }
	}
    }

  cfgFile = setext (f_config_file, "ini", EXT_ADDIFNONE);

  if (!GetFullPathName (cfgFile, 1024, virtuosoDir, (LPTSTR *) &partName))
    {
      log (L_ERR, "Cannot determine qualified name for %s", cfgFile);
      return -1;
    }
  f_config_file = s_strdup (virtuosoDir);

  /* Strip all after last \ */
  if ((cp = strrchr (virtuosoDir, '\\')) == NULL)
    {
      log (L_ERR, "Invalid directory %s", virtuosoDir);
      return -1;
    }
  /* If it is in the root, don't modify (eg. E:\) */
  if (cp[-1] != '\\')
    *cp = 0;

  if (!SetCurrentDirectory (virtuosoDir))
    {
      err = GetLastError ();
      log (L_ERR, "Unable to change the working directory to %s (%d)",
	  virtuosoDir, err);
      logwinerr (err);
      return -1;
    }

  hFind = FindFirstFile (f_config_file, &findInfo);
  if (hFind == INVALID_HANDLE_VALUE)
    {
      log (L_ERR, "There is no configuration file %s", f_config_file);
      return -1;
    }
  FindClose (hFind);

  log (L_DEBUG, "[Using %s in %s]", partName, virtuosoDir);

  return 0;
}


extern void langfunc_kernel_init(void);
int kernel_init(void)
{
  langfunc_kernel_init();
  return 0;
}

static int console_handlers_set = 0;

void
virtuoso_restore_sig_handlers (void)
{
  if (console_handlers_set)
    {
      SetConsoleCtrlHandler (NULL, FALSE);
      SetConsoleCtrlHandler (CtrlEventHandler, TRUE);
    }
}

/*
 *  This acts as the main of the application
 */
int
ApplicationMain (int argc, char **argv)
{
  dk_session_t *listening;

#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif

  /*
   *  Windows NT (running as a service) already has allocated a console
   */
  if (debugFlag || f_foreground)
    {
      console_handlers_set = 1;
      SetConsoleCtrlHandler (NULL, FALSE);
      SetConsoleCtrlHandler (CtrlEventHandler, TRUE);
    }

  tzset ();

  thread_initial (50000);
  background_sem = semaphore_allocate (0);

  /*
   *  Open stderr logging for debugging etc
   */
  stderr_log = log_open_fp (stderr, LOG_DEBUG, L_MASK_ALL,
            f_debug ?
                L_STYLE_LEVEL | L_STYLE_GROUP | L_STYLE_TIME :
		L_STYLE_GROUP | L_STYLE_TIME);

  /* change to virtuoso directory */
  if (set_virtuoso_dir () == -1)
    terminate (1);

  if (kernel_init () == -1)
    terminate (1);

  /* parse configuration file */
  if (cfg_setup () == -1)
    terminate (1);

  /* make sure database is not in use */
  if (db_check_in_use () == -1)
    terminate (1);

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
      os_sigh_action (SIGH_BLOCK);
      srv_global_init (f_mode);
      os_sigh_action (SIGH_EXIT);
      db_to_log ();
      terminate (0);
    }

  if (recover_file_prefix)
    {
      os_sigh_action (SIGH_BLOCK);
      srv_global_init (f_mode);
      os_sigh_action (SIGH_EXIT);
      terminate (0);
    }

  if (f_crash_dump)
    {
      os_sigh_action (SIGH_BLOCK);
      in_crash_dump = 1;
      {
	char mode2[20];
	sprintf (mode2, "D%10s", f_mode);
	srv_global_init (box_string (mode2));
      }

      os_sigh_action (SIGH_EXIT);
      db_recover_keys (f_dump_keys);
      log_info ("Using mode \'%s\'", f_mode);
      db_crash_to_log (f_mode);
      terminate (0);
    }

  /* begin normal server operation */
      if (!f_foreground && !f_debug)
	{
	  if (stderr_log)
	    log_close (stderr_log);
	  FreeConsole ();
	  debugFlag = 0;
	}


  /* open database, do roll forward */
  os_sigh_action (SIGH_BLOCK);
  srv_global_init (f_mode);

  /* roll forward can be lengthy - act on pending signals */
  os_sigh_action (SIGH_EXIT);

  /* make a checkpoint on startup */
  if (!f_no_checkpoint)
    {
      os_sigh_action (SIGH_BLOCK);
      sf_makecp (sf_make_new_main_log_name(), NULL, 0, 0);
    }

  /* quit after checkpoint on startup? */
  if (f_checkpoint_only)
    sf_fastdown (NULL);

  /* quit after crash-dump restore? */
  if (f_read_from_rebuilt_database)
    sf_fastdown (NULL);

  /* create listener endpoint */
  PrpcInitialize ();

  tcpses_set_reuse_address (0);	/* Fails on Windows */

  listening = PrpcListen (c_serverport, SESCLASS_TCPIP);
  server_port = tcpses_get_port (listening->dks_session);
  if (!DKSESSTAT_ISSET (listening, SST_LISTENING))
    {
      log_error ("Failed to start listening at SQL port '%s'", c_serverport);
      terminate (1);
    }

  ssl_server_listen ();
  if (!strchr (f_mode, 'b'))
    {
      http_init_part_two ();
    }
#ifdef _RENDEZVOUS
  start_rendezvous ();
#endif

  if (serviceFlag)
    UpdateRunningServiceStatus (SERVICE_RUNNING, 0);

  log (L_INFO, "Server online at %s (pid %d)", c_serverport, getpid ());

  /* Now we are ready to block on the semaphore */
  os_sigh_action (SIGH_SHUTDOWN);
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
#ifdef MALLOC_DEBUG
	  log_info ("Memory dump\n");
	  dbg_dump_mem();
#endif
	  /* fast shutdown - no checkpoint */
	  log (L_INFO, "Initiating quick shutdown");
	  if (serviceFlag)
	    UpdateRunningServiceStatus (SERVICE_STOP_PENDING, 0);
#ifdef _RENDEZVOUS
	  stop_rendezvous ();
#endif
	  sf_fastdown (NULL);
	}
      else if (db_shutdown == SHUTRQ_NORMAL)
	{
#ifdef MALLOC_DEBUG
	  log_info ("Memory dump\n");
	  dbg_dump_mem();
#endif
	  /* normal shutdown - make a checkpoint */
	  /* sf_shutdown calls sf_fastdown after the checkpoint,
	     which then invokes the db_exit_hook */
	  log (L_INFO, "Initiating normal shutdown");
	  if (serviceFlag)
	    UpdateRunningServiceStatus (SERVICE_STOP_PENDING, 0);
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
  call_exit (0);

  return NO_ERROR;
}


/* This is here so that OpenSSL can determine if this instance is running
 * as a windows service. OpenSSL tries to avoid UI when this returns TRUE.
 * It also affects the random generator which reads the screen at startup.
 */
__declspec(dllexport) BOOL __cdecl
_OPENSSL_isservice (void)
{
  return serviceFlag;
}
