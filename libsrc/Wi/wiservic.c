/*
 *  wiservic.c
 *
 *  $Id$
 *
 *  Windows NT services
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
   New module by Antti Karttunen 29. May 1997
   for installing and starting the Kubl Server executable as
   Windows NT service. With extensive modifications
   to main function in chil.c
   Accompanied with WISERVIC.H, containing prototypes
   and few common macros required here and in chil.c
   Contains also code (e.g. an auxiliary function like
   wisvc_handle_W_option) for Unix builds, so do not miss
   this module from them.

   4.Jun.1997 AK  Added call to main_the_rest() (in chil.c) to the end
   of wisvc_KublServiceStart
   Added the function (dummy macro in Unix platforms)
   wisvc_send_service_running_status() which can be
   called in the initialization when you think is an
   appropriate time to signal the service starter
   that "the Kubl Server has successfully started".
   At least it is called in wisvc_KublServiceStart
   after all the initializations and roll forwards.
   (If called multiple times then the latter invocations
   of it and wisvc_send_wait_hint are silently ignored.)
 */

#include "wi.h"
#include "wiservic.h"		/* Includes also <winsvc.h> if WIN32 */

#ifdef WIN32
#include <direct.h>		/* For getcwd and chdir */
#include <process.h>		/* For getpid */
#endif


int wisvc_Main_G_argc = 0;
char **wisvc_Main_G_argv = NULL;

int
is_started_as_service (void)
{
  return ((NULL != wisvc_Main_G_argv));
}


int
wisvc_Handle_W_option (int argc, char **argv,
		       char *s, int *i_ptr, int called_as_service)
{
  char *work_dir = (s + 2);

  if (!*work_dir)		/* directory in the next arg? */
    {
      if ((++(*i_ptr) >= argc) || !(work_dir = argv[(*i_ptr)]))
	{
	  err_printf ((
			"%s: Directory name missing after command line option \"%s\", exiting.\n",
			argv[0], s));
	  kubl_main_exit (1);
	}
    }

  if (chdir (work_dir))		/* Is not zero, i.e. -1, an error. */
    {
/*   setWindowsError(); */
      err_printf (("%s: Cannot chdir to \"%s\" because: %s",
		   argv[0], work_dir, strerror (errno)));
      kubl_main_exit (1);
    }

  return (0);			/* Return 0 to indicate that everything went all right. */
}


#ifdef WIN32

/* Should we add the stuff also to the Event Log??? */
int
wisvc_err_printf (const char *str, ...)
{
  char temp[2199];
  va_list list;
  va_start (list, str);
  vsnprintf (temp, sizeof (temp), str, list);
  OutputDebugStringA (temp);	/* Some kind of Windows debugging function. */
#ifdef PMN_LOG
  log_error (temp);
#else
  log_error_list (str, list);	/* In log.c, appends stuff to wi.err */
#endif
  return 0;
}



/* Either begins with a slash or backslash, or the second character
   is colon, e.g. D:\somewhere\something\wi
 */
#define is_abs_path(P) (('\\' == *(P)) || ('/' == *(P)) || (':' == *(P+1)))

#define MAX_BINARY_PATH (2*_MAX_PATH)

