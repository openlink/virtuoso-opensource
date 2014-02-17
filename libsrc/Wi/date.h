/*
 *  date.h
 *
 *  $Id$
 *
 *  Date support
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
 */

#ifndef _DATE_H
#define _DATE_H

#include "widv.h"
#include "odbcinc.h"

typedef unsigned char  datetime_t[DT_LENGTH];

/*#define NO_DT_TYPE_IN_TZ*/

#define CUC(p, n)	((const unsigned char *)p)[n]
#define UC(p, n)	((unsigned char *)p)[n]
#define _UC(p)		((unsigned char)(p))
#define CSIGNC(p, n)	((const signed char *)p)[n]
#define SIGNC(p, n)	((signed char *)p)[n]
#define _SIGNC(p)	((signed char)(p))

#ifndef DEBUG
#undef DATE_DEBUG
#endif

#ifdef DATE_DEBUG
extern void dt_audit_fields (char *dt);
#define DT_AUDIT_FIELDS(dt) dt_audit_fields(dt)
#else
#define DT_AUDIT_FIELDS(dt)
#endif

/* While TIMESTAMP_STRUCT value is by default in dt_local_tz timezone, DV_DATE_OBJ is always in UTC.
 * Its timezone field is SOLELY for printing with timezone and ignored by datediff and the like.
 * DV_DATE_OBJ layout:
 *
 *  1. day - 0-3.950.000 - 22 bit
 *  2. hour - 0-23          5 bit
 *  3. minute 0-59          6 bit
 *  4. second 0-59          6 bit
 *  5. fraction 0-999.999  20 bit (i.e., whole thousands of nanoseconds are stored)
 *  6. type of value 0-4 (could be more later)
 *  7. timezone for printing minus 840 to plus 840	sign bit and 10 bits
 *
 * ...:...0...:...1...:...2...:...3...:...4...:...5...:...6...:...7...:...8...:...9
 * <<dddddddddddddddddddddd<<<hhhhh<mmmmmssssssffffffffffffffffffff<<TTT-zzzzzzzzzz
 *
 */

#define DT_DAY(dt) \
  ((int32)((CUC (dt, 0) << 16) | \
    (CUC (dt, 1) << 8) | \
    CUC (dt, 2) | ((CUC (dt, 0) & 0x80) ? 0xff000000 : 0)))

/* unsigned day, dt sorts as unsigned binary string for index, so when using numeric offset it is also unsigned for dates that have the high bit set */
#define DT_UDAY(dt) \
  ((int32)((CUC (dt, 0) << 16) | \
    (CUC (dt, 1) << 8) | \
	   CUC (dt, 2)))



#define DT_HOUR(dt) \
  CUC(dt, 3)

#define DT_MINUTE(dt) \
  (CUC (dt, 4) >> 2)

#define DT_SECOND(dt) \
  (((CUC (dt, 4) & 0x3) << 4) | \
   ((CUC (dt, 5)) >> 4))

#define DT_FRACTION(dt) \
  (1000 * (((CUC (dt, 5) & 0x0F) << 16) | \
    (CUC (dt, 6) << 8) | \
     CUC (dt, 7)))

#ifdef NO_DT_TYPE_IN_TZ
#define DT_TZ(dt) \
  ((((int)CSIGNC (dt, 8)) << 8) | CUC (dt, 9))

#define DT_DT_TYPE(dt) DT_TYPE_DATETIME
#else
#define DT_TZ(dt) \
  ((((int) _SIGNC ( \
    (CUC (dt,8) & 0x04) ? \
    _UC (_UC (CUC (dt,8) & 0x07) | 0xf8)  : \
    _UC (CUC (dt,8) & 0x03) \
  )) << 8 ) | CUC (dt, 9))

#define DT_DT_TYPE(dt) \
  (int)(((CUC (dt, 8) & 0xfc) == 0 || \
   (CUC (dt, 8) & 0xfc) == 0xfc) ? DT_TYPE_DATETIME : \
   (CUC (dt, 8) >> 5))
#endif

#define DT_SET_DAY(dt, y)  \
  ((UC (dt, 0) = _UC (((y) >> 16) & 0xFF), \
    UC (dt, 1) = _UC (((y) >> 8) & 0xFF), \
    UC (dt, 2) = _UC ((y) & 0xFF)))

