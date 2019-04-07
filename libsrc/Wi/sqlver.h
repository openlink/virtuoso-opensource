/*
 *  sqlver.h
 *
 *  $Id$
 *
 *  Build & Version information, license control
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
#ifndef SQLVER_H
#define SQLVER_H

#define PRODUCT_COPYRIGHT	"Copyright (C) 1998-2019 OpenLink Software"
#define PRODUCT_NAME		"OpenLink Virtuoso"

/* DBMS Server */
#define PRODUCT_DBMS		PRODUCT_NAME
#define DBMS_SRV_NAME		PRODUCT_DBMS " Universal Server"
#define DBMS_SRV_VER_ONLY	"07.20"
#define DBMS_SRV_GEN_MAJOR	"32"
#define DBMS_SRV_GEN_MINOR	"30"
#define DBMS_SRV_VER		DBMS_SRV_VER_ONLY "." \
				DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR

/* Database compatibility version */
#define DBMS_STORAGE_VER	"3126"

/* ODBC Driver */
#define PRODUCT_ODBC		PRODUCT_NAME " ODBC"
#define ODBC_DRV_NAME		PRODUCT_ODBC " Driver"
#define ODBC_DRV_VER_ONLY	DBMS_SRV_VER_ONLY
#define ODBC_DRV_GEN_MAJOR	DBMS_SRV_GEN_MAJOR
#define ODBC_DRV_GEN_MINOR	DBMS_SRV_GEN_MINOR
#define ODBC_DRV_VER		ODBC_DRV_VER_ONLY "." \
				ODBC_DRV_GEN_MAJOR ODBC_DRV_GEN_MINOR

#define ODBC_DRV_VER_G_NO(v)	atoi (&(v)[6])

#ifdef __cplusplus
extern "C" {
#endif

extern const char *build_date;
extern const char *build_host_id;
extern const char *build_opsys_id;
extern const char *build_thread_model;
extern const char *build_special_server_model;

void build_set_special_server_model (const char *new_model);

#ifdef __cplusplus
}
#endif

#endif