int
wisvc_Handle_I_and_J_options (int argc, char **argv,
			      char *s, int i, int autostart)
{
  int called_as_service = 0;
  size_t path_len;
  int start_now = 0;
  char *service_name = (*(s + 2) ? (s + 2) : WISVC_DEFAULT_SERVICE_NAME);
  char *progname = argv[0];
  char *last_of_path, *cutpnt;
  char BinaryPathName[(MAX_BINARY_PATH) + 10];

/*
   if(i > 1)
   {
   err_printf((
   "%s: If you give %s option, it MUST be the first argument on command line!",
   progname,s));
   kubl_main_exit(1);
   }
 */

/* Then construct absolute path to this binary executable
   by combining working directory path got with getcwd
   with the program name got from argv[0].
   Note that the program name itself can be relative or absolute path.
   getcwd returns a string that represents the path of
   the current working directory. If the current working
   directory is the root, the string ends with a backslash (\).
   If the current working directory is a directory
   other than the root, the string ends with the directory
   name and not with a backslash.
   Note that absolute paths with upward parts (..)
   like the one below seem to work equally well, so
   we do not need to worry about .. :s and .:s in any
   special way.
   D:\inetpub\wwwroot\..\..\ic\.\diskit\wi\windebug\wi.exe
 */

  if (is_abs_path (progname))
    {
      strncpy (BinaryPathName, progname, (MAX_BINARY_PATH));
    }
  else
    /* We have to combine pwd + relative starting path */
    {
      if (NULL == getcwd (BinaryPathName, _MAX_PATH))
	{
	  err_printf (("%s: Cannot getcwd because: %s",
		       progname, strerror (errno)));
	  exit (1);
	}
      path_len = strlen (BinaryPathName);
      last_of_path = (BinaryPathName + path_len - 1);
      if ((0 == path_len) || !is_abs_path (last_of_path))
	{			/* Add the missing path separator between if needed */
	  strncat_ck (BinaryPathName, "\\", (MAX_BINARY_PATH));
	}
      /* And then the progname itself. */
      strncat_ck (BinaryPathName, progname, (MAX_BINARY_PATH));
    }

  /* Add our own special .eXe extension to the program name, so that
     when service is started, the code in main can see from argv[0]
     that it was started as a service, not as an ordinary command
     line program.
   */
  strncat_ck (BinaryPathName, WISVC_EXE_EXTENSION_FOR_SERVICE, (MAX_BINARY_PATH));

  /* Do chdir to the same directory where the executable is, needed
     because of wi.cfg check soon performed. */
  if ((NULL != (cutpnt = strrchr (BinaryPathName, '\\'))))
    {				/* Search the last backslash. */
      unsigned char
        save_the_following_char = *(((unsigned char *) cutpnt) + 1);
      *(cutpnt + 1) = '\0';

      if (chdir (BinaryPathName))	/* Is not zero, i.e. -1, an error. */
	{			/* However, we do not exit yet. */
	  err_printf (("%s: Cannot chdir to \"%s\" because: %s",
		       argv[0], BinaryPathName, strerror (errno)));
	  exit (1);
	}

      *(((unsigned char *) cutpnt) + 1) = save_the_following_char;
    }


/* Add all command line arguments after the absolute program name
   itself, separated by spaces. The started service will see them
   in the elements of argv vector, in the normal way, that is
   argv[0] will contain just the absolute program name which ends with
   .eXe and arguments are in argv[1], argv[2], etc.

   Check also for options -S (start the service), and -W change working
   directory. The latter would not be actually necessary to do here,
   but, if the directory is invalid, then it is much more friendly
   to give an error message here, than let the service itself fail,
   and hide the same error message to god knows which log file.
   Check that the user does not try to give options -D, -U, -R or -d
   to the service to be installed.

 */

  for (i = 1; i < argc; i++)
    {
      s = argv[i];
      if ('-' == s[0])
	{
	  switch (s[1])
	    {			/* With -S ignore the possibility that a different service
				   name could be specified after it than after -I or -J
				   DON'T ADD OPTIONS -S, -I or -J to BinaryPathName, as
				   they would be ignored anyway in service. */
	    case 'S':
	      {
		start_now = 1;
		continue;
	      }
	    case 'I':
	    case 'J':
	      {
		continue;
	      }
	    case 'W':
	      {
		int stat
		= wisvc_Handle_W_option (argc, argv, s, &i, called_as_service);
		if (stat)
		  {
		    kubl_main_exit (stat);
		  }
		break;
	      }
	    case 'D':
	    case 'U':		/* case 'R': */
	    case 'd':
	      {
		err_printf ((
			      "%s: Sorry, the option %s can be used only from command line, not in service!\n",
			      argv[0], s));
		exit (1);
	      }
	    }
	}

      strncat_ck (BinaryPathName, " ", (MAX_BINARY_PATH));
      strncat_ck (BinaryPathName, argv[i], (MAX_BINARY_PATH));
    }

  {				/* Check already HERE that there is a config file in the final
				   working directory, for the same user-friendly reason as
				   checking the validity of -W option's argument. */
    int fd = open (CFG_FILE, O_RDWR);
    if (fd < 0)
      {
	err_printf ((
		      "There must be a %s file in the server's working directory. Exiting.\n",
		      CFG_FILE));
	exit (-1);
      }
    fd_close (fd, NULL);	/* Defined in widisk.h */
  }

  wisvc_CreateKublService (argc, argv, service_name, BinaryPathName,
			   autostart, start_now);

  return (0);
}



