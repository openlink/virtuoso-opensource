/*
 *  runbg.c
 *
 *  $Id$
 *
 *  Runs a process in the background, similar to nohup but slightly different.
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
 */

#define IN_LIBUTIL
#include <libutil.h>

char *f_output = "runbg.out";
int f_shell;


int
main (int argc, char **argv, char **environ)
{
  RETSIGTYPE (*usr1)();
  char tempfile[60];
  char line[1024];
  char **args;
  FILE *fd;
  char *shell;
  int outfd;
  int infd;
  int pid;
  int key;
  int niceval = 0;
  int i;
#ifdef MALLOC_DEBUG
  dk_mutex_t *x = mutex_allocate();
  char *y = dk_alloc_box(1,1);
  dk_hash_t * z = hash_table_allocate(10);
#endif

  while ((key = getopt (argc, argv, "+o:n:s")) != EOF)
    {
      switch (key)
        {
	case 'o':
	  f_output = optarg;
	  break;
	case 's':
	  f_shell = 1;
	  break;
	case 'n':
	  niceval = atoi (optarg);
	  break;
	case '?':
	  fprintf (stderr, "usage: %s [-n nice] [-o filename] [-s] [command [options ..]]\n",
	      argv[0]);
	  exit (1);
	}
    }

  outfd = open (f_output, O_RDWR|O_CREAT|O_TRUNC, 0666);
  if (outfd == -1)
    {
    failed:
      fprintf (stderr, "Unable to open %s\n", f_output);
      exit (1);
    }

  shell = getenv ("SHELL");
  if (!shell)
    shell = "/bin/sh";

  i = 0;
  args = calloc (argc + 3, sizeof (char *));
  if (optind == argc)
    {
      sprintf (tempfile, "/tmp/runbg.%d", getpid ());
      if ((fd = fopen (tempfile, "w")) == NULL)
	goto failed;
      while (fgets (line, sizeof (line), stdin) != NULL)
	fputs (line, fd);
      fclose (fd);
      if ((infd = open (tempfile, O_RDONLY)) == -1)
	goto failed;
      unlink (tempfile);
      args[i++] = shell;
    }
  else
    {
      if ((infd = open ("/dev/null", O_RDONLY)) == -1)
	goto failed;
      if (f_shell)
	{
	  args[i++] = shell;
	  args[i++] = "-c";
	}
      while (optind < argc)
	args[i++] = argv[optind++];
    }
  args[i] = NULL;

  usr1 = signal (SIGUSR1, SIG_IGN);
  pid = fork ();
  switch (pid)
    {
    default:
      printf ("started %s - pid=%d\n", args[0], pid);
      return 0;
    case -1:
      fprintf (stderr, "fork() failed\n");
      close (outfd);
      unlink (f_output);
      return 1;
    case 0:
      break;
    }

  close (0);
  close (1);
  close (2);
  dup2 (infd, 0);
  dup2 (outfd, 1);
  dup2 (outfd, 2);
  close (infd);
  close (outfd);
  if (setsid () == -1)
    {
      fprintf (stderr, "setsid() failed\n");
      return 1;
    }
  if (niceval && nice (niceval) == -1)
    {
      fprintf (stderr, "nice() failed\n");
    }
  signal (SIGUSR1, usr1);
  execvp (args[0], args);
  fprintf (stderr, "Cannot execute %s", args[0]);
  exit (1);
}
