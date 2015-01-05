/*
 *  $Id$
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
 */

package virtuoso.javax;

import javax.sql.RowSetMetaData;
import java.sql.*;
import java.io.Serializable;


/**
 * <P>The RowSetMetaData interface extends ResultSetMetaData with
 * methods that allow a metadata object to be initialized.
 */

public class OPLRowSetMetaData implements RowSetMetaData, Serializable {

  private static final long serialVersionUID = 4491018005954285242L;

  private Coldesc[] desc;

  public OPLRowSetMetaData(ResultSetMetaData rsmd) throws SQLException {
    int count = rsmd.getColumnCount();
    setColumnCount(count);
    for(int i = 0; i < count; i++){
        int col = i + 1;
        String v;
        desc[i].columnLabel = rsmd.getColumnLabel(col);
        desc[i].columnName = rsmd.getColumnName(col);
        v = rsmd.getSchemaName(col);
          desc[i].schemaName = ( v != null ? v : "");
        v = rsmd.getTableName(col);
          desc[i].tableName = ( v != null ? v : "");
        v = rsmd.getCatalogName(col);
        desc[i].catalogName = ( v != null ? v : "");
        desc[i].typeName = rsmd.getColumnTypeName(col);
        desc[i].type = rsmd.getColumnType(col);
        desc[i].precision = rsmd.getPrecision(col);
        desc[i].scale = rsmd.getScale(col);
        desc[i].displaySize = rsmd.getColumnDisplaySize(col);
        desc[i].isAutoIncrement = rsmd.isAutoIncrement(col);
        desc[i].isCaseSensitive = rsmd.isCaseSensitive(col);
        desc[i].isCurrency = rsmd.isCurrency(col);
        desc[i].nullable = rsmd.isNullable(col);
        desc[i].isSigned = rsmd.isSigned(col);
        desc[i].isSearchable = rsmd.isSearchable(col);
        desc[i].isDefinitelyWritable = rsmd.isDefinitelyWritable(col);
        desc[i].isReadOnly = rsmd.isReadOnly(col);
        desc[i].isWritable = rsmd.isWritable(col);
    }
  }

  /**
   * Specify whether the is column automatically numbered, thus read-only.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either true or false (default is false).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setAutoIncrement(int column, boolean property) throws java.sql.SQLException {
    check_index(column).isAutoIncrement = property;
  }

  /**
   * Specify whether the column is case sensitive.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either true or false (default is false).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setCaseSensitive(int column, boolean property) throws java.sql.SQLException {
    check_index(column).isCaseSensitive = property;
  }

  /**
   * Specify the column's table's catalog name, if any.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param catalogName column's catalog name.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setCatalogName(int column, String catalogName) throws java.sql.SQLException {
    if (catalogName != null)
      check_index(column).catalogName = catalogName;
    else
      check_index(column).catalogName = "";
  }

  /**
   * Set the number of columns in the RowSet.
   *
   * @param columnCount number of columns.
   * @exception SQLException if a database-access error occurs.
   */
  public void setColumnCount(int columnCount) throws SQLException {
    if (columnCount <= 0)
       throw OPLMessage_x.makeException(OPLMessage_x.errx_Invalid_column_count);
    desc = new Coldesc[columnCount];
    for(int i = 0; i < columnCount; i++)
       desc[i] = new Coldesc();
  }

  /**
   * Specify the column's normal max width in chars.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param size size of the column
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setColumnDisplaySize(int column, int size) throws java.sql.SQLException {
    check_index(column).displaySize = size;
  }

  /**
   * Specify the suggested column title for use in printouts and
   * displays, if any.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param label the column title
   * @exception SQLException if a database-access error occurs.
   */
  public void setColumnLabel(int column, String label) throws java.sql.SQLException {
    check_index(column).columnLabel = label;
  }

  /**
   * Specify the column name.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param columnName the column name
   * @exception SQLException if a database-access error occurs.
   */
  public void setColumnName(int column, String columnName) throws java.sql.SQLException {
    check_index(column).columnName = columnName;
  }

  /**
   * Specify the column's SQL type.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param SQLType column's SQL type.
   * @exception SQLException if a database-access error occurs.
   * @see Types
   */
  public void setColumnType(int column, int SQLType) throws java.sql.SQLException {
    check_index(column).type = SQLType;
  }

  /**
   * Specify the column's data source specific type name, if any.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param typeName data source specific type name.
   * @exception SQLException if a database-access error occurs.
   */
  public void setColumnTypeName(int column, String typeName) throws java.sql.SQLException {
    check_index(column).typeName = typeName;
  }

