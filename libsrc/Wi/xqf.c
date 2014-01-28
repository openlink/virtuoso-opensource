/*
 *  xqf.c
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

#include "CLI.h"
#include "xmltree.h"
#include "arith.h"
#include "sqlbif.h"
#include "xml.h"
#include "date.h"
#include "xpathp_impl.h"
#include "xml_ecm.h"
#include "bif_text.h"
#include "srvmultibyte.h"
#include "http.h"

#include "xpf.h"
#include "xqf.h"

#include "util/pcrelib/pcre.h"

#define ecm_isname(c) \
  ( ((c) & ~0xFF) ? (ecm_utf8props[(c)] & ECM_ISNAME) : \
    ((UCP_ALPHA | UCP_IDEO) & unichar_getprops((c))) )

#ifndef UTF8_IS_SINGLECHAR
#define UTF8_IS_SINGLECHAR(c) (!(c & 0x80))
#endif
#ifndef UTF8_IS_HEADCHAR
#define UTF8_IS_HEADCHAR(c) (UTF8_IS_SINGLECHAR(c) || (0xc0 == (c & 0xc0)))
#endif

#define DVC_TO_C_STYLE(res) \
     ( ((res) == DVC_MATCH) ? 0L : \
       ( ((res) == DVC_LESS) ? -1L : 1L ))

sql_tree_tmp * st_double;
double virt_rint (double x);

int
utf8_strlen (const unsigned char *str)
{
  const unsigned char *tail;
  int len = 0;
  if (!(DV_STRINGP (str)))
    return 0;
  for (tail = str; '\0' != tail[0]; tail++)
    {
      unsigned char c = tail[0];
      if (UTF8_IS_HEADCHAR(c))
	len++;
    }
  return len;
}

static void
__xqf_str_ctr (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, qpq_ctr_callback proc, int do_what)
{
  dtp_t dtp;
  caddr_t val, n = NULL;
  if (tree->_.xp_func.argcount)
    val = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
  else
    val = (caddr_t) ctx_xe;
  if (!val)
    {
      proc (&n, NULL, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
      return;
    }

  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      caddr_t *str2 = XQI_ADDRESS (xqi, tree->_.xp_func.res);
      xe->_->xe_string_value (xe, str2, DV_SHORT_STRING);
      proc (&n, *str2, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
  else
    {
      val = box_cast ((caddr_t *) xqi->xqi_qi, val, (sql_tree_tmp*) st_varchar, dtp);
      proc (&n, val, do_what);
      dk_free_box (val);
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
}


static void
__xqf_raw_ctr (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, qpq_ctr_callback proc, int do_what)
{
  dtp_t dtp;
  caddr_t val, n = NULL;
  if (tree->_.xp_func.argcount)
    val = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
  else
    val = (caddr_t) ctx_xe;
  if (!val)
    {
      proc (&n, NULL, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
      return;
    }

  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      caddr_t *str2 = XQI_ADDRESS (xqi, tree->_.xp_func.res);
      xe->_->xe_string_value (xe, str2, DV_UNKNOWN);
      proc (&n, *str2, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
  else
    {
      proc (&n, val, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
}


static void
__boolean_from_string (caddr_t *n, const char *str, int do_what)
{
  if (!strcmp ("true", str) || ! (strcmp ("1", str)))
    n[0] = box_num (1);
  else if (!strcmp ("false", str) || ! (strcmp ("0", str)))
    n[0] = box_num (0);
  else
    sqlr_new_error ("42001", "XPQ??", "Invalid string representation of boolean: '%.100s'", str);
}


static int
__boolean_rcheck (caddr_t *n, int do_what)
{
  boxint old_val = unbox (n[0]);
  if ((0 != old_val) && (1 != old_val))
    {
      dk_free_tree (n[0]);
      n[0] = box_num (old_val ? 1 : 0);
    }
  return 1;
}


static void
__numeric_from_string (caddr_t *n, const char *str, int do_what)
{
  const char *p = str;
  int df = 0;
  if ('+' == p[0] || '-' == p[0])
    p++;
  for (; *p; p ++ )
    {
      if (('.' != p[0]) && (p[0] > '9' || p[0] <'0' ))
	sqlr_new_error ("42001", "XPQ??", "Incorrect argument in decimal constructor:\"%s\"", str);
      if ('.' == p[0])
	{
	  if (df)
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in decimal constructor (too many decimal points):\"%s\"", str);
	  df++;
	}
    }
  *n = (caddr_t)numeric_allocate ();
  numeric_from_string ((numeric_t)*n, str);
}


static void
xqf_decimal (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __numeric_from_string, 0);
}

static int
__chk_int_string (const char *str)
{
  int n = 0;
  const char *p = str;
  if ('+' == p[0] || '-' == p[0])
    p++;
  for (; *p; p ++, n++ )
    {
      if (p[0] > '9' || p[0] <'0' )
	return -1;
    }
  return 0;
}

#define XQ_INT8		0
#define XQ_INT16	1
#define XQ_INT32	2
#define XQ_INT64	3
#define XQ_UINT8	4
#define XQ_UINT16	5
#define XQ_UINT32	6
#define XQ_UINT64	7
#define XQ_INT		8
#define XQ_NINT		9
#define XQ_NPINT	10
#define XQ_NNINT	11
#define XQ_PINT		12
#define COUNTOF__XQ_INT_TYPE 13

static void
__integer_from_string (caddr_t *n, const char *str, int do_what)
{
  static const char *s_int[] = {
    "127",			"128",
    "32767",			"32768",
    "2147483647",		"2147483648",
    "223372036854775807",	"223372036854775808",
    "255",			NULL,
    "65535",			NULL,
    "4294967295",		NULL,
    "446754073709551615",	NULL };
  static int l_int[] = {3, 5, 10, 18, 3, 5, 10, 18};
  static const char *s_int_name[] = {
    "byte",
    "short",
    "int",
    "long",
    "unsigned byte",
    "unsigned short",
    "unsigned int",
    "unsigned long",
    "integer",
    "negative integer",
    "nonpositive integer",
    "nonnegative integer",
    "positive integer" };
  int l, s = 0;
  const char *p = str;
  assert (do_what >= 0 && do_what < COUNTOF__XQ_INT_TYPE);
  if  ('-' == str[0])
    {
      s = 1;
      p ++;
    }
  while ('0'== *p) p++;
  if  (
    (s && ((XQ_NNINT == do_what) || (XQ_PINT == do_what) || ((XQ_UINT8 <= do_what) && (XQ_UINT64 >= do_what)))) ||
    (!s && ((XQ_NPINT == do_what) || (XQ_NINT == do_what))) ||
    (('\0' == p[0]) && ((XQ_NINT == do_what) || (XQ_PINT == do_what))) )
    sqlr_new_error ("42001", "XPQ??", "'%.100s' is not a valid value for %s constructor", str, s_int_name[do_what] );
  if (XQ_INT <= do_what)
    {
      l = (int) strlen (p);
      if ((l > l_int[XQ_INT32]) || ((l == l_int[XQ_INT32]) && strcmp (s_int[2 * XQ_INT32 + s], p) < 0))
        __numeric_from_string (n, str, 0);
      else
        *n = box_num (atoi (str));
      return;
    }
  if ((l = __chk_int_string (str)) < 0)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in %.100s constructor: '%.100s'", s_int_name[do_what], str);

  l = (int) strlen (p);
  if (NULL == s_int [2 * do_what + s])
    sqlr_new_error ("42001", "XPQ??", "Sign of argument '%.100s' does not match expected type %s", str, s_int_name[do_what]);
  if ((l > l_int[do_what]) || ((l == l_int[do_what]) && strcmp (s_int[2 * do_what + s], p) < 0))
    sqlr_new_error ("42001", "XPQ??", "Magnitude is too big (%.100s) to be packed into %s", str, s_int_name[do_what]);
  switch (do_what) {
    case XQ_INT8:
    case XQ_INT16:
    case XQ_INT32:
    case XQ_UINT8:
    case XQ_UINT16:
    case XQ_UINT32:
      *n = box_num (atoi (str));
      break;
    case XQ_INT64:
    case XQ_UINT64:
      __numeric_from_string (n, str, 0);
      break;
  };
}

static int
__integer_rcheck (caddr_t *n, int do_what)
{
  static int bits[]     = {7, 15, 31, 63, 8, 16, 32, 64};
  static int issigned[] = {1, 1, 1, 1, 0, 0, 0, 0};
  boxint val;
  int64 v64;
  assert (do_what >= 0 && do_what < COUNTOF__XQ_INT_TYPE);
  if (DV_NUMERIC == DV_TYPE_OF (n[0]))
    {
      numeric_t num = (numeric_t)(n[0]);
      switch (do_what)
        {
        case XQ_UINT8: case XQ_UINT16: case XQ_UINT32: case XQ_UINT64:
          if (num->n_neg) return 0;
          break;
        case XQ_NNINT:
          return !(num->n_neg);
        case XQ_NINT:
          return num->n_neg;
        case XQ_NPINT:
          return (num->n_neg || num_is_zero(num));
        case XQ_PINT:
          return !(num->n_neg || num_is_zero(num));
        }
      if (!numeric_to_int64 (num, &v64))
        return 0;
      val = v64;
    }
  else
    val = unbox (n[0]);
  if (val < 0)
    {
      if (!issigned[do_what])
        return 0;
      val = 1 - val;
    }
  if (val >> bits[do_what])
    return 0;
  return 1;
}


static void
xqf_byte (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __integer_from_string, XQ_INT8);
}

static void
xqf_short (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __integer_from_string, XQ_INT16);
}

static void
xqf_int (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __integer_from_string, XQ_INT32);
}

static void
xqf_long (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __integer_from_string, XQ_INT64);
}

static void
xqf_integer (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __integer_from_string, XQ_INT);
}

static int
__chk_float_string (const char *str)
{
  int n = 0;
  int df = 0, ef = 0;
  const char *p = str;
  if ('+' == p[0] || '-' == p[0])
    p++;
  for (; *p; p ++, n++ )
    {
      if (NULL == strchr("+-eE.", *p) && (p[0] > '9' || p[0] <'0' ))
	return -1;;

      if ('.' == p[0])
	{
	  if (df || ef)
	    return -1;
	  df++;
	}
      else if ('e' == p[0] || 'E' == p[0])
	{
	  if (ef)
	    return -1;
	  ef++;
	}
    }
  return 0;
}


#define XQ_FLOAT	5
#define XQ_DOUBLE	6
static void
__float_from_string (caddr_t *n, const char *str, int do_what)
{
  assert (XQ_FLOAT == do_what || XQ_DOUBLE == do_what);
  if (__chk_float_string (str) < 0)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in float constructor:\"%s\"", str);
  if (XQ_FLOAT == do_what)
    *n = box_float ((float)(atof (str)));
  else
    *n = box_double (atof (str));
}


static void
xqf_float (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __float_from_string, XQ_FLOAT);
}

static void
xqf_double (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __float_from_string, XQ_DOUBLE);
}

static caddr_t
xqf_YM_from_months (long months)
{
  /*
  caddr_t * res = (caddr_t*) dk_alloc_box_zero (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  res[0] = box_num (1);
  res[1] = box_num (months);
  return (caddr_t) res;
  */
  return box_num (months);
}

static caddr_t
xqf_DT_from_secs (double secs)
{
  /*
  caddr_t * res = (caddr_t*) dk_alloc_box_zero (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  res[0] = box_num (0);
  res[1] = box_double (secs);
  return (caddr_t) res;
  */
  return box_double (secs);
}

static void
__duration_from_string (caddr_t *n, const char *str, int do_what)
{
  const char *p, *pp;
  int sign = 0, val, timeflag = 0, dot_hit = 0;
  caddr_t res;
  signed long year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0, frac = 0;

  p = str;
  if ('-' == *p)
    {
      sign ++;
      p ++;
    }
  if ('+' == *p)
    p++;
  if ('P' != *p++)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor (missing 'P' char):\"%s\"", str);
  for (;;)
    {
      pp=p;
      while (isdigit (pp[0])) pp++;
      if (NULL == pp || '\0' == pp[0])
	{
	  if ('\0' != p[0])
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor:\"%s\"", str);
	  break;
	}
      val = atoi (p);
      if (sign) val *= -1;
      switch (pp[0]) {
	default:;
	  sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor:\"%s\"", str);
	case 'T':
	  if (timeflag)
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor (too many 'T' chars):\"%s\"", str);
	  timeflag ++;
	  break;
	case 'Y':
	  if (timeflag)
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor ('Y' after 'T'):\"%s\"", str);
	  year = val;
	  break;
	case 'M':
	  if (timeflag)
	    minute = val;
	  else
	    month = val;
	  break;
	case 'D':
	  if (timeflag)
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor ('D' after 'T'):\"%s\"", str);
	  day = val;
	  break;
	case 'H':
	  hour = val;
	  break;
	case 'S':
	  if (!dot_hit)
	    second = val;
	  switch (pp-p) /* ???fraction??? */
	    {
	      case 0:
		frac = 0;
		break;
	      case 1:
		frac = 100 * (p[0] - '0');
		break;
	      case 2:
		frac = 100 * p[0] + 10 * p[1] - 110 * '0';
		break;
	      case 3:
		frac = 100 * p[0] + 10 * p[1] + p [2] - 111 * '0';
		break;
	      default:
		if (dot_hit)
		  sqlr_new_error ("42001", "XPQ??", "Incorrect length of fraction: \"%s\"", str);
	    }
	  break;
        case '.':
	  if (dot_hit)
	    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor (double '.'):\"%s\"", str);
	  second = val;
	  dot_hit=1;
	  break;
      };
      p = pp + 1;
    }
  if (timeflag && 0 == hour && 0 == minute && 0 == second)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor ('T' char is specified with no time data after it):\"%s\"", str);
  if (timeflag && 0 != year && 0 != month)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument in duration constructor ('T' char is specified with no date data):\"%s\"", str);
  if (year || month)
    res = xqf_YM_from_months (year * 12 + month);
  else
    res = xqf_DT_from_secs ((day * 24 + hour) * 3600 + minute * 60 + second + (double) frac / 1000.0);/*!!! */
  *n = res;
}


static void
xqf_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __duration_from_string, 0);
}


#define XQ_DATETIME	0
#define XQ_DATE		1
#define XQ_TIME		2
#define XQ_YEARMONTH	3
#define XQ_YEAR		4
#define XQ_MONTHDAY	5
#define XQ_MONTH	6
#define XQ_DAY		7
#define COUNTOF__XQ_DT_MODE	8

static void
__datetime_from_string (caddr_t *n, const char *str, int do_what)
{
  int flags[] = {0x1ff, 0x187, 0x1f8, 0x183, 0x181, 0x186, 0x182, 0x184};
  int types[] = { DT_TYPE_DATETIME, DT_TYPE_DATE, DT_TYPE_TIME, DT_TYPE_DATETIME, DT_TYPE_DATETIME, DT_TYPE_DATETIME, DT_TYPE_DATETIME, DT_TYPE_DATETIME };
  const char *names[] = {	"dateTime",
				"date",
				"time",
				"gYearMonth",
				"gYear",
				"gMonthDay",
				"gMonth",
				"gDay",
  };
  caddr_t err_msg = NULL;
  caddr_t err;
  assert (do_what >= 0 && do_what < COUNTOF__XQ_DT_MODE);
  n[0] = dk_alloc_box_zero (DT_LENGTH, DV_DATETIME);
  iso8601_or_odbc_string_to_dt (str, n[0], flags[do_what], types[do_what], &err_msg);
  if (NULL == err_msg)
    return;
  if (0 == do_what)
    {
      if (http_date_to_dt (str, n[0]))
        return;
    }
  dk_free_box (n[0]);
  n[0] = NULL;
  err = srv_make_new_error ("42001", "XPQ??", "%s in %s constructor: \"%.300s\"", err_msg, names[do_what], str);
  dk_free_box (err_msg);
  sqlr_resignal (err);
}

static int
__datetime_rcheck (caddr_t *n, int do_what)
{
  caddr_t dt = n[0];
  int dttype = DT_DT_TYPE (dt);
  switch (do_what)
    {
    case XQ_DATETIME: return (DT_TYPE_DATETIME == dttype);
    case XQ_DATE: if (DT_TYPE_TIME == dttype) return 0; break;
    case XQ_TIME: if (DT_TYPE_DATE == dttype) return 0; break;
    case XQ_YEARMONTH: case XQ_YEAR: case XQ_MONTHDAY: case XQ_MONTH: case XQ_DAY: if (DT_TYPE_TIME == dttype) return 0;
    }
  if (DT_TYPE_DATETIME == dttype)
    {
      if (XQ_TIME == do_what)
        {
          DT_SET_DAY (dt, DAY_ZERO);
          DT_SET_FRACTION (dt, 0);
          DT_SET_DT_TYPE (dt, DT_TYPE_TIME);
        }
      else
        {
          dt_date_round (dt);
          DT_SET_DT_TYPE (dt, DT_TYPE_DATE);
        }
    }
  return 1;
}

static void
xqf_datetime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_DATETIME);
}


static void
xqf_date (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_DATE);
}


static void
xqf_time (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_TIME);
}


static void
xqf_gYearMonth (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_YEARMONTH);
}

static void
xqf_gYear (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_YEAR);
}

static void
xqf_gMonthDay (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_MONTHDAY);
}

static void
xqf_gMonth (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_MONTH);
}

static void
xqf_gDay (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __datetime_from_string, XQ_DAY);
}


static void
__cur_datetime (caddr_t *n, const char *str, int do_what)
{
  *n = dk_alloc_box_zero (DT_LENGTH, DV_DATETIME);
  dt_now (*n);
}

