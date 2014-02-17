/*
 *  $Id$
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
 */

package virtuoso.javax;

import java.io.*;
import java.math.BigDecimal;
import java.util.Calendar;
import java.util.LinkedList;
import java.util.HashMap;
import java.util.Map;
import java.util.BitSet;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Collection;
import java.net.URL;
import java.sql.*;
import javax.sql.*;
import javax.naming.*;
import openlink.util.OPLHeapBlob;
import openlink.util.OPLHeapClob;
#if JDK_VER >= 16
import openlink.util.OPLHeapNClob;
#endif

/**
 *
 * <P>A OPLCachedRowSet is a disconnected, serializable, scrollable container
 * for tabular data.  A primary purpose of the OPLCachedRowSet class is to
 * provide a representation of a JDBC ResultSet that can be passed
 * between different components of a remote application.  For example, a
 * OPLCachedRowSet can be used to send the result of a query executed by
 * an Enterprise JavaBeans component running in a server environment over
 * a network to a client running in a web browser.  A second use for
 * OPLCachedRowSets is to provide scrolling and updating for ResultSets that
 * don't provide these capabilities themselves.  A OPLCachedRowSet can be
 * used to augment the capabilities of a JDBC driver that doesn't have
 * full support for scrolling and updating.  Finally, a OPLCachedRowSet can
 * be used to provide Java applications with access to tabular data in an
 * environment such as a thin client or PDA, where it would be
 * inappropriate to use a JDBC driver due to resource limitations or
 * security considerations.  The OPLCachedRowSet class provides a means to
 * "get rows in" and "get changed rows out" without the need to implement
 * the full JDBC API.
 *
 * <P>A OPLCachedRowSet object can contain data retrieved via a JDBC driver or
 * data from some other source, such as a spreadsheet.  Both a
 * OPLCachedRowSet object and its metadata can be created from scratch.  A
 * component that acts as a factory for rowsets can use this capability
 * to create a rowset containing data from non-JDBC data sources.
 *
 * <P>The term 'disconnected' implies that a OPLCachedRowSet only makes use of
 * a JDBC connection briefly while data is being read from the database
 * and used to populate it with rows, and again while updated rows are being
 * propagated back to the underlying database.  During the remainder of
 * its lifetime, a OPLCachedRowSet object isn't associated with an
 * underlying database connection. A OPLCachedRowSet object can simply be
 * thought of as a disconnected set of rows that are being cached outside
 * of a data source.  Since all data is cached in memory, OPLCachedRowSets are
 * not appropriate for extremely large data sets.
 *
 * <P>The contents of a OPLCachedRowSet may be updated and the updates can be
 * propagated to an underlying data source.  OPLCachedRowSets support an
 * optimistic concurrency control mechanism - no locks are maintained in
 * the underlying database during disconnected use of the rowset. Both the
 * original value and current value of the OPLCachedRowSet are maintained
 * for use by the optimistic routines.
 *
 */
