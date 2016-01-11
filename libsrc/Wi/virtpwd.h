/*
 *  virtpwd.h
 *
 *  $Id$
 *
 *  password encryption
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

#ifndef _VIRTPWD_H
# define _VIRTPWD_H

#define xx_encrypt_passwd  ___C_GCC_QQ_COMPILED
void xx_encrypt_passwd (char *thing, int thing_len, char *user_name);

#define pass1 ___C_GCC_Q_COMPILED
#define pass2 ___G_GCC_V2
#define the_pass  ___Y_GCC_3
#define calculate_pass ___M_GCC_DATA_Y
#define EMPTY_PASS "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

#endif /* _VIRTPWD_H */