static void
xqf_currentDateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __cur_datetime, 0);
}

#define XQ_STRING	1
#define XQ_NORM_STRING	2
#define XQ_TOKEN	3
#define XQ_STRING_END	100

static void
__string_from_string (caddr_t *n, const char *str, int do_what, const char *where )
{
  dk_session_t *ses = NULL;
  const char *p, *pp, *ppp;
  int val;
  char c;

  for (p = str; NULL != p;)
    {
      pp = strchr(p, '&');
      if (NULL != pp)
	{
	  if (NULL == ses)
            ses = strses_allocate ();
	  ppp = strchr(pp, ';');
	  if ('#' == pp[1] && 'x' == pp[2] && (isxdigit(pp[3])) && NULL != ppp)
	    {
	      session_buffered_write (ses, (char *)(p), pp-p);
	      sscanf (pp + 3, "%x", (unsigned *)(&val));
	      p = ppp + 1;
	      switch (val) {
		case 0x9:
		case 0xd:
		  if (XQ_NORM_STRING == do_what || XQ_TOKEN == do_what)
		    {
		      strses_free (ses); /* the bellow will jump outside */
		      ses = NULL;
		    sqlr_new_error ("42001", "XPQ??", "Symbol '#x%x' is not allowed in %s constructor:\"%s\"", val, where, str);
		    }
		  break;
		case 0xa:
		  if (XQ_NORM_STRING == do_what)
		    continue;
		  break;
		case 0x20:
		  ecm_isname (val);
		  break;
	      };
	      c = (char)val;
	      session_buffered_write (ses, &c, 1);
	      continue;
	    }
	}
      else
        {
          if (NULL == ses)
            {
              n[0] = box_dv_short_string (str);
              return;
            }
        }
      session_buffered_write (ses, (char *)(p), strlen (p));
      break; /* all is written */
    }
  *n = strses_string (ses);
  strses_free (ses);
}

static int
__gen_string_rcheck (caddr_t *n, int do_what)
{
  dk_session_t *ses = NULL;
  const char *p, *pp, *ppp;
  int val;
  char c;
  for (p = n[0]; NULL != p;)
    {
      pp = strchr(p, '&');
      if (NULL != pp)
	{
	  if (NULL == ses)
            ses = strses_allocate ();
	  ppp = strchr(pp, ';');
	  if ('#' == pp[1] && 'x' == pp[2] && (isxdigit(pp[3])) && NULL != ppp)
	    {
	      session_buffered_write (ses, (char *)(p), pp-p);
	      sscanf (pp + 3, "%x", (unsigned *)(&val));
	      p = ppp + 1;
	      switch (val) {
		case 0x9:
		case 0xd:
		  if (XQ_NORM_STRING == do_what || XQ_TOKEN == do_what)
		    {
		      strses_free (ses); /* the bellow will jump outside */
		      ses = NULL;
		      return 0;
		    }
		  break;
		case 0xa:
		  if (XQ_NORM_STRING == do_what)
		    continue;
		  break;
		case 0x20:
		  ecm_isname (val);
		  break;
	      };
	      c = (char)val;
	      session_buffered_write (ses, &c, 1);
	      continue;
	    }
	}
      else
        {
          if (NULL == ses)
            return 1;
        }
      session_buffered_write (ses, (char *)(p), strlen (p));
      break; /* all is written */
    }
  dk_free_tree (n[0]);
  *n = strses_string (ses);
  strses_free (ses);
  return 0;
}


static void
__gen_string_from_string (caddr_t *n, const char *str, int do_what)
{
  const char *names[] = {	"string",
				"normalizedString",
				"token",
  };
  assert (do_what > 0 && do_what <= XQ_STRING_END);
  __string_from_string (n, str, do_what, names[do_what - 1]);
}

static void
xqf_string (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __gen_string_from_string, XQ_STRING);
}

static void
xqf_normalized_string (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __gen_string_from_string, XQ_NORM_STRING);
}

static void
xqf_token (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_str_ctr (xqi, tree, ctx_xe, __gen_string_from_string, XQ_TOKEN);
}


#define XQ_GET_CENTURY_FROM_DATE	1
#define XQ_GET_YEAR_FROM_DATE		2
#define XQ_GET_MONTH_FROM_DATE		3
#define XQ_GET_DAY_FROM_DATE		4
#define XQ_GET_HOUR_FROM_DATE		5
#define XQ_GET_MINUTES_FROM_DATE	6
#define XQ_GET_SECONDS_FROM_DATE	7
#define XQ_GET_TZ_FROM_DATE		8
#define XQ_FLAG_DURATION		128
#define XQ_GETDATE_END			100

static int
__get_smth_from_date (caddr_t *n, caddr_t str, int do_what, const char *where )
{
  TIMESTAMP_STRUCT ts;
  int type = IS_BOX_POINTER (str) ? box_tag (str) : DV_LONG_INT;
  int is_duration = do_what & XQ_FLAG_DURATION;
  do_what &= ~XQ_FLAG_DURATION;
  if (is_duration && IS_NUM_DTP (type))
    {
      int is_ym;
      is_ym = ( type == DV_DOUBLE_FLOAT) ? 0 : 1;
      if (is_ym)
	{
	  long months = unbox (str);
	  switch (do_what) {
	    case XQ_GET_YEAR_FROM_DATE:
	      *n = box_num (months / 12);
	      break;
	    case XQ_GET_MONTH_FROM_DATE:
	      *n = box_num (months % 12);
	      break;
	    default:
	      sqlr_new_error ("42001", "XQR??", "incorrect operation over duration");
	  }
	}
      else
	{
	  double secs = unbox_double (str);
	  switch (do_what) {
	    case XQ_GET_SECONDS_FROM_DATE:
	      *n = box_num (((long)secs) % 60);
	      break;
	    case XQ_GET_MINUTES_FROM_DATE:
	      *n = box_num ((((long)secs) / 60) % 60);
	      break;
	    case XQ_GET_HOUR_FROM_DATE:
	      *n = box_num ((((long)secs) / 3600) % 24);
	      break;
	    case XQ_GET_DAY_FROM_DATE:
	      *n = box_num (((long)secs) / 3600 / 24);
	      break;
	  default:
	    sqlr_new_error ("42001", "XQR??", "incorrect operation over duration");
	  }
	}
      return 0;
    }
  if (DV_DATETIME != type)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument type:%s in %s", dv_type_title (type), where);
  if (do_what <= XQ_GET_SECONDS_FROM_DATE)
    {
      dt_to_timestamp_struct ((caddr_t)str, &ts); /*??? GMT or remembered timezone? */
      switch (do_what) {
	case XQ_GET_CENTURY_FROM_DATE:
	  *n = box_num (ts.year / 100);
	  break;
	case XQ_GET_YEAR_FROM_DATE:
	  if ((ts.year < 0) && ts.month)
	    *n = box_num (ts.year+1);
	  else
	  *n = box_num (ts.year);
	  break;
	case XQ_GET_MONTH_FROM_DATE:
	  if (ts.year < 0)
	    *n = box_num (ts.month-12);
	  else
	  *n = box_num (ts.month);
	  break;
	case XQ_GET_DAY_FROM_DATE:
	  *n = box_num (ts.day);
	  break;
	case XQ_GET_HOUR_FROM_DATE:
	  {
	  *n = box_num (ts.hour);
	  }
	  break;
	case XQ_GET_MINUTES_FROM_DATE:
	  *n = box_num (ts.minute);
	  break;
	case XQ_GET_SECONDS_FROM_DATE:
	  *n = box_num (ts.second);
	  break;
        }
    }
  else
    {
      int tz = DT_TZ (str);
      int sign = (tz < 0)?1:0;
      char buf[256];
      if (sign) tz *= -1;
      sprintf (buf, "%s%02d:%02d", (sign)?"-":"", tz/60, tz%60);
      *n = box_dv_short_string (buf);
    }
  return 0;
}

static void
__gen_get_smth_from_date (caddr_t *n, const char *str, int do_what)
{
  static const char *names[] = {"get-Century-from-dateTime",
				"get-gYear-from-dateTime",
				"get-gMonth-from-dateTime",
				"get-gDay-from-dateTime",
				"get-hour-from-dateTime",
				"get-minutes-from-dateTime",
				"get-seconds-from-dateTime",
				"get-TZ-from-dateTime",
  };
  assert (do_what > 0 && (do_what&(~XQ_FLAG_DURATION)) <= XQ_GETDATE_END);
  __get_smth_from_date (n, (caddr_t) str, do_what, names[(do_what-1)&(~XQ_FLAG_DURATION)]);
}

static void
xqf_get_Century_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_CENTURY_FROM_DATE);
}

static void
xqf_get_Year_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_YEAR_FROM_DATE);
}

static void
xqf_get_Month_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_MONTH_FROM_DATE);
}

static void
xqf_get_Day_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_DAY_FROM_DATE);
}

static void
xqf_get_hour_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_HOUR_FROM_DATE);
}

static void
xqf_get_minutes_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_MINUTES_FROM_DATE);
}

static void
xqf_get_seconds_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_SECONDS_FROM_DATE);
}

static void
xqf_get_TZ_from_dateTime (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_TZ_FROM_DATE);
}


static void
xqf_get_Year_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_YEAR_FROM_DATE | XQ_FLAG_DURATION);
}

static void
xqf_get_Month_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_MONTH_FROM_DATE | XQ_FLAG_DURATION);
}

static void
xqf_get_Day_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_DAY_FROM_DATE | XQ_FLAG_DURATION);
}

static void
xqf_get_hour_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_HOUR_FROM_DATE | XQ_FLAG_DURATION);
}

static void
xqf_get_minutes_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_MINUTES_FROM_DATE | XQ_FLAG_DURATION);
}

static void
xqf_get_seconds_from_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ctr (xqi, tree, ctx_xe, __gen_get_smth_from_date, XQ_GET_SECONDS_FROM_DATE | XQ_FLAG_DURATION);
}



static void
__xqf_raw_oper (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, qpq_oper_callback proc, int do_what)
{
  dtp_t dtp1, dtp2;
  caddr_t val1, val2, n = NULL;
  if (tree->_.xp_func.argcount)
    {
      val1 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
      val2 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1);
    }
  else
    {
      val1 = (caddr_t) ctx_xe;
      val2 = NULL;
    }
  if (!val1 || !val2)
    {
      proc (&n, val1, val2, do_what);
      XQI_SET (xqi, tree->_.xp_func.res, n);
      return;
    }

  dtp1 = DV_TYPE_OF (val1);
  dtp2 = DV_TYPE_OF (val2);
  if (DV_XML_ENTITY == dtp1)
    {
      xml_entity_t * xe1 = (xml_entity_t *) val1;
      caddr_t *str1=NULL;
      xe1->_->xe_string_value (xe1, str1, DV_UNKNOWN);

      if (DV_XML_ENTITY == dtp2)
	{
	  xml_entity_t * xe2 = (xml_entity_t *) val2;
	  caddr_t *str2=NULL;
	  xe2->_->xe_string_value (xe2, str2, DV_UNKNOWN);
	  proc (&n, *str1, *str2, do_what);
	}
      else
	{
	  proc (&n, *str1, val2, do_what);
	}
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
  else
    {
      if (DV_XML_ENTITY == dtp2)
	{
	  xml_entity_t * xe2 = (xml_entity_t *) val2;
	  caddr_t *str2=NULL;
	  xe2->_->xe_string_value (xe2, str2, DV_UNKNOWN);
	  proc (&n, val1, *str2, do_what);
	}
      else
	{
	  proc (&n, val1, val2, do_what);
	}
      XQI_SET (xqi, tree->_.xp_func.res, n);
    }
}


#define XQ_ADD_YEARS	1
#define XQ_ADD_MONTHS	2
#define XQ_ADD_DAYS	3
#define XQ_ADD_GMONTH	4
#define XQ_ADD_GYEAR	5
#define XQ_ADD_MAX	100
static int
__do_smth_with_date (caddr_t *n, const char *arg1, const char *arg2, int do_what, const char *where)
{
  int tz, ival;
  GMTIMESTAMP_STRUCT ts;
  dtp_t type1 = DV_TYPE_OF (arg1);
  dtp_t type2 = DV_TYPE_OF (arg2);
  caddr_t val;
  if (DV_DATETIME != type1)
    sqlr_new_error ("42001", "XPQ??", "Incorrect argument type:%s in %s", dv_type_title (type1), where);
  memset (&ts, 0, sizeof(ts));
  tz = DT_TZ (arg1);
  dt_to_GMTimestamp_struct ((caddr_t)arg1, &ts);
  *n = dk_alloc_box_zero (DT_LENGTH, DV_DATETIME);
  val = box_cast (NULL, (caddr_t)arg2, (sql_tree_tmp*) st_integer, type2);
  ival = (int) unbox (val);
  dk_free_box (val);
  val = NULL;
  switch (do_what) {
    case XQ_ADD_YEARS:
    case XQ_ADD_GYEAR:
      ts_add (&ts, ival, "year");
      break;
    case XQ_ADD_MONTHS:
    case XQ_ADD_GMONTH:
      ts_add (&ts, ival, "month");
      break;
    case XQ_ADD_DAYS:
      ts_add (&ts, ival, "day");
      break;
  };
  GMTimestamp_struct_to_dt (&ts, *n);
  DT_SET_TZ (*n, tz);
  return 0;
}

static void
__gen_do_smth_with_date (caddr_t *n, const char *arg1, const char *arg2, int do_what)
{
  static const char *names[] = {"add-years",
				"add-months",
				"add-days",
				"add-gMonth",
				"add-gYear",
  };
  assert (do_what >0 && do_what < XQ_ADD_MAX);
  __do_smth_with_date (n, arg1, arg2, do_what, names[do_what-1]);
}

static void
xqf_add_years (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_date, XQ_ADD_YEARS);
}

static void
xqf_add_months (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_date, XQ_ADD_MONTHS);
}

static void
xqf_add_days (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_date, XQ_ADD_DAYS);
}

static void
xqf_add_gmonth (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_date, XQ_ADD_GMONTH);
}

static void
xqf_add_gyear (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_date, XQ_ADD_GYEAR);
}

static int
__arithm_dates ( const char *x, const char *y, caddr_t ret, int sign )
{
  int tz1;
  GMTIMESTAMP_STRUCT tsx, tsy;

  memset (&tsx, 0, sizeof(tsx));
  memset (&tsy, 0, sizeof(tsy));

  tz1 = DT_TZ (x);

  dt_to_GMTimestamp_struct ((caddr_t)x, &tsx);
  dt_to_GMTimestamp_struct ((caddr_t)y, &tsy);

  ts_add (&tsx, (sign)?-tsy.year:tsy.year, "year");
  ts_add (&tsx, (sign)?-tsy.month:tsy.month, "month");
  ts_add (&tsx, (sign)?-tsy.day:tsy.day, "day");
  ts_add (&tsx, (sign)?-tsy.hour:tsy.hour, "hour");
  ts_add (&tsx, (sign)?-tsy.minute:tsy.minute, "minute");
  ts_add (&tsx, (sign)?-tsy.second:tsy.second, "second");
  if (sign) /* ie - */
    {
      if (tsx.fraction < tsy.fraction)
	{
	  ts_add (&tsx, -1, "second");
	  tsx.fraction += 1000000000;
	}
      tsx.fraction -= tsy.fraction;
    }
  else
    {
      tsx.fraction += tsy.fraction;
      if (tsx.fraction >= 1000000000)
	{
	  ts_add (&tsx, 1, "second");
	  tsx.fraction -= 1000000000;
	}
    }
  GMTimestamp_struct_to_dt (&tsx, ret);
  DT_SET_TZ (ret, tz1);
  return 0;
}


#define XQ_DT_DIFF	1
#define XQ_DT_END	2
#define XQ_DT_START	3
#define XQ_DT_MAX	100
static int
__do_smth_with_dates (caddr_t *n, const char *arg1, const char *arg2, int do_what, const char *where)
{
  int tz1, tz2;
  int type1 = (IS_BOX_POINTER (arg1))?box_tag (arg1):DV_LONG_INT;
  int type2 = (IS_BOX_POINTER (arg2))?box_tag (arg2):DV_LONG_INT;

  if (DV_DATETIME != type1)
    sqlr_new_error ("42001", "XPQ??", "Incorrect 1'st argument type:%s in %s", dv_type_title (type1), where);
  if (DV_DATETIME != type2)
    sqlr_new_error ("42001", "XPQ??", "Incorrect 2'nd argument type:%s in %s", dv_type_title (type2), where);

  tz1 = DT_TZ (arg1);
  tz2 = DT_TZ (arg2);
  *n = dk_alloc_box_zero (DT_LENGTH, DV_DATETIME);

  switch (do_what) {
    case XQ_DT_DIFF:
      __arithm_dates (arg1, arg2, *n, 1);
      break;
    case XQ_DT_END:
      __arithm_dates (arg1, arg2, *n, 0);
      break;
    case XQ_DT_START:
      __arithm_dates (arg1, arg2, *n, 1);
      break;
  };

  return 0;
}

static void
__gen_do_smth_with_dates (caddr_t *n, const char *arg1, const char *arg2, int do_what)
{
  static const char *names[] = {"get-duration",
				"get-end",
				"get-start",
  };
  assert (do_what >0 && do_what < XQ_DT_MAX);
  __do_smth_with_dates (n, arg1, arg2, do_what, names[do_what-1]);
}

static void
xqf_get_duration (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_dates, XQ_DT_DIFF);
}

