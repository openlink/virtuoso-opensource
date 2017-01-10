//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2017 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
using System;
using System.IO;

public class UnRest 
{
   public static int IntegerTest ()
    {
      return 1;
    }
  
   public static int FileAccessTest (String file_name)
    {
      FileInfo fi = new FileInfo (file_name);
      FileStream fs = fi.OpenRead ();
      Console.WriteLine (fi.Length);
      Byte [] bt = new byte [fi.Length];
      return fs.Read (bt, 0, (int) fi.Length);
    }

   public static int GetEnvTest ()
    {
      return Environment.GetEnvironmentVariable("PATH").Length;
    }
}

