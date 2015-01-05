/*
 *  BrowserCheck.java
 *
 *  $Id$
 *
 *  Check the version of JVM in the browser
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
 *  
*/

import java.awt.*;
import java.applet.*;
import java.net.URL;

public class BrowserCheck extends Applet {

  public void init() {
    super.init();
    String jdkVersion  = (System.getProperty("java.version")).substring(0,3);
    String fileLocation = getDocumentBase().toString();
    String demoLocation = fileLocation;
    String targetFile = getParameter("targetFile");
    if (targetFile == null)
      targetFile = "index.htm";
    if(fileLocation.endsWith("index.htm"))
      {
        demoLocation = fileLocation.substring(0,fileLocation.indexOf("index.htm"));
      }
    if(fileLocation.endsWith("index"))
      {
        demoLocation = fileLocation.substring(0,fileLocation.indexOf("index"));
      }
    showStatus("Fetching JDK"+jdkVersion+" applet demos");
    try
      {
	URL url = new URL(demoLocation+"jdk"+jdkVersion+"/"+targetFile);
	getAppletContext().showDocument(url, "_self");
      }
    catch (Exception e)
      {
	showStatus("Unable to show document : "+e);
      }
  }
}