static void
xqf_get_end (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_dates, XQ_DT_END);
}

static void
xqf_get_start (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_oper (xqi, tree, ctx_xe, __gen_do_smth_with_dates, XQ_DT_START);
}


static caddr_t
__normalize_arg ( caddr_t arg )
{
  int dtp = (IS_BOX_POINTER (arg))?box_tag (arg):DV_LONG_INT;
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) arg;
      caddr_t str = NULL;
      xe->_->xe_string_value (xe, &str, DV_UNKNOWN);
      return str;
    }
  return arg;
}

static void
__xqf_raw_ternary_oper (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, qpq_teroper_callback proc, int do_what)
{
  caddr_t val1, val2, val3, n = NULL;
  if (tree->_.xp_func.argcount)
    {
      val1 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
      val2 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1);
      val3 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 2);
    }
  else
    {
      val1 = (caddr_t) ctx_xe;
      val2 = NULL;
      val3 = NULL;
    }

  val1 = __normalize_arg (val1);
  val2 = __normalize_arg (val2);
  val3 = __normalize_arg (val3);

  proc (&n, val1, val2, val3, do_what);

  XQI_SET (xqi, tree->_.xp_func.res, n);
}


#define XQ_DDT_CONTAINS		1
#define XQ_DDT_CONTAINSD	2
#define XQ_DDT_DCONTAINS	3
#define XQ_DDT_MAX	100
static int
__do_smth_else_with_dates (caddr_t *n, const char *arg1, const char *arg2, const char *arg3, int do_what, const char *where)
{
  int type1 = (IS_BOX_POINTER (arg1))?box_tag (arg1):DV_LONG_INT;
  int type2 = (IS_BOX_POINTER (arg2))?box_tag (arg2):DV_LONG_INT;
  int type3 = (IS_BOX_POINTER (arg3))?box_tag (arg3):DV_LONG_INT;
  char dt[DT_LENGTH];
  const char *pdf = NULL, *pdt = NULL;

  if (DV_DATETIME != type1)
    sqlr_new_error ("42001", "XPQ??", "Incorrect 1'st argument type:%s in %s", dv_type_title (type1), where);
  if (DV_DATETIME != type2)
    sqlr_new_error ("42001", "XPQ??", "Incorrect 2'nd argument type:%s in %s", dv_type_title (type2), where);
  if (DV_DATETIME != type3)
    sqlr_new_error ("42001", "XPQ??", "Incorrect 3'rd argument type:%s in %s", dv_type_title (type3), where);


  switch (do_what) {
    case XQ_DDT_CONTAINS:
      pdf = arg2;
      pdt = arg1;
      break;
    case XQ_DDT_CONTAINSD:
      pdf = arg1;
      __arithm_dates (arg1, arg2, dt, 0);
      pdt = dt;
      break;
    case XQ_DDT_DCONTAINS:
      pdt = arg2;
      __arithm_dates (arg2, arg1, dt, 1);
      pdt = dt;
      break;
  };
  *n = box_num ((memcmp (arg3, pdf, DT_LENGTH) >= 0 && memcmp (arg3, pdt, DT_LENGTH) <= 0)? 1 : 0);
  return 0;
}

static void
__gen_do_smth_else_with_dates (caddr_t *n, const char *arg1, const char *arg2, const char *arg3, int do_what)
{
  static const char *names[] = {"xf:temporal-dateTimes-contains",
  };
  assert (do_what >0 && do_what < XQ_DT_MAX);
  __do_smth_else_with_dates (n, arg1, arg2, arg3, do_what, names[do_what-1]);
}


static void
xqf_dateTimes_contains (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ternary_oper (xqi, tree, ctx_xe, __gen_do_smth_else_with_dates, XQ_DDT_CONTAINS);
}

static void
xqf_dateTimeDuration_contains (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ternary_oper (xqi, tree, ctx_xe, __gen_do_smth_else_with_dates, XQ_DDT_CONTAINSD);
}

static void
xqf_durationDateTime_contains (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  __xqf_raw_ternary_oper (xqi, tree, ctx_xe, __gen_do_smth_else_with_dates, XQ_DDT_DCONTAINS);
}


static void
xqf_string_length (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  XQI_SET (xqi, tree->_.xp_func.res, box_num (utf8_strlen ((utf8char *)str1)));
}

static
collation_t * xpf_arg_collation (xp_instance_t* xqi, XT * tree, xml_entity_t * ctx_xe, int argnum)
{
  caddr_t coll_name = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, argnum);
  collation_t * coll = 0;
  if (NULL != coll_name)
    {
      coll = sch_name_to_collation (coll_name);
      if (!coll)
	sqlr_new_error ("22023", "IN006", "Collation %.300s not defined", coll_name);
      if (!coll->co_is_wide)
	sqlr_new_error ("42001", "XPQ??", "Collation %.300s must be wide", coll_name);
    }
  return coll;
}


#define XQ_STRCMP	1
#define XQ_CODECMP	2
#define XQ_STARTSWITH	3
#define XQ_ENDSWITH	4
#define XQ_STRCMP_MAX	100
static void
__xqf_compare  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int do_what, const char *where)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  collation_t *coll = 0;
  int res = 0, n;

  if (XQ_CODECMP != do_what)
    {
      if (tree->_.xp_func.argcount>2)
	coll = xpf_arg_collation (xqi, tree, ctx_xe, 2);
    }
  switch (do_what) {
    case XQ_STRCMP:
      res = compare_utf8_with_collation (str1, (long) strlen (str1), str2, (long) strlen (str2), coll);
      res = DVC_TO_C_STYLE(res);
      break;
    case XQ_CODECMP:
      res = strcmp(str1, str2);
      break;
    case XQ_STARTSWITH:
      {
	int len = 0, wide_len;
	caddr_t wide_box = box_utf8_as_wide_char (str1, NULL, strlen (str1), 0, DV_WIDE), utf8_box;

	wide_len = box_length (wide_box) / sizeof (wchar_t) - 1;
	n = utf8_strlen ((utf8char *)str2);
	utf8_box = box_wide_as_utf8_char (wide_box, MIN (n, wide_len), DV_SHORT_STRING);
	len = strlen (utf8_box);
	dk_free_box (wide_box);
	dk_free_box (utf8_box);
	if (DVC_MATCH == compare_utf8_with_collation (str1, len, str2, (long) strlen (str2), coll))
	  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
	else
	  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
	return;
      }
  };
  XQI_SET (xqi, tree->_.xp_func.res, box_num (res));
}

static void
xqf_gen_compare  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int do_what)
{
  static const char *names[] = {"compare",
				"codepoint-compare",
				"starts-with",
				"ends-with",
  };
  assert (do_what > 0 && do_what <= XQ_STRCMP_MAX);
  __xqf_compare  (xqi, tree, ctx_xe, do_what, names[do_what-1]);
}

static void
xqf_compare  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_gen_compare (xqi, tree, ctx_xe, XQ_STRCMP);
}


static void
xqf_codepoint_compare  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_gen_compare (xqi, tree, ctx_xe, XQ_CODECMP);
}


static void
xqf_starts_with  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_gen_compare (xqi, tree, ctx_xe, XQ_STARTSWITH);
}


static void
xqf_check_regexp (caddr_t pattern, int c_opts)
{
  caddr_t pre_res;
  int next;

  dk_free_box (pre_res=regexp_split_match (pattern, "", &next, c_opts));
  if (next != -1)
    sqlr_new_error ("42001", "XPQ??", "regular expression matches zero-length string");
  if (!pre_res)
    sqlr_new_error ("42001", "XRQ??", "invalid regular expression");
}

static int
xqf_make_regexp_modes(const char * flag)
{
  int c_opts;
  if ((c_opts=regexp_make_opts (flag)) == -1)
    sqlr_new_error ("42001", "XRQ??", "invalid regular expression flag");
  c_opts |= PCRE_UTF8;
  return c_opts;
}


static caddr_t*
__xqf_tokenize (caddr_t str, caddr_t pattern, caddr_t flag)
{
  caddr_t *res;
  int next = 1;
  caddr_t str_inx = str;
  dk_set_t res_set = 0;
  int c_opts;

  c_opts=xqf_make_regexp_modes (flag);
  xqf_check_regexp (pattern, c_opts);

  while (next > 0)
  {
    caddr_t token = regexp_split_match (pattern,str_inx, &next, c_opts);
    if (token)
      {
	dk_set_push (&res_set, token);
	str_inx += next;
      }
    else
      break;
  }

  res = (caddr_t *) list_to_array_of_xqval (dk_set_nreverse (res_set));
  return res;
}

static void
xqf_tokenize (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val1, val2, val3 = NULL;
  caddr_t res;
  if (tree->_.xp_func.argcount)
    {
      val1 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
      val2 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1);
      if (tree->_.xp_func.argcount > 2)
	val3 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 2);
    }
  else
    {
      XQI_SET (xqi, tree->_.xp_func.res, NEW_DB_NULL);
      return;
    }

  val1 = __normalize_arg (val1);
  val2 = __normalize_arg (val2);
  val3 = __normalize_arg (val3);

  {
    /* prevent memory leak */
    caddr_t *tmp_res = (caddr_t *)dk_alloc_box_zero (0 * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) tmp_res);
    res = (caddr_t) __xqf_tokenize (val1, val2, val3);
    box_tag_modify (tmp_res, DV_ARRAY_OF_LONG); /* To prevent erasing of original tuple values in XQI_SET */
    XQI_SET (xqi, tree->_.xp_func.res, res);
  }
  return;
}

static void
xqf_matches (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val1, val2, val3 = NULL;
  int c_opts;

  if (tree->_.xp_func.argcount)
    {
      val1 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
      val2 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1);
      if (tree->_.xp_func.argcount > 2)
	val3 = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 2);
    }
  else
    {
      XQI_SET (xqi, tree->_.xp_func.res, NEW_DB_NULL);
      return;
    }

  val1 = __normalize_arg (val1);
  val2 = __normalize_arg (val2);
  val3 = __normalize_arg (val3);

  c_opts = xqf_make_regexp_modes (val3);
  xqf_check_regexp (val2, c_opts);

  {
    caddr_t res = DV_STRINGP (val1) ? regexp_match_01 (val2, val1, c_opts) : NULL;
    if (res)
      XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L );
    else
      XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L );
    dk_free_box (res);
  }

  return;
}

static void
xqf_numeric_subtract (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_sub (v1,v2, NULL, NULL));
}

static void
xqf_numeric_multiply (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_mpy (v1,v2, NULL, NULL));
}

static void
xqf_numeric_divide (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_div (v1,v2, NULL, NULL));
}

static void
xqf_numeric_mod (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_mod (v1,v2, NULL, NULL));
}

static void
xqf_numeric_uminus (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v2;
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  XQI_SET (xqi, tree->_.xp_func.res, box_sub (0 ,v2, NULL, NULL));
}

static void
xqf_numeric_equal (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2,res;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  res = box_sub (v1, v2, NULL, NULL);
  if (DVC_MATCH == cmp_boxes (res, 0, NULL, NULL))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
  dk_free_box (res);
}

static void
xqf_numeric_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  if (DVC_GREATER == cmp_boxes (v1, v2, NULL, NULL))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}
static void
xqf_numeric_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);

  if (DVC_LESS == cmp_boxes (v1, v2, NULL, NULL))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}

static void
xqf_numeric_abs (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);

  if (DVC_LESS == cmp_boxes (v1, 0, NULL, NULL))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) box_sub (0, v1, NULL, NULL));
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) box_copy (v1));
}

static void
xqf_numeric_idivide (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t v1,v2;

  v1 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  if (DV_TYPE_OF (v1) != DV_LONG_INT)
    v1 = box_cast ((caddr_t *) xqi->xqi_qi, v1, (sql_tree_tmp*) st_integer, DV_TYPE_OF (v1));

  v2 = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);
  if (DV_TYPE_OF (v2) != DV_LONG_INT)
    v2 = box_cast ((caddr_t *) xqi->xqi_qi, v2, (sql_tree_tmp*) st_integer, DV_TYPE_OF (v2));

  XQI_SET (xqi, tree->_.xp_func.res, box_div (v1,v2, NULL, NULL));
}

void
xqf_substring  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t length, start_loc = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);
  long n2 = 0x7fffffffL, n1;
  long str_utf8len = 0;
  unsigned char *cut_begin = NULL, *cut_end = NULL, *tail = NULL;
  if (!DV_STRINGP (str))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  length = (tree->_.xp_func.argcount > 2
	    ? xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 2) : 0);

  n1 = (int)virt_rint(unbox_double (box_cast ((caddr_t *) xqi->xqi_qi, start_loc, (sql_tree_tmp*) st_double, DV_TYPE_OF (start_loc))));
  if (length)
    n2 = n1+(int)virt_rint(unbox_double (box_cast ((caddr_t *) xqi->xqi_qi, length, (sql_tree_tmp*) st_double, DV_TYPE_OF (length))));

  if (n1 <= 0)
    cut_begin = (unsigned char *)str;
  if (n2 <= 0)
    cut_end = (unsigned char *)str;
  if ((NULL == cut_begin) || (NULL == cut_end))
    {
      for (tail = (unsigned char *)str; '\0' != tail[0]; tail++)
	{
	  unsigned char c = tail[0];
	  if (UTF8_IS_HEADCHAR(c))
	    {
	      str_utf8len++;
	      if (n1 == str_utf8len)
		cut_begin = tail;
	      if (n2 == str_utf8len)
		cut_end = tail;
	    }
	}
    }
  if (NULL == cut_begin)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  if (NULL == cut_end)
    cut_end = tail;
  if (cut_end < cut_begin)
    cut_end = cut_begin;
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_nchars ((char *)cut_begin, cut_end-cut_begin));
}

void
xqf_lower_case  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  wchar_t * wide_str = (wchar_t*) box_utf8_as_wide_char ((caddr_t) str, NULL, box_length (str), 0, DV_LONG_WIDE);
  int i;
  int len = box_length (wide_str)/sizeof (wchar_t);
  wchar_t * res =  (wchar_t*)dk_alloc_box (len * sizeof (wchar_t), DV_WIDE);
  for (i = 0; i < len; i++)
    res[i] = (wchar_t)unicode3_getlcase((unichar)(wide_str[i]));

  XQI_SET (xqi, tree->_.xp_func.res, box_cast_to_UTF8( (caddr_t*)xqi->xqi_qi, (caddr_t)res));
  dk_free_box (res);
  dk_free_box (wide_str);
}

void
xqf_upper_case  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  wchar_t * wide_str = (wchar_t*) box_utf8_as_wide_char ((caddr_t) str, NULL, box_length (str), 0, DV_LONG_WIDE);
  int i;
  int len = box_length (wide_str)/sizeof (wchar_t);
  wchar_t * res =  (wchar_t*)dk_alloc_box (len * sizeof (wchar_t), DV_WIDE);
  for (i = 0; i < len; i++)
    res[i] = (wchar_t)unicode3_getucase((unichar)(wide_str[i]));

  XQI_SET (xqi, tree->_.xp_func.res, box_cast_to_UTF8((caddr_t*)xqi->xqi_qi, (caddr_t)res));
  dk_free_box (res);
  dk_free_box (wide_str);
}

void
xqf_escape_uri  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  ptrlong esc_reserved = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  wchar_t * wide_res = 0, *wide_str = (wchar_t*) box_utf8_as_wide_char ((caddr_t) str, NULL, box_length (str), 0, DV_LONG_WIDE);
  int esc_type = DKS_ESC_URI_NRES;

  if (esc_reserved)
    esc_type = DKS_ESC_URI_RES;

  {
    dk_session_t * out = strses_allocate ();
    dks_wide_esc_write (out, wide_str, box_length (wide_str) / sizeof (wchar_t) - 1, QST_CHARSET (xqi->xqi_qi),  esc_type);
    wide_res = (wchar_t*) strses_string (out);
    strses_free (out);
  }
  XQI_SET (xqi, tree->_.xp_func.res, box_cast_to_UTF8((caddr_t*)xqi->xqi_qi, (caddr_t)wide_res));

  dk_free_box (wide_str);
  dk_free_box (wide_res);
}

void
xqf_contains  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t match_str = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  collation_t * coll = 0;
  if (tree->_.xp_func.argcount > 2)
    coll = xpf_arg_collation (xqi, tree, ctx_xe, 2);

  if (strstr_utf8_with_collation (str, utf8_strlen ((utf8char *)str), match_str, utf8_strlen ((utf8char *)match_str), NULL, coll))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}