/* Globals */

struct _SERVICE_STATUS wisvc_KublServiceStatus;
SERVICE_STATUS_HANDLE wisvc_KublServiceStatusHandle;


/*
   The lpServiceStartTable parameter contains an entry for each service
   that can run in the calling process. Each entry specifies the
   ServiceMain function for that service. For SERVICE_WIN32_SHARE_PROCESS
   services, each entry must contain the name of a service. This name is
   the service name that was specified by the CreateService function
   when the service was installed. For SERVICE_WIN32_OWN_PROCESS services,
   the service name in the table entry is ignored. (Fortunately!)
 */
SERVICE_TABLE_ENTRY wisvc_ServiceDispatchTable[] =
{
  {TEXT ("Kubl"), ((LPSERVICE_MAIN_FUNCTION) wisvc_KublServiceStart)},
  {NULL, NULL}
};


void
wisvc_start_kubl_service_dispatcher (int argc, char **argv)
{
  if (0 == StartServiceCtrlDispatcher (wisvc_ServiceDispatchTable))
    {
      wisvc_err_printf ("%s: StartServiceCtrlDispatcher error =  %d\n",
			argv[0], GetLastError ());
      exit (1);
    }
}




#define find_service_name_from(AV) ((AV)[0])


/* Note! Unlike the MS documentation claims, argv seems not to be
   NULL-terminated. That is, we have to watch argc when accessing
   elements of argv.
 */

int kubl_main (int argc, char **argv, int called_as_service, DWORD * errptr);

VOID
wisvc_KublServiceStart (DWORD argc, LPTSTR * argv)
{
  DWORD status;
  DWORD specificError = 0;
  char *service_name = find_service_name_from (argv);
  char *cutpnt;

/* First chdir to the same directory where the executable is
   (got from argv[0] of original main arguments), so that further
   error messages printed with wisvc_err_printf (which calls log_error
   in turn) will be appended to wi.err file in more appropriate
   place than \WINNT\SYSTEM32 directory.
 */
  if (wisvc_Main_G_argv && wisvc_Main_G_argv[0] &&
      (NULL != (cutpnt = strrchr (wisvc_Main_G_argv[0], '\\'))))
    {				/* Search the last backslash. */
      ptrlong len;
      char *work_dir;

      len = (cutpnt - wisvc_Main_G_argv[0]);
      if (NULL == (work_dir = ((char *) malloc (len + 1))))
	{
	  exit (7);		/* Failed beyond all reason, best to exit. */
	}
      else
	{
	  strncpy (work_dir, wisvc_Main_G_argv[0], len);	/* Leave backslash there */
	  work_dir[len] = '\0';
	}

      if (chdir (work_dir))	/* Is not zero, i.e. -1, an error. */
	{			/* However, we do not exit yet. */
/*        DWORD erhe = GetLastError(); */

	  wisvc_err_printf ("%s: Cannot chdir to \"%s\" because: %s",
			    argv[0], work_dir, strerror (errno));
	}
      free (work_dir);
    }

  wisvc_KublServiceStatus.dwServiceType = SERVICE_WIN32;
  wisvc_KublServiceStatus.dwCurrentState = SERVICE_START_PENDING;
  wisvc_KublServiceStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP;
  /* | SERVICE_ACCEPT_PAUSE_CONTINUE; (Not for wisvc_Kubl) */
  wisvc_KublServiceStatus.dwWin32ExitCode = 0;
  wisvc_KublServiceStatus.dwServiceSpecificExitCode = 0;
  wisvc_KublServiceStatus.dwCheckPoint = 0;
  wisvc_KublServiceStatus.dwWaitHint = 2;

  wisvc_KublServiceStatusHandle =
    RegisterServiceCtrlHandler (TEXT (service_name),
		       ((LPHANDLER_FUNCTION) wisvc_KublServiceCtrlHandler));

  if (wisvc_KublServiceStatusHandle == (SERVICE_STATUS_HANDLE) 0)
    {
      wisvc_err_printf ("%s: (%s) RegisterServiceCtrlHandler failed %ld\n",
			wisvc_Main_G_argv[0], service_name, GetLastError ());
      return;
    }

  /* Now we are calling kubl_main second time. */
  status = kubl_main (argc, argv, 1, &specificError);

  if (status != NO_ERROR)	/* Handle error condition */
    {
      wisvc_KublServiceStatus.dwCurrentState = SERVICE_STOPPED;
      wisvc_KublServiceStatus.dwCheckPoint = 0;
      wisvc_KublServiceStatus.dwWaitHint = 0;
      wisvc_KublServiceStatus.dwWin32ExitCode = status;
      wisvc_KublServiceStatus.dwServiceSpecificExitCode = specificError;

      SetServiceStatus (wisvc_KublServiceStatusHandle, &wisvc_KublServiceStatus);
      return;
    }

  wisvc_send_service_running_status ();


  /* This is where the service either does few checkpoints now and then
     or does nothing: */
    main_the_rest ();		/* In chil.c */

  return;
}



