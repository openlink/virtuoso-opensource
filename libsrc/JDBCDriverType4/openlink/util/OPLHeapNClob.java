/*
 *  OPLHeapNClob.java
 *
 *  $Id$
 *
 *  Implementation of the JDBC Clob class
 *
 *  (C)Copyright 2008 OpenLink Software.
 *  All Rights Reserved.
 *
 *  The copyright above and this notice must be preserved in all
 *  copies of this source code.  The copyright above does not
 *  evidence any actual or intended publication of this source code.
 *
 *  This is unpublished proprietary trade secret of OpenLink Software.
 *  This source code may not be copied, disclosed, distributed, demonstrated
 *  or licensed except as authorized by OpenLink Software.
 */
package openlink.util;

import java.sql.Clob;
import java.sql.NClob;
import java.io.*;
import java.sql.SQLException;

public class OPLHeapNClob extends OPLHeapClob implements NClob, Serializable {

  public OPLHeapNClob() {
    super();
  }

  public OPLHeapNClob(String b) {
    super(b);
  }

  public OPLHeapNClob(char[] b) {
    super(b);
  }

  public OPLHeapNClob(Reader is) throws SQLException {
    super(is);
  }


}