static caddr_t
__xqf_ends_with (caddr_t str, caddr_t mstr, collation_t * coll)
{
  long idx, utf8_idx = 0;
  if (coll)
    {
      wchar_t *wide1 = (wchar_t*) box_utf8_as_wide_char (str, NULL, box_length (str) - 1, 0, DV_LONG_WIDE);
      wchar_t *wide2 = (wchar_t*) box_utf8_as_wide_char (mstr, NULL, box_length (mstr) - 1, 0, DV_LONG_WIDE);
      size_t _1len = box_length (wide1)/sizeof (wchar_t) - 1;
      size_t _2len = box_length (wide2)/sizeof (wchar_t) - 1;
      int n1inx=0, n2inx=0;
      caddr_t res = 0;
      reverse_wide_string (wide1);
      reverse_wide_string (wide2);

      while (1)
	{
	again:
	  if (_1len && n1inx == _1len && n2inx != _2len)
	    return 0;
	  if (n2inx == _2len)
	    {
	      res = (caddr_t) 1;
	      break;
	    }
	  if (!((wchar_t *)coll->co_table)[wide2[n2inx]])
	    { /* ignore symbol, unicode normalization algorithm */
	      n2inx++;
	      goto again;
	    }
	  if (!_1len)
	    break;
	  if (!((wchar_t *)coll->co_table)[wide1[n1inx]])
	    { /* ignore symbol, unicode normalization algorithm */
	      n1inx++;
	      goto again;
	    }
	  if (((wchar_t *)coll->co_table)[wide1[n1inx]] != ((wchar_t *)coll->co_table)[wide2[n2inx]])
	    break;
	  n1inx++;
	  n2inx++;
	}
      dk_free_box (wide1);
      dk_free_box (wide2);
      return res;
    }
  else
    {
      long mstr_len = utf8_strlen ((utf8char *)mstr);
      long str_len = utf8_strlen ((utf8char *)str);
      if (str_len < mstr_len)
	return (caddr_t) 0;
      for (idx=0; idx < str_len; idx++)
	{
	  if (idx == (str_len - mstr_len))
	    {
	      if (!memcmp (mstr, str + utf8_idx, box_length (mstr) - 1))
		return (caddr_t) 1;
	      else
		return (caddr_t) 0;
	    }
	  utf8_idx++;
	  while (!UTF8_IS_HEADCHAR(str[utf8_idx])) utf8_idx++;
	}
    }
  /* must not be here */
  GPF_T1 ("Unexpected function behaviour");
  /* keeps compiler happy */
  return 0;
}


static void
xqf_ends_with  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  collation_t * coll = 0;
  if (tree->_.xp_func.argcount > 2)
    coll = xpf_arg_collation (xqi, tree, ctx_xe, 2);

  XQI_SET (xqi, tree->_.xp_func.res, __xqf_ends_with (str1, str2, coll));
}

#define XQF_REPL_SYNTAX_ERR	-1
#define XQF_REPL_OK	0

static int
xqf_write_replacement (dk_session_t * ses, caddr_t input, int * offvect, int offvect_sz, caddr_t replacement)
{
  int repl_sz = box_length (replacement) - 1;
  int idx = 0;
  while (idx < repl_sz)
    {
      switch (replacement[idx])
	{
	case '$': /* $n */
	  {
	    int num = 0;
	    if (idx++ >= (repl_sz - 1))
	      return XQF_REPL_SYNTAX_ERR;
	    while (idx < repl_sz && isdigit (replacement[idx]))
	      {
		num *= 10;
		num += replacement[idx++] - '0';
	      }
	    if (num <= 0)
	      return XQF_REPL_SYNTAX_ERR;
	    if (num > ((offvect_sz+1) / 2))
	      break;
	    session_buffered_write (ses, input + offvect[num*2], offvect[num*2+1] - offvect[num*2]) ;
	  }
	  break;
	default:
	  session_buffered_write_char (replacement[idx++], ses);
	}
    }
  return XQF_REPL_OK;
}

static void
xqf_replace  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t input = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t pattern = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  caddr_t replacement = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 2);
  caddr_t flag = 0;
  int c_opts;
  if (tree->_.xp_func.argcount > 3)
    flag = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 3);

  c_opts = xqf_make_regexp_modes (flag);
  xqf_check_regexp (pattern, c_opts);

  {
    int offvect[128];
    int res = regexp_split_parse (pattern, input, offvect, 128, c_opts);
    int utf8_str_len = box_length (input) - 1;
    if (res != -1)
      {
	dk_session_t * strses = strses_allocate ();
	int idx = 0;

	while (res != -1 && idx < utf8_str_len)
	  {
	    session_buffered_write (strses, input + idx, offvect[0]);
	    if (xqf_write_replacement (strses, input + idx, offvect, res, replacement) < 0)
	      {
		strses_free (strses);
		sqlr_new_error ("42001", "XPQ??", "Wrong replacement string: \"%s\"", replacement);
	      }

	    idx += offvect[1];
	    res = regexp_split_parse (pattern, input + idx, offvect, 128, c_opts);
	  }
	if (idx < utf8_str_len)
	  session_buffered_write (strses, input + idx, utf8_str_len - idx);

	XQI_SET (xqi, tree->_.xp_func.res, strses_string(strses));
	strses_free (strses);
      }
  }
}

static void
xqf_substring_before  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t arg1 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t arg2 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  collation_t * coll = 0;
  caddr_t first_pointer = 0;
  if (tree->_.xp_func.argcount > 2)
    coll = xpf_arg_collation (xqi, tree, ctx_xe,  2);
  first_pointer = strstr_utf8_with_collation (arg1, utf8_strlen ((utf8char *)arg1), arg2, utf8_strlen ((utf8char *)arg2), NULL, coll);

  if (first_pointer)
    {
      caddr_t result = dk_alloc_box (first_pointer - arg1 + 1, DV_STRING);
      memcpy (result, arg1, first_pointer - arg1);
      result[first_pointer - arg1] = 0;
      XQI_SET (xqi, tree->_.xp_func.res, result);
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_string (""));
}

static void
xqf_substring_after  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t arg1 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  caddr_t arg2 = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  collation_t * coll = 0;
  caddr_t first_pointer = 0;
  caddr_t end = 0;
  if (tree->_.xp_func.argcount > 2)
    coll = xpf_arg_collation (xqi, tree, ctx_xe,  2);
  first_pointer = strstr_utf8_with_collation (arg1, utf8_strlen ((utf8char *)arg1), arg2, utf8_strlen ((utf8char *)arg2), &end, coll);

  if (first_pointer && end)
    {
      size_t len = box_length (arg1) - (end - arg1) - 1;
      caddr_t result = dk_alloc_box (len + 1, DV_STRING);
      memcpy (result, end, len);
      result[len] = 0;
      XQI_SET (xqi, tree->_.xp_func.res, result);
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_string (""));
}

static void
xqf_codepoints_to_string  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int arginx = 0;
  caddr_t res_str, res_str_beg;
  long len = 0;
  virt_mbstate_t state;
  unsigned char mbs[VIRT_MB_CUR_MAX];

  memset (&state, 0, sizeof (virt_mbstate_t));
  for(arginx=0;arginx<tree->_.xp_func.argcount;arginx++)
    {
      long num = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, arginx));
      if (num < 0 || num >= 65536)
	sqlr_new_error ("42001", "XQR??", "codepoint is out of range %ld", num);
      len += (long) virt_wcrtomb (mbs, (wchar_t) num, &state);
    }

  arginx=0;
  res_str_beg = res_str = dk_alloc_box (len+1, DV_STRING);
  memset (&state, 0, sizeof (virt_mbstate_t));
  while (arginx < tree->_.xp_func.argcount)
    {
      long num = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, arginx));
      res_str += virt_wcrtomb ((utf8char *)res_str, (wchar_t) num, &state);
      arginx++;
    }
  res_str[0]=0;
  XQI_SET (xqi, tree->_.xp_func.res, res_str_beg);
}

static void
xqf_string_to_codepoints (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  utf8char * utf8_str = (utf8char *)xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  virt_mbstate_t state;
  size_t utf8_len = box_length ((caddr_t)utf8_str) -1;
  size_t inx = 0;
  dk_set_t set = 0;
  caddr_t res;
  memset (&state, 0, sizeof (virt_mbstate_t));

  while (inx < utf8_len)
    {
      wchar_t wtmp;
      int rc = (int) virt_mbrtowc (&wtmp, utf8_str + inx, utf8_len - inx, &state);
      if (rc < 0)
	GPF_T1 ("inconsistent wide char data");
      dk_set_push (&set, (caddr_t)((ptrlong)(wtmp)));
      inx += rc;
    }
  res = (caddr_t) list_to_array_of_xqval (dk_set_nreverse (set));
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

static void
xqf_string_join (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t* strings = (caddr_t*)xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 0);
  caddr_t delim = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);

  if (DV_TYPE_OF (strings) != DV_ARRAY_OF_XQVAL)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_string (""));
      return;
    }
  else
    {
      dk_session_t * ses;
      int inx;
      DO_BOX_FAST (caddr_t, el, inx, strings)
	{
	  if (!(DV_STRINGP (el)))
	    sqlr_new_error ("41001", "XQR??", "The first argument must be sequence of strings");
	}
      END_DO_BOX_FAST;

      ses = strses_allocate();
      DO_BOX_FAST (caddr_t, el, inx, strings)
	{
	  session_buffered_write (ses, el, box_length (el) - 1);
	  if (inx < (int)(BOX_ELEMENTS (strings) - 1))
	    session_buffered_write (ses, delim, box_length (delim) - 1);
	}
      END_DO_BOX_FAST;
      XQI_SET (xqi, tree->_.xp_func.res, strses_string(ses));
      strses_free (ses);
    }
}

void
xqf_root (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xml_entity_t *ent;
  ent = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 0));
  if (DV_XML_ENTITY != DV_TYPE_OF (ent))
    sqlr_new_error ("42001", "XQR??", "The argument of %s() must be xml entity", tree->_.xp_func.qname);
  while (XI_RESULT != ent->_->xe_up (ent, (XT *) XP_NODE, XE_UP_MAY_TRANSIT));
  XQI_SET (xqi, tree->_.xp_func.res, box_copy((caddr_t) ent));
}

void
xqf_zero_or_one (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);

  if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (val))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (val));
    }
  else
    {
      if (BOX_ELEMENTS (val) > 1)
	sqlr_new_error ("42001", "XQR??", "%s() called with a sequence containing more than one item", tree->_.xp_func.qname);
      XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (((caddr_t *)val)[0]));
    }
}

void
xqf_one_or_more (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t ** res_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  int len;
  xpf_arg_list (xqi, tree, ctx_xe, 0, (caddr_t *)res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  len = BOX_ELEMENTS (res_ptr[0]);
  if (0 == len)
    sqlr_new_error ("42001", "XQR??", "%s() called with a sequence containing no items", tree->_.xp_func.qname);
}

void
xqf_exactly_one (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);

  if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (val))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (val));
    }
  else
    {
      if (BOX_ELEMENTS (val) != 1)
	sqlr_new_error ("42001", "XQR??", "fn:exactly-one called with a sequence containing zero or more than one");
      XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (((caddr_t *)val)[0]));
    }
}

void
xqf_boolean (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT * arg = xpf_arg_tree (tree, 0);
  caddr_t val;
  dtp_t dtp;
  caddr_t zbox = box_num_nonull (0);

  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  dtp = DV_TYPE_OF (val);
  if (IS_STRING_DTP (dtp))
    XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (box_length (val) > 1));
  else if (IS_NUM_DTP (dtp))
    XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (DVC_MATCH != cmp_boxes (val, zbox, NULL, NULL)));
  else if (DV_ARRAY_OF_XQVAL == dtp && !BOX_ELEMENTS(val))
    XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (0L));
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (1L));
  dk_free_box (zbox);
}


static void
xqf_index_of (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * val;
  XT * arg = xpf_arg_tree (tree, 0);
  caddr_t match_obj = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1);
  collation_t * coll = 0;

  if (tree->_.xp_func.argcount > 2)
    coll = xpf_arg_collation (xqi, tree, ctx_xe, 2);

  xqi_eval (xqi, arg, ctx_xe);
  val = (caddr_t*)xqi_raw_value (xqi, arg);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
    {
      dk_set_t set = 0;
      caddr_t * arr;
      int inx;
      DO_BOX (caddr_t, elt, inx, val)
	{
	  int res = DVC_LESS;
	  dtp_t dtp = DV_TYPE_OF (elt);
	  if (IS_STRING_DTP(dtp) && DV_STRINGP(match_obj))
	    res = compare_utf8_with_collation (elt, box_length(elt)-1, match_obj, box_length(match_obj)-1, coll);
	  else if (IS_NUM_DTP (dtp))
	    res = cmp_boxes (elt, match_obj, NULL, NULL);
	  if (DVC_MATCH == res)
	    dk_set_push (&set, box_num (inx+1));
	}
      END_DO_BOX;
      arr = (caddr_t*) list_to_array_of_xqval (dk_set_nreverse (set));
      XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) arr);
    }
  else
    sqlr_new_error ("42001", "XQR??", "The first argument of fn:index-of must be sequence");
}

#ifdef NOT_CURRENTLY_USED
static void
xqf_empty (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = (caddr_t*)xqi_raw_value (xqi, arg);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val) &&
      BOX_ELEMENTS (val) == 0)
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_exists (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = (caddr_t*)xqi_raw_value (xqi, arg);
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val) &&
      BOX_ELEMENTS (val) > 0)
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}
#endif

#define ROL(h) ((h << 1) | ((h >> 31) & 1))
static id_hashed_key_t
xqf_box_hash (query_instance_t* qi, caddr_t box, collation_t * coll)
{
  dtp_t dtp = DV_TYPE_OF (box);
  if (IS_STRING_DTP (dtp) && coll)
    {
      virt_mbstate_t state;
      wchar_t wtmp;
      id_hashed_key_t h = 0;
      memset (&state, 0, sizeof (virt_mbstate_t));
      {
	int inx=0, len = box_length (box)-1;
	while (inx < len)
	  {
	    int rc = (int) virt_mbrtowc (&wtmp, ((utf8char *)(box)) + inx, len - inx, &state);
	    if (rc < 0)
	      GPF_T1 ("inconsistent wide char data");
	    if (((wchar_t*)coll->co_table)[wtmp])
	      {
		h = ROL (h) ^ ((wchar_t*)coll->co_table)[wtmp];
	      }
	    inx+=rc;
	  }
	return h & ID_HASHED_KEY_MASK;
      }
    }
  else if (IS_NUM_DTP(dtp))
    {
      caddr_t double_box = box_cast ((caddr_t*)qi, box, (sql_tree_tmp*)st_double, dtp);
      id_hashed_key_t hash = box_hash (double_box);
      dk_free_box (double_box);
      return hash;
    }
  else
    return box_hash (box);
}

static void
xqf_remove_duplicates (query_instance_t* qi, caddr_t *res_ptr, caddr_t *tmp_ptr, collation_t * coll)
{
  caddr_t *res;
  ptrlong *finprns;
  int items_no, items_ctr, items_c2, items_new_no;
  res = (caddr_t *)res_ptr[0];
  items_no = ((NULL == res) ? 0 : BOX_ELEMENTS(res));
  if (0 == items_no)
    {
      XP_SET(res_ptr, NULL);
      return;
    }
  finprns = (ptrlong *) dk_alloc_box (items_no * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  XP_SET (tmp_ptr, (caddr_t)finprns);
/* Every item must get its comparison value */
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      xml_entity_t *item = (xml_entity_t *)(res[items_ctr]);
      if (DV_XML_ENTITY == DV_TYPE_OF (item))
	finprns[items_ctr] = xe_equal_fingerprint((xml_entity_t *)item);
      else
	finprns[items_ctr] = xqf_box_hash (qi, (caddr_t)item, coll);
    }
/* Run from the end toward the beginning to remove duplicates. */
  items_new_no = items_no;
  for (items_c2 = items_no; (--items_c2) > 0; /* no step */)
    {
      xml_entity_t *i2 = (xml_entity_t *)(res[items_c2]);
      dtp_t i2_dtp = DV_TYPE_OF (i2);
      ptrlong fp2 = finprns[items_c2];
      for (items_ctr = 0; items_ctr < items_c2; items_ctr++)
	{
	  xml_entity_t *item = (xml_entity_t *)(res[items_ctr]);
	  dtp_t item_dtp = DV_TYPE_OF (item);
	  ptrlong finprn = finprns[items_ctr];
	  if (finprn != fp2)
	    continue;
	  if (IS_STRING_DTP (item_dtp) && IS_STRING_DTP (i2_dtp) && coll)
	    {
	      if (DVC_MATCH != compare_utf8_with_collation ((caddr_t)item, box_length(item) -1,
							    (caddr_t)i2, box_length(i2)-1, coll))
		continue;
	    }
	  else if ((DV_XML_ENTITY == item_dtp) ?
	    ((DV_XML_ENTITY != i2_dtp) || !xe_are_equal (i2, item)) :
	    ((DV_XML_ENTITY == i2_dtp) || (DVC_MATCH != cmp_boxes ((caddr_t)i2, (caddr_t)item, NULL, NULL)))
	    )
	    continue;
	  dk_free_tree ((box_t) item);
	  items_new_no--;
	  if (items_c2 > items_new_no)
	    items_c2 = items_new_no;
	  if (items_ctr < items_new_no)
	    {
	      res[items_ctr] = res[items_new_no];
	      finprns[items_ctr] = finprns[items_new_no];
	    }
	  res[items_new_no] = NULL;
	}
    }
/* Conclusion */
  if (items_new_no != items_no)
    {
      size_t final_res_size = items_new_no * sizeof(caddr_t);
      caddr_t final_res = dk_alloc_box (final_res_size, DV_ARRAY_OF_XQVAL);
      memcpy (final_res, res, final_res_size);
      memset (res, 0, final_res_size);
      XP_SET (res_ptr, final_res);
    }
}

static void
xqf_distinct_values (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  collation_t * coll = 0;
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.res);
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);

  if (tree->_.xp_func.argcount > 1)
    coll = xpf_arg_collation (xqi, tree, ctx_xe, 1);
  xqf_remove_duplicates (xqi->xqi_qi, res_ptr, tmp_ptr, coll);
}