VOID wisvc_KublServiceCtrlHandler (IN DWORD Opcode)
{
  DWORD status;
  int my_pid = getpid ();	/* To ease the debugging. */

  switch (Opcode)
    {
    case SERVICE_CONTROL_STOP:
      {
	/* Do whatever it takes to stop here.
	   What it might be? Killing a thread or two?
	   Setting a global flag, stop now boys?
	 */
	wisvc_KublServiceStatus.dwWin32ExitCode = 0;
	wisvc_KublServiceStatus.dwCurrentState = SERVICE_STOPPED;
	wisvc_KublServiceStatus.dwCheckPoint = 0;
	wisvc_KublServiceStatus.dwWaitHint = 0;

	if (!SetServiceStatus (wisvc_KublServiceStatusHandle,
			       &wisvc_KublServiceStatus))
	  {
	    status = GetLastError ();
	    wisvc_err_printf (
			" [KUBL_SERVICE (%d)] SetServiceStatus error %ld\n",
			       my_pid, status);
	  }

	wisvc_err_printf (" [KUBL_SERVICE (%d)] Stopped\n",
			  my_pid);
	return;
      }

    case SERVICE_CONTROL_INTERROGATE:
      {
	/* Just send the current status in the end of this function. */
	break;
      }

#ifdef NOT_IMPLEMENTED_FOR_KUBL_SERVICE
    case SERVICE_CONTROL_PAUSE:
      /* Do whatever it takes to pause here. */
      wisvc_KublServiceStatus.dwCurrentState = SERVICE_PAUSED;
      break;

    case SERVICE_CONTROL_CONTINUE:
      /* Do whatever it takes to continue here. */
      wisvc_KublServiceStatus.dwCurrentState = SERVICE_RUNNING;
      break;
#endif

    default:
      {
	wisvc_err_printf (
	       " [KUBL_SERVICE (%d)] Unimplemented/recognized opcode %ld\n",
			   my_pid, Opcode);
      }
    }				/* switch */

  /* Send current status. */
  if (!SetServiceStatus (wisvc_KublServiceStatusHandle, &wisvc_KublServiceStatus))
    {
      status = GetLastError ();
      wisvc_err_printf (
			 " [KUBL_SERVICE (%d)] SetServiceStatus error %ld\n",
			 my_pid, status);
    }
  return;
}





