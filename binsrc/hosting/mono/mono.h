/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#ifdef __CYGWIN__
#define setjmp _setjmp
#endif
#include <Dk.h>
#ifdef SOLARIS
#undef gettext
#endif
/*#define _WINSOCKAPI_*/
#ifdef WIN32
#define GC_THREADS
#include <gc/gc.h>
typedef HANDLE (WINAPI *CreateThreadPtr)(
  LPSECURITY_ATTRIBUTES lpThreadAttributes,
  SIZE_T dwStackSize,
  LPTHREAD_START_ROUTINE lpStartAddress,
  LPVOID lpParameter,
  DWORD dwCreationFlags,
  LPDWORD lpThreadId
);
void virtuoso_set_create_thread (CreateThreadPtr ptr);
#endif
#include <mono/jit/jit.h>
#ifdef OLD_KIT_1_1_4
#include <mono/metadata/cil-coff.h>
#include <mono/metadata/debug-helpers.h>
#endif


#ifndef OLD_KIT
#include <mono/metadata/metadata.h>
#include <mono/metadata/object.h>
#include <mono/metadata/appdomain.h>
#include <mono/metadata/assembly.h>
#include <mono/metadata/exception.h>
#include <mono/utils/mono-uri.h>
#include <mono/metadata/debug-helpers.h>
#include <mono/metadata/loader.h>
#if defined (NO_MONO_INTERNAL_CODE) || defined (OLD_KIT_1_1_4)
#include <mono/metadata/domain-internals.h>
#include <mono/metadata/metadata-internals.h>
#include <mono/metadata/class-internals.h>
#endif
#endif
#include <mono/metadata/threads.h>
#include <mono/metadata/tabledefs.h>

#ifndef WIN32
#undef MIN
#undef MAX
#undef LONG
#define ULONG VIRT_ULONG
#ifndef NO_UDBC_SDK
/*GK: conflict with the new opl kit */
#define BOOL VIRT_BOOL
#endif
#define HANDLE VIRT_HANDLE
#define WORD VIRT_WORD
#define DWORD VIRT_DWORD
#define BYTE VIRT_BYTE
#define LPVOID VIRT_LPVOID
#define PVOID VIRT_PVOID
#define LONG VIRT_LONG
#define HMODULE VIRT_HMODULE
#define LPBYTE VIRT_LPBYTE
#define LPDWORD VIRT_LPDWORD
#define TCHAR VIRT_TCHAR
#define LPTSTR VIRT_LPTSTR
#define LPCTSTR VIRT_LPCTSTR
#endif

#include "libutil.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "security.h"
#include <util/fnmatch.h>
#include "statuslog.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "sqlbif.h"
#include "sqlo.h"
#include "sqlpfn.h"
#include "arith.h"
#include "srvmultibyte.h"
#undef LONG
#include "sql3.h"

#ifndef WIN32
#undef LONG
#undef BOOL
#undef ULONG
#undef HANDLE
#undef WORD
#undef DWORD
#undef BYTE
#undef LPVOID
#undef PVOID
#undef HMODULE
#undef LPBYTE
#undef LPDWORD
#undef TCHAR
#undef LPTSTR
#undef LPCTSTR
#endif

#ifdef WIN32
#include <windows.h>
#define HAVE_DIRECT_H
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define mkdir(p,m)	_mkdir (p)
#define FS_DIR_MODE	0
#define PATH_MAX	 MAX_PATH
#define get_cwd(p,l)	_get_cwd (p,l)
#else
#include <dirent.h>
#define FS_DIR_MODE	 (S_IRWXU | S_IRWXG)
#endif


void VirtuosoServerSetInitHook (void (*hook) (void));
int VirtuosoServerMain (int argc, char **argv);
char pid_dir [PATH_MAX + 1];
caddr_t cpp_udt_clr_instance_allocate (int val, void *udt);
void * udt_find_class_for_clr_instance (int clr_ret, void *target_udt);
void * scan_session_boxing (dk_session_t *session);
int session_flush (dk_session_t * session);
void print_object2 (void *object, dk_session_t *session);
caddr_t bif_dotnet_get_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern void bif_init_func_clr (void);


void mono_assembly_set_main (MonoAssembly *assembly);
MonoMethod * mono_marshal_get_runtime_invoke (MonoMethod *method);
caddr_t dotnet_get_instance_name (int instance);
void mono_init_virt ();
int clr_serialize (int gc_in, dk_session_t * ses);
caddr_t clr_deserialize (dk_session_t * ses, long mode, caddr_t asm_name, caddr_t type, void *udt);

/* agent functions */
caddr_t agent_make_new_error (char *code, char *virt_code, char *msg, ...);
void agent_new_error (char *code, char *virt_code, char *string, ...);
void agent_resignal (caddr_t err);
caddr_t agent_box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
	dtp_t to_dtp, ptrlong prec, ptrlong scale, caddr_t *err_ret);
void *agent_find_class_for_clr_instance (int clr_ret, void *target_udt);
caddr_t agent_udt_clr_instance_allocate (int val, void *udt);
extern jmp_buf_splice *curr_buf;
extern caddr_t curr_err;

void mono_set_rootdir (void); /* from mono/os/utils.h */
extern char *mono_cfg_dir;
#ifndef VIRT_MINT
extern gboolean mono_jit_trace_calls;
#endif
extern void (*mono_thread_attach_aborted_cb ) (MonoObject *obj);

#ifdef MONO_AGENT
#define srv_make_new_error agent_make_new_error
#define sqlr_new_error agent_new_error
#define sqlr_resignal(err) agent_resignal(err)
#define box_cast_to(qst,data,data_dtp,to_dtp,prec,scale,err_ret) \
	agent_box_cast_to (qst,data,data_dtp,to_dtp,prec,scale,err_ret)
#define udt_find_class_for_clr_instance(clr_ret,target_udt) \
	agent_find_class_for_clr_instance(clr_ret,target_udt)
#define cpp_udt_clr_instance_allocate(val,udt) \
	agent_udt_clr_instance_allocate(val,udt)

#undef QR_RESET_CTX
#define QR_RESET_CTX \
{ \
  int reset_code;  \
  jmp_buf_splice * __old_ctx = curr_buf;\
  jmp_buf_splice __ctx;  \
  curr_buf = &__ctx; \
  if (0 == (reset_code = setjmp_splice (&__ctx)))

#undef QR_RESET_CODE
#define QR_RESET_CODE \
  else


#undef END_QR_RESET
#define END_QR_RESET \
    POP_QR_RESET; \
}

#undef POP_QR_RESET
#define POP_QR_RESET \
  curr_buf = __old_ctx

#endif

#define TA_MONO_THREAD 4000
