/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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
public class so_s_30
{
  public String varString;
  public int varInt;
  public float varFloat;
  public String processingResult;
  public String javavmVersion;

  public so_s_30 ()
    {
      varString = null;
      varInt = 0;
      varFloat = 0;
    }

  public String process_data ()
    {
      System.err.println ("processing varString=[" + varString + "] varInt =" + varInt + " varFloat=" + varFloat);
      processingResult = "processing varString=[" + varString + "] varInt =" + varInt + " varFloat=" + varFloat;
      javavmVersion = System.getProperty ("java.vm.name") + " ver. " + System.getProperty ("java.vm.version");
      return processingResult;
    }
}