static void
xqf_insert_before (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t ** ins_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  caddr_t ** res_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *new_res;
  long pos = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  int len, ins_len;
  xpf_arg_list (xqi, tree, ctx_xe, 0, (caddr_t *)res_ptr);
  xpf_arg_list (xqi, tree, ctx_xe, 2, (caddr_t *)ins_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  ins_len = BOX_ELEMENTS (ins_ptr[0]);
  if (0 == ins_len)
    return;
  len = BOX_ELEMENTS (res_ptr[0]);
  if (pos < 1) pos = 0;
  else if (pos > len) pos = len;
  else pos--;
  new_res = (caddr_t *)dk_alloc_box ((len+ins_len) * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  if (pos)
    memcpy (new_res, res_ptr[0], pos * sizeof (caddr_t));
  memcpy (new_res + pos, ins_ptr[0], ins_len * sizeof (caddr_t));
  if (pos < len)
    memcpy (new_res + pos + ins_len, res_ptr[0] + pos, (len - pos) * sizeof (caddr_t));
  dk_free_box (ins_ptr[0]);
  dk_free_box (res_ptr[0]);
  ins_ptr[0] = NULL;
  res_ptr[0] = new_res;
}

static void
xqf_remove (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t ** res_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *new_res;
  long pos = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  int len;
  xpf_arg_list (xqi, tree, ctx_xe, 0, (caddr_t *)res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  len = BOX_ELEMENTS (res_ptr[0]);
  if ((pos > len) || (pos < 1))
    return;
  pos--;
  new_res = (caddr_t *)dk_alloc_box ((len-1) * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  if (pos)
    memcpy (new_res, res_ptr[0], pos * sizeof (caddr_t));
  dk_free_tree (res_ptr[0][pos]);
  pos++;
  memcpy (new_res + pos - 1, res_ptr[0] + pos, (len - pos) * sizeof (caddr_t));
  dk_free_box (res_ptr[0]);
  res_ptr[0] = new_res;
}

static void
xqf_reverse (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t ** res_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *left, *right;
  int len;
  xpf_arg_list (xqi, tree, ctx_xe, 0, (caddr_t *)res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  len = BOX_ELEMENTS (res_ptr[0]);
  left = res_ptr[0];
  right = res_ptr[0]+len-1;
  while (left < right)
    {
      caddr_t swap = left[0];
      left[0] = right[0];
      right[0] = swap;
      left++;
      right--;
    }
}

static void
xqf_subsequence (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t ** res_ptr = (caddr_t **)XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  long n1, n2 = 0x7fffffffL;
  int len;
  caddr_t start_loc = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 1);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  xpf_arg_list (xqi, tree, ctx_xe, 0, (caddr_t *)res_ptr);
  len = BOX_ELEMENTS (res_ptr[0]);
  n1 = (int)virt_rint(unbox_double (box_cast ((caddr_t *) xqi->xqi_qi, start_loc, (sql_tree_tmp*) st_double, DV_TYPE_OF (start_loc))));
  if (n1 < 1)
    n1 = 0;
  else
    n1--;
  if (tree->_.xp_func.argcount > 2)
    {
      caddr_t sub_len = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 2);
      n2 = n1 + (int)virt_rint(unbox_double (box_cast ((caddr_t *) xqi->xqi_qi, sub_len, (sql_tree_tmp*) st_double, DV_TYPE_OF (sub_len))));
    }
  if (n2 > len)
    n2 = len;
  if ((n1 > 0) || (n2 < len))
    {
      int sz = (n2-n1) * sizeof (caddr_t);
      caddr_t *new_res = dk_alloc_box (sz, DV_ARRAY_OF_XQVAL);
      memcpy (new_res, res_ptr[0] + n1, sz);
      memset (res_ptr[0] + n1, '\0', sz);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)new_res);
    }
}

#ifdef NOT_CURRENTLY_USED
static void
xqf_is_same_node (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xml_entity_t *i1, *i2;
  XT * arg1 = xpf_arg_tree (tree, 0);
  XT * arg2 = xpf_arg_tree (tree, 1);
  xqi_eval (xqi, arg1, ctx_xe);
  xqi_eval (xqi, arg2, ctx_xe);
  i1 = (xml_entity_t*)xqi_raw_value (xqi, arg1);
  i2 = (xml_entity_t*)xqi_raw_value (xqi, arg2);

  if ((DV_XML_ENTITY != DV_TYPE_OF (i1)) ||
      (DV_XML_ENTITY != DV_TYPE_OF (i2)))
    sqlr_new_error ("42001", "XQR??", "The both arguments of op:is-same-node must be xml entity");
  if (i1->_->xe_is_same_as (i1, i2))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_count (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * seq;
  XT * arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  seq= (caddr_t*)xqi_raw_value (xqi, arg1);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (seq))
    XQI_SET (xqi, tree->_.xp_func.res, box_num (BOX_ELEMENTS(seq)));
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)1L);
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_avg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * seq;
  XT * arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  seq = (caddr_t*)xqi_raw_value (xqi, arg1);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (seq) && (BOX_ELEMENTS (seq)))
    {
      int inx;
      caddr_t avg, sum = box_num (0);
      DO_BOX (caddr_t, elt, inx, seq)
	{
	  caddr_t s1, s2, d;
	  d = box_cast ((caddr_t *) xqi->xqi_qi, elt, (sql_tree_tmp*) st_double, DV_TYPE_OF (elt));
	  s2 = box_add (sum, d, NULL, NULL);
	  s1 = sum;
	  sum = s2;
	  dk_free_box (d);
	  dk_free_box (s1);
	}
      END_DO_BOX;
      avg = box_div (sum, box_num (BOX_ELEMENTS(seq)), NULL, NULL);
      XQI_SET (xqi, tree->_.xp_func.res, avg);
      dk_free_box (sum);
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (seq));
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_min (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * seq;
  XT * arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  seq = (caddr_t*)xqi_raw_value (xqi, arg1);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (seq) && (BOX_ELEMENTS (seq)))
    {
      int inx;
      caddr_t _min = seq[0];
      DO_BOX (caddr_t, elt, inx, seq)
	{
	  if (DVC_LESS == cmp_boxes(elt, _min, NULL, NULL))
	    _min = elt;
	}
      END_DO_BOX;
      XQI_SET (xqi, tree->_.xp_func.res, box_copy(_min));
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (seq));
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_max (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * seq;
  XT * arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  seq = (caddr_t*)xqi_raw_value (xqi, arg1);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (seq) && (BOX_ELEMENTS (seq)))
    {
      int inx;
      caddr_t _max = seq[0];
      DO_BOX (caddr_t, elt, inx, seq)
	{
	  if (DVC_GREATER == cmp_boxes(elt, _max, NULL, NULL))
	    _max = elt;
	}
      END_DO_BOX;
      XQI_SET (xqi, tree->_.xp_func.res, box_copy(_max));
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (seq));
}
#endif

#ifdef NOT_CURRENTLY_USED
static void
xqf_sum (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t * seq;
  XT * arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  seq = (caddr_t*)xqi_raw_value (xqi, arg1);

  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (seq) && (BOX_ELEMENTS (seq)))
    {
      int inx;
      caddr_t sum = box_num (0);
      DO_BOX (caddr_t, elt, inx, seq)
	{
	  caddr_t s1, s2, d;
	  d = box_cast ((caddr_t *) xqi->xqi_qi, elt, (sql_tree_tmp*) st_double, DV_TYPE_OF (elt));
	  s2 = box_add (sum, d, NULL, NULL);
	  s1 = sum;
	  sum = s2;
	  dk_free_box (d);
	  dk_free_box (s1);
	}
      END_DO_BOX;
      XQI_SET (xqi, tree->_.xp_func.res, sum);
    }
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (seq));
}
#endif

static void
xqf_boolean_equal (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 0));
  long arg2 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  if ((arg1 && arg2) || (!arg1 && !arg2))
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}
static void
xqf_boolean_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 0));
  long arg2 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  if (!arg1 && arg2)
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}

static void
xqf_boolean_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 0));
  long arg2 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  if (arg1 && !arg2)
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
  else
    XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}

/* DV_DOUBLE_FLOAT for dayTimeDuration
   DV_LONG_INT for yearMonthDuration
*/
static caddr_t
xqf_duration_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int argnum, int is_ym)
{
  caddr_t duration = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, argnum);
  dtp_t type = DV_TYPE_OF (duration);
  if (!IS_NUM_DTP (type))
    sqlr_new_error ("42001", "XQR??", "duration is expected as argument N %d", argnum);
  return duration;
}

static long
xqf_YM_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xq, int argnum)
{
  caddr_t val = xqf_duration_arg (xqi, tree, ctx_xq, argnum, 1);
  long res;
  val = box_cast (NULL, val, (sql_tree_tmp*) st_integer, DV_TYPE_OF (val));
  res = unbox (val);
  dk_free_box (val);
  return res;
}

static double
xqf_DT_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xq, int argnum)
{
  caddr_t val = xqf_duration_arg (xqi, tree, ctx_xq, argnum, 0);
  double res;
  val = box_cast (NULL, val, (sql_tree_tmp*) st_double, DV_TYPE_OF(val));
  res = unbox_double (val);
  dk_free_box (val);
  return res;
}

static void
xqf_YM_eq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = xqf_YM_arg (xqi, tree, ctx_xe, 0);
  long arg2 = xqf_YM_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 == arg2));
}

static void
xqf_YM_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = xqf_YM_arg (xqi, tree, ctx_xe, 0);
  long arg2 = xqf_YM_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 < arg2));
}

static void
xqf_YM_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long arg1 = xqf_YM_arg (xqi, tree, ctx_xe, 0);
  long arg2 = xqf_YM_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 > arg2));
}
static void
xqf_DT_eq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double arg1 = xqf_DT_arg (xqi, tree, ctx_xe, 0);
  double arg2 = xqf_DT_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 == arg2));
}

static void
xqf_DT_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double arg1 = xqf_DT_arg (xqi, tree, ctx_xe, 0);
  double arg2 = xqf_DT_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 < arg2));
}

static void
xqf_DT_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double arg1 = xqf_DT_arg (xqi, tree, ctx_xe, 0);
  double arg2 = xqf_DT_arg (xqi, tree, ctx_xe, 1);

  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (arg1 > arg2));
}


int xqf_dT_op_eq (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  return ((t1->year == t2->year) &&
	  (t1->month == t2->month) &&
	  (t1->day == t2->day) &&
	  (t1->hour == t2->hour) &&
	  (t1->minute == t2->minute) &&
	  (t1->second == t2->second) &&
	  (t1->fraction == t2->fraction));
}

int xqf_dT_op_cmp (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  uint32 days1 = date2num (t1->year, t1->month, t1->day);
  uint32 days2 = date2num (t2->year, t2->month, t2->day);
  long sec1, sec2;
  if (days1 < days2)
    return -1;
  if (days1 > days2)
    return 1;
  sec1 = t1->hour * 3600 + t1->minute * 60 + t1->second;
  sec2 = t2->hour * 3600 + t2->minute * 60 + t2->second;
  if (sec1 < sec2)
    return -1;
  if (sec1 > sec2)
    return 1;
  if (t1->fraction < t2->fraction)
    return -1;
  if (t1->fraction > t2->fraction)
    return 1;
  return 0;
}


int xqf_date_op_eq (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  return ((t1->year == t2->year) &&
	  (t1->month == t2->month) &&
	  (t1->day == t2->day) );
}

int xqf_date_op_cmp (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  uint32 days1 = date2num (t1->year, t1->month, t1->day);
  uint32 days2 = date2num (t2->year, t2->month, t2->day);

  if (days1 < days2)
    return -1;
  if (days1 > days2)
    return 1;
  else
    return 0;
}


int xqf_time_op_eq (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  return ((t1->hour == t2->hour) &&
	  (t1->minute == t2->minute) &&
	  (t1->second == t2->second) &&
	  (t1->fraction == t2->fraction));
}

int xqf_time_op_cmp (TIMESTAMP_STRUCT* t1, TIMESTAMP_STRUCT* t2)
{
  long sec1, sec2;
  sec1 = t1->hour * 3600 + t1->minute * 60 + t1->second;
  sec2 = t2->hour * 3600 + t2->minute * 60 + t2->second;
  if (sec1 < sec2)
    return -1;
  if (sec1 > sec2)
    return 1;
  if (t1->fraction < t2->fraction)
    return -1;
  if (t1->fraction > t2->fraction)
    return 1;
  return 0;
}


typedef int (*xqf_dt_operation_f)(TIMESTAMP_STRUCT*,TIMESTAMP_STRUCT*);
xqf_dt_operation_f xqf_dt_ops[] = {
  xqf_dT_op_eq,
  xqf_dT_op_cmp,
  xqf_date_op_eq,
  xqf_date_op_cmp,
  xqf_time_op_eq,
  xqf_time_op_cmp
};

static void xqf_dt_check (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, xqf_dt_operation_f op, int expected)
{
  caddr_t arg1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t arg2 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 1);
  TIMESTAMP_STRUCT ts1;
  TIMESTAMP_STRUCT ts2;
  ptrlong res;
  dt_to_timestamp_struct (arg1, &ts1);
  dt_to_timestamp_struct (arg2, &ts2);
  ts_add (&ts1, -DT_TZ (arg1), "minute");
  ts_add (&ts2, -DT_TZ (arg2), "minute");
  res = ((expected == op(&ts1, &ts2)) ? 1 : 0);
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (res));
}

static void xqf_dT_eq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_dT_op_eq, 1);
}

static void xqf_dT_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_dT_op_cmp, -1);
}

static void xqf_dT_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_dT_op_cmp, 1);
}

static void xqf_date_eq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_date_op_eq, 1);
}

static void xqf_date_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_date_op_cmp, -1);
}

static void xqf_date_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_date_op_cmp, 1);
}

static void xqf_time_eq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_time_op_eq, 1);
}

static void xqf_time_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_time_op_cmp, -1);
}

static void xqf_time_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqf_dt_check(xqi, tree, ctx_xe, xqf_time_op_cmp, 1);
}

static void xqf_yMd_add (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long a1 = xqf_YM_arg (xqi,tree,ctx_xe,0);
  long a2 = xqf_YM_arg (xqi,tree,ctx_xe,1);

  XQI_SET (xqi, tree->_.xp_func.res, xqf_YM_from_months (a1+a2));
}
static void xqf_yMd_sub (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long a1 = xqf_YM_arg (xqi,tree,ctx_xe,0);
  long a2 = xqf_YM_arg (xqi,tree,ctx_xe,1);

  XQI_SET (xqi, tree->_.xp_func.res, xqf_YM_from_months (a1-a2));
}
static void xqf_yMd_mult (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long a1 = xqf_YM_arg (xqi,tree,ctx_xe,0);
  caddr_t a2 = xpf_arg (xqi,tree,ctx_xe, DV_NUMERIC, 1);
  caddr_t d2 = box_cast (NULL, a2, (sql_tree_tmp*) st_double, DV_TYPE_OF(a2));
  if (0 == unbox_double (d2))
    sqlr_new_error ("42001", "XQR??", "divide to zero error");

  XQI_SET (xqi, tree->_.xp_func.res, xqf_YM_from_months ((long)(virt_rint (a1*unbox_double (d2)))));
  dk_free_box (d2);
}
static void xqf_yMd_div (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long a1 = xqf_YM_arg (xqi,tree,ctx_xe,0);
  caddr_t a2 = xpf_arg (xqi,tree,ctx_xe, DV_NUMERIC, 1);
  caddr_t d2 = box_cast (NULL, a2, (sql_tree_tmp*) st_double, DV_TYPE_OF(a2));
  if (0 == unbox_double (d2))
    sqlr_new_error ("42001", "XQR??", "divide to zero error");
  XQI_SET (xqi, tree->_.xp_func.res, xqf_YM_from_months ((long)(virt_rint (a1/unbox_double (d2)))));
  dk_free_box (d2);
}
static void xqf_yMd_div_yMd (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long a1 = xqf_YM_arg (xqi,tree,ctx_xe,0);
  long a2 = xqf_YM_arg (xqi,tree,ctx_xe,1);
  if (0 == a2)
    sqlr_new_error ("42001", "XQR??", "divide to zero error");

  XQI_SET (xqi, tree->_.xp_func.res, box_double ((double)a1/a2));
}

