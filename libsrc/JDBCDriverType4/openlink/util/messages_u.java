/*
 *  $Id$
 *
 *  Error messages
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
 */

/* #English locale & DEFAULT#*/

package openlink.util;

import java.util.*;

public class messages_u extends ListResourceBundle {

  public messages_u() {
  }
  static final Object[][] contents = new String[][]{

//##
//###jdbcu error messages
//##
   { "jdbcu.err.1", "Stream is closed"},
   { "jdbcu.err.2", "Invalid start position."},
   { "jdbcu.err.3", "Invalid length."},
   { "jdbcu.err.4", "Blob is freed."},

  };


  protected Object[][] getContents() {
    return contents;
  }
}