public class OPLCachedRowSet extends BaseRowSet
        implements RowSetInternal, Serializable, Cloneable {

    private static final long serialVersionUID = -8262862611500365291L;

    private static final int BEFOREFIRST    = 0;
    private static final int FIRSTROW	    = 1;
    private static final int BODYROW	    = 2;
    private static final int LASTROW	    = 3;
    private static final int AFTERLAST	    = 4;
    private static final int NOROWS	    = 5;

    private RowSetReader rowSetReader;
    private RowSetWriter rowSetWriter;
    private transient Connection conn;
    private RowSetMetaData rowSMD;
    private int keyCols[];
    private String tableName;
#if JDK_VER >= 16
    private ArrayList<Object> rowsData;
#else
    private ArrayList rowsData;
#endif
    private int curState = NOROWS;
    private int curRow;
    private int absolutePos;
    private int countDeleted;
    private int countRows;
    private Row updateRow;
    private boolean onInsertRow;
    private boolean showDeleted;
    private InputStream objInputStream = null;
    private Reader      objReader      = null;
    private boolean _wasNull = false;

  /**
   * Create a OPLCachedRowSet object.  The object has no metadata.
   *
   * @exception SQLException if an error occurs.
   */
  public OPLCachedRowSet() throws SQLException {
    rowSetReader = new RowSetReader();
    rowSetWriter = new RowSetWriter();
#if JDK_VER >= 16
    rowsData = new ArrayList<Object>();
#else
    rowsData = new ArrayList();
#endif
    onInsertRow = false;
    updateRow = null;
    setType(ResultSet.TYPE_SCROLL_INSENSITIVE);
    setConcurrency(ResultSet.CONCUR_READ_ONLY);
    showDeleted = false;
    curRow = -1;
    absolutePos = 0;
  }

  protected Object clone() throws CloneNotSupportedException {
    return super.clone();
  }

  public synchronized void finalize () throws Throwable
  {
    close();
  }

  /**
   * Sets this OPLCachedRowSet object's command property to the given
   * String object and clears the parameters, if any, that were set
   * for the previous command.
   *
   * @param cmd - a String object containing an SQL query that will be
   * set as the command
   *
   * @exception SQLException - if an error occurs
   */
  public synchronized void setCommand(String cmd) throws SQLException {
    tableName = null;
    keyCols = null;
    super.setCommand(cmd);
  }

  /**
   * Sets the concurrency for this rowset to the specified concurrency.
   * The default concurrency is ResultSet.CONCUR_UPDATABLE.
   * @param concurrency - one of the following constants: ResultSet.CONCUR_READ_ONLY
   *   or ResultSet.CONCUR_UPDATABLE
   * @exception SQLException - if an error occurs
   */
  public synchronized void setConcurrency(int concurrency) throws SQLException {
    if (tableName == null && concurrency == ResultSet.CONCUR_UPDATABLE)
      throw OPLMessage_x.makeException(OPLMessage_x.errx_The_name_of_table_is_not_defined);
    super.setConcurrency(concurrency);
  }

  /**
   * Propagate all row update, insert, and delete changes to a data source.
   *
   * An SQLException is thrown if any of the updates cannot be
   * propagated. If acceptChanges() fails then the caller can assume that
   * none of the updates are reflected in the data source.  The current row
   * is set to the first "updated" row that resulted in an exception, in
   * the case that an exception is thrown.  With one exception, if the row
   * that caused the exception is a "deleted" row, then in the usual case,
   * when deleted rows are not shown, the current row isn't affected.
   *
   * When successful, calling acceptChanges() replaces the original value
   * of the rowset with the current value.  Note: Both the original and
   * current value of the rowset are maintained.  The original state is the
   * value of the rowset following its creation (i.e. empty), or following
   * the last call to acceptChanges(), execute(), populate(), release(), or
   * restoreOriginal().
   *
   * Internally, a RowSetWriter component is envoked to write the data for
   * each row.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void acceptChanges() throws SQLException {
    check_InsertMode("'acceptChanges()'");
    if (rowSetWriter == null)
      throw OPLMessage_x.makeException(OPLMessage_x.errx_RowSetWriter_is_not_defined);
    int _curRow = curRow;
    int _absolutePos = absolutePos;
    int _curState = curState;
    boolean success = true;
    SQLException ex = null;
    try {
      success = rowSetWriter.writeData(this);
    } catch (SQLException e) {
      ex = e;
    } finally {
      curRow = _curRow;
      absolutePos = _absolutePos;
      curState = _curState;
    }
    if (success) {
      setOriginal();
    } else {
      if (ex == null)
         throw OPLMessage_x.makeException(OPLMessage_x.errx_acceptChanges_Failed);
      else
         throw ex;
    }
  }

  /**
   * Like acceptChanges() above, but takes a Connection argument.  The
   * Connection is used internally when doing the updates.  This form
   * isn't used unless the underlying data source is a JDBC data source.
   *
   * @param _conn a database connection
   *
   * @exception SQLException if an error occurs.
   */
  public void acceptChanges(Connection _conn) throws SQLException {
    conn = _conn;
    acceptChanges();
  }


  /**
   * Populates this OPLCachedRowSet object with data. This form of the method uses
   * the rowset's user, password, and url or data source name properties to
   * create a database connection. If properties that are needed have not been set,
   * this method will throw an exception. Another form of this method uses an
   * existing JDBC Connection object instead of creating a new one;
   * therefore, it ignores the properties used for establishing a new connection.
   * The query specified by the command property is executed to create
   * a ResultSet object from which to retrieve data.
   * The current contents of the rowset are discarded, and the rowset's
   * metadata is also (re)set. If there are outstanding updates, they are also ignored.
   * The method execute closes any database connections that it creates.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void execute() throws java.sql.SQLException {
    rowSetReader.readData(this);
    if (tableName == null) {
      Scanner scan = new Scanner(getCommand());
      tableName = scan.check_Select();
      if (tableName == null)
        setConcurrency(ResultSet.CONCUR_READ_ONLY);
      else
        setConcurrency(ResultSet.CONCUR_UPDATABLE);
    }
  }

  /**
   * Populates the rowset with data.  The first form uses the properties:
   * url/data source name, user, and password to create a database
   * connection.  If these properties haven't been set, an exception is
   * thrown.  The second form uses an existing JDBC connection object
   * instead.  The values of the url/data source name, user, and password
   * properties are ignored when the second form is used.  Execute() closes
   * any database connections that it creates.
   *
   * The command specified by the command property is executed to retrieve
   * the data.  The current contents of the rowset are discarded and the
   * rowset's metadata is also (re)set.  If there are outstanding updates,
   * they are also ignored.
   *
   * @param _conn a database connection
   *
   * @exception SQLException if an error occurs.
   */
  public void execute(Connection _conn) throws SQLException {
    conn = _conn;
    execute();
  }


  /**
   * Populate the OPLCachedRowSet object with data from a ResultSet.  This
   * method is an alternative to execute() for filling the rowset with
   * data.  Populate() doesn't require that the properties needed by
   * execute(), such as the command property, be set. A RowSetChangedEvent
   * is sent to all registered listeners prior to returning.
   *
   * @param rs the data to be read
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void populate(ResultSet rs) throws SQLException {
    check_InsertMode("'populate((...)'");

    tableName = null;
    keyCols = null;

#if JDK_VER >= 16
    Map<String,Class<?>> map = getTypeMap();
#else
    Map map = getTypeMap();
#endif
    ResultSetMetaData rsmd = rs.getMetaData();
    int colCount = rsmd.getColumnCount();
    int i;
    for(i = 0; rs.next(); i++) {
      Row row = new Row(colCount);
      for (int j = 1; j <= colCount; j++) {
        Object x;

        if (map == null)
          x = rs.getObject(j);
        else
          x = rs.getObject(j, map);

        if (x instanceof Blob)
          x = new OPLHeapBlob(((Blob)x).getBytes(0L, (int)((Blob)x).length()));
        else
        if  (x instanceof Clob)
          x = new OPLHeapClob(((Clob)x).getSubString(0L, (int)((Clob)x).length()));
#if JDK_VER >= 16
        else
        if  (x instanceof NClob)
          x = new OPLHeapNClob(((NClob)x).getSubString(0L, (int)((NClob)x).length()));
#endif
        row.setOrigColData(j, x);
      }
      rowsData.add(row);
    }
    countRows = i;
    if (countRows > 0)
      curState = BEFOREFIRST;
    else
      curState = NOROWS;
    curRow = -1;
    absolutePos = 0;
    rowSMD = new OPLRowSetMetaData(rsmd);
    notifyListener(ev_RowSetChanged);
  }


  /**
   * Set the show deleted property.
   * @param value true if deleted rows should be shown, false otherwise
   * @exception SQLException if an error occurs.
   */
  public synchronized void setShowDeleted(boolean value) throws SQLException {
    check_InsertMode("'setShowDeleted(...)'");
    if (showDeleted && !value && rowDeleted()) {
      showDeleted = value;
      switch(curState) {
        case FIRSTROW:
          _first();
          notifyListener(ev_RowChanged);
          break;
        case BODYROW:
          int _absPos = absolutePos;
          _next();
          absolutePos = _absPos;
          notifyListener(ev_RowChanged);
          break;
        case LASTROW:
          _last();
          notifyListener(ev_RowChanged);
          break;
      }
    } else {
      //recalc absolutePos
      showDeleted = value;
      switch(curState) {
        case FIRSTROW:
        case LASTROW:
        case BODYROW:
          if (curRow < countRows / 2) {
              int _row = curRow;
             _beforeFirst();
             while(_next() && _row != curRow) ;
          } else {
              int _row = curRow;
             _afterLast();
             while(_previous() && _row != curRow) ;
          }
          break;
        case BEFOREFIRST:
          _beforeFirst();
          break;
        case AFTERLAST:
          _afterLast();
          break;
      }
    }
  }

  /**
   * This property determines whether or not rows marked for deletion
   * appear in the set of current rows.  The default value is false.
   * @return true if deleted rows are visible, false otherwise
   * @exception SQLException if an error occurs.
   */
  public boolean getShowDeleted() throws SQLException {
    return showDeleted;
  }

  /**
   * Returns an identifier for the object (table) that was used to create this rowset.
   * @return a String object that identifies the table from which this
   *   OPLCachedRowSet object was derived
   * @exception SQLException if an error occurs.
   */
  public String getTableName() throws SQLException {
    return tableName;
  }

  /**
   * Sets the identifier for the table from which this rowset was derived
   * to the given table name.
   *
   * Note: You don't usually need to set a table name, because the OPLCachedRowSet tries
   * to determine the table name from your SQL query command.
   *
   * @param _tabName - a String object that identifies the table from which
   * this OPLCachedRowSet object was derived
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void setTableName(String _tableName) throws SQLException {
    tableName = _tableName;
  }

  /**
   * Returns the columns that make a key to uniquely identify a row in this
   *   OPLCachedRowSet object.
   * @return an array of column numbers that constitute a key for this rowset
   * @exception SQLException if an error occurs.
   */
  public int[] getKeyCols() throws SQLException {
    return keyCols;
  }

  /**
   * Sets this OPLCachedRowSet object's keyCols field with the given array of column numbers,
   * which forms a key for uniquely identifying a row in this rowset.
   *
   * Note: If you don't set the keyCols, the OPLCachedRowSet will set automatically
   * based on RowSetMetaData
   *
   * @param keys - an array of int indicating the columns that form a key for
   * this OPLCachedRowSet object; every element in the array must be greater
   * than 0 and less than or equal to the number of columns in this rowset
   *
   * @exception SQLException if an error occurs.
   */
  public void setKeyColumns(int[] keys) throws SQLException {
     int colsCount = (rowSMD != null ? rowSMD.getColumnCount() : 0);

     for (int i = 0; i < keys.length; i++) {
       if (keys[i] < 1 || keys[i] > colsCount)
          throw OPLMessage_x.makeException(OPLMessage_x.errx_Column_Index_out_of_range);
     }

     if (keys.length > colsCount)
         throw OPLMessage_x.makeException(OPLMessage_x.errx_Invalid_key_columns);

    keyCols = new int[keys.length];
    System.arraycopy(keys, 0, keyCols, 0, keys.length);
  }

  /**
   * Cancels deletion of the current row and notifies listeners that a row
   * has changed.  After calling cancelRowDelete()
   * the current row is no longer marked for deletion.  An exception is
   * thrown if there is no current row.  Note:  This method can be
   * ignored if deleted rows aren't being shown (the normal case).
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void cancelRowDelete() throws SQLException {
    if (!showDeleted)
       return;

    check_pos("'cancelRowDelete()'");
    check_InsertMode("'cancelRowDelete()'");

    Row row = (Row)getCurRow();
    if (row.isDeleted) {
       row.isDeleted = false;
       countDeleted--;
       notifyListener(this.ev_RowChanged);
    }
  }

  /**
   * Cancels insertion of the current row and notifies listeners that a row
   * has changed.  An exception is thrown if
   * the row isn't an inserted row.  The current row is immediately removed
   * from the rowset.  This operation cannot be undone.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void cancelRowInsert() throws SQLException {
    check_pos("'cancelRowInsert()'");
    check_InsertMode("'cancelRowInsert()'");
    Row row = (Row)getCurRow();
    if (row.isInserted) {
       rowsData.remove(curRow);
       notifyListener(ev_RowChanged);
       countRows--;
       if (countRows == 0) {
          curState = NOROWS;
          curRow = -1;
          absolutePos = 0;
       }
       switch(curState) {
         case FIRSTROW:
            _first();
            break;
         case LASTROW:
            _last();
            break;
         case BODYROW:
            //check, if next exists
            if (curRow == countRows - 1) {
              curState = LASTROW;
            } else {
              boolean found = false;
              int i = curRow;
              while (!found) {
                i++;
                if (i < countRows)
                  found = true;
                else
                  break;
                if (!showDeleted && ((Row)rowsData.get(i)).isDeleted)
                 found = false;
              }
              if (!found)
                curState = LASTROW;
            }
            break;
       }
    } else {
       throw OPLMessage_x.makeException(OPLMessage_x.errx_Illegal_operation_on_non_inserted_row);
    }
  }

  /**
   * The cancelRowUpdates() method may be called after calling an
   * updateXXX() method(s) and before calling updateRow() to rollback
   * the updates made to a row.  If no updates have been made or
   * updateRow() has already been called, then this method has no
   * effect. It notifies listeners that a row has changed, if it has effect.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void cancelRowUpdates() throws SQLException {
    check_pos("'cancelRowUpdates()'");
    cancelUpdates();
    Row row = (Row)getCurRow();
    if (row.isUpdated) {
       row.clearUpdated();
       notifyListener(ev_RowChanged);
    }

  }


  /**
   * Determine if the column from the current row has been updated.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return true if the column has been updated
   * @exception SQLException if a database-access error occurs
   */
  public synchronized boolean columnUpdated(int columnIndex) throws SQLException {
    check_pos("'columnUpdated(...)'");
    check_InsertMode("'columnUpdated(...)'");
    return ((Row)getCurRow()).isColUpdated(columnIndex);
  }

  /**
   * Marks all rows in this rowset as being original rows. Any updates made
   * to the rows become the original values for the rowset.
   * Calls to the method setOriginal cannot be reversed.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void setOriginal() throws SQLException {
    if (countRows == 0)
      return;
    for(Iterator i = rowsData.iterator(); i.hasNext(); ) {
      Row row = (Row)i.next();
      if (row.isDeleted) {
        i.remove();
        countRows--;
      } else {
        row.moveCurToOrig();
      }
    }
    countDeleted = 0;
    curState = BEFOREFIRST;
    curRow = -1;
    absolutePos = 0;
    _wasNull = false;
    notifyListener(ev_RowSetChanged);
  }

  /**
   * Marks the current row in this rowset as being an original row.
   * The row is no longer marked as inserted, deleted, or updated,
   * and its values become the original values.
   * A call to setOriginalRow cannot be reversed.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void setOriginalRow() throws SQLException {
    if (countRows == 0)
      return;
    check_InsertMode("'setOriginalRow()'");
    check_pos("'setOriginalRow()'");
    Row row = (Row)getCurRow();
      if (row.isDeleted) {
        rowsData.remove(curRow);
        countRows--;
        countDeleted--;
        _next();
      } else {
        row.moveCurToOrig();
      }
    notifyListener(ev_RowChanged);
  }

  /**
   * Restores the rowset to its original state ( the original value
   * of the rowset becomes the current value).  All updates, inserts, and
   * deletes made to the original state are lost.  The cursor is positioned
   * before the first row.  A RowSetChangedEvent is sent to all registered
   * listeners prior to returning.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void restoreOriginal() throws SQLException {
    closeInputStream();
    cancelUpdates();
    if (countRows == 0)
      return;
    for(Iterator i = rowsData.iterator(); i.hasNext(); ) {
       Row row = (Row)i.next();
       if (row.isInserted) {
           i.remove();
           countRows--;
       } else {
          if (row.isDeleted)
             row.isDeleted = false;
          if (row.isUpdated)
             row.clearUpdated();
       }
    }
    curRow = -1;
    absolutePos = 0;
    curState = BEFOREFIRST;
    _wasNull = false;
    notifyListener(ev_RowSetChanged);
  }

  /**
   * Returns the number of rows in this OPLCachedRowSet object.
   */
  public int size() {
    return countRows;
  }

  /**
   * Convert the rowset to a collection of tables.  Each tables represents
   * a row of the original rowset.  The tables are keyed by column number.
   * A copy of the rowset's contents is made.
   *
   * @return a collection object
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized Collection toCollection() throws SQLException {
    int count = countRows - countDeleted;
    if (count == 0)
      return null;
#if JDK_VER >= 16
    ArrayList<Object> tmpRowset = new ArrayList<Object>(count);
#else
    ArrayList tmpRowset = new ArrayList(count);
#endif
    int colCount = rowSMD.getColumnCount();
    for(Iterator i = rowsData.iterator(); i.hasNext(); ) {
      Row row = (Row)i.next();
      if (!row.isDeleted) {
#if JDK_VER >= 16
        ArrayList<Object> tmpCol = new ArrayList<Object>(colCount);
#else
        ArrayList tmpCol = new ArrayList(colCount);
#endif
        for(int j = 1; j <= colCount; j++)
          tmpCol.add(row.getColData(j));
        tmpRowset.add(tmpCol);
      }
    }
    return tmpRowset;
  }

  /**
   * Return a column of the rowset as a collection.  Makes a copy of the
   * column's data.
   *
   * @return a collection object
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized Collection toCollection(int col)  throws SQLException {
    int count = countRows - countDeleted;
    if (count == 0)
      return null;
#if JDK_VER >= 16
    ArrayList<Object> tmpRowset = new ArrayList<Object>(count);
#else
    ArrayList tmpRowset = new ArrayList(count);
#endif
    checkColumnIndex(col);
    for(Iterator i = rowsData.iterator(); i.hasNext(); ) {
      Row row = (Row)i.next();
      if (!row.isDeleted)
        tmpRowset.add(row.getColData(col));
    }
    return tmpRowset;
  }

  /**
   * Releases the current contents of the rowset.  Outstanding updates are
   * discarded.  The rowset contains no rows after release is called.
   * A RowSetChangedEvent is sent to all registered listeners prior
   * to returning.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void release() throws SQLException {
    closeInputStream();
    cancelUpdates();
    rowsData.clear();
    curState = NOROWS;
    onInsertRow = false;
    updateRow = null;
    showDeleted = false;
    curRow = -1;
    absolutePos = 0;
    countRows = 0;
    countDeleted = 0;
    notifyListener(ev_RowSetChanged);
  }



  /**
   * Creates a RowSet object that is a deep copy of this OPLCachedRowSet object's data.
   * Updates made on a copy are not visible to the original rowset;
   * a copy of a rowset is completely independent from the original.
   * Making a copy saves the cost of creating an identical rowset from
   * first principles, which can be quite expensive.
   * For example, it doesn't do the query to a remote database server.
   *
   * @return a copy of the rowset
   * @exception SQLException if an error occurs.
   */
  public RowSet createCopy() throws SQLException {
    try {
      ByteArrayOutputStream os = new ByteArrayOutputStream();
      ObjectOutputStream obj_os = new ObjectOutputStream(os);
      obj_os.writeObject(this);
      ObjectInputStream obj_in = new ObjectInputStream(new ByteArrayInputStream(os.toByteArray()));
      return (RowSet)obj_in.readObject();
    } catch(Exception e) {
       throw new SQLException("createCopy failed: " + e.getMessage());
    }
  }

  /**
   * Returns a new rowset object backed by the same data.  Updates
   * made by a shared duplicate are visible to the original rowset and other
   * duplicates.  A rowset and its duplicates form a set of cursors
   * that iterate over a shared set of rows, providing different views
   * of the underlying data.
   * Duplicates also share property values. So, for example, if a rowset
   * is read-only then all of its duplicates will be read-only.
   *
   * @return a shared rowset object
   *
   * @exception SQLException if an error occurs.
   */
  public RowSet createShared() throws SQLException {
    RowSet rowset;
    try {
      rowset = (RowSet)clone();
    } catch(CloneNotSupportedException e) {
       throw OPLMessage_x.makeException(e);
    }
    return rowset;
  }


////// RowSetInternal  interface //////////
  /**
   * Set the rowset's metadata.
   * @param md a metadata object
   * @exception SQLException if a database-access error occurs.
   */
  public void setMetaData(RowSetMetaData md) throws SQLException {
    rowSMD = md;
  }

  /**
   * Get the Connection passed to the rowset.
   * @return the Connection passed to the rowset, or null if none
   * @exception SQLException if a database-access error occurs.
   */
  public Connection getConnection() throws SQLException {
    return conn;
  }

  /**
   * Returns a result set containing the original value of the rowset.
   * The cursor is positioned before the first row in the result set.
   * Only rows contained in the result set returned by getOriginal()
   * are said to have an original value.
   *
   * @return the original value of the rowset
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized ResultSet getOriginal() throws SQLException {
    OPLCachedRowSet crs = new OPLCachedRowSet();
    crs.rowSMD = rowSMD;
    crs.countRows = countRows;
    crs.curRow = -1;
    crs.rowSetReader = null;
    crs.rowSetWriter = null;
    crs.curState = BEFOREFIRST;
    crs._wasNull = false;
    for(Iterator i = rowsData.iterator(); i.hasNext(); ) {
      crs.rowsData.add( new Row( ((Row)i.next()).getOrigData() ) );
    }
    return crs;
  }

  /**
   * Returns a result set containing the original value of the current
   * row only.  If the current row has no original value an empty result set
   * is returned. If there is no current row an exception is thrown.
   *
   * @return the original value of the row
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized ResultSet getOriginalRow() throws SQLException {
    OPLCachedRowSet crs = new OPLCachedRowSet();
    crs.rowSMD = rowSMD;
    crs.countRows = 1;
    crs.rowSetReader = null;
    crs.rowSetWriter = null;
    crs.curState = BEFOREFIRST;
    crs._wasNull = false;
    crs.rowsData.add( new Row( getCurRow().getOrigData() ) );
    return crs;
  }


///////////// ResultSet interface /////////////
  /**
   * Releases the current contents of this rowset, discarding outstanding updates.
   * The rowset contains no rows after the method release is called.
   * This method sends a RowSetChangedEvent object to all registered listeners
   * prior to returning.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void close() throws SQLException {
    release();
    super.close();
    conn = null;
  }

  /**
   * A ResultSet is initially positioned before its first row; the
   * first call to next makes the first row the current row; the
   * second call makes the second row the current row, etc.
   *
   * <P>If an input stream from the previous row is open, it is
   * implicitly closed. The ResultSet's warning chain is cleared
   * when a new row is read.
   *
   * @return true if the new current row is valid; false if there
   *   are no more rows
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean next() throws SQLException {
    check_move("'next()'", true);
    closeInputStream();
    cancelUpdates();
    boolean ret = _next();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the previous row in the rowset.
   *
   * <p>Note: previous() is not the same as relative(-1) since it
   * makes sense to call previous() when there is no current row.
   *
   * @return true if on a valid row, false if off the rowset.
   * @exception SQLException if a database-access error occurs, or
   * rowset type is TYPE_FORWAR_DONLY.
   */
  public synchronized boolean previous() throws SQLException {
    check_move("'previous()'", false);
    closeInputStream();
    cancelUpdates();
    boolean ret = _previous();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the first row in the rowset.
   * It notifies listeners that the cursor has moved.
   *
   * @return true if on a valid row, false if no rows in the rowset.
   * @exception SQLException if a database-access error occurs, or
   * rowset type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean first() throws SQLException {
    check_move("'first()'", false);
    closeInputStream();
    cancelUpdates();
    boolean ret = _first();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the last row in the rowset.
   * It notifies listeners that the cursor has moved.
   *
   * @return true if on a valid row, false if no rows in the rowset.
   * @exception SQLException if a database-access error occurs, or
   * rowset type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean last() throws SQLException {
    check_move("'last()'", false);
    closeInputStream();
    cancelUpdates();
    boolean ret = _last();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Move to an absolute row number in the rowset.
   * It notifies listeners that the cursor has moved.
   *
   * <p>If row is positive, moves to an absolute row with respect to the
   * beginning of the rowset.  The first row is row 1, the second
   * is row 2, etc.
   *
   * <p>If row is negative, moves to an absolute row position with respect to
   * the end of rowset.  For example, calling absolute(-1) positions the
   * cursor on the last row, absolute(-2) indicates the next-to-last
   * row, etc.
   *
   * <p>An attempt to position the cursor beyond the first/last row in
   * the rowset, leaves the cursor before/after the first/last
   * row, respectively.
   *
   * <p>Note: Calling absolute(1) is the same as calling first().
   * Calling absolute(-1) is the same as calling last().
   *
   * @return true if on the rowset, false if off.
   * @exception SQLException if a database-access error occurs, or
   * row is 0, or rowset type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean absolute(int row) throws SQLException {
    check_move("'absolute(...)'", false);
    closeInputStream();
    cancelUpdates();
    if (row == 0)
       throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Invalid_row_number_for_XX, "'absolute(...)'");

    boolean ret;

    if (!showDeleted) {

      if (row > 0) {
        if (row == 1) {
           _first();
        } else {
           while(absolutePos != row) {
             if (absolutePos >= row)
               ret = _previous();
             else
               ret = _next();
             if (!ret)
               break;
           }
        }
      } else {
        //row < 0
        ret = _last();
        if (ret && row < -1) {
          int pos = -1;
          while (pos != row && ret) {
            ret = _previous();
            if (ret)
               pos--;
          }
        }
      }

    } else {

      // showDeleted == true
      if (row > 0) {
        if (row > countRows) {
          _afterLast();
        } else {
          curRow = row - 1;
          absolutePos = row;
          curState = BODYROW;
        }
      } else {
        // row < 0
        if (row * -1 > countRows) {
          _beforeFirst();
        } else {
          curRow = countRows + row;
          absolutePos = curRow + 1;
          curState = BODYROW;
        }
      }
    }
    notifyListener(ev_CursorMoved);
    return !isAfterLast() && !isBeforeFirst();
  }

  /**
   * <p>Moves a relative number of rows, either positive or negative.
   * Attempting to move beyond the first/last row in the
   * rowset positions the cursor before/after the
   * the first/last row. Calling relative(0) is valid, but does
   * not change the cursor position.
   * It notifies listeners that the cursor has moved.
   *
   * <p>Note: Calling relative(1) is different than calling next()
   * since is makes sense to call next() when there is no current row,
   * for example, when the cursor is positioned before the first row
   * or after the last row of the rowset.
   *
   * @return true if on a row, false otherwise.
   * @exception SQLException if a database-access error occurs, or there
   * is no current row, or rowset type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean relative(int rows) throws SQLException {
    check_move("'relative(...)'", false);
    closeInputStream();
    cancelUpdates();
    if (rows == 0)
      return true;
    if (rows > 0) {
       if (curRow + rows >= countRows) {
         _afterLast();
       } else {
         for (int i = 0; i < rows; i++)
            if (!_next())
               break;
       }
    } else {
      // rows < 0
      if (curRow + rows < 0) {
         beforeFirst();
      } else {
         for (int i = rows; i < 0; i++)
            if (!_previous())
               break;
      }
    }
    notifyListener(this.ev_CursorMoved);
    return !isAfterLast() && !isBeforeFirst();
  }

  /**
   * <p>Moves to the front of the rowset, just before the
   * first row. Has no effect if the rowset contains no rows.
   * It notifies listeners that the cursor has moved.
   *
   * @exception SQLException if a database-access error occurs, or
   * rowset type is TYPE_FORWARD_ONLY
   */
  public synchronized void beforeFirst() throws SQLException {
    check_move("'beforeFirst()'", false);
    closeInputStream();
    cancelUpdates();
    _beforeFirst();
    notifyListener(this.ev_CursorMoved);
  }

  /**
   * <p>Moves to the end of the rowset, just after the last
   * row.  Has no effect if the rowset contains no rows.
   * It notifies listeners that the cursor has moved.
   *
   * @exception SQLException if a database-access error occurs, or
   * rowset type is TYPE_FORWARD_ONLY.
   */
  public synchronized void afterLast() throws SQLException {
    check_move("'afterLast()'", false);
    closeInputStream();
    cancelUpdates();
    _afterLast();
    notifyListener(this.ev_CursorMoved);
  }

  /**
   * <p>Determine if the cursor is before the first row in the rowset.
   *
   * @return true if before the first row, false otherwise. Returns
   * false when the rowset contains no rows.
   * @exception SQLException if a database-access error occurs.
   */
  public boolean isBeforeFirst() throws SQLException {
    check_InsertMode("'isBeforeFirst()'");
    if (curState == BEFOREFIRST)
      return true;
    else
      return false;
  }

  /**
   * <p>Determine if the cursor is after the last row in the rowset.
   *
   * @return true if after the last row, false otherwise.  Returns
   * false when the rowset contains no rows.
   * @exception SQLException if a database-access error occurs.
   */
  public boolean isAfterLast() throws SQLException {
    check_InsertMode("'isAfterLast()'");
    if (curState == AFTERLAST)
      return true;
    else
      return false;
  }

  /**
   * <p>Determine if the cursor is on the first row of the rowset.
   *
   * @return true if on the first row, false otherwise.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isFirst() throws SQLException {
    check_InsertMode("'isFirst()'");
    if (curState == FIRSTROW) {
      return true;
    } else if (curState == LASTROW) {
      int _curRow = curRow;
      int _absolutePos = absolutePos;
      boolean prev_exists = _previous();
      curRow = _curRow;
      absolutePos = _absolutePos;
      curState = LASTROW;
      if (!prev_exists)
        return true;
    }
    return false;
  }

  /**
   * <p>Determine if the cursor is on the last row of the rowset.
   * Note: Calling isLast() may be expensive since the rowset
   * might need to check ahead one row in order to determine
   * whether the current row is the last row in the rowset.
   *
   * @return true if on the last row, false otherwise.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isLast() throws SQLException {
    check_InsertMode("'isLast()'");
    if (curState == LASTROW) {
      return true;
    } else if (curState == FIRSTROW) {
      int _curRow = curRow;
      int _absolutePos = absolutePos;
      boolean next_exists = _next();
      curRow = _curRow;
      absolutePos = _absolutePos;
      curState = FIRSTROW;
      if (!next_exists)
        return true;
    }
    return false;
  }

  /**
   * <p>Determine the current row number.  The first row is number 1, the
   * second number 2, etc.
   *
   * @return the current row number, else return 0 if there is no
   * current row
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int getRow() throws SQLException {
    check_InsertMode("'getRow()'");
    if (curState == BEFOREFIRST || curState == AFTERLAST || curState == NOROWS)
      return 0;
    return absolutePos;
  }

  /**
   * Determine if the current row has been updated.  The value returned
   * depends on whether or not the rowset can detect updates.
   *
   * @return true if the row has been visibly updated by the owner or
   * another, and updates are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#updatesAreDetected
   */
  public synchronized boolean rowUpdated() throws SQLException {
    check_InsertMode("'rowUpdated()'");
    if (curState == BEFOREFIRST || curState == AFTERLAST || curState == NOROWS)
       return false;
    return ((Row)rowsData.get(curRow)).isUpdated;
  }

  /**
   * Determine if the current row has been inserted.  The value returned
   * depends on whether or not the rowset can detect visible inserts.
   *
   * @return true if inserted and inserts are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#insertsAreDetected
   */
  public synchronized boolean rowInserted() throws SQLException {
    check_InsertMode("'rowInserted()'");
    if (curState == BEFOREFIRST || curState == AFTERLAST || curState == NOROWS)
       return false;
    return ((Row)rowsData.get(curRow)).isInserted;
  }

  /**
   * Determine if this row has been deleted.  A deleted row may leave
   * a visible "hole" in a rowset.  This method can be used to
   * detect holes in a rowset.  The value returned depends on whether
   * or not the rowset can detect deletions.
   *
   * @return true if deleted and deletes are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#deletesAreDetected
   */
  public synchronized boolean rowDeleted() throws SQLException {
    check_InsertMode("'rowDeleted()'");
    if (curState == BEFOREFIRST || curState == AFTERLAST || curState == NOROWS)
       return false;
    return ((Row)rowsData.get(curRow)).isDeleted;
  }

  /**
   * Sets the current row with its original value and marks the row
   * as not updated, thus undoing any changes made to the row since
   * the last call to the methods updateRow or deleteRow.
   * This method should be called only when the cursor is on a row in
   * this rowset. Cannot be called when on the insert row.
   *
   * @exception SQLException if a database-access error occurs, or if
   * called when on the insert row.
   */
  public synchronized void refreshRow() throws SQLException {
    check_move("'refreshRow()'", false);
    closeInputStream();
    cancelUpdates();
  }


  /**
   * Inserts the contents of the insert row into this
   * rowset following the current row and it notifies
   * listeners that the row has changed.
   * The cursor must be on the insert row when this method is called.
   * The method marks the current row as inserted,
   * but it does not insert the row to the underlying data source.
   * The method acceptChanges must be called to insert the row to
   * the data source.
   *
   * @exception SQLException if a database access error occurs,
   * if this method is called when the cursor is not on the insert row
   */
  public synchronized void insertRow() throws SQLException {
    if (!onInsertRow)
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_XX_was_called_when_the_insert_row_is_off, "'insertRow()'");
    check_Update("'insertRow()'");
    if (updateRow == null || !updateRow.isCompleted())
        throw OPLMessage_x.makeException(OPLMessage_x.errx_Failed_to_insert_Row);
    Row row = new Row(updateRow.getCurData());
    row.isInserted = true;
    switch(curState) {
      case FIRSTROW:
      case LASTROW:
      case BODYROW:
          rowsData.add(curRow, row);
          break;
      case BEFOREFIRST:
      case NOROWS:
          rowsData.add(0, row);
          curState = BEFOREFIRST;
          break;
      case AFTERLAST:
          rowsData.add(row);
        break;
    }
    countRows++;
    notifyListener(ev_RowChanged);
  }

  /**
   * Marks the current row of this rowset as updated but it does not update
   * the row to the underlying data source. The method acceptChanges must
   * be called to update the row to the data source.
   * It notifies listeners that the row has changed also.
   * Cannot be called when on the insert row.
   *
   * @exception SQLException if a database-access error occurs, or
   * if called when on the insert row
   */
  public synchronized void updateRow() throws SQLException {
    if (onInsertRow)
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_XX_was_called_when_the_insert_row_is_off, "'updateRow()'");
    check_Update("'updateRow()'");
    check_pos("'updateRow()'");

    if (updateRow != null) {
      ((Row)getCurRow()).update(updateRow.getCurData(), updateRow.getListUpdatedCols());
      notifyListener(ev_RowChanged);
      updateRow.clear();
      updateRow = null;
    }

  }

  /**
   * Delete the current row from this OPLCachedRowSet object and it notifies
   * listeners that a row has changed. Cannot be called when the cursor is
   * on the insert row. The method marks the current row as deleted,
   * but it does not delete the row from the underlying data source.
   * The method acceptChanges must be called to delete the row in
   * the data source.
   *
   * @exception SQLException if a database-access error occurs, or if
   * called when on the insert row.
   */
  public synchronized void deleteRow() throws SQLException {
    if (onInsertRow)
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_XX_was_called_when_the_insert_row_is_off, "'deleteRow()'");
    check_Update("'deleteRow()'");
    check_pos("'deleteRow()'");
    Row row = (Row)getCurRow();
    if (!row.isDeleted) {
       row.isDeleted = true;
       countDeleted++;
       if (!showDeleted) {
         int _absPos = absolutePos;
         _next();
         absolutePos = _absPos;
      }
       notifyListener(ev_RowChanged);
    }
  }

  /**
   * Move to the insert row.  The current cursor position is
   * remembered while the cursor is positioned on the insert row.
   *
   * The insert row is a special row associated with an updatable
   * rowset.  It is essentially a buffer where a new row may
   * be constructed by calling the updateXXX() methods prior to
   * inserting the row into the rowset.
   *
   * Only the updateXXX(), getXXX(), and insertRow() methods may be
   * called when the cursor is on the insert row.  All of the columns in
   * a rowset must be given a value each time this method is
   * called before calling insertRow().  UpdateXXX()must be called before
   * getXXX() on a column.
   *
   * @exception SQLException if a database-access error occurs,
   * or the rowset is not updatable
   */
  public synchronized void moveToInsertRow() throws SQLException {
    check_Update("'moveToInsertRow()'");
    if (updateRow != null)
      updateRow.clear();
    int count = rowSMD.getColumnCount();
    if (count > 0) {
      updateRow = new Row(count);
      onInsertRow = true;
    }
  }

  /**
   * Move the cursor to the remembered cursor position, usually the
   * current row.  Has no effect unless the cursor is on the insert
   * row.
   *
   * @exception SQLException if a database-access error occurs,
   * or the rowset is not updatable
   */
  public synchronized void moveToCurrentRow() throws SQLException {
    if (onInsertRow) {
      cancelUpdates();
      onInsertRow = false;
      if (curState == AFTERLAST) {
        _last();
      }
      return;
    }
  }


  /**
   * A column may have the value of SQL NULL; wasNull reports whether
   * the last column read had this special value.
   * Note that you must first call getXXX on a column to try to read
   * its value and then call wasNull() to find if the value was
   * the SQL NULL.
   *
   * @return true if last column read was SQL NULL
   * @exception SQLException if a database-access error occurs.
   */
  public boolean wasNull() throws SQLException {
    return _wasNull;
  }

  /**
   * <p>The first warning reported by calls on this ResultSet is
   * returned. Subsequent ResultSet warnings will be chained to this
   * SQLWarning.
   *
   * <P>The warning chain is automatically cleared each time a new
   * row is read.
   *
   * <P><B>Note:</B> This warning chain only covers warnings caused
   * by ResultSet methods.  Any warning caused by statement methods
   * (such as reading OUT parameters) will be chained on the
   * Statement object.
   *
   * @return the first SQLWarning or null
   * @exception SQLException if a database-access error occurs.
   */
  public SQLWarning getWarnings() throws SQLException {
    return null;
  }

  /**
   * After this call getWarnings returns null until a new warning is
   * reported for this ResultSet.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void clearWarnings() throws SQLException {
  }

  /**
   * Get the name of the SQL cursor used by this ResultSet.
   *
   * @return the null
   * @exception SQLException if an error occurs.
   */
  public String getCursorName() throws SQLException {
    return null;
  }

  /**
   * The number, types and properties of a ResultSet's columns
   * are provided by the getMetaData method.
   *
   * @return the description of a ResultSet's columns
   * @exception SQLException if a database-access error occurs.
   */
  public ResultSetMetaData getMetaData() throws SQLException {
    return rowSMD;
  }

  /**
   * Map a Resultset column name to a ResultSet column index.
   *
   * @param columnName the name of the column
   * @return the column index
   * @exception SQLException if a database-access error occurs.
   */
  public int findColumn(String columnName) throws SQLException {
    if (rowSMD == null)
          throw OPLMessage_x.makeException(OPLMessage_x.errx_Names_of_columns_are_not_found);

    int count = rowSMD.getColumnCount();

    for (int i = 1; i <= count; i++) {
      String name = rowSMD.getColumnName(i);
      if (name != null && name.equalsIgnoreCase(columnName))
        return i;
    }
    throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Invalid_column_name, columnName);
  }

  /**
   * Get the value of a column in the current row as a Java String.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized String getString(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof byte[])
        return Bin2Hex((byte[])x);
      else if (x instanceof Blob)
        return Bin2Hex(((Blob)x).getBytes(0L, (int)((Blob)x).length()));
      else if (x instanceof Clob)
        return ((Clob)x).getSubString(0L, (int)((Clob)x).length());
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return ((NClob)x).getSubString(0L, (int)((NClob)x).length());
#endif
      else
        return x.toString();
    }
  }

  /**
   * Get the value of a column in the current row as a Java boolean.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is false
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean getBoolean(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return false;
    } else {
      int c;
      if (x instanceof Boolean)
         return ((Boolean)x).booleanValue();
      else if (x instanceof String) {
        c =((String)x).charAt(0);
        return (c == 'T' || c == 't' || c == '1');
      }else if (x instanceof byte[])
        return ((byte[])x)[0] != 0;
      else if (x instanceof Blob)
        return ((Blob)x).getBytes(0L, 1)[0] != 0;
      else if (x instanceof Clob) {
        c =((Clob)x).getSubString(0L, 1).charAt(0);
        return (c == 'T' || c == 't' || c == '1');
#if JDK_VER >= 16
      }else if (x instanceof NClob) {
        c =((NClob)x).getSubString(0L, 1).charAt(0);
        return (c == 'T' || c == 't' || c == '1');
#endif
      }else if (x instanceof Number)
        return ((Number)x).intValue() != 0;
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'boolean'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java byte.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte getByte(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).byteValue();
      else if (x instanceof Boolean)
        return (byte)(((Boolean)x).booleanValue()? 1 : 0);
      else if (x instanceof String) {
        return (new BigDecimal(((String)x).toString())).byteValue();
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'byte'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java short.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized short getShort(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).shortValue();
      else if (x instanceof Boolean)
        return (short)(((Boolean)x).booleanValue()? 1 : 0);
      else if (x instanceof String) {
        return (new BigDecimal(((String)x).toString())).shortValue();
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'short'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java int.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int getInt(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).intValue();
      else if (x instanceof Boolean)
        return (((Boolean)x).booleanValue()? 1 : 0);
      else if (x instanceof String) {
        return (new BigDecimal(((String)x).toString())).intValue();
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'int'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java long.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized long getLong(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).longValue();
      else if (x instanceof Boolean)
        return (((Boolean)x).booleanValue()? 1L : 0L);
      else if (x instanceof String) {
        return (new BigDecimal(((String)x).toString())).longValue();
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'long'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java float.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized float getFloat(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).floatValue();
      else if (x instanceof Boolean)
        return (float)(((Boolean)x).booleanValue()? 1 : 0);
      else if (x instanceof String) {
        return Float.parseFloat(((String)x).toString().trim());
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'float'");
    }
  }

  /**
   * Get the value of a column in the current row as a Java double.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized double getDouble(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return 0;
    } else {
      int c;
      if (x instanceof Number)
         return ((Number)x).doubleValue();
      else if (x instanceof Boolean)
        return (double)(((Boolean)x).booleanValue()? 1 : 0);
      else if (x instanceof String) {
        return Double.parseDouble(((String)x).toString().trim());
      }else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'double'");
    }
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value (full precision); if the value is SQL NULL,
   * the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized BigDecimal getBigDecimal(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Boolean)
        return new BigDecimal((((Boolean)x).booleanValue()? 1L : 0L));
      else
        try {
            return new BigDecimal(x.toString().trim());
        }  catch(NumberFormatException e) {
            throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'BigDecimal'");
        }
    }
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param scale the number of digits to the right of the decimal
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized BigDecimal getBigDecimal(int columnIndex, int scale) throws SQLException {
    return getBigDecimal(columnIndex).setScale(scale);
  }

  /**
   * Get the value of a column in the current row as a Java byte array.
   * The bytes represent the raw values returned by the driver.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte[] getBytes(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof byte[])
        return (byte[])x;
      else if (x instanceof Blob)
        return ((Blob)x).getBytes(0L, (int)((Blob)x).length());
      else if (x instanceof Clob)
        return ((Clob)x).getSubString(0L, (int)((Clob)x).length()).getBytes();
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return ((NClob)x).getSubString(0L, (int)((NClob)x).length()).getBytes();
#endif
      else if (x instanceof String)
        return ((String)x).getBytes();
      else
         throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'byte[]'");
    }
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Date getDate(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Date) {
        return (Date)x;
      } else if (x instanceof Timestamp) {
        return new Date(((Timestamp)x).getTime());
      } else if (x instanceof String) {
        Date dt = _getDate((String)x);
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Date'");
        return dt;
      } else if (x instanceof Clob) {
        Date dt = _getDate(((Clob)x).getSubString(0L, (int)((Clob)x).length()));
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Date'");
        return dt;
#if JDK_VER >= 16
      } else if (x instanceof NClob) {
        Date dt = _getDate(((NClob)x).getSubString(0L, (int)((NClob)x).length()));
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Date'");
        return dt;
#endif
       } else
         throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Date'");
    }
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Time getTime(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Time) {
        return (Time)x;
      } else if (x instanceof Timestamp) {
        return new Time(((Timestamp)x).getTime());
      } else if (x instanceof String) {
        Time dt = _getTime((String)x);
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Time'");
        return dt;
      } else if (x instanceof Clob) {
        Time dt = _getTime(((Clob)x).getSubString(0L, (int)((Clob)x).length()));
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Time'");
        return dt;
#if JDK_VER >= 16
      } else if (x instanceof NClob) {
        Time dt = _getTime(((NClob)x).getSubString(0L, (int)((NClob)x).length()));
        if (dt == null)
              throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Time'");
        return dt;
#endif
       } else
         throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Time'");
    }
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Timestamp getTimestamp(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Timestamp) {
        return (Timestamp)x;
      } else if (x instanceof Time) {
        return new Timestamp(((Time)x).getTime());
      } else if (x instanceof Date) {
        return new Timestamp(((Date)x).getTime());
      } else if (x instanceof String) {
        Timestamp dt = _getTimestamp((String)x);
        if (dt == null)
           throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Timestamp'");
        return dt;
      } else if (x instanceof Clob) {
        Timestamp dt = _getTimestamp(((Clob)x).getSubString(0L, (int)((Clob)x).length()));
        if (dt == null)
           throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Timestamp'");
        return dt;
#if JDK_VER >= 16
      } else if (x instanceof NClob) {
        Timestamp dt = _getTimestamp(((NClob)x).getSubString(0L, (int)((NClob)x).length()));
        if (dt == null)
           throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Timestamp'");
        return dt;
#endif
       } else
         throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Timestamp'");
    }
  }

  /**
   * A column value can be retrieved as a stream of ASCII characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into ASCII.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. . Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of one byte ASCII characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getAsciiStream(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    closeInputStream();
    if (_wasNull = (x == null)) {
      return (objInputStream = null);
    } else {
      if (x instanceof String)
        return objInputStream = new ByteArrayInputStream(((String)x).getBytes());
      else if (x instanceof Clob)
        return objInputStream = ((Clob)x).getAsciiStream();
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return objInputStream = ((NClob)x).getAsciiStream();
#endif
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'AsciiStream'");
    }
  }

  /**
   * A column value can be retrieved as a stream of Unicode characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into Unicode.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. . Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of two byte Unicode characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized InputStream getUnicodeStream(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    closeInputStream();
    if (_wasNull = (x == null)) {
      return (objInputStream = null);
    } else {
      if (x instanceof String)
        return objInputStream = new ByteArrayInputStream(((String)x).getBytes());
      else if (x instanceof Clob)
        return objInputStream = ((Clob)x).getAsciiStream();
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return objInputStream = ((NClob)x).getAsciiStream();
#endif
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'UnicodeStream'");
    }
  }

  /**
   * A column value can be retrieved as a stream of uninterpreted bytes
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARBINARY values.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of uninterpreted bytes.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getBinaryStream(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    closeInputStream();
    if (_wasNull = (x == null)) {
      return (objInputStream = null);
    } else {
      if (x instanceof byte[])
        return objInputStream = new ByteArrayInputStream(((byte[])x));
      else if (x instanceof String)
        return objInputStream = new ByteArrayInputStream(((String)x).getBytes());
      else if (x instanceof Blob)
        return objInputStream = ((Blob)x).getBinaryStream();
      else if (x instanceof Clob)
        return objInputStream = ((Clob)x).getAsciiStream();
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return objInputStream = ((NClob)x).getAsciiStream();
#endif
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'BinaryStream'");
    }
  }

  /**
   * <p>Get the value of a column in the current row as a Java object.
   *
   * <p>This method will return the value of the given column as a
   * Java object.  The type of the Java object will be the default
   * Java object type corresponding to the column's SQL type,
   * following the mapping for built-in types specified in the JDBC
   * spec.
   *
   * <p>This method may also be used to read database specific
   * abstract data types.
   *
   * JDBC 2.0
   *
   * New behavior for getObject().
   * The behavior of method getObject() is extended to materialize
   * data of SQL user-defined types.  When the column @column is
   * a structured or distinct value, the behavior of this method is as
   * if it were a call to: getObject(column,
   * this.getStatement().getConnection().getTypeMap()).
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a java.lang.Object holding the column value.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Object getObject(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    InputStream retVal = null;
    if (_wasNull = (x == null)) {
      return null;
    } else {
      return x;
    }
  }

  /**
   * Get the value of a column in the current row as a Java String.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public String getString(String columnName) throws SQLException {
    return getString(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java boolean.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is false
   * @exception SQLException if a database-access error occurs.
   */
  public boolean getBoolean(String columnName) throws SQLException {
    return getBoolean(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java byte.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public byte getByte(String columnName) throws SQLException {
    return getByte(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java short.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public short getShort(String columnName) throws SQLException {
    return getShort(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java int.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public int getInt(String columnName) throws SQLException {
    return getInt(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java long.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public long getLong(String columnName) throws SQLException {
    return getLong(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java float.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public float getFloat(String columnName) throws SQLException {
    return getFloat(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a Java double.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public double getDouble(String columnName) throws SQLException {
    return getDouble(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   * @param columnName is the SQL name of the column
   * @param scale the number of digits to the right of the decimal
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public BigDecimal getBigDecimal(String columnName, int scale) throws SQLException {
    return getBigDecimal(findColumn (columnName), scale);
  }

  /**
   * Get the value of a column in the current row as a Java byte array.
   * The bytes represent the raw values returned by the driver.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public byte[] getBytes(String columnName) throws SQLException {
    return getBytes(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Date getDate(String columnName) throws SQLException {
    return getDate(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Time getTime(String columnName) throws SQLException {
    return getTime(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Timestamp getTimestamp(String columnName) throws SQLException {
    return getTimestamp(findColumn (columnName));
  }

  /**
   * A column value can be retrieved as a stream of ASCII characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into ASCII.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of one byte ASCII characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public InputStream getAsciiStream(String columnName) throws SQLException {
    return getAsciiStream(findColumn (columnName));
  }

  /**
   * A column value can be retrieved as a stream of Unicode characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into Unicode.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of two byte Unicode characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public InputStream getUnicodeStream(String columnName) throws SQLException {
    return getUnicodeStream(findColumn (columnName));
  }

  /**
   * A column value can be retrieved as a stream of uninterpreted bytes
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARBINARY values.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of uninterpreted bytes.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public InputStream getBinaryStream(String columnName) throws SQLException {
    return getBinaryStream(findColumn (columnName));
  }

  /**
   * <p>Get the value of a column in the current row as a Java object.
   *
   * <p>This method will return the value of the given column as a
   * Java object.  The type of the Java object will be the default
   * Java object type corresponding to the column's SQL type,
   * following the mapping for built-in types specified in the JDBC
   * spec.
   *
   * <p>This method may also be used to read database specific
   * abstract data types.
   *
   * JDBC 2.0
   *
   * New behavior for getObject().
   * The behavior of method getObject() is extended to materialize
   * data of SQL user-defined types.  When the column @columnName is
   * a structured or distinct value, the behavior of this method is as
   * if it were a call to: getObject(columnName,
   * this.getStatement().getConnection().getTypeMap()).
   *
   * @param columnName is the SQL name of the column
   * @return a java.lang.Object holding the column value.
   * @exception SQLException if a database-access error occurs.
   */
  public Object getObject(String columnName) throws SQLException {
    return getObject(findColumn (columnName));
  }

  /**
   * <p>Get the value of a column in the current row as a java.io.Reader.
   */
  public synchronized Reader getCharacterStream(int columnIndex) throws SQLException {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    closeInputStream();
    if (_wasNull = (x == null)) {
      return (objReader = null);
    } else {
      if (x instanceof String)
        return objReader = new StringReader((String)x);
      else if (x instanceof Clob)
        return objReader = ((Clob)x).getCharacterStream();
#if JDK_VER >= 16
      else if (x instanceof NClob)
        return objReader = ((NClob)x).getCharacterStream();
#endif
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'CharacterStream'");
    }
  }

  /**
   * <p>Get the value of a column in the current row as a java.io.Reader.
   */
  public Reader getCharacterStream(String columnName) throws SQLException {
    return getCharacterStream(findColumn (columnName));
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   */
  public BigDecimal getBigDecimal(String columnName) throws SQLException {
    return getBigDecimal(findColumn (columnName));
  }

  /**
   * Give a nullable column a null value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateNull(int columnIndex) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateNull(...)'");
    r.setColData(columnIndex, null);
  }

  /**
   * Update a column with a boolean value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBoolean(int columnIndex, boolean x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateBoolean(...)'");
    switch(rowSMD.getColumnType(columnIndex)) {
#if JDK_VER >= 14
     case Types.BOOLEAN:
        r.setColData(columnIndex, new Boolean(x));
        break;
#endif
      case Types.BIT:
      case Types.TINYINT:
      case Types.SMALLINT:
      case Types.INTEGER:
      case Types.BIGINT:
      case Types.REAL:
      case Types.FLOAT:
      case Types.DOUBLE:
      case Types.DECIMAL:
      case Types.NUMERIC:
        r.setColData(columnIndex, new Integer((x ?1:0)));
        break;
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
#if JDK_VER >= 16
     case Types.NCHAR:
     case Types.NVARCHAR:
     case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, String.valueOf(x));
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'boolean'");
    }
  }

  /**
   * Update a column with a byte value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateByte(int columnIndex, byte x) throws SQLException {
    updateNumber(columnIndex, new Byte(x), "'byte'", "'updateByte(...)'");
  }

  /**
   * Update a column with a short value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateShort(int columnIndex, short x) throws SQLException {
    updateNumber(columnIndex, new Short(x), "'short'", "'updateShort(...)'");
  }

  /**
   * Update a column with an integer value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateInt(int columnIndex, int x) throws SQLException {
    updateNumber(columnIndex, new Integer(x), "'int'", "'updateInt(...)'");
  }

  /**
   * Update a column with a long value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateLong(int columnIndex, long x) throws SQLException {
    updateNumber(columnIndex, new Long(x), "'long'", "'updateLong(...)'");
  }

  /**
   * Update a column with a float value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateFloat(int columnIndex, float x) throws SQLException {
    updateNumber(columnIndex, new Float(x), "'float'", "'updateFloat(...)'");
  }

  /**
   * Update a column with a Double value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateDouble(int columnIndex, double x) throws SQLException {
    updateNumber(columnIndex, new Double(x), "'double'", "'updateDouble(...)'");
  }

  /**
   * Update a column with a BigDecimal value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateBigDecimal(int columnIndex, BigDecimal x) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      updateNumber(columnIndex, x, "'BigDecimal'", "'updateBigDecimal(...)'");
  }

  /**
   * Update a column with a String value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateString(int columnIndex, String x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateString(...)'");
    if (x == null)
      updateNull(columnIndex);
    else
      switch(rowSMD.getColumnType(columnIndex)) {
#if JDK_VER >= 14
      case Types.BOOLEAN:
        r.setColData(columnIndex, new Boolean(x));
        break;
#endif
      case Types.BIT:
      case Types.TINYINT:
      case Types.SMALLINT:
      case Types.INTEGER:
      case Types.BIGINT:
      case Types.REAL:
      case Types.FLOAT:
      case Types.DOUBLE:
      case Types.DECIMAL:
      case Types.NUMERIC:
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
#if JDK_VER >= 14
      case Types.DATALINK:
#endif
#if JDK_VER >= 16
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
      case Types.NCLOB:
#endif
      case Types.BLOB:
      case Types.CLOB:
        r.setColData(columnIndex, x);
        break;
      case Types.BINARY:
      case Types.VARBINARY:
      case Types.LONGVARBINARY:
        r.setColData(columnIndex, HexString2Bin(x));
        break;
      case Types.TIME:
       {
        Time val = _getTime(x);
        if (val == null)
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'String'");
        r.setColData(columnIndex, val);
        break;
       }
      case Types.TIMESTAMP:
       {
        Timestamp val = _getTimestamp(x);
        if (val == null)
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'String'");
        r.setColData(columnIndex, val);
        break;
       }
      case Types.DATE:
       {
        Date val = _getDate(x);
        if (val == null)
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'String'");
        r.setColData(columnIndex, val);
        break;
       }
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'String'");
    }
  }

  /**
   * Update a column with a byte array value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBytes(int columnIndex, byte[] x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateBytes(...)'");
    if (x == null)
      updateNull(columnIndex);
    else
      switch(rowSMD.getColumnType(columnIndex)) {
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
      case Types.CLOB:
#if JDK_VER >= 16
      case Types.NCLOB:
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, Bin2Hex(x));
        break;
      case Types.BLOB:
        r.setColData(columnIndex, x);
        break;
      case Types.BINARY:
      case Types.VARBINARY:
      case Types.LONGVARBINARY:
        r.setColData(columnIndex, x);
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'byte[]'");
    }
  }

  /**
   * Update a column with a Date value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateDate(int columnIndex, Date x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateDate(...)'");
    if (x == null)
      updateNull(columnIndex);
    else
      switch(rowSMD.getColumnType(columnIndex)) {
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
      case Types.CLOB:
#if JDK_VER >= 16
      case Types.NCLOB:
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, x.toString());
        break;
      case Types.DATE:
        r.setColData(columnIndex, x);
        break;
      case Types.TIMESTAMP:
        r.setColData(columnIndex, new Timestamp(x.getTime()));
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'Date'");
    }
  }

  /**
   * Update a column with a Time value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTime(int columnIndex, Time x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateTime(...)'");
    if (x == null)
      updateNull(columnIndex);
    else
      switch(rowSMD.getColumnType(columnIndex)) {
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
      case Types.CLOB:
#if JDK_VER >= 16
      case Types.NCLOB:
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, x.toString());
        break;
      case Types.TIME:
        r.setColData(columnIndex, x);
        break;
      case Types.TIMESTAMP:
        r.setColData(columnIndex, new Timestamp(x.getTime()));
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'Time'");
    }
  }

  /**
   * Update a column with a Timestamp value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTimestamp(int columnIndex, Timestamp x) throws SQLException {
    Row r = this.getRowForUpdate(columnIndex, "'updateTimestamp(...)'");
    if (x == null)
      updateNull(columnIndex);
    else
      switch(rowSMD.getColumnType(columnIndex)) {
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
      case Types.CLOB:
#if JDK_VER >= 16
      case Types.NCLOB:
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, x.toString());
        break;
      case Types.TIMESTAMP:
        r.setColData(columnIndex, x);
        break;
      case Types.DATE:
        r.setColData(columnIndex, new Date(x.getTime()));
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, "'Timestamp'");
    }
  }

  /**
   * Update a column with an ascii stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateAsciiStream(int columnIndex, InputStream x, int length) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      try {
        byte[] buf = new byte[length];
        int count = 0;
        do {
          int n = x.read(buf, count, length - count);
          if (n <=0)
            break;
          count += n;
        } while (count < length);
        updateString(columnIndex, new String(buf, 0, count));
      } catch(IOException e) {
        throw OPLMessage_x.makeException(e);
      }
  }

  /**
   * Update a column with a binary stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateBinaryStream(int columnIndex, InputStream x, int length) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      try {
        byte[] buf = new byte[length];
        int count = 0;
        do {
          int n = x.read(buf, count, length - count);
          if (n <=0)
            break;
          count += n;
        } while (count < length);
        updateBytes(columnIndex, buf);
      } catch(IOException e) {
        throw OPLMessage_x.makeException(e);
      }
  }

  /**
   * Update a column with a character stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateCharacterStream(int columnIndex, Reader x, int length) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      try {
        char[] buf = new char[length];
        int count = 0;
        do {
          int n = x.read(buf, count, length - count);
          if (n <=0)
            break;
          count += n;
        } while (count < length);
        updateString(columnIndex, new String(buf, 0, count));
      } catch(IOException e) {
        throw OPLMessage_x.makeException(e);
      }
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
   *  this is the number of digits after the decimal.  For all other
   *  types this value will be ignored.
   * @exception SQLException if a database-access error occurs
   */
  public void updateObject(int columnIndex, Object x, int scale) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else {
      if (x instanceof BigDecimal)
        ((BigDecimal)x).setScale(scale);
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateObject(...)'");
       r.setColData(columnIndex, x);
      }
    }
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateObject(int columnIndex, Object x) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateObject(...)'");
       r.setColData(columnIndex, x);
      }
  }


  /**
   * Update a column with a null value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @exception SQLException if a database-access error occurs
   */
  public void updateNull(String columnName) throws SQLException {
    updateNull(findColumn(columnName));
  }

  /**
   * Update a column with a boolean value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateBoolean(String columnName, boolean x) throws SQLException {
    updateBoolean(findColumn(columnName), x);
  }

  /**
   * Update a column with a byte value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateByte(String columnName, byte x) throws SQLException {
    updateByte(findColumn(columnName), x);
  }

  /**
   * Update a column with a short value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateShort(String columnName, short x) throws SQLException {
    updateShort(findColumn(columnName), x);
  }

  /**
   * Update a column with an integer value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateInt(String columnName, int x) throws SQLException {
    updateInt(findColumn(columnName), x);
  }

  /**
   * Update a column with a long value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateLong(String columnName, long x) throws SQLException {
    updateLong(findColumn(columnName), x);
  }

  /**
   * Update a column with a float value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateFloat(String columnName, float x) throws SQLException {
    updateFloat(findColumn(columnName), x);
  }

  /**
   * Update a column with a double value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateDouble(String columnName, double x) throws SQLException {
    updateDouble(findColumn(columnName), x);
  }

  /**
   * Update a column with a BigDecimal value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateBigDecimal(String columnName, BigDecimal x) throws SQLException {
    updateBigDecimal(findColumn(columnName), x);
  }

  /**
   * Update a column with a String value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateString(String columnName, String x) throws SQLException {
    updateString(findColumn(columnName), x);
  }

  /**
   * Update a column with a byte array value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateBytes(String columnName, byte[] x) throws SQLException {
    updateBytes(findColumn(columnName), x);
  }

  /**
   * Update a column with a Date value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateDate(String columnName, Date x) throws SQLException {
    updateDate(findColumn(columnName), x);
  }

  /**
   * Update a column with a Time value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateTime(String columnName, Time x) throws SQLException {
    updateTime(findColumn(columnName), x);
  }

  /**
   * Update a column with a Timestamp value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateTimestamp(String columnName, Timestamp x) throws SQLException {
    updateTimestamp(findColumn(columnName), x);
  }

  /**
   * Update a column with an ascii stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateAsciiStream(String columnName, InputStream x, int length) throws SQLException {
    updateAsciiStream(findColumn(columnName), x, length);
  }

  /**
   * Update a column with a binary stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateBinaryStream(String columnName, InputStream x, int length) throws SQLException {
    updateBinaryStream(findColumn(columnName), x, length);
  }

  /**
   * Update a column with a character stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public void updateCharacterStream(String columnName, Reader reader, int length) throws SQLException {
    updateCharacterStream(findColumn(columnName), reader, length);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
   *  this is the number of digits after the decimal.  For all other
   *  types this value will be ignored.
   * @exception SQLException if a database-access error occurs
   */
  public void updateObject(String columnName, Object x, int scale) throws SQLException {
    updateObject(findColumn(columnName), x, scale);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public void updateObject(String columnName, Object x) throws SQLException {
    updateObject(findColumn(columnName), x);
  }

  /**
   * Return the Statement that produced the ResultSet.
   *
   * @return the Statement that produced the rowset
   * (return the null for the OPLCachedRowSet)
   * @exception SQLException if a database-access error occurs
   */
  public Statement getStatement() throws SQLException {
    return null;
  }

  /**
   * Returns the value of column @i as a Java object.  Use the
   * map to determine the class from which to construct data of
   * SQL structured and distinct types.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @param map the mapping from SQL type names to Java classes
   * @return an object representing the SQL value
   */
  public Object getObject(int colIndex, Map map) throws SQLException {
    return getObject(colIndex);
  }

  /**
   * Get a REF(&lt;structured-type&gt;) column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing data of an SQL REF type
   */
  public synchronized Ref getRef(int colIndex) throws SQLException {
    checkColumnIndex(colIndex);
    Object x = getCurRow().getColData(colIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Ref)
        return (Ref)x;
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Ref'");
    }
  }

  /**
   * Get a BLOB column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing a BLOB
   */
  public synchronized Blob getBlob(int colIndex) throws SQLException {
    checkColumnIndex(colIndex);
    Object x = getCurRow().getColData(colIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Blob)
        return (Blob)x;
      else if (x instanceof byte[])
        return new OPLHeapBlob((byte[])x);
      else if (x instanceof String)
        return new OPLHeapBlob(((String)x).getBytes());
      else
         throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Blob'");
    }
  }

  /**
   * Get a CLOB column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing a CLOB
   */
  public synchronized Clob getClob(int colIndex) throws SQLException {
    checkColumnIndex(colIndex);
    Object x = getCurRow().getColData(colIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Clob)
        return (Clob)x;
      else if (x instanceof byte[])
        return new OPLHeapClob(Bin2Hex((byte[])x));
      else
        return new OPLHeapClob(x.toString());
    }
  }

  /**
   * Get an array column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing an SQL array
   */
  public synchronized Array getArray(int colIndex) throws SQLException {
    checkColumnIndex(colIndex);
    Object x = getCurRow().getColData(colIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof Array)
        return (Array)x;
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'Array'");
    }
  }

  /**
   * Returns the value of column @i as a Java object.  Use the
   * map to determine the class from which to construct data of
   * SQL structured and distinct types.
   *
   * @param colName the column name
   * @param map the mapping from SQL type names to Java classes
   * @return an object representing the SQL value
   */
  public Object getObject(String colName, Map map) throws SQLException {
    return getObject(findColumn (colName), map);
  }

  /**
   * Get a REF(&lt;structured-type&gt;) column.
   *
   * @param colName the column name
   * @return an object representing data of an SQL REF type
   */
  public Ref getRef(String colName) throws SQLException {
    return getRef(findColumn (colName));
  }

  /**
   * Get a BLOB column.
   *
   * @param colName the column name
   * @return an object representing a BLOB
   */
  public Blob getBlob(String colName) throws SQLException {
    return getBlob(findColumn (colName));
  }

  /**
   * Get a CLOB column.
   *
   * @param colName the column name
   * @return an object representing a CLOB
   */
  public Clob getClob(String colName) throws SQLException {
    return getClob(findColumn (colName));
  }

  /**
   * Get an array column.
   *
   * @param colName the column name
   * @return an object representing an SQL array
   */
  public Array getArray(String colName) throws SQLException {
    return getArray(findColumn (colName));
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date
   * object.  Use the calendar to construct an appropriate millisecond
   * value for the Date, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the date
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Date getDate(int columnIndex, Calendar cal) throws SQLException {
    Date dt = getDate(columnIndex);
    if (dt == null)
       return null;

    Calendar def_cal = Calendar.getInstance();
    def_cal.setTime(dt);
    cal.set(Calendar.YEAR, def_cal.get(Calendar.YEAR));
    cal.set(Calendar.MONTH, def_cal.get(Calendar.MONTH));
    cal.set(Calendar.DAY_OF_MONTH, def_cal.get(Calendar.DAY_OF_MONTH));
    return new Date(cal.getTime().getTime());
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Date, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the date
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Date getDate(String columnName, Calendar cal) throws SQLException {
    return getDate(findColumn (columnName), cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Time, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the time
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Time getTime(int columnIndex, Calendar cal) throws SQLException {
    Time dt = getTime(columnIndex);
    if (dt == null)
       return null;

    Calendar def_cal = Calendar.getInstance();
    def_cal.setTime(dt);
    cal.set(Calendar.HOUR_OF_DAY, def_cal.get(Calendar.HOUR_OF_DAY));
    cal.set(Calendar.MINUTE, def_cal.get(Calendar.MINUTE));
    cal.set(Calendar.SECOND, def_cal.get(Calendar.SECOND));
    return new Time(cal.getTime().getTime());
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Time, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the time
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Time getTime(String columnName, Calendar cal) throws SQLException {
    return getTime(findColumn (columnName), cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Timestamp, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the timestamp
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Timestamp getTimestamp(int columnIndex, Calendar cal) throws SQLException {
    Timestamp dt = getTimestamp(columnIndex);
    if (dt == null)
       return null;

    Calendar def_cal = Calendar.getInstance();
    def_cal.setTime(dt);
    cal.set(Calendar.YEAR, def_cal.get(Calendar.YEAR));
    cal.set(Calendar.MONTH, def_cal.get(Calendar.MONTH));
    cal.set(Calendar.DAY_OF_MONTH, def_cal.get(Calendar.DAY_OF_MONTH));
    cal.set(Calendar.HOUR_OF_DAY, def_cal.get(Calendar.HOUR_OF_DAY));
    cal.set(Calendar.MINUTE, def_cal.get(Calendar.MINUTE));
    cal.set(Calendar.SECOND, def_cal.get(Calendar.SECOND));
    Timestamp ts = new Timestamp(cal.getTime().getTime());
    ts.setNanos(dt.getNanos());
    return ts;
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Timestamp, if the underlying database doesn't store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the timestamp
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public Timestamp getTimestamp(String columnName, Calendar cal) throws SQLException {
    return getTimestamp(findColumn (columnName), cal);
  }

#if JDK_VER >= 14
    //-------------------------- JDBC 3.0 ----------------------------------------
    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnIndex the index of the column 1 is the first, 2 is the second,...
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs,
     *            or if a URL is malformed
     * @since 1.4
     */
  public synchronized java.net.URL getURL(int columnIndex)
          throws SQLException
  {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof java.net.URL)
        return (java.net.URL)x;
      else if (x instanceof String)
        try {
          return new java.net.URL((String)x);
        } catch(java.net.MalformedURLException e) {
          throw OPLMessage_x.makeException(e);
        }
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'URL'");
    }
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnName the SQL name of the column
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs
     *            or if a URL is malformed
     * @since 1.4
     */
  public java.net.URL getURL(String columnName)
          throws SQLException
  {
    return getURL(findColumn (columnName));
  }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateRef(int columnIndex, java.sql.Ref x) throws SQLException {
//FIXME must throw unsupported type
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateRef(...)'");
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateRef(String columnName, java.sql.Ref x) throws SQLException {
    updateRef (findColumn (columnName), x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateBlob(int columnIndex, java.sql.Blob x) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateBlob(...)'");
       x = new OPLHeapBlob(((Blob)x).getBytes(0L, (int)((Blob)x).length()));
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateBlob(String columnName, java.sql.Blob x) throws SQLException {
    updateBlob (findColumn (columnName), x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateClob(int columnIndex, java.sql.Clob x) throws SQLException {
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateClob(...)'");
       x = new OPLHeapClob(((Clob)x).getSubString(0L, (int)((Clob)x).length()));
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateClob(String columnName, java.sql.Clob x) throws SQLException {
    updateClob (findColumn (columnName), x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateArray(int columnIndex, java.sql.Array x) throws SQLException {
//FIXME must throw unsupported type
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateArray(...)'");
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public void updateArray(String columnName, java.sql.Array x) throws SQLException {
    updateArray (findColumn (columnName), x);
  }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @return the column value; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized RowId getRowId(int columnIndex) throws SQLException
  {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof RowId)
        return (RowId)x;
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'RowId'");
    }
  }

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value ; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public RowId getRowId(String columnLabel) throws SQLException
  {
    return getRowId(findColumn (columnLabel));
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param x the column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateRowId(int columnIndex, RowId x) throws SQLException
  {
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateRowId(...)'");
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateRowId(String columnLabel, RowId x) throws SQLException
  {
    updateRowId (findColumn (columnLabel), x);
  }

    /**
     * Retrieves the holdability of this <code>ResultSet</code> object
     * @return  either <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> or <code>ResultSet.CLOSE_CURSORS_AT_COMMIT</code>
     * @throws SQLException if a database access error occurs
     * or this method is called on a closed result set
     * @since 1.6
     */
  public int getHoldability() throws SQLException
  {
    return ResultSet.HOLD_CURSORS_OVER_COMMIT;
  }

    /**
     * Retrieves whether this <code>ResultSet</code> object has been closed. A <code>ResultSet</code> is closed if the
     * method close has been called on it, or if it is automatically closed.
     *
     * @return true if this <code>ResultSet</code> object is closed; false if it is still open
     * @throws SQLException if a database access error occurs
     * @since 1.6
     */
  public boolean isClosed() throws SQLException
  {
    return (conn == null ? true : false);
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNString(int columnIndex, String nString) throws SQLException
  {
    updateString (columnIndex, nString);
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <CODE>CONCUR_READ_ONLY</code>
     *  or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNString(String columnLabel, String nString) throws SQLException
  {
    updateNString (findColumn (columnLabel), nString);
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex, NClob x) throws SQLException
  {
    if (x == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateNClob(...)'");
       x = new OPLHeapNClob(((NClob)x).getSubString(0L, (int)((NClob)x).length()));
       r.setColData(columnIndex, x);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel, NClob nClob) throws SQLException
  {
    updateNClob (findColumn (columnLabel), nClob);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>NClob</code> object representing the SQL
     *         <code>NCLOB</code> value in the specified column
     * @exception SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized NClob getNClob(int columnIndex) throws SQLException
  {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof NClob)
        return (NClob)x;
      else if (x instanceof byte[])
        return new OPLHeapNClob(Bin2Hex((byte[])x));
      else
        return new OPLHeapNClob(x.toString());
    }
  }

  /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>NClob</code> object representing the SQL <code>NCLOB</code>
     * value in the specified column
     * @exception SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public NClob getNClob(String columnLabel) throws SQLException
  {
    return getNClob(findColumn (columnLabel));
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(int columnIndex) throws SQLException
  {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    if (_wasNull = (x == null)) {
      return null;
    } else {
      if (x instanceof SQLXML)
        return (SQLXML)x;
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'SQLXML'");
    }
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(String columnLabel) throws SQLException
  {
    return getSQLXML(findColumn (columnLabel));
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param xmlObject the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateSQLXML(int columnIndex, SQLXML xmlObject) throws SQLException
  {
    if (xmlObject == null)
      updateNull(columnIndex);
    else
      synchronized(this) {
       Row r = this.getRowForUpdate(columnIndex, "'updateSQLXML(...)'");
       r.setColData(columnIndex, xmlObject);
      }
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param xmlObject the column value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateSQLXML(String columnLabel, SQLXML xmlObject) throws SQLException
  {
    updateSQLXML (findColumn (columnLabel), xmlObject);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized String getNString(int columnIndex) throws SQLException
  {
    return getString(columnIndex);
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public String getNString(String columnLabel) throws SQLException
  {
    return getNString(findColumn (columnLabel));
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized java.io.Reader getNCharacterStream(int columnIndex) throws SQLException
  {
    checkColumnIndex(columnIndex);
    Object x = getCurRow().getColData(columnIndex);
    closeInputStream();
    if (_wasNull = (x == null)) {
      return (objReader = null);
    } else {
      if (x instanceof String)
        return objReader = new StringReader((String)x);
      else if (x instanceof Clob)
        return objReader = ((Clob)x).getCharacterStream();
      else if (x instanceof NClob)
        return objReader = ((NClob)x).getCharacterStream();
      else
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_convert_parameter_to_XX, "'NCharacterStream'");
    }
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public java.io.Reader getNCharacterStream(String columnLabel) throws SQLException
  {
    return getNCharacterStream (findColumn (columnLabel));
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.   The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(int columnIndex,
			     java.io.Reader x,
		     long length) throws SQLException
  {
    updateCharacterStream(columnIndex, x, (int)length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(String columnLabel,
			     java.io.Reader reader,
			     long length) throws SQLException
  {
    updateNCharacterStream (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(int columnIndex,
			   java.io.InputStream x,
			   long length) throws SQLException
  {
    updateAsciiStream(columnIndex, x, (int)length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(int columnIndex,
			    java.io.InputStream x,
			    long length) throws SQLException
  {
    updateBinaryStream(columnIndex, x, (int)length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(int columnIndex,
			     java.io.Reader x,
			     long length) throws SQLException
  {
    updateCharacterStream(columnIndex, x, (int)length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(String columnLabel,
			   java.io.InputStream x,
			   long length) throws SQLException
  {
    updateAsciiStream (findColumn (columnLabel), x, length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(String columnLabel,
			    java.io.InputStream x,
			    long length) throws SQLException
  {
    updateBinaryStream (findColumn (columnLabel), x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(String columnLabel,
			     java.io.Reader reader,
			     long length) throws SQLException
  {
    updateCharacterStream (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(int columnIndex, InputStream inputStream, long length) throws SQLException
  {
    updateBinaryStream(columnIndex, inputStream, (int)length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(String columnLabel, InputStream inputStream, long length) throws SQLException
  {
    updateBlob (findColumn (columnLabel), inputStream, length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    updateCharacterStream(columnIndex, reader, (int)length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    updateClob (findColumn (columnLabel), reader, length);
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    updateNCharacterStream(columnIndex, reader, (int)length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    updateNClob (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateNCharacterStream(columnIndex, x)");
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateNCharacterStream(columnLabel, reader)");
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateAsciiStream(columnIndex, x)");
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateBinaryStream(columnIndex, x)");
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateCharacterStream(columnIndex, x)");
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateAsciiStream(columnLabel, x)");
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateBinaryStream(columnLabel, x)");
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateCharacterStream(columnLabel, reader)");
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnIndex is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(int columnIndex, InputStream inputStream) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateBlob(columnIndex, inputStream)");
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(String columnLabel, InputStream inputStream) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateBlob(columnLabel, inputStream)");
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(int columnIndex,  Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateClob(columnIndex,  reader)");
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(String columnLabel,  Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateClob(columnLabel,  reader)");
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     *
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(int columnIndex,  Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateNClob(columnIndex,  reader)");
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnLabel is not valid; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel,  Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "updateNClob(columnLabel,  reader)");
  }


    /**
     * Returns an object that implements the given interface to allow access to
     * non-standard methods, or standard methods not exposed by the proxy.
     *
     * If the receiver implements the interface then the result is the receiver
     * or a proxy for the receiver. If the receiver is a wrapper
     * and the wrapped object implements the interface then the result is the
     * wrapped object or a proxy for the wrapped object. Otherwise return the
     * the result of calling <code>unwrap</code> recursively on the wrapped object
     * or a proxy for that result. If the receiver is not a
     * wrapper and does not implement the interface, then an <code>SQLException</code> is thrown.
     *
     * @param iface A Class defining an interface that the result must implement.
     * @return an object that implements the interface. May be a proxy for the actual implementing object.
     * @throws java.sql.SQLException If no object found that implements the interface
     * @since 1.6
     */
  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    try {
      // This works for classes that aren't actually wrapping anything
      return iface.cast(this);
    } catch (ClassCastException cce) {
      throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Unable_to_unwrap_to_XX, iface.toString());
    }
  }

    /**
     * Returns true if this either implements the interface argument or is directly or indirectly a wrapper
     * for an object that does. Returns false otherwise. If this implements the interface then return true,
     * else if this is a wrapper then return the result of recursively calling <code>isWrapperFor</code> on the wrapped
     * object. If this does not implement the interface and is not a wrapper, return false.
     * This method should be implemented as a low-cost operation compared to <code>unwrap</code> so that
     * callers can use this method to avoid expensive <code>unwrap</code> calls that may fail. If this method
     * returns true then calling <code>unwrap</code> with the same argument should succeed.
     *
     * @param iface a Class defining an interface.
     * @return true if this implements the interface or directly or indirectly wraps an object that does.
     * @throws java.sql.SQLException  if an error occurs while determining whether this is a wrapper
     * for an object with the given interface.
     * @since 1.6
     */
  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    // This works for classes that aren't actually wrapping anything
    return iface.isInstance(this);
  }

#if JDK_VER >= 17

    //------------------------- JDBC 4.1 -----------------------------------


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(int columnIndex, Class<T> type) throws SQLException
  {
    if (type == null) {
      throw new SQLException("Type parameter can not be null", "S1009");
    }
		
    if (type.equals(String.class)) {
      return (T) getString(columnIndex);
    } else if (type.equals(BigDecimal.class)) {
      return (T) getBigDecimal(columnIndex);
    } else if (type.equals(Boolean.class) || type.equals(Boolean.TYPE)) {
      return (T) Boolean.valueOf(getBoolean(columnIndex));
    } else if (type.equals(Integer.class) || type.equals(Integer.TYPE)) {
      return (T) Integer.valueOf(getInt(columnIndex));
    } else if (type.equals(Long.class) || type.equals(Long.TYPE)) {
      return (T) Long.valueOf(getLong(columnIndex));
    } else if (type.equals(Float.class) || type.equals(Float.TYPE)) {
      return (T) Float.valueOf(getFloat(columnIndex));
    } else if (type.equals(Double.class) || type.equals(Double.TYPE)) {
      return (T) Double.valueOf(getDouble(columnIndex));
    } else if (type.equals(byte[].class)) {
      return (T) getBytes(columnIndex);
    } else if (type.equals(java.sql.Date.class)) {
      return (T) getDate(columnIndex);
    } else if (type.equals(Time.class)) {
      return (T) getTime(columnIndex);
    } else if (type.equals(Timestamp.class)) {
      return (T) getTimestamp(columnIndex);
    } else if (type.equals(Clob.class)) {
      return (T) getClob(columnIndex);
    } else if (type.equals(Blob.class)) {
      return (T) getBlob(columnIndex);
    } else if (type.equals(Array.class)) {
      return (T) getArray(columnIndex);
    } else if (type.equals(Ref.class)) {
      return (T) getRef(columnIndex);
    } else if (type.equals(java.net.URL.class)) {
      return (T) getURL(columnIndex);
//		} else if (type.equals(Struct.class)) {
//				
//			} 
//		} else if (type.equals(RowId.class)) {
//			
//		} else if (type.equals(NClob.class)) {
//			
//		} else if (type.equals(SQLXML.class)) {
			
    } else {
      try {
        return (T) getObject(columnIndex);
      } catch (ClassCastException cce) {
         throw new SQLException ("Conversion not supported for type " + type.getName(), 
                    "S1009");
      }
    }
  }


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.
     * If the SQL AS clause was not specified, then the label is the name
     * of the column
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(String columnLabel, Class<T> type) throws SQLException
  {
    return getObject(findColumn(columnLabel), type);
  }
#endif

#endif
#endif

/////////////////////////////////////////////////////////////////////////////

  private Row getCurRow() {
    if (onInsertRow)
      return updateRow;
    else
      return (Row)rowsData.get(curRow);
  }

  private void check_pos(String s)  throws SQLException {
    if (isAfterLast() || isBeforeFirst())
        throw OPLMessage_x.makeException(OPLMessage_x.errx_Invalid_cursor_position);
  }

  private void check_move(String s, boolean isNext)  throws SQLException
  {
    if (onInsertRow)
      throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_call_XX_when_the_cursor_on_the_insert_row, s);
    if (!isNext && getType() == ResultSet.TYPE_FORWARD_ONLY)
      throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_call_XX_on_a_TYPE_FORWARD_ONLY_result_set, s);
  }

  private void check_InsertMode(String s)  throws SQLException
  {
    if (onInsertRow)
      throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_call_XX_when_the_cursor_on_the_insert_row, s);
  }

  private void closeInputStream()
  {
    if(objInputStream != null) {
      try {
        objInputStream.close();
      } catch(Exception _ex) {
      }
      objInputStream = null;
    }
    if(objReader != null) {
      try {
        objReader.close();
      } catch(Exception _ex) {
      }
      objReader = null;
    }
  }

  private void check_Update(String s) throws SQLException
  {
    if (getConcurrency() == ResultSet.CONCUR_READ_ONLY)
      throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_call_XX_on_a_CONCUR_READ_ONLY_result_set, s);
  }

  private int checkColumnIndex(int columnIndex) throws SQLException
  {
    if (rowSMD == null || ((curState == NOROWS || countRows == 0) && !onInsertRow) )
       throw OPLMessage_x.makeException(OPLMessage_x.errx_No_row_is_currently_available);

    if(!onInsertRow && (isAfterLast() || isBeforeFirst()))
        throw OPLMessage_x.makeException(OPLMessage_x.errx_Invalid_cursor_position);

    if (columnIndex < 1 || columnIndex > rowSMD.getColumnCount())
        throw OPLMessage_x.makeException(OPLMessage_x.errx_Column_Index_out_of_range);

    return columnIndex;
  }


  private void cancelUpdates() {
    if (updateRow != null)
       updateRow.clear();
    updateRow = null;
  }

  private Row getRowForUpdate(int columnIndex, String cmd) throws SQLException {
    check_Update(cmd);
    checkColumnIndex(columnIndex);
    if (updateRow == null) {
        updateRow = new Row(rowSMD.getColumnCount());
    }
    return updateRow;
  }


  private synchronized void updateNumber(int columnIndex, Number val, String typeName, String funcName)
      throws SQLException
  {
    Row r = this.getRowForUpdate(columnIndex, funcName);
    switch(rowSMD.getColumnType(columnIndex)) {
#if JDK_VER >= 14
      case Types.BOOLEAN:
        r.setColData(columnIndex, new Boolean((val.intValue()!=0? true:false)));
        break;
#endif
      case Types.BIT:
      case Types.TINYINT:
      case Types.SMALLINT:
      case Types.INTEGER:
      case Types.BIGINT:
      case Types.REAL:
      case Types.FLOAT:
      case Types.DOUBLE:
      case Types.DECIMAL:
      case Types.NUMERIC:
        r.setColData(columnIndex, val);
        break;
      case Types.CHAR:
      case Types.VARCHAR:
      case Types.LONGVARCHAR:
#if JDK_VER >= 16
      case Types.NCHAR:
      case Types.NVARCHAR:
      case Types.LONGNVARCHAR:
#endif
        r.setColData(columnIndex, val.toString());
        break;
      default:
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Could_not_set_XX_value_to_field, typeName);
    }
  }


  private boolean _next() throws SQLException {
    if (countRows == 0) {
      curState = NOROWS;
      return false;
    }
    if (curRow >= countRows) {
      curState = AFTERLAST;
      return false;
    }
    boolean ret = false;
    while(!ret) {
      curRow++;
      if (curRow < countRows) //WAS countRows - 1
        ret = true;
      else
        break;
      if (!showDeleted && ((Row)rowsData.get(curRow)).isDeleted)
         ret = false;
    }
    if (ret) {
       absolutePos++;
       if (curState == BEFOREFIRST) {
          curState = FIRSTROW;
       } else {
          curState = BODYROW;
          //check, if next exists
          if (curRow == countRows - 1) {
            curState = LASTROW;
          } else {
            boolean found = false;
            int i = curRow;
            while (!found) {
              i++;
              if (i < countRows)
                found = true;
              else
                break;
              if (!showDeleted && ((Row)rowsData.get(i)).isDeleted)
                 found = false;
            }
            if (!found)
              curState = LASTROW;
          }
       }
    } else {
       if (curState == LASTROW)
          absolutePos++;
       curState = AFTERLAST;
    }
    return ret;
  }

  private boolean _previous() throws SQLException {
    if (countRows == 0) {
      curState = NOROWS;
      return false;
    }
    if (curRow < 0) {
      curState = BEFOREFIRST;
      return false;
    }
    boolean ret = false;
    while(!ret) {
      curRow--;
      if (curRow >= 0)
        ret = true;
      else
        break;
      if (!showDeleted && ((Row)rowsData.get(curRow)).isDeleted)
         ret = false;
    }
    if (ret) {
       absolutePos--;
       if (curState == AFTERLAST) {
          curState = LASTROW;
       } else {
          curState = BODYROW;
          //check, if prev exists
          if (curRow == 0) {
            curState = FIRSTROW;
          } else {
            boolean found = false;
            int i = curRow;
            while (!found) {
              i--;
              if (i >= 0)
                found = true;
              else
                break;
              if (!showDeleted && ((Row)rowsData.get(i)).isDeleted)
                 found = false;
            }
            if (!found)
              curState = FIRSTROW;
          }
       }
    } else {
       if (curState == FIRSTROW)
          absolutePos--;
       curState = BEFOREFIRST;
    }
    return ret;
  }

  private boolean _first() throws SQLException {
    _beforeFirst();
    return _next();
  }

  private boolean _last() throws SQLException {
    _afterLast();
    return _previous();
  }

  private void _afterLast() throws SQLException {
    if (countRows == 0) {
      curState = NOROWS;
    } else {
      curRow = countRows;
      absolutePos = countRows - (showDeleted ? 0 : countDeleted) + 1;
      curState = AFTERLAST;
    }
  }

  private void _beforeFirst() throws SQLException {
    if (countRows == 0) {
      curState = NOROWS;
    } else {
      curRow = -1;
      absolutePos = 0;
      curState = BEFOREFIRST;
    }
  }

////////////////////////////////////////////////////////////////////////////
  private byte[] HexString2Bin (String str)
    throws SQLException
  {
    if (str == null)
      return null;

    int slen = (str.length() / 2) * 2;
    byte[] bdata = new byte[slen / 2];
    int c1, c0, i, j;

    for (i = 0, j = 0 ; i < slen; i += 2, j++)
    {
      c1 = Character.digit(str.charAt(i), 16);
      c0 = Character.digit(str.charAt(i + 1), 16);
      if ( c1 == -1 || c0 == -1)
         throw OPLMessage_x.makeException(OPLMessage_x.errx_Invalid_hex_number);
      bdata[j] = (byte) (c1 * 16 + c0);
    }
    return bdata;
  }

  private String Bin2Hex(byte[] bdata)
  {
    if (bdata == null)
       return null;
    String hex = "0123456789ABCDEF";
    StringBuffer hstr = new StringBuffer(bdata.length * 2);

    byte val;
    for (int i = 0; i < bdata.length; i++) {
      val = bdata[i];
      hstr.append(hex.charAt(val >>> 4 & 0x0F));
      hstr.append(hex.charAt(val & 0xF));
    }
    return hstr.toString();
  }


  /**
   * Convert a string in JDBC date escape format to a Date value
   *
   * @param s date in format "yyyy-mm-dd"
   * @return corresponding Date
   */
  private java.sql.Date _getDate (String s)
  {
    java.sql.Date dt = null;
    if (s == null)
       return null;
    try {
	dt = java.sql.Date.valueOf (s);
    } catch (Exception e) {
    }
    if (dt == null)
      {
	try {
	    java.text.DateFormat df = java.text.DateFormat.getDateInstance();
	    java.util.Date juD = df.parse (s);
	    dt = new java.sql.Date (juD.getTime());
        } catch (Exception e) {
        }
      }
    return dt;
  }


  /**
   * Convert a string in JDBC timestamp escape format to a Timestamp value
   *
   * @param s timestamp in format "yyyy-mm-dd hh:mm:ss.fffffffff"
   * @return corresponding Timestamp
   */
  private java.sql.Timestamp _getTimestamp (String s)
  {
    java.sql.Timestamp ts = null;

    if (s == null)
      return null;
    try {
	ts = java.sql.Timestamp.valueOf (s);
    } catch (Exception e) {
    }
    if (ts == null)
      {
	try {
	    java.text.DateFormat df = java.text.DateFormat.getDateInstance();
	    java.util.Date juD = df.parse (s);
	    ts = new java.sql.Timestamp (juD.getTime());
        } catch (Exception e) {
        }
      }
    return ts;
  }


  /**
   * Convert a string in JDBC time escape format to a Time value
   *
   * @param s time in format "hh:mm:ss"
   * @return corresponding Time
   */
  private java.sql.Time _getTime (String s)
  {
    java.sql.Time tm = null;

    if (s == null)
       return null;
    try {
	tm = java.sql.Time.valueOf (s);
    } catch (Exception e) {
    }
    if (tm == null)
      {
	try {
	    java.text.DateFormat df = java.text.DateFormat.getTimeInstance();
	    java.util.Date juD = df.parse(s);
	    tm = new java.sql.Time(juD.getTime());
        } catch (Exception e) {
        }
      }
    return tm;
  }




////////////////////////////////////////////////////////////////////////////
  ////////Inner class/////////////
  protected class Row implements Serializable, Cloneable {
    private Object[] origData;  // original data
    private Object[] curData;   // current data for a changed rows
    private BitSet   colUpdated;
    private int cols;
    protected boolean isDeleted;
    protected boolean isUpdated;
    protected boolean isInserted;

    private Row(int count) {
      origData = new Object[count];
      curData  = new Object[count];
      colUpdated = new BitSet(count);
      cols = count;
    }

    private Row(Object[] data) {
      cols = data.length;
      origData = new Object[cols];
      curData  = new Object[cols];
      colUpdated = new BitSet(cols);
      for(int i = 0; i < cols; i++)
        origData[i] = data[i];
    }

    private void clear() {
      for(int i = 0; i < cols; i++) {
        origData[i] = null;
        curData[i] = null;
        colUpdated.clear(i);
      }
      cols = 0;
    }

    private void setOrigColData(int col, Object data) {
      origData[col - 1] = data;
    }

    private boolean isColUpdated(int col) {
      return colUpdated.get(col - 1);
    }

    private Object getColData(int col) {
      col--;
      if (colUpdated.get(col))
        return curData[col];
      else
        return origData[col];
    }

    private void setColData(int col, Object data) {
      col--;
      colUpdated.set(col);
      curData[col] = data;
    }

    private Object[] getOrigData() {
      return origData;
    }

    private Object[] getCurData() {
      return curData;
    }

    private BitSet getListUpdatedCols() {
      return colUpdated;
    }

    private void update(Object[] data, BitSet changedCols) {
      if (data.length != cols) //DROPME  || colUpdated.size() != cols)
        throw new IllegalArgumentException();
      isUpdated = true;
      for (int i = 0; i < cols; i++)
        if (changedCols.get(i)) {
          colUpdated.set(i);
          curData[i] = data[i];
        }
    }

    private void clearUpdated() {
      isUpdated = false;
      for(int i = 0; i < cols; i++) {
        curData[i] = null;
        colUpdated.clear(i);
      }
    }

    private boolean isCompleted() throws SQLException {
      if (rowSMD == null)
        return false;
      for(int i = 0; i < cols; i++) {
         if(!colUpdated.get(i) && rowSMD.isNullable(i + 1) == 0)
            return false;
      }
      return true;
    }

    private void moveCurToOrig() {
      for(int i = 0; i < cols; i++)
        if( colUpdated.get(i)) {
            origData[i] = curData[i];
            colUpdated.clear(i);
            curData[i] = null;
          }
      isUpdated = false;
      isInserted = false;
    }
  }

  ////////////Inner class ///////////////////////
  private class Scanner {
      int pos;
      int end;
      char[] query;
      final static String blankChars = " \t\n\r\f";
      final static String symb = "_-$#";
#if JDK_VER >= 16
      HashMap<String,Integer> keywords = new HashMap<String,Integer>();
#else
      HashMap keywords = new HashMap();
#endif
      Token tok = null;

    private Scanner(String sql) {
      pos = 0;
      query = sql.toCharArray();
      end = query.length - 1;

      keywords.put("SELECT", new Integer(Token.T_SELECT));
      keywords.put("FROM", new Integer(Token.T_FROM));
      keywords.put("WHERE", new Integer(Token.T_WHERE));
      keywords.put("ORDER", new Integer(Token.T_ORDER));
      keywords.put("BY", new Integer(Token.T_BY));
      keywords.put("GROUP", new Integer(Token.T_GROUP));
      keywords.put("UNION", new Integer(Token.T_UNION));
      keywords.put("HAVING", new Integer(Token.T_HAVING));
    }

    //  select_stmt =  SELECT [ ALL | DISTINCT ] select_item { "," select_item }
    //                 FROM   table_ref { "," table_ref }
    //               [ WHERE  expr ]
    //               [ GROUP BY column_ref { "," column_ref } ]
    //               [ HAVING expr ]
    //               [ ORDER BY order_item { "," order_item } ]
    private String check_Select() {
      String tableName = null;

      if ((tok = nextToken()) == null || tok.type != Token.T_SELECT)
        return null;

      while((tok = nextToken()) != null) {
        if (tok.type == Token.T_FROM)
          break;
      }

      // table_ref :
      //             table_name
      //           | table_name correlation_name
      if ((tableName = table_name()) == null)
        return null;

      //we are already on the next token
      if (tok == null)
        //SELECT select_item { "," select_item } FROM table_name
        return tableName;

      // looks for 'correlation_name'
      if (tok.type == Token.T_STRING) {
          if ((tok = nextToken()) == null)
             //SELECT select_item { "," select_item } FROM table_name corr_name
             return tableName;
      }

      if (tok.type == Token.T_WHERE) {
        while((tok = nextToken()) != null) {
          if (tok.type == Token.T_GROUP || tok.type == Token.T_HAVING)
            break;
        }
      } else {
        return null;
      }

      if (tok != null)
        return null;
      else
        return tableName;

    }

    // table_name :
    //      STRING
    //    | STRING '.' STRING   /* Qualifier '.' TableIdent */
    //    | STRING '@' STRING   /* TableIdent '@' Qualifier  (Oracle) */
    //    | STRING ':' STRING   /* Qualifier ':' TableIdent (Informix) */
    //    | STRING '.' '.' STRING   /* Qualifier '.' '.' TableIdent */
    //    | STRING '.' STRING '.' STRING  /* Qualifier '.' Owner '.' TableIdent */
    //    | STRING '.' STRING '@' STRING  /* Owner '.' TableIdent '@' Qualifier */
    //    | STRING ':' STRING '.' STRING  /* Qualifier ':' Owner '.' TableIdent (Informix) */
    private String table_name() {
      int state = 0;
      StringBuffer table = new StringBuffer();
      while((tok = nextToken()) != null) {
        switch (state) {
          case 0:
              if (tok.type == Token.T_STRING) {
                // STRING
                state = 1;
                table.append(new String(query, tok.start, tok.length));
              } else
                // XXX
                return null; //ERROR
              break;
          case 1: // STRING
              switch(tok.type) {
                case Token.T_DOT:  // STRING '.'
                      table.append('.');
                      state = 2;
                      break;
                case Token.T_DELIM: // STRING '@'
                      table.append('@');
                      state = 3;
                      break;
                case Token.T_COLON:  // STRING ':'
                      table.append(':');
                      state = 4;
                      break;
                default: // STRING XXX
                      return table.toString();
              }
              break;
          case 2: // STRING '.'
              switch(tok.type) {
                case Token.T_STRING: // STRING '.' STRING
                      table.append(new String(query, tok.start, tok.length));
                      state = 5;
                      break;
                case Token.T_DOT: // STRING '.' '.'
                      table.append('.');
                      state = 6;
                      break;
               default: // STRING '.' XXX
                      return null; //ERROR
              }
              break;
          case 3: // STRING '@'
              if (tok.type == Token.T_STRING) {
                 // STRING '@' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 99;
              } else {
                 // STRING '@' XXX
                 return null; // ERROR
              }
              break;
          case 4: // STRING ':'
              if (tok.type == Token.T_STRING) {
                 // STRING ':' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 7;
              } else {
                 // STRING ':' XXX
                 return null; // ERROR
              }
              break;

          case 5: // STRING '.' STRING
              switch(tok.type) {
                case Token.T_DOT: // STRING '.' STRING '.'
                      table.append('.');
                      state = 8;
                      break;
                case Token.T_DELIM: // STRING '.' STRING '@'
                      table.append('@');
                      state = 9;
                      break;
                default: // STRING '.' STRING XXX
                      return table.toString();
              }
              break;
          case 6: // STRING '.' '.'
              if (tok.type == Token.T_STRING) {
                 // STRING '.' '.' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 99;
              } else {
                 // STRING '.' '.' XXX
                 return null; //ERROR
              }
              break;
          case 7: // STRING ':' STRING
              if (tok.type == Token.T_DOT) {
                 // STRING ':' STRING '.'
                 table.append('.');
                 state = 10;
              } else {
                 // STRING ':' STRING XXX
                 return table.toString();
              }
              break;
          case 8: // STRING '.' STRING '.'
              if (tok.type == Token.T_STRING) {
                 // STRING '.' STRING '.' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 99;
              } else {
                 // STRING '.' STRING '.' XXX
                 return null; //ERROR
              }
              break;
          case 9: // STRING '.' STRING '@'
              if (tok.type == Token.T_STRING) {
                 // STRING '.' STRING '@' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 99;
              } else {
                 // STRING '.' STRING '@' XXX
                 return null; //ERROR
              }
              break;
          case 10:// STRING ':' STRING '.'
              if (tok.type == Token.T_STRING) {
                 // STRING ':' STRING '.' STRING
                 table.append(new String(query, tok.start, tok.length));
                 state = 99;
              } else {
                // STRING ':' STRING '.' XXX
                return null; //ERROR
              }
              break;

          case 99: //END
              return table.toString();
          default:
              return null; //ERROR
        }
      }
      if (state == 1 || state == 5 || state == 7 || state == 99)
        return table.toString();
      else
        return null; //ERROR
    }

    /*** for debug only
    private void parseSQL() {
      Token tok;
      while((tok = nextToken()) != null) {
        System.out.println(tok);
      }
    }
    *****/

    private Token nextToken() {
      int start;
      while (pos <= end) {
        while(pos <= end && isBlank(query[pos]))   pos++;
        if (pos > end)
          return null;
        switch(query[pos++]) {
          case '.': return new Token(Token.T_DOT);
          case ':': return new Token(Token.T_COLON);
          case '@': return new Token(Token.T_DELIM);
          case ',': return new Token(Token.T_COMMA);

          case '\'':
          case '\"':
              {
                char ch = query[pos - 1];
                start = pos - 1;
                if (pos <= end && (query[pos] == '_' || Character.isLetterOrDigit(query[pos]))) {
                   while(pos <= end && isLetterOrDigit(query[pos]))  pos++;
                   if (pos > end || (pos <= end && query[pos] != ch)) {
                      return new Token(Token.T_ERROR);
                   } else {
                      pos++;
                      return new Token(Token.T_STRING, start, pos - 1, true);
                   }
                } else
                   return new Token(Token.T_ERROR);
              }
          default:
             start = pos - 1;
             if (pos <= end && (query[pos] == '_' || Character.isLetterOrDigit(query[pos]))) {
                while(pos <= end && isLetterOrDigit(query[pos]))  pos++;
                Object tok_type = keywords.get(new String(query, start, pos - start).toUpperCase());
                if (tok_type != null)
                   return new Token(((Integer)tok_type).intValue(), start, pos - 1);
                else
                   return new Token(Token.T_STRING, start, pos - 1);
             } else
                return new Token(query[start]);
        }
      }
      return null;
    }


    private boolean isBlank(int ch) {
      return (blankChars.indexOf(ch) != -1);
    }

    private boolean isLetterOrDigit(int ch) {
      return (Character.isLetterOrDigit((char)ch) || symb.indexOf(ch) != -1);
    }

    //////////// Inner class /////////////////////////////////////////
    private class Token {
        final static int T_ERROR = -1;
        final static int T_CHAR = 0;
        final static int T_DOT = 1;
        final static int T_COLON = 2;
        final static int T_DELIM = 3;
        final static int T_COMMA = 4;
        final static int T_STRING = 5;
        final static int T_SELECT = 6;
        final static int T_FROM = 7;
        final static int T_WHERE = 8;
        final static int T_ORDER = 9;
        final static int T_BY = 10;
        final static int T_GROUP = 11;
        final static int T_UNION = 12;
        final static int T_HAVING = 13;

        private int type;
        private int start;
        private int end;
        private int length;
        private boolean quoted;
        private char symbol;

        private Token(int _type, int _start, int _end) {
          type = _type;
          start = _start;
          end = _end;
          length = end - start + 1;
        }

        private Token(int _type, int _start, int _end, boolean _quoted) {
          this(_type, _start, _end);
          quoted = _quoted;
        }

        private Token(int _type) {
          type = _type;
        }

        private Token(char _symbol) {
          type = T_CHAR;
          symbol = _symbol;
        }

        /**** for debug only
        public String toString() {
           switch(type) {
            case Token.T_ERROR:
              return "T_ERROR";
            case Token.T_CHAR:
              return "T_CHAR =>"+symbol;
            case Token.T_DOT:
              return "T_DOT";
            case Token.T_COLON:
              return "T_COLON";
            case Token.T_DELIM:
              return "T_DELIM";
            case Token.T_COMMA:
              return "T_COMMA";
            case Token.T_STRING:
              return "T_STRING ="+ (new String(query, start, length));

            case Token.T_SELECT:
              return "T_SELECT";
            case Token.T_FROM:
              return "T_FROM";
            case Token.T_WHERE:
              return "T_WHERE";
            case Token.T_ORDER:
              return "T_ORDER";
            case Token.T_BY:
              return "T_BY";
            case Token.T_GROUP:
              return "T_GROUP";
            case Token.T_UNION:
              return "T_UNION";
            case Token.T_HAVING:
              return "T_HAVING";
            default:
              return "?UNKNOWN?";
           }
        }
        ***********/
    }
  }


  /////////////Inner class//////////////////////
  private class RowSetReader implements Serializable, Cloneable {
    private transient Connection conn;

    protected Connection connect(RowSet rowSet) throws SQLException {
      String connName;
      if ((connName = rowSet.getDataSourceName()) != null)
        try {
          InitialContext initialcontext = new InitialContext();
          DataSource ds = (DataSource)initialcontext.lookup(connName);
          return ds.getConnection(rowSet.getUsername(), rowSet.getPassword());
        } catch(NamingException e) {
          throw OPLMessage_x.makeException(e);
        }
      else if((connName = rowSet.getUrl()) != null)
        return DriverManager.getConnection(connName, rowSet.getUsername(), rowSet.getPassword());
      else
        return null;
      }

    private void setParams(PreparedStatement pstmt, Object[] params) throws SQLException {
      if (params == null)
        return;

      for(int i = 0; i < params.length; i++) {
        BaseRowSet.Parameter par = (BaseRowSet.Parameter)params[i];
        switch(par.jType) {
          case Parameter.jObject:
              pstmt.setObject(i + 1, par.value);
              break;
          case Parameter.jObject_1:
              pstmt.setObject(i + 1, par.value, par.sqlType);
              break;
          case Parameter.jObject_2:
              pstmt.setObject(i + 1, par.value, par.sqlType, par.scale);
              break;
          case Parameter.jAsciiStream:
              pstmt.setAsciiStream(i + 1, (InputStream)par.value, par.length);
              break;
          case Parameter.jBinaryStream:
              pstmt.setBinaryStream(i + 1, (InputStream)par.value, par.length);
              break;
          case Parameter.jUnicodeStream:
              pstmt.setUnicodeStream(i + 1, (InputStream)par.value, par.length);
              break;
          case Parameter.jCharacterStream:
              pstmt.setCharacterStream(i + 1, (Reader)par.value, par.length);
              break;
          case Parameter.jDateWithCalendar:
              pstmt.setDate(i + 1, (Date)par.value, par.cal);
              break;
          case Parameter.jTimeWithCalendar:
              pstmt.setTime(i + 1, (Time)par.value, par.cal);
              break;
          case Parameter.jTimestampWithCalendar:
              pstmt.setTimestamp(i + 1, (Timestamp)par.value, par.cal);
              break;
          case Parameter.jNull_1:
              pstmt.setNull(i + 1, par.sqlType);
              break;
          case Parameter.jNull_2:
              pstmt.setNull(i + 1, par.sqlType, par.typeName);
              break;
          default:
            throw OPLMessage_x.makeException(OPLMessage_x.errx_Unknown_type_of_parameter);
        }
      }
    }

    private void readData(RowSetInternal x) throws java.sql.SQLException {
      boolean doDisconnect = false;
      close();
      try {
        OPLCachedRowSet crs = (OPLCachedRowSet)x;
        crs.release();
        conn = x.getConnection();
        if (conn == null) {
          conn = connect(crs);
          doDisconnect = true;
        }
        if (conn == null || crs.getCommand() == null)
          throw OPLMessage_x.makeException(OPLMessage_x.errx_SQL_query_is_undefined);

        try {
          conn.setTransactionIsolation(crs.getTransactionIsolation());
        } catch(Exception e) { }

        PreparedStatement pstmt = conn.prepareStatement(crs.getCommand(),
          crs.getType(), crs.getConcurrency());
        setParams(pstmt, x.getParams());

        try {
          pstmt.setMaxRows(crs.getMaxRows());
          pstmt.setMaxFieldSize(crs.getMaxFieldSize());
          pstmt.setEscapeProcessing(crs.getEscapeProcessing());
          pstmt.setQueryTimeout(crs.getQueryTimeout());
        } catch(Exception e) { }

        ResultSet rs = pstmt.executeQuery();
        crs.populate(rs);
        rs.close();
        pstmt.close();

        try {
          conn.commit();
        } catch(SQLException e) { }

      } finally {
        if (conn != null && doDisconnect)
          conn.close();
        else
          conn = null;
      }
    }

    private void close() throws SQLException {
      if (conn != null)
        conn.close();
      conn = null;

    }
  }

  /////////////Inner class//////////////////////
  private class RowSetWriter implements Serializable, Cloneable {
    private transient Connection conn;
    private String updateSQL;
    private String deleteSQL;
    private String insertSQL;
    private int[]  keyCols;
    private ResultSetMetaData rsmd;
    private int colCount;
#if JDK_VER >= 16
    private LinkedList<Object> params = new LinkedList<Object>();
#else
    private LinkedList params = new LinkedList();
#endif

    private boolean writeData(RowSetInternal x) throws java.sql.SQLException {
      OPLCachedRowSet crs = (OPLCachedRowSet)x;
      boolean showDel = false;
      boolean conflict = false;
      conn = crs.rowSetReader.connect(crs);
      if (conn == null)
        throw OPLMessage_x.makeException(OPLMessage_x.errx_Unable_to_get_a_Connection);
      if (conn.getAutoCommit())
        conn.setAutoCommit(false);
      conn.setTransactionIsolation(crs.getTransactionIsolation());

      initializeStmts(crs);

      showDel = crs.getShowDeleted();
      crs.setShowDeleted(true);

      try {
        crs.beforeFirst();
        while(!conflict && crs.next()) {
          if (crs.rowDeleted() && !crs.rowInserted())
            conflict = doDelete(crs);
        }

        crs.beforeFirst();
        while(!conflict && crs.next()) {
          if (crs.rowUpdated() && !crs.rowDeleted() && !crs.rowInserted())
            conflict = doUpdate(crs);
        }

        PreparedStatement pstmtInsert = conn.prepareStatement(insertSQL);
        try {
          pstmtInsert.setMaxFieldSize(crs.getMaxFieldSize());
          pstmtInsert.setEscapeProcessing(crs.getEscapeProcessing());
          pstmtInsert.setQueryTimeout(crs.getQueryTimeout());
        } catch (Exception e) { }

        crs.beforeFirst();
        while(!conflict && crs.next()) {
          if (crs.rowInserted() && !crs.rowDeleted())
            conflict = doInsert(pstmtInsert, crs);
        }
        try {
          pstmtInsert.close();
        } catch (Exception e) { }


      } finally {
        crs.setShowDeleted(showDel);
      }

      try {
        if (conflict) {
          conn.rollback();
          return false;
        }
        conn.commit();
        return true;
      } finally {
        crs.rowSetReader.close();
        conn = null;
        rsmd = null;
        params.clear();
      }
    }


    private boolean doUpdate(OPLCachedRowSet crs) throws SQLException {
      ResultSet rs_orig = crs.getOriginalRow();
      if (!rs_orig.next())
        return true; //ERROR , data isn't found

      StringBuffer tmpSQL = new StringBuffer(updateSQL);
#if JDK_VER >= 16
      LinkedList<Object> setData = new LinkedList<Object>();
#else
      LinkedList setData = new LinkedList();
#endif
      boolean comma = false;
      for (int i = 1; i <= colCount; i++)
        if (crs.columnUpdated(i)) {
          if (!comma)
            comma = true;
          else
            tmpSQL.append(", ");
          tmpSQL.append(rsmd.getColumnName(i));
          tmpSQL.append(" = ? ");
          setData.add(new Integer(i));
        }

      tmpSQL.append(" WHERE ");
      tmpSQL.append(createWhere(keyCols, rs_orig));
      PreparedStatement pstmt = conn.prepareStatement(tmpSQL.toString());
      try {
        pstmt.setMaxFieldSize(crs.getMaxFieldSize());
        pstmt.setEscapeProcessing(crs.getEscapeProcessing());
        pstmt.setQueryTimeout(crs.getQueryTimeout());
      } catch (Exception e) { }

      int par = 0;

      //put new data values
      for (Iterator i = setData.iterator(); i.hasNext(); ) {
        int col = ((Integer)i.next()).intValue();
        Object x = crs.getObject(col);
        if (crs.wasNull())
          pstmt.setNull(++par, rsmd.getColumnType(col));
        else
          pstmt.setObject(++par, x);
      }

      //put data for where clause
      for (Iterator i = params.iterator(); i.hasNext(); )
        pstmt.setObject(++par, i.next());

      if (pstmt.executeUpdate() != 1)
        return true; //ERROR , data wasn't updated

      pstmt.close();
      return false;
    }

    private boolean doInsert(PreparedStatement insertPStmt, OPLCachedRowSet crs)
      throws SQLException
    { //FIXME  rewrite via BATCHES
      for (int i = 1; i <= colCount; i++) {
        Object x = crs.getObject(i);
        if (crs.wasNull())
          insertPStmt.setNull(i, rsmd.getColumnType(i));
        else
          insertPStmt.setObject(i, x);
      }

      if (insertPStmt.executeUpdate() != 1)
        return true; //ERROR , data wasn't inserted

      return false;
    }

    private boolean doDelete(OPLCachedRowSet crs) throws SQLException {
      ResultSet rs = crs.getOriginalRow();
      if (!rs.next())
        return true; //ERROR , data isn't found

      String delWhere = createWhere(keyCols, rs);
      PreparedStatement pstmt = conn.prepareStatement(deleteSQL + delWhere);
      try {
        pstmt.setMaxFieldSize(crs.getMaxFieldSize());
        pstmt.setEscapeProcessing(crs.getEscapeProcessing());
        pstmt.setQueryTimeout(crs.getQueryTimeout());
      } catch (Exception e) { }

      int par = 0;
      for (Iterator i = params.iterator(); i.hasNext(); )
        pstmt.setObject(++par, i.next());

      if (pstmt.executeUpdate() != 1)
        return true; //ERROR , data wasn't deleted

      pstmt.close();
      return false;
    }

    private String createWhere(int[] keys, ResultSet rs) throws SQLException {
      StringBuffer tmp = new StringBuffer();
      params.clear();
      for (int i = 0; i < keys.length; i++) {
        if (i > 0)
          tmp.append("AND ");

        tmp.append(rsmd.getColumnName(keys[i]));
        Object x = rs.getObject(keys[i]);
        if (rs.wasNull()) {
          tmp.append(" IS NULL ");
        } else {
          tmp.append(" = ? ");
          params.add(x);
        }
      }
      return tmp.toString();
    }

    private void  initializeStmts(OPLCachedRowSet crs) throws SQLException {
      if ((rsmd = crs.getMetaData()) == null)
        throw OPLMessage_x.makeException(OPLMessage_x.errx_RowSetMetaData_is_not_defined);

      if ((colCount = rsmd.getColumnCount()) < 1)
        return;

      DatabaseMetaData dbmd = conn.getMetaData();
      String tableName = crs.getTableName();
      if (tableName == null) {
        String schName = rsmd.getSchemaName(1);
        if (schName != null && schName.length() == 0)
          schName = null;
        String tabName = rsmd.getTableName(1);
        if (tabName == null || (tabName != null && tabName.length() == 0))
          throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_XX_can_not_determine_the_table_name, "'RowSetWriter'");
        tableName = schName + "." + tabName;
      }
      StringBuffer _updateSQL = new StringBuffer("UPDATE ");
      StringBuffer _insertSQL = new StringBuffer("INSERT INTO ");
      StringBuffer _deleteSQL = new StringBuffer("DELETE FROM ");
      StringBuffer listColName = new StringBuffer();
      StringBuffer fullListParm = new StringBuffer();
      for (int i = 1; i <= colCount; i++) {
        if (i > 1) {
          listColName.append(", ");
          fullListParm.append(", ");
        } else {
          listColName.append(" ");
          fullListParm.append(" ");
        }
        listColName.append(rsmd.getColumnName(i));
        fullListParm.append('?');
      }

      _updateSQL.append(tableName);
        _updateSQL.append(" SET ");

      _deleteSQL.append(tableName);
        _deleteSQL.append(" WHERE ");

      _insertSQL.append(tableName);
        _insertSQL.append("(");
        _insertSQL.append(listColName.toString());
        _insertSQL.append(") VALUES ( ");
        _insertSQL.append(fullListParm.toString());
        _insertSQL.append(")");

      insertSQL = _insertSQL.toString();
      updateSQL = _updateSQL.toString();
      deleteSQL = _deleteSQL.toString();

      setKeyCols(crs);

    }

    private void setKeyCols(OPLCachedRowSet crs) throws SQLException {
      keyCols = crs.getKeyCols();
      if (keyCols == null || keyCols.length == 0) {
        int count = 0;
        int[] tmpCols = new int[colCount];
        for (int i = 1; i <= colCount; i++)
          switch(rsmd.getColumnType(i)) {
            case Types.BIGINT:
            case Types.TINYINT:
            case Types.SMALLINT:
            case Types.INTEGER:
            case Types.REAL:
            case Types.FLOAT:
            case Types.DOUBLE:
            case Types.DECIMAL:
            case Types.NUMERIC:
            case Types.BIT:
#if JDK_VER >= 14
            case Types.BOOLEAN:
#endif
            case Types.CHAR:
            case Types.VARCHAR:
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.DATE:
            case Types.TIME:
            case Types.TIMESTAMP:
#if JDK_VER >= 14
            case Types.DATALINK:
#endif
#if JDK_VER >= 16
            case Types.NCHAR:
            case Types.ROWID:
            case Types.NVARCHAR:
#endif
            case Types.DISTINCT:
              tmpCols[count++] = i;
              break;
          }
        if (count > 0) {
          keyCols = new int[count];
          System.arraycopy(tmpCols, 0, keyCols, 0, count);
        }
      }
      if (keyCols == null && keyCols.length == 0)
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_XX_can_not_determine_the_keyCols, "'RowSetWriter'");
    }

  }
}