  /**
   * Specify whether the column is a cash value.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either true or false (default is false).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setCurrency(int column, boolean property) throws java.sql.SQLException {
    check_index(column).isCurrency = property;
  }

  /**
   * Specify whether the column's value can be set to NULL.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either one of columnNoNulls, columnNullable
   *   or columnNullableUnknown (default is columnNullableUnknown).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setNullable(int column, int property) throws java.sql.SQLException {
    check_index(column).nullable = property;
  }

  /**
   * Specify the column's number of decimal digits.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param precision number of decimal digits.
   * @exception SQLException if a database-access error occurs.
   */
  public void setPrecision(int column, int precision) throws java.sql.SQLException {
    check_index(column).precision = precision;
  }

  /**
   * Specify the column's number of digits to right of the decimal point.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param scale number of digits to right of decimal point.
   * @exception SQLException if a database-access error occurs.
   */
  public void setScale(int column, int scale) throws java.sql.SQLException {
    check_index(column).scale = scale;
  }

  /**
   * Specify the column's table's schema, if any.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param schemaName the schema name
   * @exception SQLException if a database-access error occurs.
   */
  public void setSchemaName(int column, String schemaName) throws java.sql.SQLException {
    if (schemaName != null)
      check_index(column).schemaName = schemaName;
    else
      check_index(column).schemaName = "";
  }

  /**
   * Specify whether the column can be used in a where clause.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either true or false (default is false).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setSearchable(int column, boolean property) throws java.sql.SQLException {
    check_index(column).isSearchable = property;
  }

  /**
   * Speicfy whether the column is a signed number.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param property is either true or false (default is false).
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void setSigned(int column, boolean property) throws java.sql.SQLException {
    check_index(column).isSigned = property;
  }

  /**
   * Specify the column's table name, if any.
   *
   * @param column the first column is 1, the second is 2, ...
   * @param tableName column's table name.
   * @exception SQLException if a database-access error occurs.
   */
  public void setTableName(int column, String tableName) throws java.sql.SQLException {
    if (tableName != null)
      check_index(column).tableName = tableName;
    else
      check_index(column).tableName = "";
  }

  /**
   * Returns the number of columns in this RowSet
   *
   * @return the number of columns
   * @exception SQLException if a database access error occurs
   */
  public int getColumnCount() throws SQLException {
    return (desc != null ? desc.length : 0);
  }

  /**
   * Indicates whether the column is automatically numbered, thus read-only.
   *
   * @param column the first column is 1, the second is 2, ...
   * @return true if so
   * @exception SQLException if a database access error occurs
   */
  public boolean isAutoIncrement(int column) throws SQLException {
    return check_index(column).isAutoIncrement;
  }

  /**
   * Indicates whether a column's case matters.
   *
   * @param column the first column is 1, the second is 2, ...
   * @return <code>true</code> if so; <code>false</code> otherwise
   * @exception SQLException if a database access error occurs
   */
  public boolean isCaseSensitive(int column) throws SQLException {
    return check_index(column).isCaseSensitive;
  }

  /**
   * Indicates whether the designated column can be used in a where clause.
   *
   * @param column the first column is 1, the second is 2, ...
   * @return <code>true</code> if so; <code>false</code> otherwise
   * @exception SQLException if a database access error occurs
   */
  public boolean isSearchable(int column) throws SQLException {
    return check_index(column).isSearchable;
  }

  /**
   * Indicates whether the designated column is a cash value.
   *
   * @param column the first column is 1, the second is 2, ...
   * @return <code>true</code> if so; <code>false</code> otherwise
   * @exception SQLException if a database access error occurs
   */
  public boolean isCurrency(int column) throws SQLException {
    return check_index(column).isCurrency;
  }

  /**
   * Indicates the nullability of values in the designated column.
   *
   * @param column the first column is 1, the second is 2, ...
   * @return the nullability status of the given column; one of <code>columnNoNulls</code>,
   *          <code>columnNullable</code> or <code>columnNullableUnknown</code>
   * @exception SQLException if a database access error occurs
   */
  public int isNullable(int column) throws SQLException {
    return check_index(column).nullable;
  }

    /**
     * Indicates whether values in the designated column are signed numbers.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     */
  public boolean isSigned(int column) throws SQLException {
    return check_index(column).isSigned;
  }

    /**
     * Indicates the designated column's normal maximum width in characters.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return the normal maximum number of characters allowed as the width
	 *          of the designated column
     * @exception SQLException if a database access error occurs
     */
  public int getColumnDisplaySize(int column) throws SQLException {
    return check_index(column).displaySize;
  }

