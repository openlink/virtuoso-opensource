/*
 *  wiservic.h
 *
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

/*
   WISERVIC.H -- New include file by Antti Karttunen 29. May 1997
                 for the new module WISERVIC.C and main module CHIL.C
                 Contains also prototypes and macros (e.g. an auxiliary
                 function like wisvc_handle_W_option) for Unix builds,
                 so do not miss this module from them.

    4.June.1997 AK  Changed the prototype of wisvc_send_wait_hint
 */

#ifndef _WISERVIC_H
#define _WISERVIC_H

#ifdef WIN32
#include "wi.h" /* Includes widisk.h in turn. */
#include <windows.h> /* Includes winsvc.h in turn. */
#endif


#define WISVC_SEND_WAIT_HINT_EVERY_N_MSEC 500

#define WISVC_DEFAULT_SERVICE_NAME "Kubl" /* For Windows NT services. */

/* Added to the end of the file path of binary executable of Kubl
   by -S option, and this is then transferred in argv[0] to started
   service, so this can be used for checking whether the executable
   has been started normally at MS-DOS command prompt, or as a service.
 */
#define WISVC_EXE_EXTENSION_FOR_SERVICE ".eXe"

int main_the_rest(void); /* Actually in chil.c */

int wisvc_Handle_W_option(int argc, char **argv,
                    char *s, int *i_ptr, int called_as_service);


#ifdef WIN32

int ftruncate (int fh, long sz);
/* wisvc_err_printf should be of same type as printf to be usable in
\c err_printf macro. Thus it should return int. */
int wisvc_err_printf (const char *str, ...);

int wisvc_Handle_I_and_J_options(int argc, char **argv,
                            char *s, int i, int autostart);

void wisvc_start_kubl_service_dispatcher (int argc, char **argv);
VOID wisvc_KublServiceCtrlHandler (IN DWORD opcode);
VOID wisvc_KublServiceStart (DWORD argc, LPTSTR *argv);
VOID wisvc_KublServiceCtrlHandler (IN  DWORD  Opcode);
void wisvc_CreateKublService (int argc, char ** argv,
                        char *service_name, char *BinaryPathName,
                        int autostart, int start_now);
int wisvc_StartKublService(int argc, char **argv, SC_HANDLE schService,
              char *service_name, char *BinaryPathName,int discard_argv);
SC_HANDLE wisvc_OpenKublService(char **argv, char *service_name,
                          char *what_for, DWORD access_code);
void wisvc_UninstallKublService(char **argv, char *service_name);

int is_started_as_service(void);

/* THEN FEW MACROS, NEEDED IN WISERVIC.C and CHIL.C */

/* Used in kubl_main (in chil.c) and wisvc_Handle_*_options functions. */
#define setWindowsError() { if(errptr) { *errptr = GetLastError(); } }
#define err_printf(ARGS)\
 ( ( (is_started_as_service() ? (wisvc_err_printf) : (printf)) ARGS),\
 (!is_started_as_service() ? fflush(stdout) : 0))

unsigned long wisvc_send_wait_hint(unsigned long every_n_msec,
                                   unsigned long wait_n_secs);

void wisvc_send_service_running_status(void);

#else /* Unix platforms. */

#define wisvc_send_wait_hint(X,Y)
#define wisvc_send_service_running_status()

#define setWindowsError()
#define err_printf(ARGS) ((printf ARGS), fflush(stdout))

#endif

/* If used as Windows Service, then we have to return the status
   code to KublServiceStart, instead of raw exit. */
#define kubl_main_exit(S)\
 if(called_as_service) { return(S); } else { exit(S); }

int is_started_as_service (void);
#endif /* _WISERVIC_H */