static void xqf_dT_add (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double a1 = xqf_DT_arg (xqi,tree,ctx_xe,0);
  double a2 = xqf_DT_arg (xqi,tree,ctx_xe,1);

  XQI_SET (xqi, tree->_.xp_func.res, xqf_DT_from_secs (a1+a2));
}
static void xqf_dT_sub (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double a1 = xqf_DT_arg (xqi,tree,ctx_xe,0);
  double a2 = xqf_DT_arg (xqi,tree,ctx_xe,1);

  XQI_SET (xqi, tree->_.xp_func.res, xqf_DT_from_secs (a1-a2));
}
static void xqf_dT_mult (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double a1 = xqf_DT_arg (xqi,tree,ctx_xe,0);
  caddr_t a2 = xpf_arg (xqi,tree,ctx_xe, DV_NUMERIC, 1);
  caddr_t d2 = box_cast (NULL, a2, (sql_tree_tmp*) st_double, DV_TYPE_OF(a2));
  if (0 == unbox_double (d2))
    sqlr_new_error ("42001", "XQR??", "divide to zero error");

  XQI_SET (xqi, tree->_.xp_func.res, xqf_DT_from_secs ( a1*unbox_double (d2)) );
  dk_free_box (d2);
}
static void xqf_dT_div (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double a1 = xqf_DT_arg (xqi,tree,ctx_xe,0);
  caddr_t a2 = xpf_arg (xqi,tree,ctx_xe, DV_NUMERIC, 1);
  caddr_t d2 = box_cast (NULL, a2, (sql_tree_tmp*) st_double, DV_TYPE_OF(a2));
  if (0 == unbox_double (d2))
    sqlr_new_error ("42001", "XQR??", "divide to zero error");
  XQI_SET (xqi, tree->_.xp_func.res, xqf_DT_from_secs ( a1/unbox_double (d2)) );
  dk_free_box (d2);
}
static void xqf_dT_div_dT (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double a1 = xqf_DT_arg (xqi,tree,ctx_xe,0);
  double a2 = xqf_DT_arg (xqi,tree,ctx_xe,1);
  if (0 == a2)
    sqlr_new_error ("42001", "XQR??", "divide to zero error");

  XQI_SET (xqi, tree->_.xp_func.res, box_double (a1/a2));
}
static void xqf_adj_tz (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t dt = xpf_arg (xqi,tree,ctx_xe,DV_DATETIME,0);
  double a2 = xqf_DT_arg (xqi,tree,ctx_xe,1);
  long mins = (long)(virt_rint (a2 / 60.0));
  caddr_t res = box_copy (dt);
  DT_SET_TZ (res, mins);
  XQI_SET (xqi, tree->_.xp_func.res, res);
}
static void xqf_dT_sub_yMD (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t dt2 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 1);
  TIMESTAMP_STRUCT ts1,ts2;
  int sec1, sec2, c2 = 0;

  dt_to_timestamp_struct (dt1, &ts1);
  dt_to_timestamp_struct (dt2, &ts2);
  sec1 = ((ts1.day * 24) + ts1.hour)*3600 + ts1.minute*60 +ts1.second;
  sec2 = ((ts2.day * 24) + ts2.hour)*3600 + ts2.minute*60 +ts2.second;
  if ((sec2 > sec1) || ((sec2 == sec1) && (ts2.fraction > ts1.fraction)))
    c2 = 1;
  XQI_SET (xqi, tree->_.xp_func.res, xqf_YM_from_months ((ts1.year * 12 + ts1.month) - (ts2.year * 12 + ts2.month) - c2));
}

static numeric_t xqf_num_from_ts (TIMESTAMP_STRUCT* ts1)
{
  numeric_t s1,res, tmp;
  s1 = numeric_allocate();
  tmp = numeric_allocate();
  res = numeric_allocate();


  numeric_from_int32 (s1, date2num (ts1->year,ts1->month,ts1->day));
  numeric_from_int32 (tmp, 24 * 3600);
  numeric_multiply (res, s1, tmp);
  numeric_copy (s1, res);
  numeric_from_int32 (tmp, ts1->hour * 3600 + ts1->minute * 60 + ts1->second);
  numeric_add (res, s1, tmp);
  dk_free_box ((caddr_t) s1);
  dk_free_box ((caddr_t) tmp);

  return res;
}

static void xqf_dT_sub_dTD (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t dt2 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 1);
  GMTIMESTAMP_STRUCT ts1,ts2;
  numeric_t s1, s2, res;
  dt_to_GMTimestamp_struct (dt1, &ts1);
  dt_to_GMTimestamp_struct (dt2, &ts2);
  /* possible sign/unsigned problem */
  s1 = xqf_num_from_ts(&ts1);
  s2 = xqf_num_from_ts(&ts2);

  res = numeric_allocate();
  numeric_subtract (res, s1, s2);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)res);
  dk_free_box ((caddr_t)s1);
  dk_free_box ((caddr_t)s2);
}

static void xqf_add_yMD_to_dT  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long ymd = xqf_YM_arg (xqi, tree, ctx_xe, 1);
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t res = box_copy (dt1);
  GMTIMESTAMP_STRUCT ts;
  dt_to_GMTimestamp_struct (dt1, &ts);
  ts_add (&ts, ymd / 12, "year");
  ts_add (&ts, ymd % 12 , "month");
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (dt1));
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

static void xqf_add_dTD_to_dT  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double dtd = xqf_DT_arg (xqi, tree, ctx_xe, 1);
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t res = box_copy (dt1);
  long secs= (long) dtd;
  GMTIMESTAMP_STRUCT ts;
  dt_to_GMTimestamp_struct (dt1, &ts);
  ts_add (&ts, secs, "second");
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (dt1));
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

static void xqf_ts_add_year_month (TIMESTAMP_STRUCT* ts, int years,  int months)
{
  static int days_in_month[] = { 31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
  days_in_month[1] = days_in_february (ts->year);
  if (ts->day == days_in_month[ts->month-1])
    {
      ts_add (ts, years, "year");
      ts_add (ts, months, "month");
      days_in_month[1] = days_in_february (ts->year);
      ts->day = days_in_month[ts->month-1];
    }
  else
    {
      ts_add (ts, years, "year");
      ts_add (ts, months, "month");
    }
}

static void xqf_sub_yMD_to_dT  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  long ymd = xqf_YM_arg (xqi, tree, ctx_xe, 1);
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t res = box_copy (dt1);
  GMTIMESTAMP_STRUCT ts;
  dt_to_GMTimestamp_struct (dt1, &ts);
  xqf_ts_add_year_month (&ts,-ymd/12, -ymd % 12);
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (dt1));
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

static void xqf_sub_dTD_to_dT  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  double dtd = xqf_DT_arg (xqi, tree, ctx_xe, 1);
  caddr_t dt1 = xpf_arg (xqi, tree, ctx_xe, DV_DATETIME, 0);
  caddr_t res = box_copy (dt1);
  long secs= (long) dtd;
  GMTIMESTAMP_STRUCT ts;
  dt_to_GMTimestamp_struct (dt1, &ts);
  ts_add (&ts, -secs, "second");
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (dt1));
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

/* QNames */
static void xqf_qname_eq  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t qn1 = xpf_raw_arg (xqi, tree, ctx_xe, 0),
    qn2 = xpf_raw_arg (xqi, tree, ctx_xe, 1);
  if ((DV_XML_ENTITY != DV_TYPE_OF (qn1)) ||
      (DV_XML_ENTITY != DV_TYPE_OF (qn2)))
    sqlr_new_error ("42001", "XQR??", "The arguments of op:QName-equal must be xml entities");
  else
    {
      xml_entity_t * xe1 = (xml_entity_t *) qn1;
      xml_entity_t * xe2 = (xml_entity_t *) qn2;
      caddr_t name1 = xe1->_->xe_ent_name (xe1);
      caddr_t name2 = xe1->_->xe_ent_name (xe2);
      XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (DVC_MATCH == cmp_boxes (name1, name2, NULL, NULL)));
      dk_free_box (name1);
      dk_free_box (name2);
    }
}


static void
xpf_current_date_impl  (xp_instance_t * xqi, XT * tree, dtp_t ret_type)
{
  query_instance_t *qi = xqi->xqi_qi;
  lock_trx_t *lt = qi->qi_trx;
  caddr_t res;
  if (!lt)
    sqlr_new_error ("25000", "DT008", "now/get_timestamp: No current txn for timestamp");
  res = lt_timestamp_box (lt);
  box_tag_modify (res, ret_type);
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

static void
xpf_current_date  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_current_date_impl (xqi, tree, DV_DATE);
}

static void
xqf_current_time  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_current_date_impl (xqi, tree, DV_TIME);
}

static void
xqf_current_dateTime  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_current_date_impl (xqi, tree, DV_DATETIME);
}

void
xqf_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpfm_create_and_store_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args, XFN_NS_URI "/#");
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, XFN_NS_URI "/#", "#", 0);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, XFN_NS_URI "/#", "", 0);
}

void
xsd_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpfm_create_and_store_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args, XS_NS_URI "/#");
  xpfm_store_alias (xpfm_name, XS_NS_URI, xpfm_name, XS_NS_URI "/#", "#", 0);
  xpfm_store_alias (xpfm_name, XS_NS_URI, xpfm_name, XS_NS_URI "/#", "", 0);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, XS_NS_URI "/#", "/#", 1);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, XS_NS_URI "/#", "#", 1);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, XS_NS_URI "/#", "", 1);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, XS_NS_URI "/#", "/#", 1);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, XS_NS_URI "/#", "#", 1);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, XS_NS_URI "/#", "", 1);
}

void
xop_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpfm_create_and_store_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args, XOP_NS_URI "/#");
  xpfm_store_alias (xpfm_name, XOP_NS_URI, xpfm_name, XOP_NS_URI "/#", "#", 0);
  xpfm_store_alias (xpfm_name, XOP_NS_URI, xpfm_name, XOP_NS_URI "/#", "", 0);
}

void
xdt_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpfm_create_and_store_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args, XDT_NS_URI "/#");
  xpfm_store_alias (xpfm_name, XDT_NS_URI, xpfm_name, XDT_NS_URI "/#", "#", 0);
  xpfm_store_alias (xpfm_name, XDT_NS_URI, xpfm_name, XDT_NS_URI "/#", "", 0);
}

static xqf_str_parser_desc_t xqf_str_parser_descs[] = {
/* Keep these strings sorted alphabetically by p_name! */
/*	p_name			| p_proc			| p_rcheck		| p_opcode		| null	| box	| p_dest_dtp	| p_typed_bif_name		| p_sql_cast_type */
    {	"boolean"		, __boolean_from_string		, __boolean_rcheck	, 0			, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_boolean"	, NULL			},
    {	"byte"			, __integer_from_string		, __integer_rcheck	, XQ_INT8		, 0	, 1	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"currentDateTime"	, __cur_datetime		, NULL			, 0			, 0	, 0	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"date"			, __datetime_from_string	, __datetime_rcheck	, XQ_DATE		, 0	, 0	, DV_DATETIME	, "__xqf_str_parse_date"	, "DATE"		},
    {	"dateTime"		, __datetime_from_string	, __datetime_rcheck	, XQ_DATETIME		, 0	, 0	, DV_DATETIME	, "__xqf_str_parse_datetime"	, "DATETIME"		},
    {	"dayTimeDuration"	, __duration_from_string	, NULL /*???*/		, 0			, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"decimal"		, __numeric_from_string		, NULL			, 0			, 0	, 0	, DV_NUMERIC	, "__xqf_str_parse_numeric"	, "DECIMAL"		},
    {	"double"		, __float_from_string		, NULL			, XQ_DOUBLE		, 0	, 0	, DV_DOUBLE_FLOAT, "__xqf_str_parse_double"	, "DOUBLE PRECISION"	},
    {	"duration"		, __duration_from_string	, NULL /*???*/		, 0			, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"float"			, __float_from_string		, NULL			, XQ_FLOAT		, 0	, 0	, DV_SINGLE_FLOAT, "__xqf_str_parse_float"	, "REAL"		},
    {	"gDay"			, __datetime_from_string	, __datetime_rcheck	, XQ_DAY		, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"gMonth"		, __datetime_from_string	, __datetime_rcheck	, XQ_MONTH		, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"gMonthDay"		, __datetime_from_string	, __datetime_rcheck	, XQ_MONTHDAY		, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"gYear"			, __datetime_from_string	, __datetime_rcheck	, XQ_YEAR		, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"gYearMonth"		, __datetime_from_string	, __datetime_rcheck	, XQ_YEARMONTH		, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			},
    {	"int"			, __integer_from_string		, __integer_rcheck	, XQ_INT32		, 0	, 1	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"integer"		, __integer_from_string		, __integer_rcheck	, XQ_INT		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, "INTEGER"		},
    {	"long"			, __integer_from_string		, __integer_rcheck	, XQ_INT64		, 0	, 1	, DV_LONG_INT	, "__xqf_str_parse_integer"	, "INTEGER"		},
    {	"negativeInteger"	, __integer_from_string		, __integer_rcheck	, XQ_NINT		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"nonNegativeInteger"	, __integer_from_string		, __integer_rcheck	, XQ_NNINT		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"nonPositiveInteger"	, __integer_from_string		, __integer_rcheck	, XQ_NPINT		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"normalizedString"	, __gen_string_from_string	, __gen_string_rcheck	, XQ_NORM_STRING	, 0	, 1	, 0		, "__xqf_str_parse_nvarchar"	, NULL			},
    {	"positiveInteger"	, __integer_from_string		, __integer_rcheck	, XQ_PINT		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"precisionDecimal"	, __numeric_from_string		, NULL /*???*/		, 0			, 0	, 1	, DV_NUMERIC	, "__xqf_str_parse_numeric"	, NULL			},
    {	"short"			, __integer_from_string		, __integer_rcheck	, XQ_INT16		, 0	, 1	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"string"		, __gen_string_from_string	, __gen_string_rcheck	, XQ_STRING		, 0	, 1	, DV_STRING	, "__xqf_str_parse_nvarchar"	, "VARCHAR"		},
    {	"time"			, __datetime_from_string	, __datetime_rcheck	, XQ_TIME		, 0	, 0	, DV_DATETIME	, "__xqf_str_parse_time"	, "TIME"		},
    {	"token"			, __gen_string_from_string	, __gen_string_rcheck	, XQ_TOKEN		, 0	, 1	, 0		, "__xqf_str_parse_nvarchar"	, NULL			},
    {	"unsignedByte"		, __integer_from_string		, __integer_rcheck	, XQ_UINT8		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"unsignedInt"		, __integer_from_string		, __integer_rcheck	, XQ_UINT32		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"unsignedLong"		, __integer_from_string		, __integer_rcheck	, XQ_UINT64		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"unsignedShort"		, __integer_from_string		, __integer_rcheck	, XQ_UINT16		, 0	, 0	, DV_LONG_INT	, "__xqf_str_parse_integer"	, NULL			},
    {	"yearMonthDuration"	, __duration_from_string	, NULL /*???*/		, 0			, 0	, 1	, 0		, "__xqf_str_parse_datetime"	, NULL			} };

/* No parsing or validation for
hexBinary
base64Binary
anyURI
QName
NOTATION
language
NMTOKEN
NMTOKENS
Name
NCName
ID
IDREF
IDREFS
ENTITY
ENTITIES
*/

xqf_str_parser_desc_t *xqf_str_parser_descs_ptr = xqf_str_parser_descs;
int xqf_str_parser_desc_count = sizeof (xqf_str_parser_descs)/sizeof (xqf_str_parser_desc_t);

caddr_t
bif_xqf_str_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t p_name = bif_string_arg (qst, args, 0, "xqf_str_parse");
  caddr_t arg;
  dtp_t arg_dtp;
  caddr_t res = NULL;
  long desc_idx;
  int flags = 0;
  xqf_str_parser_desc_t *desc;
  desc_idx = ecm_find_name (p_name, xqf_str_parser_descs_ptr,
    xqf_str_parser_desc_count, sizeof (xqf_str_parser_desc_t) );
  if (ECM_MEM_NOT_FOUND == desc_idx)
    sqlr_new_error ("22023", "SR486", "Function xqf_str_parse() does not support XQuery library function '%.300s'", p_name);
  desc = xqf_str_parser_descs + desc_idx;
  if (3 <= BOX_ELEMENTS (args))
    flags = bif_long_arg (qst, args, 2, "xqf_str_parse");
  if ((desc->p_can_default) && (1 == BOX_ELEMENTS (args)))
    arg = NULL;
  else
    {
      arg = bif_arg_unrdf (qst, args, 1, "xqf_str_parse");
      arg_dtp = DV_TYPE_OF (arg);
      if (DV_DB_NULL == arg_dtp)
        return NEW_DB_NULL;
      if (DV_STRING != arg_dtp)
        {
          if (desc->p_dest_dtp == arg_dtp)
            res = box_copy_tree (arg);
          else
            {
              caddr_t err = NULL;
              res = box_cast_to (qst, arg, arg_dtp, desc->p_dest_dtp, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
              if (err)
                {
                  dk_free_tree (err);
                  goto cvt_error; /* see below */
                }
            }
          if (NULL == desc->p_rcheck)
            return res;
          if (desc->p_rcheck (&res, desc->p_opcode))
            return res;
          if (flags & 1)
            return NEW_DB_NULL;
          sqlr_new_error ("22023", "SR487",
            "Function xqf_str_parse() has failed to convert an arg of type %s (%d) by XQuery library function xsd:%.300s() because the result does not fit the XSD range restrictions",
            dv_type_title (arg_dtp), arg_dtp, p_name );
cvt_error:
          if (flags & 1)
            return NEW_DB_NULL;
          sqlr_new_error ("22023", "SR487",
            "Function xqf_str_parse() can not use XQuery library function xsd:%.300s() to process an arg of type %s (%d)",
            p_name, dv_type_title (arg_dtp), arg_dtp);
        }
    }
  if (flags & 1)
    {
      QR_RESET_CTX
        {
          desc->p_proc (&res, arg, desc->p_opcode);
        }
      QR_RESET_CODE
        {
          POP_QR_RESET;
          return NEW_DB_NULL;
        }
      END_QR_RESET
    }
  else
    desc->p_proc (&res, arg, desc->p_opcode);
  return res;
}


caddr_t
bif_xqf_str_parse_to_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "__xqf_str_parse_to_rdf_box");
  caddr_t type_iri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 1, "__xqf_str_parse_to_rdf_box");
  int suppress_error = ((BOX_ELEMENTS (args) > 2) ? bif_long_arg (qst, args, 2, "__xqf_str_parse_to_rdf_box") : 0);
  dtp_t arg_dtp = DV_TYPE_OF (arg);
  dtp_t type_iri_dtp = DV_TYPE_OF (type_iri);
  caddr_t p_name;
  caddr_t res = NULL;
  long desc_idx;
  xqf_str_parser_desc_t *desc;
  {
    if (IS_WIDE_STRING_DTP (type_iri_dtp))
      {
        sqlr_new_error ("22023", "SR007",
          "Function %s needs a string or UNAME or NULL as argument 2, "
    "not an arg of type %s (%d)",
    "__xqf_str_parse_to_rdf_box", dv_type_title (type_iri_dtp), type_iri_dtp);
      }
  }
  if ((strlen (type_iri) <= XMLSCHEMA_NS_URI_LEN) || ('#' != type_iri[XMLSCHEMA_NS_URI_LEN]))
    {
      if (!strcmp (type_iri, uname_rdf_ns_uri_XMLLiteral))
        {
          caddr_t err = NULL;
          xml_ns_2dict_t ns_2dict;
          dtd_t *dtd = NULL;
          id_hash_t *id_cache = NULL;
          xml_tree_ent_t *xte;
	  caddr_t tree;

	  if (arg_dtp == DV_XML_ENTITY)
	    return box_copy_tree (arg);
          tree = xml_make_mod_tree ((query_instance_t *)qst, arg, &err, FINE_XML | GE_XML, NULL /* no uri! */, "UTF-8", NULL, NULL, &dtd, &id_cache, &ns_2dict);
          if (NULL == tree)
            sqlr_resignal (err);
          xte = xte_from_tree (tree, (query_instance_t*) qst);
          xte->xe_doc.xd->xd_uri = NULL; /* instead of typical box_copy_tree (uri), because uri is definitely unknown */
          xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented inside xml_make_tree */
          xte->xe_doc.xd->xd_id_dict = id_cache;
          xte->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
          xte->xe_doc.xd->xd_ns_2dict = ns_2dict;
          xte->xe_doc.xd->xd_namespaces_are_valid = 0;
          /* test only : xte_word_range(xte,&l1,&l2); */
          return ((caddr_t) xte);
        }
      if ((!strcmp (type_iri, "http://www.openlinksw.com/schemas/virtrdf#Geometry")
	   || !strcmp (type_iri, "http://www.opengis.net/ont/geosparql#wktLiteral"))
	  && DV_STRING == arg_dtp)
	{
	  caddr_t err = NULL;
	  caddr_t g = geo_parse_wkt (arg, &err);
	  if (err && !suppress_error)
	    sqlr_resignal (err);
	  if (!err)
	    {
	      rdf_box_t * rb = rb_allocate ();
	      rb->rb_type = RDF_BOX_GEO;
	      rb->rb_lang = RDF_BOX_DEFAULT_LANG;
	      rb->rb_box = g;
	      rb->rb_is_complete = 1;
	      return (caddr_t) rb;
	    }
	}
      return NEW_DB_NULL;
    }
  p_name = type_iri + XMLSCHEMA_NS_URI_LEN + 1; /* +1 is to skip '#' */
  desc_idx = ecm_find_name (p_name, xqf_str_parser_descs,
    xqf_str_parser_desc_count, sizeof (xqf_str_parser_desc_t) );
  if (ECM_MEM_NOT_FOUND == desc_idx)
    return NEW_DB_NULL;
  desc = xqf_str_parser_descs + desc_idx;
  if (DV_DB_NULL == arg_dtp)
    return NEW_DB_NULL;
  /* if we have wide and we want typed string we do utf8, cast do to default charset so we do not do it */
  if (DV_WIDE == arg_dtp && desc->p_dest_dtp == DV_STRING)
    {
      res = box_wide_as_utf8_char (arg, box_length (arg) / sizeof (wchar_t) - 1, DV_STRING);
      goto res_ready;
    }
  if (DV_STRING != arg_dtp)
    {
      caddr_t err = NULL;
      if (desc->p_dest_dtp == arg_dtp)
        {
          res = box_copy_tree (arg);
          goto res_ready;
        }
      if (!strcmp (type_iri, uname_xmlschema_ns_uri_hash_dayTimeDuration))
        {
          caddr_t res1 = box_cast_to (qst, arg, arg_dtp, DV_STRING, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
          if (NULL == err)
            {
              res = box_sprintf (100, "PT%.100sS", res1);
              dk_free_box (res1);
              goto res_ready;
            }
          dk_free_box (res1);
        }
      else
        {
          res = box_cast_to (qst, arg, arg_dtp, desc->p_dest_dtp, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
          if (NULL == err)
            goto res_ready;
        }
      sqlr_new_error ("22023", "SR553",
        "Literal of type xsd:%s can not be created from SQL value of type %s (%d): %.1000s",
        p_name, dv_type_title (arg_dtp), arg_dtp, ERR_MESSAGE (err) );
    }
  QR_RESET_CTX
    {
      desc->p_proc (&res, arg, desc->p_opcode);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      if (suppress_error)
        return NEW_DB_NULL;
      sqlr_new_error ("22023", "SR552",
        "Literal '%.100s' does not match syntax for xsd:%s", arg, type_iri + XMLSCHEMA_NS_URI_LEN + 1);
    }
  END_QR_RESET;

res_ready:
  if (desc->p_rdf_boxed)
    {
      rdf_box_t *rb = rb_allocate ();
      rb->rb_box = res;
      rb->rb_is_complete = 1;
      rb->rb_type = RDF_BOX_DEFAULT_TYPE;
      rb->rb_lang = RDF_BOX_DEFAULT_LANG;
      return (caddr_t)(rb);
    }
  return res;
}

#define XQF_STR_FN(n) \
caddr_t bif_xqf_str_parse_##n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  return bif_xqf_str_parse (qst, err_ret, args); \
}

