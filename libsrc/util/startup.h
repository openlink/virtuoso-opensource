/*
 *  startup.h
 *
 *  $Id$
 *
 *  Includes for startup.c
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
 *  
*/

#ifndef _STARTUP_H
#define _STARTUP_H

#include "itypes.h"
#include <util/getopt.h>

struct pgm_option
{
  char *long_opt;
  char short_opt;
  int arg_type;
  void *arg_ptr;
  char *help;
};

struct pgm_info {
  char *program_name;
  char *program_version;
  char *extra_usage;
  int flags;
  struct pgm_option *program_options;
};

#define MYNAME		program_info.program_name

#define ARG_NONE	0
#define ARG_STR		1
#define ARG_INT		2
#define ARG_LONG	3
#define ARG_FUNC	4

#define EXP_WILDCARD	0x0001
#define EXP_RESPONSE	0x0002
#define EXP_ORDER_MASK		0x00F0
#define EXP_DEFAULT_ORDER	0x0000
#define EXP_REQUIRE_ORDER	0x0010
#define EXP_RETURN_IN_ORDER	0x0020

GLOBALREF struct pgm_info program_info;


BEGIN_CPLUSPLUS

void	terminate (int);
void	expand_argv (int *, char ***, int);
void	initialize_program (int *, char ***);
void	default_usage (void);
void	usage (void);
#ifdef WIN32
void	StartNTApplication (void);
void	EndNTApplication (void);
#endif

END_CPLUSPLUS

#endif
