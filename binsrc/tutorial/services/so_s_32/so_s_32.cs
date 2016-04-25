//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2016 OpenLink Software
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

public class so_s_32
{
  public string varString;
  public int varInt;
  public float varFloat;
  public string processingResult;
  public string clrVersion;

  public so_s_32 ()
    {
      varString = null;
      varInt = 0;
      varFloat = 0;
    }

  public String process_data ()
    {
      processingResult = "processing varString=[" + varString + "] varInt =" + varInt + " varFloat=" + varFloat;
      clrVersion = "CLR Version " + System.Environment.Version.ToString() + " on " + System.Environment.OSVersion;
      return processingResult;
    }
}