/*

   A service configuration program uses the CreateService function to
   install a service in a service control manager database.
   The application-defined schSCManager handle must have
   SC_MANAGER_CREATE_SERVICE access to the SCManager object.
   The following example shows how to install a service.

   Start type is one of the following:
   SERVICE_AUTO_START   Specifies a device driver or Win32 service started
   by the service control manager automatically during
   system startup.
   SERVICE_DEMAND_START Specifies a device driver or Win32 service started
   by the service control manager when a process calls
   the StartService function.
   SERVICE_DISABLED     Specifies a device driver or Win32 service that can
   no longer be started.

   Error control type is one of the following:

   SERVICE_ERROR_IGNORE   The startup (boot) program logs the error but
   continues the startup operation.
   SERVICE_ERROR_NORMAL   The startup program logs the error and displays
   a message but continues the startup operation.
   SERVICE_ERROR_SEVERE   The startup program logs the error. If the
   last-known-good configuration is being started,
   the startup operation continues. Otherwise,
   the system is restarted with the last-known-good
   configuration.
   SERVICE_ERROR_CRITICAL The startup program logs the error, if possible.
   If the last-known-good configuration is being
   started, the startup operation fails. Otherwise,
   the system is restarted with the last-known-good
   configuration.

 */


void
wisvc_CreateKublService (int argc, char **argv,
			 char *service_name, char *BinaryPathName,
			 int autostart, int start_now)
{
  int called_as_service = 0;	/* Needed by macro err_printf */
  SC_HANDLE schSCManager, schService;
  int stat;

  schSCManager = OpenSCManager (
				 NULL,	/* LPCTSTR  lpMachineName, address of machine name string */
				 NULL,	/* LPCTSTR  lpDatabaseName, address of database name string */
				 SC_MANAGER_ALL_ACCESS	/* DWORD dwDesiredAccess, type of access */
    );

  if (NULL == schSCManager)
    {
      DWORD erhe = GetLastError ();

      err_printf ((
       "%s: Installing \"%s\" (path: \"%s\") as Windows NT service failed. "
	"Could not open Services Database with OpenSCManager, errno=%ld.\n",
		    argv[0], service_name, BinaryPathName, erhe));
      exit (1);
    }

  schService = CreateService (
			       schSCManager,	/* SCManager database      */
			       TEXT (service_name),	/* name of service         */
			       service_name,	/* service name to display */
			       SERVICE_ALL_ACCESS,	/* desired access          */
			       SERVICE_WIN32_OWN_PROCESS,	/* service type            */
		    (autostart ? SERVICE_AUTO_START : SERVICE_DEMAND_START),	/* start type */
			       SERVICE_ERROR_NORMAL,	/* error control type      */
			       ((LPCSTR) BinaryPathName),	/* service's binary        */
			       NULL,	/* no load ordering group  */
			       NULL,	/* no tag identifier       */
			       NULL,	/* no dependencies         */
			       NULL,	/* LocalSystem account     */
			       NULL);	/* no password             */

  if (NULL == schService)
    {
      DWORD erhe = GetLastError ();

      if (ERROR_SERVICE_EXISTS == erhe)
	{
	  err_printf ((
			"%s: Cannot install service \"%s\" because a service with the same "
			"name already exists! (errno=%ld, path=\"%s\").\n",
			argv[0], service_name, erhe, BinaryPathName));
	}
      else if (ERROR_SERVICE_MARKED_FOR_DELETE == erhe)
	{
	  err_printf ((
			"%s: Cannot install service \"%s\" because a service with the same "
			"name still exists, although it has been marked for delete. Use ISQL to "
			"stop the old service with shutdown or raw_exit() before continuing "
			" (errno=%ld, path=\"%s\").\n",
			argv[0], service_name, erhe, BinaryPathName));
	}
      else
	{
	  err_printf ((
			"%s: Installing \"%s\" (path: \"%s\") as Windows NT service failed. "
			"CreateService returned NULL, errno=%ld.\n",
			argv[0], service_name, BinaryPathName, erhe));
	}
      exit (1);
    }

  err_printf (("%s: Service \"%s\" installed successfully.\n",
	       argv[0], service_name));

  if (start_now)
    {
      stat = wisvc_StartKublService (argc, argv, schService,
				     service_name, BinaryPathName, 1);

    }

  CloseServiceHandle (schService);

  exit (!stat);
}


