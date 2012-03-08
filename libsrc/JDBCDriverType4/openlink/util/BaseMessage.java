/*
 *  $Id$
 *
 *  Implementation of the BaseMessage class
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
 */

package openlink.util;

import java.util.MissingResourceException;
import java.util.ResourceBundle;
import java.sql.SQLException;

abstract public class BaseMessage {

  public static final String RESBUNDLE_NOTFOUND = "HY000:Could not found resource file '";
  public static final String NO_MESSAGE = "HY000:Can not retrieve message for code : ";
  public static final String S_GENERAL_ERR = "HY000";
  protected ResourceBundle rb;
  protected String defaultMessage;
  protected String msgPrefix;

#if JDK_VER >= 16
    public static final String err_Prefix = "[OpenLink][OPLJDBC4]";
#elif JDK_VER >= 14
    public static final String err_Prefix = "[OpenLink][OPLJDBC3]";
#elif JDK_VER >= 12
    public static final String err_Prefix = "[OpenLink][OPLJDBC2]";
#else
    public static final String err_Prefix = "[OpenLink][OPLJDBC]";
#endif

  protected void init(String resourceFile) {
    defaultMessage = RESBUNDLE_NOTFOUND + (resourceFile != null ? resourceFile : "null") + "'";
    if (resourceFile == null)
      return;
    try {
        rb = ResourceBundle.getBundle(resourceFile);
    } catch(MissingResourceException e) { }
      catch(ClassFormatError e) { }
  }

  protected String getBundle(String s) {
    if (rb != null)
      try {
        return rb.getString(s);
      } catch (MissingResourceException e) {
        return NO_MESSAGE + s;
      } catch (ClassFormatError e) {
        return NO_MESSAGE + s;
      }
    return defaultMessage;
  }


  public static SQLException makeException (Exception e)
  {
    return new SQLException(err_Prefix + "Error :" + e.toString(), S_GENERAL_ERR);
  }
}
