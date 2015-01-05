/*
 *  $Id$
 *
 *  Implementation of the OPLMessage_x class
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
 */

package openlink.util;

import java.text.MessageFormat;
import java.sql.SQLException;

class OPLMessage_u extends openlink.util.BaseMessage {

  protected static final int erru_Stream_is_closed = 1;
  protected static final int erru_Invalid_start_position = 2;
  protected static final int erru_Invalid_length = 3;
  protected static final int erru_Blob_is_freed = 4;

  private static OPLMessage_u msg = new OPLMessage_u();

  private OPLMessage_u() {
    msgPrefix = "jdbcu.err.";
    init("openlink.util.messages_u");
  }


  protected static String getMessage(int err_id) {
    return msg.getBundle(msg.msgPrefix + err_id);
  }

  protected static String getMessage(int err_id, Object[] params) {
     return MessageFormat.format(getMessage(err_id), params);
  }


  protected static SQLException makeException (int err_id)
  {
    return new SQLException (err_Prefix + getMessage(err_id), S_GENERAL_ERR);
  }

/*******
  protected static SQLException makeExceptionV (int err_id, String p0)
  {
    Object params[] = { p0 };
    return new SQLException (err_Prefix + getMessage(err_id, params), S_GENERAL_ERR);
  }

  protected static SQLException makeExceptionV (int err_id, String p0, String p1)
  {
    Object params[] = { p0, p1 };
    return new SQLException (err_Prefix + getMessage(err_id, params), S_GENERAL_ERR);
  }
********/

}