    /**
     * Gets the designated column's suggested title for use in printouts and
     * displays.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return the suggested column title
     * @exception SQLException if a database access error occurs
     */
  public String getColumnLabel(int column) throws SQLException {
    return check_index(column).columnLabel;
  }

    /**
     * Get the designated column's name.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return column name
     * @exception SQLException if a database access error occurs
     */
  public String getColumnName(int column) throws SQLException {
    return check_index(column).columnName;
  }

    /**
     * Get the designated column's table's schema.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return schema name or "" if not applicable
     * @exception SQLException if a database access error occurs
     */
  public String getSchemaName(int column) throws SQLException {
    return check_index(column).schemaName;
  }

    /**
     * Get the designated column's number of decimal digits.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return precision
     * @exception SQLException if a database access error occurs
     */
  public int getPrecision(int column) throws SQLException {
    return check_index(column).precision;
  }

    /**
     * Gets the designated column's number of digits to right of the decimal point.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return scale
     * @exception SQLException if a database access error occurs
     */
  public int getScale(int column) throws SQLException {
    return check_index(column).scale;
  }

    /**
     * Gets the designated column's table name.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return table name or "" if not applicable
     * @exception SQLException if a database access error occurs
     */
  public String getTableName(int column) throws SQLException {
    return check_index(column).tableName;
  }

    /**
     * Gets the designated column's table's catalog name.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return column name or "" if not applicable
     * @exception SQLException if a database access error occurs
     */
  public String getCatalogName(int column) throws SQLException {
    return check_index(column).catalogName;
  }

    /**
     * Retrieves the designated column's SQL type.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return SQL type from java.sql.Types
     * @exception SQLException if a database access error occurs
     * @see Types
     */
  public int getColumnType(int column) throws SQLException {
    return check_index(column).type;
  }

    /**
     * Retrieves the designated column's database-specific type name.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return type name used by the database. If the column type is
	 * a user-defined type, then a fully-qualified type name is returned.
     * @exception SQLException if a database access error occurs
     */
  public String getColumnTypeName(int column) throws SQLException {
    return check_index(column).typeName;
  }

    /**
     * Indicates whether the designated column is definitely not writable.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     */
  public boolean isReadOnly(int column) throws SQLException {
    return check_index(column).isReadOnly;
  }

    /**
     * Indicates whether it is possible for a write on the designated column to succeed.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     */
  public boolean isWritable(int column) throws SQLException {
    return check_index(column).isWritable;
  }

    /**
     * Indicates whether a write on the designated column will definitely succeed.
     *
     * @param column the first column is 1, the second is 2, ...
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     */
  public boolean isDefinitelyWritable(int column) throws SQLException {
    return check_index(column).isDefinitelyWritable;
  }

    /**
     * <p>Returns the fully-qualified name of the Java class whose instances
     * are manufactured if the method <code>ResultSet.getObject</code>
	 * is called to retrieve a value
     * from the column.  <code>ResultSet.getObject</code> may return a subclass of the
     * class returned by this method.
	 *
	 * @return the fully-qualified name of the class in the Java programming
	 *         language that would be used by the method
	 * <code>ResultSet.getObject</code> to retrieve the value in the specified
	 * column. This is the class name used for custom mapping.
     * @exception SQLException if a database access error occurs
	 * @since 1.2
	 * @see <a href="package-summary.html#2.0 API">What Is in the JDBC
	 *      2.0 API</a>
     */
  public String getColumnClassName(int column) throws SQLException {
    return null;
  }


#if JDK_VER >= 16
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

#endif

  private Coldesc check_index(int column) throws SQLException
  {
    if (desc==null || column < 1 || column > desc.length)
          throw OPLMessage_x.makeException(OPLMessage_x.errx_Column_Index_out_of_range);

    return desc[column - 1];
  }


  /////////// Inner class ///////
  private class Coldesc implements Serializable {
    private String columnLabel;
    private String columnName;
    private String schemaName;
    private String tableName;
    private String catalogName;
    private String typeName;
    private int type;
    private int precision;
    private int scale;
    private int displaySize;
    private int nullable;
    private boolean isAutoIncrement;
    private boolean isCaseSensitive;
    private boolean isCurrency;
    private boolean isSigned;
    private boolean isSearchable;
    private boolean isDefinitelyWritable;
    private boolean isReadOnly;
    private boolean isWritable;
  }
}
