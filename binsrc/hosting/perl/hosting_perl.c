/*
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
 *  
*/
#include <stdio.h>
#include <EXTERN.h>
#include <perl.h>
#include <perlapi.h>
#undef _
#include <hosting.h>
#include <sqlver.h>

#ifndef MULTIPLICITY
#error  Your perl should be compiled w -Dusemultiplicity. Check the output of perl -V:usemultiplicity
#endif

#define SET_ERR(str) \
      { \
	if (err && max_len > 0) \
	  { \
	    strncpy (err, str, max_len); \
	    err[max_len] = 0; \
	  } \
      }

#ifdef DEBUG
static int
log_debug (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  fprintf (stderr, "HOSTING_PERL:");
  rc = vfprintf (stderr, format, ap);
  fprintf (stderr, "\n");
  va_end (ap);
  return rc;
}
#else
static int
log_debug (char *format, ...)
{
  return 0;
}
#endif

#include "virt_handler.c"

#if !defined (__APPLE__)
EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);
#endif

EXTERN_C void
xs_init(pTHX)
{
	char *file = __FILE__;
	dXSUB_SYS;

	/* DynaLoader is a special case */
#if !defined (__APPLE__)
	newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
#endif
}

static PerlInterpreter *
start_perl_interpreter (char *err, int max_len)
{
  PerlInterpreter *intrp;
  char *embedding[3];
#ifdef MY_ENV
  char *envp[] = {
    NULL
  };
#else
  char **envp = NULL;
#endif

  embedding[0] = "CGI";
  embedding[1] = "-e";
  embedding[2] = virt_handler;
  log_debug ("start_perl_interpreter");
  if (NULL == (intrp = perl_alloc()))
    {
      SET_ERR ("Unable to allocate perl interpreter");
      return NULL;
    }
    {
      dTHX;
      perl_construct(intrp);
      PERL_SET_CONTEXT(intrp);

      if (0 == perl_parse(intrp, xs_init, 3, embedding, envp))
	{
	  PERL_SET_CONTEXT(intrp);
	  if (0 == perl_run(intrp))
	    return intrp;
	  else
	    SET_ERR ("Unable to run the perl interpreter");
	}
      else
	SET_ERR ("Unable to parse virt_handler.pl");
#ifdef PERL_EXIT_DESTRUCT_END
      PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
#endif
      perl_destruct (intrp);
      perl_free (intrp);
    }
  return NULL;
}


static PerlInterpreter *
clone_perl_interpreter (void *parent_intrp, char *err, int max_len)
{
  PerlInterpreter *intrp = (PerlInterpreter *) parent_intrp;
  UV clone_flags = CLONEf_KEEP_PTR_TABLE;

#if defined(WIN32) && defined(CLONEf_CLONE_HOST)
  clone_flags |= CLONEf_CLONE_HOST;
#endif

  log_debug ("clone_perl_interpreter");
  PERL_SET_CONTEXT(intrp);
  return perl_clone (intrp, clone_flags);
}


static void
stop_perl_interpreter (PerlInterpreter *interp)
{
  log_debug ("stop_perl_interpreter");
  PERL_SET_CONTEXT(interp);
  perl_destruct(interp);
  perl_free (interp);
}


static void
hosting_perl_connect (void *x)
{
  log_debug ("hosting_perl_connect");
}

static hosting_version_t
hosting_perl_version = {
    {
      HOSTING_TITLE,			/*!< Title of unit, filled by unit */
      DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
      "OpenLink Software",			/*!< Plugin's developer, filled by unit */
      "Perl " PERL_VERSION_STRING " hosting plugin",			/*!< Any additional info, filled by unit */
      NULL,					/*!< Error message, filled by unit loader */
      NULL,					/*!< Name of file with unit's code, filled by unit loader */
      hosting_perl_connect,		/*!< Pointer to connection function, cannot be NULL */
      NULL,					/*!< Pointer to disconnection function, or NULL */
      NULL,					/*!< Pointer to activation function, or NULL */
      NULL,					/*!< Pointer to deactivation function, or NULL */
      NULL
    },
    NULL, NULL, NULL, NULL, NULL,
    NULL
};