/*
   To start a service, the following function uses a handle created
   with CreateService given from the function CreateKublService above,
   and gives that handle to StartService function. StartService can be
   used to start either a Win32 service or a driver service, but this
   function assumes that a Win32 service is being started. After
   starting the service, the function uses the members of the
   SERVICE_STATUS structure returned by the QueryServiceStatus
   function to track the progress of the Win32 service.

   When calling from function above (wisvc_CreateKublService)
   with discard_argv as non-zero, we pass zero and NULL as argc and argv
   to the service being started, so that it will use the arguments
   specified permanently in BinaryPathName, so that service's
   startup will be identical each time, also when it is started
   automatically in the next boot-up. This is because arguments given
   in StartService are already lost at that time, but ones specified
   in BinaryPathName will remain, being available in original argv
   of main function (and stored immediately into wisvc_Main_G_argv).
   It would work also with discard_argv being zero, but this way we
   may spot few insipid bugs faster, because arguments specified by
   a "temporary" and "permanent" means might differ a little.

 */

int
wisvc_StartKublService (int argc, char **argv, SC_HANDLE schService,
			char *service_name, char *BinaryPathName,
			int discard_argv)
{				/* The last two arguments not really needed except for error messages */
  int called_as_service = 0;	/* Needed by macro err_printf */
  int checkpoint_has_stayed_stagnant_n_iterations = 0;
  SERVICE_STATUS ssStatus;
  DWORD dwOldCheckPoint = 0, dwOlderCheckPoint = 0;

/*
   err_printf(("StartKublService: argc=%d, argv[0]=%s, argv[1]=%s\n",
   argc,argv[0],argv[1]));
 */

  if (!StartService (schService,	/* handle of service    */
		     (discard_argv ? 0 : (argc - 1)),	/* number of arguments  */
		     (discard_argv ? NULL : (argv + 1))))	/* Arg vector from main */
    {				/* without argv[0] */
      DWORD erhe = GetLastError ();

      err_printf ((
		    "%s: Starting service \"%s\" (path: \"%s\") failed. "
		    "StartService returned zero, errno=%ld%s\n",
		    argv[0], service_name, BinaryPathName, erhe,
		    ((ERROR_SERVICE_ALREADY_RUNNING == erhe) ?
		     " because service has been already started!" : ".")
		  ));
      return (0);
    }
  else
    {
      err_printf (("Service %s start in progress, BinaryPathName=%s\n",
		   service_name, BinaryPathName));
    }

  /* Check the status until the service is running. */

  if (!QueryServiceStatus (schService,	/* handle of service       */
			   &ssStatus))	/* address of status info  */
    {
      DWORD erhe = GetLastError ();

      err_printf ((
	     "%s: Querying status of service \"%s\" (path: \"%s\") failed. "
		    "QueryServiceStatus returned zero, errno=%ld.\n",
		    argv[0], service_name, BinaryPathName, erhe));
      return (0);
    }

  Sleep (10);			/* First sleep ten seconds. */
  while (ssStatus.dwCurrentState != SERVICE_RUNNING)
    {
      if (SERVICE_STOPPED == ssStatus.dwCurrentState)
	{
	  break;
	}

      dwOlderCheckPoint = dwOldCheckPoint;
      dwOldCheckPoint = ssStatus.dwCheckPoint;	/* Save current checkpoint */

      if (ssStatus.dwWaitHint > 300)
	{
	  ssStatus.dwWaitHint = 300;
	}
      Sleep (ssStatus.dwWaitHint);	/* Wait for the specified interval. */

      /* Check the status again. */
      if (!QueryServiceStatus (schService, &ssStatus))
	{
	  break;
	}
/*
   err_printf((
   "dwOlderCheckPoint=%ld, dwOldCheckPoint=%ld, ssStatus.dwCheckPoint=%ld, ssStatus.dwWaitHint=%ld\n",
   dwOlderCheckPoint, dwOldCheckPoint,
   ssStatus.dwCheckPoint, ssStatus.dwWaitHint));
 */

/* Break if the checkpoint has not been incremented for three times. */
      if ((dwOldCheckPoint >= ssStatus.dwCheckPoint)
	  && (dwOlderCheckPoint >= ssStatus.dwCheckPoint))
	{
	  if (++checkpoint_has_stayed_stagnant_n_iterations > 3)
	    {
	      break;
	    }
	}
      checkpoint_has_stayed_stagnant_n_iterations = 0;
    }


  if (ssStatus.dwCurrentState == SERVICE_RUNNING)
    {
      {
	err_printf ((
		 "%s: Service \"%s\" started successfully (path: \"%s\").\n",
		      argv[0], service_name, BinaryPathName));
      }
      return (1);
    }
  else
    {
      err_printf ((
		"%s: Service \"%s\" (path: \"%s\") %s started correctly.\n",
		    argv[0], service_name, BinaryPathName,
	     ((SERVICE_START_PENDING != ssStatus.dwCurrentState) ? "has not"
	      : "may or may not have")));
      err_printf (("  Current State: %d\n",
		   ssStatus.dwCurrentState));
      err_printf (("  Exit Code: %d\n", ssStatus.dwWin32ExitCode));
      err_printf (("  Service Specific Exit Code: %d\n",
		   ssStatus.dwServiceSpecificExitCode));
      err_printf (("  Check Point: %d\n", ssStatus.dwCheckPoint));
      err_printf (("  Wait Hint: %d\n", ssStatus.dwWaitHint));
      err_printf ((
		    "Please use services icon in Control Panel to see whether service \"%s\" was really started."
	 " Check also the file wi.err in the server's working directory.\n",
		    service_name));
      return (0);
    }
}


