/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

package virtuoso.jdbc2;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class VirtuosoArray implements Array {

    ArrayList<Object> data;
    String typeName;
    int typeCode;

    private static final HashMap<String,Integer> types = new HashMap<String,Integer>();

    static {
        types.put("varchar", Types.VARCHAR);
        types.put("character", Types.CHAR);
        types.put("nvarchar", Types.VARCHAR);
        types.put("char", Types.CHAR);
        types.put("nchar", Types.CHAR);
        types.put("numeric", Types.NUMERIC);
        types.put("decimal", Types.DECIMAL);
        types.put("integer", Types.INTEGER);
        types.put("int", Types.INTEGER);
        types.put("smallint", Types.SMALLINT);
        types.put("float", Types.FLOAT);
        types.put("real", Types.REAL);
        types.put("double", Types.DOUBLE);
        types.put("varbinary", Types.VARBINARY);
        types.put("timestamp", Types.TIMESTAMP);
        types.put("datetime", Types.TIMESTAMP);
        types.put("date", Types.DATE);
        types.put("time", Types.TIME);
        types.put("any", Types.OTHER);
    }


    public VirtuosoArray(VirtuosoConnection conn, String typeName, Object[] arr_data) throws VirtuosoException{
        this.typeName = typeName;
        Integer typeId =  types.get(typeName.toLowerCase());
        typeCode = typeId!=null?typeId.intValue():Types.OTHER;

        if (arr_data!=null) {
            this.data = new ArrayList<Object>(arr_data.length);
            for(int i=0; i< arr_data.length; i++) {
                Object x = VirtuosoTypes.mapJavaTypeToSqlType(arr_data[i], typeCode);
                if (x instanceof String)
                {
                    switch(typeCode){
                        case Types.CHAR:
                        case Types.VARCHAR:
                        case Types.LONGVARCHAR:
                        case Types.CLOB:
                        case Types.OTHER:
                            this.data.add(new VirtuosoExplicitString((String)x, VirtuosoTypes.DV_ANY,conn));
                            break;
#if JDK_VER >= 16
                        case Types.NCHAR:
                        case Types.NVARCHAR:
                        case Types.LONGNVARCHAR:
                        case Types.NCLOB:
                            this.data.add(new VirtuosoExplicitString((String)x, VirtuosoTypes.DV_WIDE,conn));
                            break;
#endif
                        default:
                            this.data.add(x);
                            break;
                    }
                }
                else {
                    this.data.add(x);
                }
            }
        }
    }

    /**
     * Retrieves the SQL type name of the elements in
     * the array designated by this <code>Array</code> object.
     * If the elements are a built-in type, it returns
     * the database-specific type name of the elements.
     * If the elements are a user-defined type (UDT),
     * this method returns the fully-qualified SQL type name.
     *
     * @return a <code>String</code> that is the database-specific
     * name for a built-in base type; or the fully-qualified SQL type
     * name for a base type that is a UDT
     * @exception SQLException if an error occurs while attempting
     * to access the type name
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public String getBaseTypeName() throws SQLException {
        return typeName;
    }

    /**
     * Retrieves the JDBC type of the elements in the array designated
     * by this <code>Array</code> object.
     *
     * @return a constant from the class {@link java.sql.Types} that is
     * the type code for the elements in the array designated by this
     * <code>Array</code> object
     * @exception SQLException if an error occurs while attempting
     * to access the base type
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public int getBaseType() throws SQLException {
        return typeCode;
    }

    /**
     * Retrieves the contents of the SQL <code>ARRAY</code> value designated
     * by this
     * <code>Array</code> object in the form of an array in the Java
     * programming language. This version of the method <code>getArray</code>
     * uses the type map associated with the connection for customizations of
     * the type mappings.
     * <p>
     * <strong>Note:</strong> When <code>getArray</code> is used to materialize
     * a base type that maps to a primitive data type, then it is
     * implementation-defined whether the array returned is an array of
     * that primitive data type or an array of <code>Object</code>.
     *
     * @return an array in the Java programming language that contains
     * the ordered elements of the SQL <code>ARRAY</code> value
     * designated by this <code>Array</code> object
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public Object getArray() throws SQLException {
        return data.toArray();
    }

    /**
     * Retrieves the contents of the SQL <code>ARRAY</code> value designated by this
     * <code>Array</code> object.
     * This method uses
     * the specified <code>map</code> for type map customizations
     * unless the base type of the array does not match a user-defined
     * type in <code>map</code>, in which case it
     * uses the standard mapping. This version of the method
     * <code>getArray</code> uses either the given type map or the standard mapping;
     * it never uses the type map associated with the connection.
     * <p>
     * <strong>Note:</strong> When <code>getArray</code> is used to materialize
     * a base type that maps to a primitive data type, then it is
     * implementation-defined whether the array returned is an array of
     * that primitive data type or an array of <code>Object</code>.
     *
     * @param map a <code>java.util.Map</code> object that contains mappings
     *            of SQL type names to classes in the Java programming language
     * @return an array in the Java programming language that contains the ordered
     *         elements of the SQL array designated by this object
     * @exception SQLException if an error occurs while attempting to
     *                         access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public Object getArray(Map<String, Class<?>> map) throws SQLException {
        return getArray();
    }

    /**
     * Retrieves a slice of the SQL <code>ARRAY</code>
     * value designated by this <code>Array</code> object, beginning with the
     * specified <code>index</code> and containing up to <code>count</code>
     * successive elements of the SQL array.  This method uses the type map
     * associated with the connection for customizations of the type mappings.
     * <p>
     * <strong>Note:</strong> When <code>getArray</code> is used to materialize
     * a base type that maps to a primitive data type, then it is
     * implementation-defined whether the array returned is an array of
     * that primitive data type or an array of <code>Object</code>.
     *
     * @param index the array index of the first element to retrieve;
     *              the first element is at index 1
     * @param count the number of successive SQL array elements to retrieve
     * @return an array containing up to <code>count</code> consecutive elements
     * of the SQL array, beginning with element <code>index</code>
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public Object getArray(long index, int count) throws SQLException {
        Object[] slice = new Object[count];

        for (int i = 0; i < count; i++)
            slice[i] = data.get((int) index + i - 1);

        return slice;
    }

    /**
     * Retreives a slice of the SQL <code>ARRAY</code> value
     * designated by this <code>Array</code> object, beginning with the specified
     * <code>index</code> and containing up to <code>count</code>
     * successive elements of the SQL array.
     * <P>
     * This method uses
     * the specified <code>map</code> for type map customizations
     * unless the base type of the array does not match a user-defined
     * type in <code>map</code>, in which case it
     * uses the standard mapping. This version of the method
     * <code>getArray</code> uses either the given type map or the standard mapping;
     * it never uses the type map associated with the connection.
     * <p>
     * <strong>Note:</strong> When <code>getArray</code> is used to materialize
     * a base type that maps to a primitive data type, then it is
     * implementation-defined whether the array returned is an array of
     * that primitive data type or an array of <code>Object</code>.
     *
     * @param index the array index of the first element to retrieve;
     *              the first element is at index 1
     * @param count the number of successive SQL array elements to
     * retrieve
     * @param map a <code>java.util.Map</code> object
     * that contains SQL type names and the classes in
     * the Java programming language to which they are mapped
     * @return an array containing up to <code>count</code>
     * consecutive elements of the SQL <code>ARRAY</code> value designated by this
     * <code>Array</code> object, beginning with element
     * <code>index</code>
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public Object getArray(long index, int count, Map<String, Class<?>> map) throws SQLException {
        return getArray(index, count);
    }

    /**
     * Retrieves a result set that contains the elements of the SQL
     * <code>ARRAY</code> value
     * designated by this <code>Array</code> object.  If appropriate,
     * the elements of the array are mapped using the connection's type
     * map; otherwise, the standard mapping is used.
     * <p>
     * The result set contains one row for each array element, with
     * two columns in each row.  The second column stores the element
     * value; the first column stores the index into the array for
     * that element (with the first array element being at index 1).
     * The rows are in ascending order corresponding to
     * the order of the indices.
     *
     * @return a {@link ResultSet} object containing one row for each
     * of the elements in the array designated by this <code>Array</code>
     * object, with the rows in ascending order based on the indices.
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public ResultSet getResultSet() throws SQLException {
#if JDK_VER >= 16
        throw new VirtuosoFNSException ("getResultSet  not supported", VirtuosoException.NOTIMPLEMENTED);
#else
        throw new VirtuosoException ("getResultSet  not supported", VirtuosoException.NOTIMPLEMENTED);
#endif
    }

    /**
     * Retrieves a result set that contains the elements of the SQL
     * <code>ARRAY</code> value designated by this <code>Array</code> object.
     * This method uses
     * the specified <code>map</code> for type map customizations
     * unless the base type of the array does not match a user-defined
     * type in <code>map</code>, in which case it
     * uses the standard mapping. This version of the method
     * <code>getResultSet</code> uses either the given type map or the standard mapping;
     * it never uses the type map associated with the connection.
     * <p>
     * The result set contains one row for each array element, with
     * two columns in each row.  The second column stores the element
     * value; the first column stores the index into the array for
     * that element (with the first array element being at index 1).
     * The rows are in ascending order corresponding to
     * the order of the indices.
     *
     * @param map contains the mapping of SQL user-defined types to
     * classes in the Java programming language
     * @return a <code>ResultSet</code> object containing one row for each
     * of the elements in the array designated by this <code>Array</code>
     * object, with the rows in ascending order based on the indices.
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public ResultSet getResultSet(Map<String, Class<?>> map) throws SQLException {
        return getResultSet();
    }

    /**
     * Retrieves a result set holding the elements of the subarray that
     * starts at index <code>index</code> and contains up to
     * <code>count</code> successive elements.  This method uses
     * the connection's type map to map the elements of the array if
     * the map contains an entry for the base type. Otherwise, the
     * standard mapping is used.
     * <P>
     * The result set has one row for each element of the SQL array
     * designated by this object, with the first row containing the
     * element at index <code>index</code>.  The result set has
     * up to <code>count</code> rows in ascending order based on the
     * indices.  Each row has two columns:  The second column stores
     * the element value; the first column stores the index into the
     * array for that element.
     *
     * @param index the array index of the first element to retrieve;
     *              the first element is at index 1
     * @param count the number of successive SQL array elements to retrieve
     * @return a <code>ResultSet</code> object containing up to
     * <code>count</code> consecutive elements of the SQL array
     * designated by this <code>Array</code> object, starting at
     * index <code>index</code>.
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public ResultSet getResultSet(long index, int count) throws SQLException {
#if JDK_VER >= 16
        throw new VirtuosoFNSException ("getResultSet  not supported", VirtuosoException.NOTIMPLEMENTED);
#else
        throw new VirtuosoException ("getResultSet  not supported", VirtuosoException.NOTIMPLEMENTED);
#endif
    }

    /**
     * Retrieves a result set holding the elements of the subarray that
     * starts at index <code>index</code> and contains up to
     * <code>count</code> successive elements.
     * This method uses
     * the specified <code>map</code> for type map customizations
     * unless the base type of the array does not match a user-defined
     * type in <code>map</code>, in which case it
     * uses the standard mapping. This version of the method
     * <code>getResultSet</code> uses either the given type map or the standard mapping;
     * it never uses the type map associated with the connection.
     * <P>
     * The result set has one row for each element of the SQL array
     * designated by this object, with the first row containing the
     * element at index <code>index</code>.  The result set has
     * up to <code>count</code> rows in ascending order based on the
     * indices.  Each row has two columns:  The second column stores
     * the element value; the first column stroes the index into the
     * array for that element.
     *
     * @param index the array index of the first element to retrieve;
     *              the first element is at index 1
     * @param count the number of successive SQL array elements to retrieve
     * @param map the <code>Map</code> object that contains the mapping
     * of SQL type names to classes in the Java(tm) programming language
     * @return a <code>ResultSet</code> object containing up to
     * <code>count</code> consecutive elements of the SQL array
     * designated by this <code>Array</code> object, starting at
     * index <code>index</code>.
     * @exception SQLException if an error occurs while attempting to
     * access the array
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.2
     */
    public ResultSet getResultSet(long index, int count, Map<String, Class<?>> map) throws SQLException {
    	return getResultSet(index, count);
    }

#if JDK_VER >= 16
    /**
     * This method frees the <code>Array</code> object and releases the resources that
     * it holds. The object is invalid once the <code>free</code>
     * method is called.
     *<p>
     * After <code>free</code> has been called, any attempt to invoke a
     * method other than <code>free</code> will result in a <code>SQLException</code>
     * being thrown.  If <code>free</code> is called multiple times, the subsequent
     * calls to <code>free</code> are treated as a no-op.
     *<p>
     *
     * @throws SQLException if an error occurs releasing
     * the Array's resources
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
    @Override
    public void free() throws SQLException {
        data = null;
    }
#endif

}
