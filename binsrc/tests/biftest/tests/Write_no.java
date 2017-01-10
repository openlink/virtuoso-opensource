/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
import java.awt.*;
import java.lang.*;
import java.security.*;

public class Write_no
{
  public void write_file_no ()
    {
      String myFile = "/tmp/foo";
      File f = new File(myFile);
      DataOutputStream dos;

      try
	{
	  dos = new DataOutputStream (new BufferedOutputStream(new FileOutputStream (myFile),128));
	  dos.writeBytes("Cats can hypnotize you when you least expect it\n");
	  dos.flush();
	  dos.close();
	}
/*    catch (SecurityException e)
	{
	  System.out.println("writeFile: caught security exception");
	}*/
      catch (IOException ioe)
	{
	  System.out.println("writeFile: caught i/o exception");
	}

    }
}