/*
   In the following function, a service configuration program uses the
   OpenService function to get a handle with DELETE access to an
   installed service object. The function then uses the service object
   handle in the DeleteService function to remove the service from the
   service control manager database.
 */

SC_HANDLE
wisvc_OpenKublService (char **argv, char *service_name,
		       char *what_for, DWORD access_code)
{
  int called_as_service = 0;	/* Needed by macro err_printf */
  SC_HANDLE schSCManager, schService;

  schSCManager = OpenSCManager (
				 NULL,	/* LPCTSTR  lpMachineName, address of machine name string */
				 NULL,	/* LPCTSTR  lpDatabaseName, address of database name string */
				 SC_MANAGER_ALL_ACCESS	/* DWORD dwDesiredAccess, type of access */
    );

  if (NULL == schSCManager)
    {
      DWORD erhe = GetLastError ();

      err_printf ((
		    "%s: %sing service \"%s\" failed. "
	"Could not open Services Database with OpenSCManager, errno=%ld.\n",
		    argv[0], what_for, service_name, erhe));
      exit (1);
    }


  schService = OpenService (
			     schSCManager,	/* SCManager database         */
			     TEXT (service_name),	/* name of service            */
			     access_code);	/* only need access specified */

  if (schService == NULL)
    {
      DWORD erhe = GetLastError ();
      if (ERROR_SERVICE_DOES_NOT_EXIST == erhe)
	{
	  err_printf ((
			"%s: Cannot %s non-existent service \"%s\" OpenService failed, errno=%ld.\n",
			argv[0], what_for, service_name, erhe));
	}
      else if (ERROR_SERVICE_MARKED_FOR_DELETE == erhe)
	{
	  err_printf ((
		 "%s: Cannot %s service \"%s\" because a service with that "
			"name still exists, although it has been marked for delete. Use ISQL to "
			"stop the old service with shutdown or raw_exit() before continuing "
			" (errno=%ld).\n",
			argv[0], what_for, service_name, erhe));
	}
      else
	{
	  err_printf ((
			"%s: %sing service \"%s\" failed. "
		    "Could not Open Service with OpenService, errno=%ld.\n",
			argv[0], what_for, service_name, erhe));
	}
      exit (1);
    }

  return (schService);
}



void
wisvc_UninstallKublService (char **argv, char *service_name)
{
  int called_as_service = 0;	/* Needed by macro err_printf */
  SC_HANDLE schService = wisvc_OpenKublService (argv, service_name,
						"uninstall", DELETE);

  if (!DeleteService (schService))
    {
      DWORD erhe = GetLastError ();

      if (ERROR_SERVICE_MARKED_FOR_DELETE == erhe)
	{
	  err_printf ((
		 "%s: Cannot %s service \"%s\" because a service with that "
			"name still exists, although it has been marked for delete. Use ISQL to "
			"stop the old service with shutdown or raw_exit() before continuing "
			" (errno=%ld).\n",
			argv[0], "uninstall", service_name, erhe));
	}
      else
	{
	  err_printf ((
			"%s: Uninstalling service \"%s\" failed. "
			"DeleteService returned zero, errno=%ld.\n",
			argv[0], service_name, erhe));
	}
      exit (1);
    }
  else
    {
      err_printf (("%s: Service \"%s\" uninstalled successfully.\n",
		   argv[0], service_name));
    }

  CloseServiceHandle (schService);
}


