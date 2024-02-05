/*
 *  memstat.c
 *
 *  Get VMsize in KBytes
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

#include "libutil.h"

#ifdef linux
#include <sys/sysinfo.h>
#endif
#ifdef __APPLE__
#include <mach/task.h>
#include <mach/mach_init.h>
#endif
#ifdef WIN32
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif

/* return VmSize in KBytes, for macOS uses footprint which represents memory usage of the process */

int64
get_proc_vm_size ()
{
  int64 proc_size = 0;
#if defined (linux)
  static long page_size;
  FILE *file = fopen("/proc/self/statm", "r"); /* only reliable way to get proper number as in ps/top etc. */
  if (!page_size) page_size = sysconf(_SC_PAGESIZE);
  if (file)
    {
      fscanf (file, "%llu", &proc_size);
      fclose (file);
      proc_size *= page_size;
    }
#elif defined (__APPLE__)
  struct task_vm_info info;
  kern_return_t rc;
  mach_msg_type_number_t info_count = TASK_VM_INFO_COUNT;
  rc = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &info_count);
  if (KERN_SUCCESS == rc)
    proc_size = info.phys_footprint; /* the footprint is a what is reported as process usage, virtual_size is not vmsize */
#elif defined (WIN32)
  PROCESS_MEMORY_COUNTERS count;
  if (GetProcessMemoryInfo (GetCurrentProcess(), &count, sizeof (count)))
    proc_size = count.PagefileUsage;
#else
  /* not implemented  */
#endif
  return proc_size / 1024;
}


