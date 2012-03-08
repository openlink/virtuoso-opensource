/*
 *  logmsg.h
 *
 *  $Id$
 *
 *  Alternate logging module
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
 *  
*/

#ifndef _LOGMSG_H
#define _LOGMSG_H

#ifdef HAVE_SYSLOG
# include <syslog.h>
#else
# define LOG_EMERG	0	/* system is unusable */
# define LOG_ALERT	1	/* action must be taken immediately */
# define LOG_CRIT	2	/* critical conditions */
# define LOG_ERR	3	/* error conditions */
# define LOG_WARNING	4	/* warning conditions */
# define LOG_NOTICE	5	/* normal but signification condition */
# define LOG_INFO	6	/* informational */
# define LOG_DEBUG	7	/* debug-level messages */


BEGIN_CPLUSPLUS

int openlog (char *ident, int options, int facility);
int syslog (int level, char *format, ...);

END_CPLUSPLUS

#endif /* HAVE_syslog */

#define MAX_LOG_LEVEL	LOG_DEBUG

typedef struct _log LOG;

typedef void (*log_emit_func) (LOG *log, int level, char *msg);
typedef void (*log_close_func) (LOG *log);

struct _log
{
  struct _log *next;
  struct _log *prev;
  int mask[MAX_LOG_LEVEL + 1];
  int style;
  int month;
  int day;
  int year;
  log_emit_func emitter;
  log_close_func closer;
  void *user_data;
};

/* log styles */
#define L_STYLE_GROUP	0x0001	/* group by date	*/
#define L_STYLE_TIME	0x0002	/* include time/date 	*/
#define L_STYLE_LEVEL	0x0004	/* include level	*/
#define L_STYLE_PROG	0x0008	/* include program name */
#define L_STYLE_LINE	0x0010	/* include file/line	*/
#define L_STYLE_ALL	(L_STYLE_GROUP|L_STYLE_TIME|L_STYLE_LEVEL|L_STYLE_PROG|L_STYLE_LINE)

/* log masks */
#define L_MASK_ALL	-1	/* all catagories	*/

/* log levels */
#define L_EMERG   LOG_EMERG,__FILE__,__LINE__	/* system is unusabled	*/
#define L_ALERT	  LOG_ALERT,__FILE__,__LINE__	/* action must be taken	*/
#define L_CRIT	  LOG_CRIT,__FILE__,__LINE__	/* critical condition	*/
#define L_ERR	  LOG_ERR,__FILE__,__LINE__	/* error condition	*/
#define L_WARNING LOG_WARNING,__FILE__,__LINE__	/* warning condition	*/
#define L_NOTICE  LOG_NOTICE,__FILE__,__LINE__	/* normal but signif	*/
#define L_INFO    LOG_INFO,__FILE__,__LINE__	/* informational	*/
#define L_DEBUG   LOG_DEBUG,__FILE__,__LINE__	/* debug-level message	*/

/* used to parse a symbolic mask list */
typedef struct
{
  char *name;
  int bit;
} LOGMASK_ALIST;

/*
  Prototypes:
*/


BEGIN_CPLUSPLUS

/*
 *  Sorry for this one, but Oracle 7 has its own mandatory olm.o wich
 *  contains log (argh)
 */
#define log	logit

int   logmsg_ap (int level, char *file, int line, int mask, char *format, va_list ap);
int   logmsg (int level, char *file, int line, int mask, char *format, ...);
int   log_error (char *format, ...);
int   log_warning (char *format, ...);
int   log_info (char *format, ...);
int   log_debug (char *format, ...);
int   log (int level, char *file, int line, char *format, ...);
int   log_set_limit (int rate);
int   log_reset_limits (void);
int   log_set_mask (LOG * logptr, int level, int mask);
int   log_set_level (LOG * logptr, int level);
LOG * log_open_syslog (char *ident, int logopt, int facility, int level,
		      int mask, int style);
LOG * log_open_fp (FILE * fp, int level, int mask, int style);
LOG * log_open_fp2 (FILE * fp, int level, int mask, int style);
LOG * log_open_callback (log_emit_func emitter, log_close_func closer,
			int level, int mask, int style);
LOG * log_open_file (char *filename, int level, int mask, int style);
int   log_close (LOG * log);
void  log_close_all (void);
int   log_parse_mask (char *mask_str, LOGMASK_ALIST * alist, int size,
		      int *maskp);
void  log_flush_all (void);

END_CPLUSPLUS

#endif
