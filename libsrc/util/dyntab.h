/*
 *  dyntab.h
 *
 *  $Id$
 *
 *  Dynamic Tables
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef _DYNTAB_H
#define _DYNTAB_H

#define DTAB_SUCCESS		0
#define DTAB_INVALID_ARG	(-1)
#define DTAB_NO_MEMORY		(-2)

typedef u_char *htrecord_t;
typedef u_int (*hthashfun_t) (htrecord_t);
typedef int   (*htcomparefun_t) (htrecord_t, htrecord_t);
typedef void  (*htuserfun_t) (htrecord_t, void *);
typedef void  (*htcreatefun_t) (htrecord_t, void *);
typedef void  (*htdestroyfun_t) (htrecord_t);
typedef struct httable_t *dyntable_t;


BEGIN_CPLUSPLUS

int dtab_create_table (
    dyntable_t *    pTable,
    u_int	    recordSize,
    u_int	    initRecords,
    u_short	    incrRecords,
    htcreatefun_t   createFunc,
    void *	    createData,
    htdestroyfun_t  destroyFunc);

int dtab_destroy_table (dyntable_t *pTable);

int dtab_define_key (
    dyntable_t      table,
    hthashfun_t     hashFunc,
    u_int           hashSize,
    htcomparefun_t  compareFunc,
    int             unique);

int dtab_create_record (dyntable_t table, htrecord_t *pRecord);

int dtab_delete_record (htrecord_t *pRecord);

int dtab_add_record (htrecord_t record);

int dtab_foreach (
    dyntable_t      table,
    int             keyNum,
    htuserfun_t     function,
    void *          argument);

int dtab_exist (
    dyntable_t      table,
    u_int           keyNum,
    htrecord_t      record);

htrecord_t dtab_find_record (
    dyntable_t      table,
    u_int           keyNum,
    htrecord_t      record);

u_int dtab_record_count (dyntable_t table, u_int keyNum);

int dtab_make_list (
    dyntable_t		table,
    u_int		keyNum,
    u_int *		pNumRecords,
    htrecord_t **	pRecords);

int dtab_debug (dyntable_t table);

END_CPLUSPLUS

#endif