#ifndef WIN32
static int
check_perl_interpreter (char *err, int max_len)
{
  int ret = 0;
  PerlInterpreter *intrp;
  char *embedding[] = { "CGI", "-e",
    "use Config;\n"
    "use DynaLoader;\n"
/*    "print STDERR 'loading ['.$Config{archlibexp}.'/CORE/'.$Config{libperl}.']\n';\n"*/
#if !defined (__APPLE__)
    "DynaLoader::dl_load_file ($Config{archlibexp}.'/CORE/'.$Config{libperl},0x01);\n"
#endif
  };
#ifdef MY_ENV
  char *envp[] = {
    NULL
  };
#else
  char **envp = NULL;
#endif
  if (NULL == (intrp = perl_alloc()))
    {
      SET_ERR ("Unable to allocate perl interpreter");
      return ret;
    }
    {
      dTHX;
      perl_construct(intrp);
      PERL_SET_CONTEXT(intrp);

      if (0 == perl_parse(intrp, xs_init, 3, embedding, envp))
	{
	  PERL_SET_CONTEXT(intrp);
	  if (0 == perl_run(intrp))
	    ret = 1;
	  else
	    {
	      SET_ERR ("Unable to run the perl interpreter");
	      ret = 0;
	    }
	}
      else
	{
	  SET_ERR ("Unable to parse virt_handler.pl");
	  ret = 0;
	}
#ifdef PERL_EXIT_DESTRUCT_END
      PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
#endif
      perl_destruct (intrp);
      perl_free (intrp);
    }
  return ret;
}
#endif


unit_version_t *
hosting_perl_check (unit_version_t *in, void *appdata)
{
  static char *args[2];
#ifndef WIN32
  char err[50];
#endif
  args[0] = "pl";
  args[1] = NULL;
  hosting_perl_version.hv_extensions = args;
  log_debug ("hosting_perl_check");
#ifndef WIN32
  /* done because dlopen doesn't add the symbols exported from hosting_perl linked libperl
     to the global apps dynamic symbol map and the perl modules shared objects won't resolve */
  if (!check_perl_interpreter (&(err[0]), sizeof (err)))
    return NULL;
#endif
  return &hosting_perl_version.hv_pversion;
}


void *
virtm_client_attach (char *err, int max_err_len)
{
  PerlInterpreter *interp = start_perl_interpreter (err, max_err_len);
  log_debug ("virtm_client_attach");
  return interp;
}


void
virtm_client_detach (void *cli)
{
  PerlInterpreter *interp = (PerlInterpreter *) cli;
  log_debug ("virtm_client_detach");
  if (interp)
    {
      PERL_SET_CONTEXT(interp);
      stop_perl_interpreter (interp);
    }
}


void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  PerlInterpreter *interp;
  log_debug ("virtm_client_clone");
  interp = clone_perl_interpreter (cli, err, max_err_len);
  return interp;
}


void
virtm_client_free (void *cli)
{
  free (cli);
}
#define DO_CLEAN 0

static SV *
virtm_make_perl_hash (pTHX_ const char **pars, int n_pars)
{
  int inx;
  HV *hv = newHV ();
  if (pars)
    {
      for (inx = 0; inx < n_pars; inx += 2)
	{
	  SV *val = sv_2mortal (newSVpv (pars[inx+1], 0));
	  hv_store (hv, pars[inx], strlen (pars[inx]), val, 0);
	}
    }
  return newRV_noinc ((SV *) hv);
}