/*
   If your service's initialization performs tasks that are expected
   to take longer than one second, your code must call SetServiceStatus
   periodically to send out wait hints and check points indicating that
   progress is being made.
   This is to be called from log_replay_file loop
   (maybe log_replay_entry?)
   We use wisvc_Main_G_argv to check whether this has been called
   as a service or from command line (in the latter case, do nothing.)

   Changed 4.June.1997 by transferring the first argument last_time_sent
   inside function itself, as a static variable.
   Note also that if the service has been already signaled as
   running (with the next function wisvc_send_service_running_status),
   then this function is NO-OP again.
 */

unsigned long
wisvc_send_wait_hint (unsigned long every_n_msec,
		      unsigned long wait_n_secs)
{

    static unsigned long last_time_sent = 0;
  unsigned long now;

  if (!wisvc_Main_G_argv)
    {
      return (last_time_sent);
    }				/* Not a service? */


    if (SERVICE_RUNNING == wisvc_KublServiceStatus.dwCurrentState)

    {
      return (last_time_sent);
    }


    now = GetTickCount ();	/* May wrap over to zero if Windows
				   runs continuously (hah!) over approximately 49.7 days. */

/*
   wisvc_err_printf(
   "wisvc_send_wait_hint: last_time_sent=%ld, now=%ld, every_n_msec=%ld\n",
   last_time_sent, now, every_n_msec);
 */

  if ((0 == last_time_sent) || ((now - last_time_sent) >= every_n_msec))
    {
      wisvc_KublServiceStatus.dwCheckPoint++;
      wisvc_KublServiceStatus.dwWaitHint = wait_n_secs;

/*
   wisvc_err_printf(
   "wisvc_send_wait_hint: wisvc_KublServiceStatus.dwCheckPoint=%ld\n",
   wisvc_KublServiceStatus.dwCheckPoint);
 */

      if (0 == SetServiceStatus (wisvc_KublServiceStatusHandle,
				 &wisvc_KublServiceStatus))
	{
	  DWORD status = GetLastError ();

	  wisvc_err_printf (
	  "%s: SetServiceStatus failed (error=%ld) in wisvc_send_wait_hint "
			     " wisvc_KublServiceStatus.dwCheckPoint=%ld\n",
			     wisvc_Main_G_argv[0], status,
			     wisvc_KublServiceStatus.dwCheckPoint);

	}

	last_time_sent = now;
      return (now);
    }
  else
    {
      return (last_time_sent);
    }
}



/* Can be called twice or more. The latter times are just ignored.
   Once called, the previous function, wisvc_send_wait_hint is
   also ignored.
 */

void
wisvc_send_service_running_status (void)
{

    if (wisvc_Main_G_argv &&
	(SERVICE_RUNNING != wisvc_KublServiceStatus.dwCurrentState))

    {				/* Initialization complete - report running status */

	wisvc_KublServiceStatus.dwCurrentState = SERVICE_RUNNING;

	wisvc_KublServiceStatus.dwCheckPoint = 0;

	wisvc_KublServiceStatus.dwWaitHint = 0;


	if (0 == SetServiceStatus (wisvc_KublServiceStatusHandle,
				   &wisvc_KublServiceStatus))

	{

	    DWORD status = GetLastError ();

	    wisvc_err_printf (
			      "%s: (wisvc_send_service_running_status) SetServiceStatus failed %ld\n",
			      wisvc_Main_G_argv[0], status);

	}

    }

}




#else /* WIN32 */

/* On Unix-platforms this is currently a NO-OP
   (defined as macro in wiservic.h) */

/*
   unsigned long wisvc_send_wait_hint(unsigned long every_n_msec,
   unsigned long wait_n_secs)
   {
   return(0);
   }
 */

#endif
