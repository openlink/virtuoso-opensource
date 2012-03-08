/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

caddr_t dotnet_get_stat_prop (int _asm_type, caddr_t asm_name, caddr_t type, caddr_t prop_name);
int create_instance (caddr_t * type_vec, int n_args, long mode, caddr_t asm_name, caddr_t type,
    void * udt);
caddr_t dotnet_method_call (caddr_t * vec1, int n_args, int instance, caddr_t method,
    void * udt, int sec_unrestricted);
caddr_t dotnet_call (caddr_t * type_vec, int n_args, int asm_type, caddr_t asm_name,
    caddr_t type, caddr_t method, void * udt, int sec_unrestricted);
caddr_t dotnet_get_property (long inst, caddr_t prop_name);
caddr_t dotnet_set_property (caddr_t * type_vec, long inst, caddr_t prop_name);
int dotnet_is_instance_of (int clr_ret, caddr_t class_name);
void add_id (int id);
void del_ref (int gc_in);
int copy_ref (int gc_in, void * udt);
int virt_com_init ();

caddr_t clr_compile (caddr_t text, caddr_t outfile);
caddr_t clr_add_comp_reference (caddr_t ref);

void dotnet_get_assembly_by_name (char *name, void **retb, long *retsize, void * (*virt_malloc) (size_t));

#ifdef VIRT_MINT
#define  _MONO_NAME_  	"Mono ECMA-CLI Interpreter"
#else
#define  _MONO_NAME_  	"Mono ECMA-CLI"
#endif
#ifndef _MONO_VERSION_
#define  _MONO_VERSION_ "0.25"
#endif
