/*
 *  SavepointWrapper.java
 *
 *  $Id$
 *
 *  Wrapper for the JDBC Savepoint class
 *
 *  (C)Copyright 2004 OpenLink Software.
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

package virtuoso.jdbc2;

import java.sql.Savepoint;
import java.sql.SQLException;

public class SavepointWrapper implements Savepoint {

  private Savepoint wsp;
  private ConnectionWrapper wconn;

  protected SavepointWrapper(Savepoint _sp, ConnectionWrapper _wconn) {
    wsp = _sp;
    wconn = _wconn;
  }


  private void exceptionOccurred(SQLException sqlEx) {
    if (wconn != null)
      wconn.exceptionOccurred(sqlEx);
  }


  public int getSavepointId() throws java.sql.SQLException {
    try {
      return wsp.getSavepointId();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public String getSavepointName() throws java.sql.SQLException {
    try {
      return wsp.getSavepointName();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

}