#define DT_SET_HOUR(dt, h) \
  UC(dt, 3) = _UC (h)

#define DT_SET_MINUTE(dt, m) \
  (UC (dt, 4) &= 0x3, \
   UC (dt, 4) |= (m) << 2)

#define DT_SET_SECOND(dt, m) \
  (UC (dt, 4) &= 0xFC, \
   UC (dt, 4) |= ((m) >> 4) & 0x3, \
   UC (dt, 5) &= 0x0F, \
   UC (dt, 5) |= ((m) & 0x0F) << 4)

#define DT_SET_FRACTION(dt, f) \
  (UC (dt, 5) &= 0xF0, \
   UC (dt, 5) |= (((f)/1000) >> 16) & 0x0F, \
   UC (dt, 6) = _UC (((f)/1000) >> 8), \
   UC (dt, 7) = _UC (((f)/1000) & 0xFF))

#ifdef NO_DT_TYPE_IN_TZ
#define DT_SET_TZ(dt, tz) \
  (SIGNC (dt, 8) = _SIGNC ((tz) >> 8), \
   SIGNC (dt, 9) = _SIGNC ((tz) & 0xFF))

#define DT_SET_COMPAT_TZ(dt, tz) DT_SET_TZ(dt, tz)

#define DT_SET_DT_TYPE(dt, type) SIGNC (dt, 8) = SIGNC (dt, 8)
#else
#define DT_SET_TZ(dt, tz) \
    (UC (dt, 8) = (_UC (_UC (UC (dt, 8) >> 3) << 3) | (_UC ((tz) >> 8) & 0x07)), \
     UC (dt, 9) = _UC ((tz) & 0xFF))

#define DT_SET_DT_TYPE_NOAUDIT(dt, type) do { \
  UC (dt, 8) = _UC (_UC (UC (dt, 8) & 0x07) | _UC ((type) << 5)); } while (0)

#define DT_SET_DT_TYPE(dt, type) do { \
  UC (dt, 8) = _UC (_UC (UC (dt, 8) & 0x07) | _UC ((type) << 5)); \
  DT_AUDIT_FIELDS(dt); } while (0)

#define DT_SET_COMPAT_TZ(dt, tz) \
  (SIGNC (dt, 8) = _SIGNC ((tz) >> 8), \
   SIGNC (dt, 9) = _SIGNC ((tz) & 0xFF))
#endif


/* arbitrary day component of time-only DV_DATETIME */
#ifdef DEBUG
#define DAY_ZERO 0x7ffefd
#else
#define DAY_ZERO (1999 * 365)
#endif

#define DT_TYPE_COMPAT_POSITIVE_TZ  0
#define DT_TYPE_DATETIME 1
#define DT_TYPE_DATE 2
#define DT_TYPE_TIME 3
#define DT_TYPE_COMPAT_NEGATIVE_TZ  4

#define SET_DT_TYPE_BY_DTP(dt,dtp) \
   DT_SET_DT_TYPE (dt, \
       (dtp == DV_DATE ? \
	DT_TYPE_DATE : \
	(dtp == DV_TIME ? \
	 DT_TYPE_TIME : \
	 DT_TYPE_DATETIME \
	) \
       ))

#define SPERDAY (24*60*60)
#define DT_CAST_TO_TOTAL_SECONDS(dt) ((boxint)DT_DAY (dt) * 24 * 60 * 60 + (boxint)DT_HOUR (dt) * 60 * 60 + (boxint)DT_MINUTE (dt) * 60 + DT_SECOND (dt))

#ifdef WORDS_BIGENDIAN
#define memcpy_dt(tgt, src) memcpy (tgt, src, DT_LENGTH)
#define memcmp_dt(dt1, dt2) \
  { if (memcmp (dt1, dt2, DT_CMP_LENGTH)) goto neq;}
#else
#define memcpy_dt(tgt1, src1) \
  { db_buf_t __tgt = (db_buf_t)tgt1, __src = (db_buf_t)src1; 	\
  *(int64*)(__tgt) = *(int64*)(__src); \
  *(short*)(__tgt + 8) = *(short*)((__src) + 8); \
}

#define memcmp_dt(dt1, dt2, neq)				\
  {if (*(int64*)(dt1) != *(int64*)(dt2)) goto neq;}
#endif

#endif /* _DATE_H */
