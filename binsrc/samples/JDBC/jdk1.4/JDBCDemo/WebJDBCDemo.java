/*
 *  WebJDBCDemo.java
 *
 *  $Id$
 *
 *  Sample JDBC program
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
 *  
*/

import java.awt.*;
import java.applet.*;

public class WebJDBCDemo extends Applet
{

  public void init()
  {
    super.init();
    String theServer = getCodeBase().getHost();
    String sNumParams = getParameter("numParams");
    int numParams = 0;
    String[] params;
    if (sNumParams != null)
      numParams = Integer.parseInt(sNumParams);
    System.out.println("numParams = "+numParams);
    params = new String[numParams];
    for (int i = 0; i < numParams; i++)
    {
      params[i] = "jdbc:virtuoso://"+theServer+getParameter("URL"+Integer.toString(i+1));
      System.out.println("Param"+i+" = "+params[i]);
    }
    JDBCDemo jd = new JDBCDemo(params,true);
    jd.show();
  }
}