static SV *
virtm_make_perl_array (pTHX_ const char **pars, int n_pars)
{
  int inx;
  AV *av = newAV ();
  if (pars)
    {
      for (inx = 0; inx < n_pars; inx++)
	{
	  SV *val = sv_2mortal (newSVpv (pars[inx], 0));
	  av_push (av, val);
	}
    }
  return newRV_noinc ((SV *) av);
}


char *
virtm_http_handler (void *cli, char *err, int max_len,
      const char *base_uri, const char *content,
      const char *params, const char **lines, int n_lines,
      char **head_ret, const char **options, int n_options, char **diag_ret, int compile_only)
{
  PerlInterpreter *intrp = (PerlInterpreter *) cli;
  STRLEN n_a;
  int nret;
  char *retval = NULL;
  log_debug ("virtm_http_handler");

  if (compile_only)
    return NULL;

  if (!intrp)
    {
      SET_ERR ("client not attached to the interface");
      return NULL;
    }
  PERL_SET_CONTEXT(intrp);

    {
      dTHXa(intrp);
      dSP;
      if (content)
	{
          ENTER ;
          SAVETMPS ;
	  PUSHMARK(SP) ;
          XPUSHs(base_uri ? sv_2mortal(newSVpv(base_uri, 0)) : &PL_sv_undef);
          XPUSHs(content ? sv_2mortal(newSVpv(content, 0)) : &PL_sv_undef);
          XPUSHs(sv_2mortal(newSViv(DO_CLEAN)));
          XPUSHs(sv_2mortal(newSVpv("", 0)));
          XPUSHs(options ? sv_2mortal(virtm_make_perl_hash(aTHX_ options, n_options)) : &PL_sv_undef);
          XPUSHs(params ? sv_2mortal(newSVpv(params, 0)) : &PL_sv_undef);
          XPUSHs(lines ? sv_2mortal(virtm_make_perl_array(aTHX_ lines, n_lines)) : &PL_sv_undef);
          PUTBACK ;
	  nret = call_pv("VIRT::Embed::Persistent::eval_string", G_ARRAY | G_EVAL);

	  SPAGAIN;
	}
      else
	{
          ENTER ;
          SAVETMPS ;
	  PUSHMARK(SP) ;
          XPUSHs(base_uri ? sv_2mortal(newSVpv(base_uri, strlen (base_uri))) : &PL_sv_undef);
          XPUSHs(sv_2mortal(newSViv(DO_CLEAN)));
          XPUSHs(options ? sv_2mortal(virtm_make_perl_hash(aTHX_ options, n_options)) : &PL_sv_undef);
          XPUSHs(params ? sv_2mortal(newSVpv(params, 0)) : &PL_sv_undef);
          XPUSHs(lines ? sv_2mortal(virtm_make_perl_array(aTHX_ lines, n_lines)) : &PL_sv_undef);
          PUTBACK ;
	  nret = call_pv("VIRT::Embed::Persistent::eval_file", G_ARRAY | G_EVAL);

	  SPAGAIN;
	}

      if(SvTRUE(ERRSV))
      {
	sprintf(err, "%.*s\n", max_len, SvPV(ERRSV,n_a));
	SPAGAIN;
	retval = NULL;
      }
      else
      {

	SPAGAIN;
	      if (nret == 3)
	      {
		      char * ptr;

#define virtPOPpx (SvPVx(POPs, n_a))
		      ptr = virtPOPpx;
		      *diag_ret = malloc (n_a + 1);
		      strncpy (*diag_ret, ptr, n_a);
		      (*diag_ret)[n_a] = 0;

		      ptr = virtPOPpx;
		      *head_ret = malloc (n_a + 1);
		      strncpy (*head_ret, ptr, n_a);
		      (*head_ret)[n_a] = 0;

		      ptr = virtPOPpx;
		      retval = malloc (n_a + 1);
		      strncpy (retval, ptr, n_a);
		      retval[n_a] = 0;
	      }
      }
      PUTBACK;
      FREETMPS ;
      LEAVE ;
    }

  return retval;
}