XQF_STR_FN(boolean)
XQF_STR_FN(date)
XQF_STR_FN(datetime)
XQF_STR_FN(double)
XQF_STR_FN(float)
XQF_STR_FN(integer)
XQF_STR_FN(numeric)
XQF_STR_FN(nvarchar)
XQF_STR_FN(time)

/* TO DO: the whole list 5.7.1 */
void xqf_init(void)
{
  st_double =  (sql_tree_tmp *) list (3, DV_DOUBLE_FLOAT, (ptrlong)0, (ptrlong)0);

  bif_define ("__xqf_str_parse", bif_xqf_str_parse);
  bif_define ("__xqf_str_parse_to_rdf_box", bif_xqf_str_parse_to_rdf_box);
  bif_define_typed ("__xqf_str_parse_boolean"	, bif_xqf_str_parse_boolean	, &bt_integer	);
  bif_define_typed ("__xqf_str_parse_date"	, bif_xqf_str_parse_date	, &bt_date	);
  bif_define_typed ("__xqf_str_parse_datetime"	, bif_xqf_str_parse_datetime	, &bt_datetime	);
  bif_define_typed ("__xqf_str_parse_double"	, bif_xqf_str_parse_double	, &bt_double	);
  bif_define_typed ("__xqf_str_parse_float"	, bif_xqf_str_parse_float	, &bt_float	);
  bif_define_typed ("__xqf_str_parse_integer"	, bif_xqf_str_parse_integer	, &bt_integer	);
  bif_define_typed ("__xqf_str_parse_numeric"	, bif_xqf_str_parse_numeric	, &bt_numeric	);
  bif_define_typed ("__xqf_str_parse_nvarchar"	, bif_xqf_str_parse_nvarchar	, &bt_wvarchar	);
  bif_define_typed ("__xqf_str_parse_time"	, bif_xqf_str_parse_time	, &bt_time	);

  /* Functions */
  x2f_define_builtin ("ENTITY"					, NULL /*xqf_entity*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("ID"					, NULL /*xqf_id*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("IDREF"					, NULL /*xqf_idref*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("NCName"					, NULL /*xqf_ncname*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("NMTOKEN"					, NULL /*xqf_nmtoken*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("add-days"				, xqf_add_days			/* ??? */	, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  x2f_define_builtin ("add-gMonth"				, xqf_add_gmonth		/* ??? */	, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  x2f_define_builtin ("add-gYear"				, xqf_add_gyear			/* ??? */	, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  x2f_define_builtin ("add-months"				, xqf_add_months		/* ??? */	, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  x2f_define_builtin ("add-years"				, xqf_add_years			/* ??? */	, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xsd_define_builtin ("boolean"					, xqf_boolean			/* XQuery 1.0 */, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,XPDV_BOOL,1))	, NULL);
  x2f_define_builtin ("boolean-from-string"			, NULL /*xqf_boolean_from_string */	/* ??? */	, XPDV_BOOL	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("byte"					, xqf_byte			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias ("ceiling", XFN_NS_URI, "ceiling", NULL);*/
  x2f_define_builtin ("codepoint-compare"			, xqf_codepoint_compare		/* ??? */	, DV_LONG_INT	, 2	, xpfmalist(2, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("codepoint-contains"			, NULL /*xqf_codepoint_contains*/ /* ??? */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("codepoint-substring-after"		, NULL /*xqf_codepoint_substring_after*/ /* ??? */	, DV_SHORT_STRING	, 2	, xpfmalist(2, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("codepoint-substring-before"		, NULL /*xqf_codepoint_substring_before*/ /* ??? */	, DV_SHORT_STRING	, 2	, xpfmalist(2, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("codepoints-to-string"			, xqf_codepoints_to_string	/* XQuery 1.0 */, DV_STRING	, 0	, xpfmalist(1, xpfma(NULL,DV_LONG_INT,1))	,  xpfmalist(1, xpfma(NULL,DV_LONG_INT,1)));
  x2f_define_builtin ("compare"					, xqf_compare			/* XQuery 1.0 */, DV_LONG_INT	, 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1))	, NULL);
  /*xpf_define_alias ("concat", XFN_NS_URI, "concat", NULL);*/
  xqf_define_builtin ("contains"				,xqf_contains			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1))	, NULL);
  /*xpf_define_alias   ("count", XFN_NS_URI, "count", NULL);*/
  /*xpf_define_alias   ("avg", XFN_NS_URI, "avg", NULL);*/
  /*xpf_define_alias   ("sum", XFN_NS_URI, "sum", NULL);*/
  /*xpf_define_alias   ("max", XFN_NS_URI, "max", NULL);*/
  /*xpf_define_alias   ("min", XFN_NS_URI, "min", NULL);*/
  x2f_define_builtin ("currentDateTime"				, xqf_currentDateTime		/* ??? */	, DV_DATETIME	, 0	, NULL	, NULL);
  xsd_define_builtin ("date"				, xqf_date			/* XQuery 1.0 */, DV_DATE	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("date", XFN_NS_URI, "date", XS_NS_URI);*/
  xsd_define_builtin ("dateTime"			, xqf_datetime			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("dateTime", XFN_NS_URI, "dateTime", XS_NS_URI);*/
  xsd_define_builtin ("decimal"					, xqf_decimal			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("double"					, xqf_double			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("duration"				, xqf_duration			/* ??? */	, XPDV_DURATION	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xqf_define_builtin ("ends-with"				, xqf_ends_with			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1))	, NULL);
  x2f_define_builtin ("escape-uri"				, xqf_escape_uri		/* XQuery 1.0 */, DV_STRING	, 2	, xpfmalist(2, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_LONG_INT,1))	, NULL);
  /*xpf_define_alias   ("false", XFN_NS_URI, "false", NULL);*/
  xsd_define_builtin ("float"					, xqf_float			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("floor", XFN_NS_URI, "floor", NULL);*/
  xsd_define_builtin ("gDay"					, xqf_gDay			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("gMonth"					, xqf_gMonth			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("gMonthDay"				, xqf_gMonthDay			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("gYear"					, xqf_gYear			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("gYearMonth"				, xqf_gYearMonth		/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("get-Century-from-date"			, xqf_get_Century_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_DATE,1))	, NULL);
  xpf_define_alias   ("get-Century-from-dateTime", XFN_NS_URI, "get-Century-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-Century-from-gYear", XFN_NS_URI, "get-Century-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-Century-from-gYearMonth", XFN_NS_URI, "get-Century-from-date", XFN_NS_URI);
  x2f_define_builtin ("get-days"				, xqf_get_Day_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("get-duration"				, xqf_get_duration		/* ??? */	, XPDV_DURATION	, 2	, xpfmalist(2, xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1))	, NULL);
  x2f_define_builtin ("get-end"					, xqf_get_end			/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_alias   ("get-gDay-from-date", XFN_NS_URI, "get-days", XFN_NS_URI);
  xpf_define_alias   ("get-gDay-from-dateTime", XFN_NS_URI, "get-days", XFN_NS_URI);
  xpf_define_alias   ("get-gDay-from-gMonthDay", XFN_NS_URI, "get-days", XFN_NS_URI);
  x2f_define_builtin ("get-gMonth-from-date"			, xqf_get_Month_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_DATE,1))	, NULL);
  xpf_define_alias   ("get-gMonth-from-dateTime", XFN_NS_URI, "get-gMonth-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-gMonth-from-gMonthDay", XFN_NS_URI, "get-gMonth-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-gMonth-from-gYearMonth", XFN_NS_URI, "get-gMonth-from-date", XFN_NS_URI);
  x2f_define_builtin ("get-gYear-from-date"			, xqf_get_Year_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_DATE,1))	, NULL);
  xpf_define_alias   ("get-gYear-from-dateTime", XFN_NS_URI, "get-gYear-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-gYear-from-gYear", XFN_NS_URI, "get-gYear-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-gYear-from-gYearMonth", XFN_NS_URI, "get-gYear-from-date", XFN_NS_URI);
  x2f_define_builtin ("get-hour-from-dateTime"			, xqf_get_hour_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_DATETIME,1))	, NULL);
  xpf_define_alias   ("get-hour-from-time", XFN_NS_URI, "get-hour-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("get-hours", XFN_NS_URI, "get-hour-from-dateTime", XFN_NS_URI);
  x2f_define_builtin ("get-minutes-from-dateTime"		, xqf_get_minutes_from_dateTime	/* ??? */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_DATETIME,1))	, NULL);
  xpf_define_alias   ("get-minutes-from-time", XFN_NS_URI, "get-minutes-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("get-minutes", XFN_NS_URI, "get-minutes-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("get-months", XFN_NS_URI, "get-gMonth-from-date", XFN_NS_URI);
  x2f_define_builtin ("get-seconds-from-dateTime"		, xqf_get_seconds_from_dateTime	/* ??? */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma(NULL,DV_DATETIME,1))	, NULL);
  xpf_define_alias   ("get-seconds-from-time", XFN_NS_URI, "get-seconds-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("get-seconds", XFN_NS_URI, "get-seconds-from-dateTime", XFN_NS_URI);
  x2f_define_builtin ("get-start"				, xqf_get_start			/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("get-timezone-from-date"			, xqf_get_TZ_from_dateTime	/* ??? */	, DV_SHORT_STRING	, 1	, xpfmalist(1, xpfma(NULL,DV_DATE,1))	, NULL);
  xpf_define_alias   ("get-timezone-from-dateTime", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-gDay", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-gMonth", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-gMonthDay", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-gYear", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-gYearMonth", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-timezone-from-time", XFN_NS_URI, "get-timezone-from-date", XFN_NS_URI);
  xpf_define_alias   ("get-years", XFN_NS_URI, "get-gYear-from-date", XFN_NS_URI);
  xsd_define_builtin ("int"					, xqf_int			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xsd_define_builtin ("integer"					, xqf_integer			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("language"				, NULL /*xqf_language*/		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("local-name", XFN_NS_URI, "local-name", NULL);*/
  xsd_define_builtin ("long"					, xqf_long			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("lower-case"				, xqf_lower_case	/* XQuery 1.0 */	, DV_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_STRING,1))	, NULL);
  x2f_define_builtin ("match"					, NULL /*xqf_match*/		/* ??? */	, DV_ARRAY_OF_XQVAL , 2	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("matches"					, xqf_matches			/* ??? */	, XPDV_BOOL, 2	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("name", XFN_NS_URI, "name", NULL);*/
  /*xpf_define_alias   ("namespace-uri", XFN_NS_URI, "namespace-uri", NULL);*/
  /*xpf_define_alias   ("not", XFN_NS_URI, "not", NULL);*/
  x2f_define_builtin ("normalizedString"			, xqf_normalized_string		/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("normalize-space", XFN_NS_URI, "normalize-space", NULL);*/
  x2f_define_builtin ("normalize-unicode"			, NULL /*xqf_normalize_unicode*/		, DV_SHORT_STRING , 2	, xpfmalist(2, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  /*xpf_define_alias   ("number", XFN_NS_URI, "number", NULL);*/
  xpf_define_alias   ("processXQuery", VIRT_BPM_XPATH_EXTENSION_NS_URI, "processXQuery", NULL);
  xpf_define_alias   ("processXSLT", VIRT_BPM_XPATH_EXTENSION_NS_URI, "processXSLT", NULL);
  xqf_define_builtin ("replace"					, xqf_replace			/* XQuery 1.0 */, DV_STRING	, 3 , xpfmalist(4, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1),  xpfma(NULL,DV_STRING,1))	, NULL);
  xpf_define_alias   ("round", XFN_NS_URI, "round-number", NULL);
  x2f_define_builtin ("root"					, xqf_root			/* XQuery 1.0 */, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,1))	, NULL);
  xsd_define_builtin ("short"					, xqf_short			/* ??? */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xqf_define_builtin ("starts-with"				, xqf_starts_with		/* ??? */	, XPDV_BOOL	, 2	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xqf_define_builtin ("string-length"				, xqf_string_length		/* XQuery 1.0 */	, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,DV_STRING,1))	, NULL);
  xsd_define_builtin ("string"					, xqf_string			/* ??? */	, DV_SHORT_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("string-join"				, xqf_string_join		/* XQuery 1.0 */, DV_STRING , 2	, xpfmalist(2, xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_STRING,1))	, NULL);
  x2f_define_builtin ("string-pad-beginning"			, NULL /*xqf_string_pad_beginning*/ /* ??? */	, DV_SHORT_STRING , 3	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("string-pad-end"				, NULL /*xqf_string_pad_end*/	/* ??? */	, DV_SHORT_STRING , 3	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("string-to-codepoints"			, xqf_string_to_codepoints	/* XQuery 1.0 */, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_STRING,1))	,  NULL);
  xqf_define_builtin ("substring"				, xqf_substring			/* XQuery 1.0 */, DV_STRING , 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xqf_define_builtin ("substring-after"				, xqf_substring_after		/* XQUery 1.0 */, DV_STRING , 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1))	, NULL);
  xqf_define_builtin ("substring-before"			, xqf_substring_before		/* XQuery 1.0 */, DV_STRING , 2	, xpfmalist(3, xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1), xpfma(NULL,DV_STRING,1))	, NULL);
  x2f_define_builtin ("temporal-dateTimeDuration-contains"	, xqf_dateTimeDuration_contains	/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("temporal-dateTimes-contains"		, xqf_dateTimes_contains	/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("temporal-durationDateTime-contains"	, xqf_durationDateTime_contains	/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xsd_define_builtin ("time"					, xqf_time			/* XQuery 1.0 */, DV_TIME	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("token"					, xqf_token			/* ??? */	, DV_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  x2f_define_builtin ("tokenize"				, xqf_tokenize			/* ??? */	, DV_UNKNOWN, 2	, xpfmalist(3, xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1), xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xpf_define_alias   ("translate", XFN_NS_URI, "translate", NULL);
  xpf_define_alias   ("true", XFN_NS_URI, "true", NULL);
  x2f_define_builtin ("upper-case"				, xqf_upper_case	/* XQuery 1.0 */	, DV_STRING , 1	, xpfmalist(1, xpfma(NULL,DV_STRING,1))	, NULL);


  /* Operators */
  xop_define_builtin ("numeric-abs"			, xqf_numeric_abs				, DV_NUMERIC , 1	, xpfmalist(1, xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xpf_define_alias ("numeric-add", XOP_NS_URI, "sum", NULL);
  xop_define_builtin ("numeric-equal"			, xqf_numeric_equal				, XPDV_BOOL  , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-greater-than"		, xqf_numeric_gt				, XPDV_BOOL  , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-integer-divide"		, xqf_numeric_idivide				, DV_NUMERIC , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-less-than"		, xqf_numeric_lt				, XPDV_BOOL  , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-mod"			, xqf_numeric_mod				, DV_NUMERIC , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-multiply"			, xqf_numeric_multiply				, DV_NUMERIC , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-subtract"			, xqf_numeric_subtract	/* ??? */		, DV_NUMERIC , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-divide"			, xqf_numeric_divide				, DV_NUMERIC , 2	, xpfmalist(2, xpfma(NULL,DV_NUMERIC,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("numeric-unary-minus"		, xqf_numeric_uminus				, DV_NUMERIC , 1	, xpfmalist(1, xpfma(NULL,DV_NUMERIC,1))				, NULL);



  x2f_define_builtin ("zero-or-one"			, xqf_zero_or_one			/* XQuery 1.0 */, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("one-or-more"			, xqf_one_or_more			/* XQuery 1.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("exactly-one"			, xqf_exactly_one				/* XQuery 1.0 */, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("index-of"				, xqf_index_of				/* XQuery 1.0 */, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  /*xpf_define_alias   ("empty", XFN_NS_URI, "empty", NULL);*/
  /*xpf_define_alias   ("exists", XFN_NS_URI, "exists", NULL);*/
  xqf_define_builtin ("distinct-values"			, xqf_distinct_values			/* XQuery 1.0 */, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("insert-before"			, xqf_insert_before			/* XQuery 1.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("remove"				, xqf_remove				/* XQuery 1.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("reverse"				, xqf_reverse				/* XQuery 1.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("subsequence"			, xqf_subsequence			/* XQuery 1.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  /*xpf_define_alias   ("unordered", XFN_NS_URI, "unordered", NULL);*/
  /*xpf_define_alias   ("union", XFN_NS_URI, "union", NULL);*/
  xpf_define_alias   ("union", XOP_NS_URI, "union", NULL);
  /*xpf_define_alias   ("intersect", XFN_NS_URI, "intersect", NULL);*/
  xpf_define_alias   ("intersect", XOP_NS_URI, "intersect", NULL);
  /*xpf_define_alias   ("except", XFN_NS_URI, "except", NULL);*/
  xpf_define_alias   ("except", XOP_NS_URI, "except", NULL);

  xpf_define_alias   ("is-same-node", XOP_NS_URI, "is-same", NULL);
  xpf_define_alias   ("node-before", XOP_NS_URI, "is-before", NULL);
  xpf_define_alias   ("node-after", XOP_NS_URI, "is-after", NULL);
  xpf_define_alias   ("to", XOP_NS_URI, "TO operator", NULL);
  /*xpf_define_alias   ("id", XFN_NS_URI, "id", NULL);*/
  /*xpf_define_alias   ("doc", XFN_NS_URI, "doc", NULL);*/
  /*xpf_define_alias   ("position", XFN_NS_URI, "position", NULL);*/
  /*xpf_define_alias   ("last", XFN_NS_URI, "last", NULL);*/

  xop_define_builtin ("boolean-equal"		       , xqf_boolean_equal			/* XQuery 1.0 */, XPDV_BOOL     , 2	, xpfmalist(2, xpfma(NULL,XPDV_BOOL,0),  xpfma(NULL,XPDV_BOOL,0)), NULL);
  xop_define_builtin ("boolean-less-than"	       , xqf_boolean_lt				/* XQuery 1.0 */, XPDV_BOOL     , 2	, xpfmalist(2, xpfma(NULL,XPDV_BOOL,0),  xpfma(NULL,XPDV_BOOL,0)), NULL);
  xop_define_builtin ("boolean-greater-than"	       , xqf_boolean_gt				/* XQuery 1.0 */, XPDV_BOOL     , 2	, xpfmalist(2, xpfma(NULL,XPDV_BOOL,0),  xpfma(NULL,XPDV_BOOL,0)), NULL);


  /* datetime functions */
  xpf_define_alias   ("year-from-dateTime", XFN_NS_URI, "get-gYear-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("day-from-dateTime", XFN_NS_URI, "get-gDay-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("month-from-dateTime", XFN_NS_URI, "get-gMonth-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("timezone-from-dateTime", XFN_NS_URI, "get-timezone-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("hours-from-dateTime", XFN_NS_URI, "get-hour-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("minutes-from-dateTime", XFN_NS_URI, "get-minutes-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("seconds-from-dateTime", XFN_NS_URI, "get-seconds-from-dateTime", XFN_NS_URI);

  xpf_define_alias   ("year-from-date", XFN_NS_URI, "get-gYear-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("day-from-date", XFN_NS_URI, "get-gDay-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("month-from-date", XFN_NS_URI, "get-gMonth-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("timezone-from-date", XFN_NS_URI, "get-timezone-from-dateTime", XFN_NS_URI);

  xpf_define_alias   ("timezone-from-time", XFN_NS_URI, "get-timezone-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("hours-from-time", XFN_NS_URI, "get-hour-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("minutes-from-time", XFN_NS_URI, "get-minutes-from-dateTime", XFN_NS_URI);
  xpf_define_alias   ("seconds-from-time", XFN_NS_URI, "get-seconds-from-dateTime", XFN_NS_URI);

  /* duration functions */
#if 1
  xpf_define_alias   ("yearMonthDuration", XDT_NS_URI, "duration", XFN_NS_URI); /* XQuery 1.0 */
  xpf_define_alias   ("dayTimeDuration", XDT_NS_URI, "duration", XFN_NS_URI); /* XQuery 1.0 */
#else
  xdt_define_builtin ("yearMonthDuration"			, xqf_duration			/* XQuery 1.0 */, XPDV_DURATION	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
  xdt_define_builtin ("dayTimeDuration"				, xqf_duration			/* XQuery 1.0 */, XPDV_DURATION	, 1	, xpfmalist(1, xpfma(NULL,DV_SHORT_STRING,1))	, NULL);
#endif
  x2f_define_builtin ("year-from-duration"			, xqf_get_Year_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("day-from-duration"			, xqf_get_Day_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("month-from-duration"			, xqf_get_Month_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("minutes-from-duration"			, xqf_get_minutes_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("hours-from-duration"			, xqf_get_hour_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);
  x2f_define_builtin ("seconds-from-duration"			, xqf_get_seconds_from_duration	/* XQuery 1.0 */, DV_LONG_INT	, 1	, xpfmalist(1, xpfma(NULL,XPDV_DURATION,1))	, NULL);

  /* duration operations */
  xop_define_builtin ("yearMonthDuration-equal"		, xqf_YM_eq			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("yearMonthDuration-less-than"	, xqf_YM_lt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("yearMonthDuration-greater-than"	, xqf_YM_gt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("dayTimeDuration-equal"		, xqf_DT_eq			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("dayTimeDuration-less-than"	, xqf_DT_lt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("dayTimeDuration-greater-than"	, xqf_DT_gt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);

  /* arithmetic operations over durations */
  xop_define_builtin ("add-yearMonthDurations"		, xqf_yMd_add			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("subtract-yearMonthDurations"	, xqf_yMd_sub			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("multiply-yearMonthDuration"	, xqf_yMd_mult			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  xop_define_builtin ("divide-yearMonthDuration"		, xqf_yMd_div			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  xop_define_builtin ("divide-yearMonthDuration-by-yearMonthDuration"	,xqf_yMd_div_yMd/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("add-dayTimeDurations"		, xqf_dT_add			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("subtract-dayTimeDurations"	, xqf_dT_sub			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);
  xop_define_builtin ("multiply-dayTimeDuration"		, xqf_dT_mult			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  xop_define_builtin ("divide-dayTimeDuration"		, xqf_dT_div			/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  xop_define_builtin ("divide-dayTimeDuration-by-dayTimeDuration"	,xqf_dT_div_dT	/* XQuery 1.0 */, DV_UNKNOWN	, 2	, xpfmalist(2,  xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);


  /* dateTime operations */
  xop_define_builtin ("dateTime-equal"			, xqf_dT_eq			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("dateTime-less-than"		, xqf_dT_lt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("dateTime-greater-than"		, xqf_dT_gt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  /* Date operations */
  xop_define_builtin ("date-equal"			, xqf_date_eq			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("date-less-than"			, xqf_date_lt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("date-greater-than"		, xqf_date_gt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  /* time operations */
  xop_define_builtin ("time-equal"			, xqf_time_eq			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("time-less-than"			, xqf_time_lt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);
  xop_define_builtin ("time-greater-than"		, xqf_time_gt			/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_DATETIME,1)), NULL);

  x2f_define_builtin ("adjust-dateTime-to-timezone"	, xqf_adj_tz			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
#if 1
  xpf_define_alias ("adjust-date-to-timezone", XFN_NS_URI, "adjust-dateTime-to-timezone", XFN_NS_URI);
  xpf_define_alias ("adjust-date-to-timezone", XXF_NS_URI, "adjust-dateTime-to-timezone", XFN_NS_URI);
  xpf_define_alias ("adjust-time-to-timezone", XFN_NS_URI, "adjust-dateTime-to-timezone", XFN_NS_URI);
  xpf_define_alias ("adjust-time-to-timezone", XXF_NS_URI, "adjust-dateTime-to-timezone", XFN_NS_URI);
#else
  x2f_define_builtin ("adjust-date-to-timezone"	,	 xqf_adj_tz			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  x2f_define_builtin ("adjust-time-to-timezone"	,	xqf_adj_tz			/* XQuery 1.0 */, DV_DATETIME	, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
#endif

  /* Arithmetic functions on Durations, Dates and Times */
  x2f_define_builtin ("subtract-dateTimes-yielding-yearMonthDuration",xqf_dT_sub_yMD		/* XQuery 1.0 */, DV_NUMERIC, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  x2f_define_builtin ("subtract-dateTimes-yielding-dayTimeDuration",xqf_dT_sub_dTD		/* XQuery 1.0 */, DV_NUMERIC, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
#if 1
  xpf_define_alias ("subtract-dates-yielding-yearMonthDuration", XFN_NS_URI, "subtract-dateTimes-yielding-yearMonthDuration", XFN_NS_URI);
  xpf_define_alias ("subtract-dates-yielding-yearMonthDuration", XXF_NS_URI, "subtract-dateTimes-yielding-yearMonthDuration", XFN_NS_URI);
  xpf_define_alias ("subtract-dates-yielding-dayTimeDuration", XFN_NS_URI, "subtract-dateTimes-yielding-dayTimeDuration", XFN_NS_URI);
  xpf_define_alias ("subtract-dates-yielding-dayTimeDuration", XXF_NS_URI, "subtract-dateTimes-yielding-dayTimeDuration", XFN_NS_URI);
  xpf_define_alias ("subtract-times", XFN_NS_URI, "subtract-dateTimes-yielding-dayTimeDuration", XFN_NS_URI);
  xpf_define_alias ("subtract-times", XXF_NS_URI, "subtract-dateTimes-yielding-dayTimeDuration", XFN_NS_URI);
#else
  x2f_define_builtin ("subtract-dates-yielding-yearMonthDuration",xqf_dT_sub_yMD		/* XQuery 1.0 */, DV_NUMERIC, 1	, xpfmalist(2,  xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  x2f_define_builtin ("subtract-dates-yielding-dayTimeDuration",xqf_dT_sub_dTD			/* XQuery 1.0 */, DV_NUMERIC, 1	, xpfmalist(2,  xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
  x2f_define_builtin ("subtract-times",xqf_dT_sub_dTD						/* XQuery 1.0 */, DV_NUMERIC, 1	, xpfmalist(2,  xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1)), NULL);
#endif

  xop_define_builtin ("add-yearMonthDuration-to-dateTime", xqf_add_yMD_to_dT		/* XQuery 1.0 */, DV_DATETIME	, 2	, xpfmalist(2, xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("add-dayTimeDuration-to-dateTime", xqf_add_dTD_to_dT		/* XQuery 1.0 */, DV_DATETIME	, 2	, xpfmalist(2, xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("subtract-yearMonthDuration-from-dateTime", xqf_sub_yMD_to_dT	/* XQuery 1.0 */, DV_DATETIME	, 2	, xpfmalist(2, xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
  xop_define_builtin ("subtract-dayTimeDuration-from-dateTime", xqf_sub_dTD_to_dT	/* XQuery 1.0 */, DV_DATETIME	, 2	, xpfmalist(2, xpfma(NULL,DV_DATETIME,1), xpfma(NULL,DV_NUMERIC,1))	, NULL);
#if 1
  xpf_define_alias ("add-yearMonthDuration-to-date"		, XOP_NS_URI  ,"add-yearMonthDuration-to-dateTime"		, XOP_NS_URI);
  xpf_define_alias ("add-dayTimeDuration-to-date"		, XOP_NS_URI  ,"add-dayTimeDuration-to-dateTime"			, XOP_NS_URI);
  xpf_define_alias ("subtract-yearMonthDuration-from-date"	, XOP_NS_URI  ,"subtract-yearMonthDuration-from-dateTime"	, XOP_NS_URI);
  xpf_define_alias ("subtract-dayTimeDuration-from-date"		, XOP_NS_URI  ,"subtract-dayTimeDuration-from-dateTime"		, XOP_NS_URI);
  xpf_define_alias ("add-dayTimeDuration-to-time"		, XOP_NS_URI  ,"add-dayTimeDuration-to-dateTime"			, XOP_NS_URI);
  xpf_define_alias ("subtract-dayTimeDuration-from-time"		, XOP_NS_URI  ,"subtract-dayTimeDuration-from-dateTime"		, XOP_NS_URI);
#else
  xop_define_builtin ("add-yearMonthDuration-to-date", xqf_add_yMD_to_dT		/* XQuery 1.0 */, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
  xop_define_builtin ("add-dayTimeDuration-to-date", xqf_add_dTD_to_dT			/* XQuery 1.0 */, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
  xop_define_builtin ("subtract-yearMonthDuration-from-date", xqf_sub_yMD_to_dT		/* XQuery 1.0 */, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
  xop_define_builtin ("subtract-dayTimeDuration-from-date", xqf_sub_dTD_to_dT		/* XQuery 1.0 */, DV_DATE	, 2	, xpfmalist(2, xpfma(NULL,DV_DATE,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
  xop_define_builtin ("add-dayTimeDuration-to-time", xqf_add_dTD_to_dT			/* XQuery 1.0 */, DV_TIME	, 2	, xpfmalist(2, xpfma(NULL,DV_TIME,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
  xop_define_builtin ("subtract-dayTimeDuration-from-time", xqf_sub_dTD_to_dT		/* XQuery 1.0 */, DV_TIME	, 2	, xpfmalist(2, xpfma(NULL,DV_TIME,1), xpfma(NULL,DV_NUMERIC,1))		, NULL);
#endif

  /* QNames */
  xop_define_builtin ("QName-equal",		xqf_qname_eq				/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(2, xpfma(NULL,DV_UNKNOWN,1), xpfma(NULL,DV_UNKNOWN,1)), NULL);

  xpf_define_builtin ("current-date", xpf_current_date						/* XQuery 1.0 */, DV_DATE	, 0	, xpfmalist(0), NULL);
  xpf_define_builtin ("current-time", xqf_current_time						/* XQuery 1.0 */, DV_TIME	, 0	, xpfmalist(0), NULL);
  xpf_define_builtin ("current-dateTime", xqf_current_dateTime					/* XQuery 1.0 */, DV_DATETIME	, 0	, xpfmalist(0), NULL);
  /*xpf_define_alias   ("deep-equal", XFN_NS_URI, "deep-equal", NULL);*/
}

