/*
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

import java.io.*;
import java.util.*;
import java.lang.*;
import java.security.*;
import java.security.Permission;
import java.security.AccessController;
import java.rmi.*;

public class __virt_access_granter extends RMISecurityManager
{
  public void checkPermission(Permission perm) throws SecurityException
    {
      String loader_name;
      String clName;
      String my_loader_name;
      try
	{
	  try
	    {
	      clName = Thread.currentThread().getContextClassLoader().toString();
	    }
	  catch (Exception e)
	    {
	      super.checkPermission(perm);
	      return;
	    }

	  loader_name = clName.substring(0, clName.indexOf('@'));
	  my_loader_name = loader_name.substring(0, 19);

	}
      catch (Exception e)
	{
	  super.checkPermission(perm);
	  return;
	}

      if (!loader_name.equals ("__virt_class_loader_ur"))
	{
/*	  System.err.println("--- granted? " + clName + " " + perm.getClass().getName() + " name=\"" + perm.getName() + "\" actions=\"" + perm.getActions() + "\"");   */

	  super.checkPermission(perm);
	}
    }

  public void checkPermission(Permission perm, Object context)
    {
      checkPermission(perm);
    }

  public void set_access_granter ()
    {
      System.setSecurityManager(new __virt_access_granter());
    }
}
