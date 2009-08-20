/*
 *  Closeable.java
 *
 *  $Id$
 *
 *
 *
 *  (C)Copyright 2002 OpenLink Software.
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

public interface Closeable {

  public abstract void close() throws java.sql.SQLException;
}
