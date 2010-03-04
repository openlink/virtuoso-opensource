/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2010 OpenLink Software
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

package virtuoso.hibernate;

import java.sql.Types;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.CallableStatement;

import org.hibernate.Hibernate;
import org.hibernate.LockMode;
import org.hibernate.MappingException;
import org.hibernate.dialect.Dialect;
import org.hibernate.dialect.function.NoArgSQLFunction;
import org.hibernate.dialect.function.VarArgsSQLFunction;
import org.hibernate.dialect.function.SQLFunctionTemplate;
import org.hibernate.dialect.function.StandardSQLFunction;
import org.hibernate.dialect.function.AnsiTrimEmulationFunction;
import org.hibernate.util.StringHelper;
import org.hibernate.exception.TemplatedViolatedConstraintNameExtracter;
import org.hibernate.exception.ViolatedConstraintNameExtracter;


/**
 * A dialect for Virtuoso DBMS
 *
 */
public class VirtuosoDialect extends Dialect {

	public VirtuosoDialect() {
		super();

		registerColumnType( Types.BIT, "smallint" );
		registerColumnType( Types.TINYINT, "smallint" );
		registerColumnType( Types.SMALLINT, "smallint" );
		registerColumnType( Types.INTEGER, "integer" );

		registerColumnType( Types.BIGINT, "decimal(20,0)" );

		registerColumnType( Types.REAL, "real" );
		registerColumnType( Types.FLOAT, "float" );
		registerColumnType( Types.DOUBLE, "double precision" );
		registerColumnType( Types.NUMERIC, "decimal($p, $s)" );
		registerColumnType( Types.DECIMAL, "decimal($p, $s)" );
		registerColumnType( Types.BINARY, 2000, "binary($l)" );
		registerColumnType( Types.VARBINARY, 2000, "varbinary($l)" );
		registerColumnType( Types.LONGVARBINARY, "long varbinary" );
		registerColumnType( Types.CHAR, 2000, "character($l)" );
		registerColumnType( Types.VARCHAR, 2000, "varchar($l)" );
		registerColumnType( Types.LONGVARCHAR, "long varchar" );
		registerColumnType( Types.DATE, "date" );
		registerColumnType( Types.TIME, "time" );
		registerColumnType( Types.TIMESTAMP, "datetime" );

		registerColumnType( Types.BLOB, "long varbinary" );
		registerColumnType( Types.CLOB, "long varchar" );

///===================

		registerFunction("iszero", new StandardSQLFunction( "iszero", Hibernate.INTEGER ) );
		registerFunction("atod", new StandardSQLFunction( "atod", Hibernate.DOUBLE ) );
		registerFunction("atof", new StandardSQLFunction( "atof", Hibernate.FLOAT ) );
		registerFunction("atoi", new StandardSQLFunction( "atoi", Hibernate.INTEGER ) );

		registerFunction("mod", new StandardSQLFunction( "mod" ) );
		registerFunction("abs", new StandardSQLFunction( "abs" ) );
		registerFunction("sign", new StandardSQLFunction( "sign", Hibernate.DOUBLE ) );
		registerFunction("acos", new StandardSQLFunction( "acos", Hibernate.DOUBLE ) );
		registerFunction("asin", new StandardSQLFunction( "asin", Hibernate.DOUBLE ) );
		registerFunction("atan", new StandardSQLFunction( "atan", Hibernate.DOUBLE ) );
		registerFunction("cos", new StandardSQLFunction( "cos", Hibernate.DOUBLE ) );
		registerFunction("sin", new StandardSQLFunction( "sin", Hibernate.DOUBLE ) );
		registerFunction("tan", new StandardSQLFunction( "tan", Hibernate.DOUBLE ) );
		registerFunction("cot", new StandardSQLFunction( "cot", Hibernate.DOUBLE ) );
		registerFunction("frexp", new StandardSQLFunction( "frexp", Hibernate.DOUBLE ) );
		registerFunction("degrees", new StandardSQLFunction( "degrees", Hibernate.DOUBLE ) );
		registerFunction("radians", new StandardSQLFunction( "radians", Hibernate.DOUBLE ) );
		registerFunction("exp", new StandardSQLFunction( "exp", Hibernate.DOUBLE ) );
		registerFunction("log", new StandardSQLFunction( "log", Hibernate.DOUBLE ) );
		registerFunction("log10", new StandardSQLFunction( "log10", Hibernate.DOUBLE ) );
		registerFunction("sqrt", new StandardSQLFunction( "sqrt", Hibernate.DOUBLE ) );
		registerFunction("atan2", new StandardSQLFunction( "atan2", Hibernate.DOUBLE ) );
		registerFunction("power", new StandardSQLFunction( "power", Hibernate.DOUBLE ) );
		registerFunction("ceiling", new StandardSQLFunction( "ceiling", Hibernate.INTEGER ) );
		registerFunction("floor", new StandardSQLFunction( "floor", Hibernate.INTEGER ) );
		registerFunction("pi", new NoArgSQLFunction( "pi", Hibernate.DOUBLE, true ) );
		registerFunction("round", new StandardSQLFunction("round", Hibernate.DOUBLE) );
		registerFunction("rand", new StandardSQLFunction( "rand") );
		registerFunction("rnd", new StandardSQLFunction( "rnd") );
		registerFunction("randomize", new StandardSQLFunction( "randomize") );


		registerFunction("hash", new StandardSQLFunction( "hash", Hibernate.INTEGER ) );
		registerFunction("md5_box", new StandardSQLFunction( "md5_box", Hibernate.STRING ) );
		registerFunction("box_hash", new StandardSQLFunction( "box_hash", Hibernate.INTEGER ) );
/* Bitwise: */
		registerFunction("bit_and", new StandardSQLFunction( "bit_and", Hibernate.INTEGER ) );
		registerFunction("bit_or", new StandardSQLFunction( "bit_or", Hibernate.INTEGER ) );
		registerFunction("bit_xor", new StandardSQLFunction( "bit_xor", Hibernate.INTEGER ) );
		registerFunction("bit_not", new StandardSQLFunction( "bit_not", Hibernate.INTEGER ) );
		registerFunction("bit_shift", new StandardSQLFunction( "bit_shift", Hibernate.INTEGER ) );

// undef=>TRUNCATE
		registerFunction("length", new StandardSQLFunction( "length", Hibernate.INTEGER ) );
		registerFunction("char_length", new StandardSQLFunction( "char_length", Hibernate.INTEGER ) );
		registerFunction("character_length", new StandardSQLFunction( "character_length", Hibernate.INTEGER ) );
		registerFunction("octet_length", new StandardSQLFunction( "octet_length", Hibernate.INTEGER ) );

		registerFunction("ascii", new StandardSQLFunction("ascii", Hibernate.INTEGER) );
		registerFunction("chr", new StandardSQLFunction("chr", Hibernate.CHARACTER) );
		registerFunction("chr1", new StandardSQLFunction("chr1", Hibernate.CHARACTER) );
		registerFunction("subseq", new StandardSQLFunction("subseq", Hibernate.STRING ) );
		registerFunction("substring", new StandardSQLFunction("substring", Hibernate.STRING ) );
		registerFunction("left", new StandardSQLFunction( "left", Hibernate.STRING ) );
		registerFunction("right", new StandardSQLFunction( "right", Hibernate.STRING ) );
		registerFunction("ltrim", new StandardSQLFunction("ltrim", Hibernate.STRING ) );
		registerFunction("rtrim", new StandardSQLFunction("rtrim", Hibernate.STRING ) );
		registerFunction("trim", new StandardSQLFunction("trim", Hibernate.STRING ) );

		registerFunction("repeat", new StandardSQLFunction( "repeat", Hibernate.STRING ) );
		registerFunction("space", new StandardSQLFunction("space", Hibernate.STRING) );

		registerFunction("make_string", new StandardSQLFunction("make_string", Hibernate.STRING) );
		registerFunction("make_wstring", new StandardSQLFunction("make_wstring", Hibernate.STRING) );
		registerFunction("make_bin_string", new StandardSQLFunction("make_bin_string", Hibernate.BINARY) );
		registerFunction("concatenate", new StandardSQLFunction("concatenate", Hibernate.STRING) );

		registerFunction("concat", new StandardSQLFunction( "concat", Hibernate.STRING ) );
		registerFunction("replace", new StandardSQLFunction( "replace", Hibernate.STRING ) );

		registerFunction("sprintf", new StandardSQLFunction( "sprintf", Hibernate.STRING ) );
		registerFunction("sprintf_or_null", new StandardSQLFunction( "sprintf_or_null", Hibernate.STRING ) );
		registerFunction("sprintf_iri", new StandardSQLFunction( "sprintf_iri", Hibernate.STRING ) );
		registerFunction("sprintf_iri_or_null", new StandardSQLFunction( "sprintf_iri_or_null", Hibernate.STRING ) );

		registerFunction("strchr", new StandardSQLFunction("strchr", Hibernate.INTEGER) );
		registerFunction("strrchr", new StandardSQLFunction("strrchr", Hibernate.INTEGER) );
		registerFunction("strstr", new StandardSQLFunction("strstr", Hibernate.INTEGER) );
		registerFunction("strindex", new StandardSQLFunction("strindex", Hibernate.INTEGER) );
		registerFunction("strcasestr", new StandardSQLFunction("strcasestr", Hibernate.INTEGER) );
		registerFunction("locate", new StandardSQLFunction("locate", Hibernate.INTEGER ) );
		registerFunction("matches_like", new StandardSQLFunction("matches_like", Hibernate.INTEGER ) );


		registerFunction("__like_min", new StandardSQLFunction( "__like_min", Hibernate.STRING ) );
		registerFunction("__like_max", new StandardSQLFunction( "__like_max", Hibernate.STRING ) );
		registerFunction("fix_identifier_case", new StandardSQLFunction( "fix_identifier_case", Hibernate.STRING ) );
		registerFunction("casemode_strcmp", new StandardSQLFunction("casemode_strcmp", Hibernate.INTEGER ) );


		registerFunction("lcase", new StandardSQLFunction("lcase", Hibernate.STRING ) );
		registerFunction("lower", new StandardSQLFunction("lower", Hibernate.STRING ) );
		registerFunction("ucase", new StandardSQLFunction("ucase", Hibernate.STRING ) );
		registerFunction("upper", new StandardSQLFunction("upper", Hibernate.STRING ) );
		registerFunction("initcap", new StandardSQLFunction("initcap", Hibernate.STRING ) );


		registerFunction("table_type", new StandardSQLFunction("table_type", Hibernate.STRING ) );
		registerFunction("internal_type_name", new StandardSQLFunction("internal_type_name", Hibernate.STRING ) );
		registerFunction("internal_type", new StandardSQLFunction("internal_type", Hibernate.INTEGER ) );
		registerFunction("isinteger", new StandardSQLFunction("isinteger", Hibernate.INTEGER ) );
		registerFunction("isnumeric", new StandardSQLFunction("isnumeric", Hibernate.INTEGER ) );
		registerFunction("isfloat", new StandardSQLFunction("isfloat", Hibernate.INTEGER ) );
		registerFunction("isdouble", new StandardSQLFunction("isdouble", Hibernate.INTEGER ) );
		registerFunction("isnull", new StandardSQLFunction("isnull", Hibernate.INTEGER ) );
		registerFunction("isnotnull", new StandardSQLFunction("isnotnull", Hibernate.INTEGER ) );
		registerFunction("isblob", new StandardSQLFunction("isblob", Hibernate.INTEGER ) );
		registerFunction("isentity", new StandardSQLFunction("isentity", Hibernate.INTEGER ) );
		registerFunction("isstring", new StandardSQLFunction("isstring", Hibernate.INTEGER ) );
		registerFunction("isbinary", new StandardSQLFunction("isbinary", Hibernate.INTEGER ) );
		registerFunction("isarray", new StandardSQLFunction("isarray", Hibernate.INTEGER ) );
		registerFunction("isiri_id", new StandardSQLFunction("isiri_id", Hibernate.INTEGER ) );
		registerFunction("is_named_iri_id", new StandardSQLFunction("is_named_iri_id", Hibernate.INTEGER ) );
		registerFunction("is_bnode_iri_id", new StandardSQLFunction("is_bnode_iri_id", Hibernate.INTEGER ) );
		registerFunction("isuname", new StandardSQLFunction("isuname", Hibernate.INTEGER ) );


		registerFunction("username", new NoArgSQLFunction( "username", Hibernate.STRING, true ) );
		registerFunction("dbname", new NoArgSQLFunction( "dbname", Hibernate.STRING, true ) );
		registerFunction("ifnull", new VarArgsSQLFunction( "ifnull(", ",", ")" ) );
		registerFunction("get_user", new NoArgSQLFunction( "get_user", Hibernate.STRING, true ) );


		registerFunction("dayname", new StandardSQLFunction( "dayname", Hibernate.STRING ) );
		registerFunction("monthname", new StandardSQLFunction( "monthname", Hibernate.STRING ) );
		registerFunction("now", new NoArgSQLFunction( "now", Hibernate.TIMESTAMP ) );
		registerFunction("curdate", new NoArgSQLFunction( "curdate", Hibernate.DATE ) );
		registerFunction("dayofmonth", new StandardSQLFunction( "dayofmonth", Hibernate.INTEGER ) );
		registerFunction("dayofweek", new StandardSQLFunction( "dayofweek", Hibernate.INTEGER ) );
		registerFunction("dayofyear", new StandardSQLFunction( "dayofyear", Hibernate.INTEGER ) );
		registerFunction("quarter", new StandardSQLFunction( "quarter", Hibernate.INTEGER ) );
		registerFunction("week", new StandardSQLFunction( "week", Hibernate.INTEGER ) );
		registerFunction("month", new StandardSQLFunction( "month", Hibernate.INTEGER ) );
		registerFunction("year", new StandardSQLFunction( "year", Hibernate.INTEGER ) );
		registerFunction("hour", new StandardSQLFunction( "hour", Hibernate.INTEGER ) );
		registerFunction("minute", new StandardSQLFunction( "minute", Hibernate.INTEGER ) );
		registerFunction("second", new StandardSQLFunction( "second", Hibernate.INTEGER ) );
		registerFunction("timezone", new StandardSQLFunction( "timezone", Hibernate.INTEGER ) );
		registerFunction("curtime", new StandardSQLFunction( "curtime", Hibernate.TIME ) );
		registerFunction("getdate", new NoArgSQLFunction( "getdate", Hibernate.TIMESTAMP ) );
		registerFunction("curdatetime", new NoArgSQLFunction( "curdatetime", Hibernate.TIMESTAMP ) );

		registerFunction( "datediff", new StandardSQLFunction( "datediff", Hibernate.INTEGER ) );
		registerFunction( "dateadd", new StandardSQLFunction( "dateadd", Hibernate.TIMESTAMP ) );
		registerFunction( "timestampdiff", new StandardSQLFunction( "timestampdiff", Hibernate.INTEGER ) );
		registerFunction( "timestampadd", new StandardSQLFunction( "timestampadd", Hibernate.TIMESTAMP ) );


//============================
		registerKeyword( "top" );
		registerKeyword( "char" );
		registerKeyword( "int" );
		registerKeyword( "name" );
		registerKeyword( "string" );
		registerKeyword( "intnum" );
		registerKeyword( "approxnum" );
		registerKeyword( "ammsc" );
		registerKeyword( "parameter" );
		registerKeyword( "as" );
		registerKeyword( "or" );
		registerKeyword( "and" );
		registerKeyword( "not" );
		registerKeyword( "uminus" );
		registerKeyword( "all" );
		registerKeyword( "ammsc" );
		registerKeyword( "any" );
		registerKeyword( "attach" );
		registerKeyword( "asc" );
		registerKeyword( "authorization" );
		registerKeyword( "between" );
		registerKeyword( "by" );
		registerKeyword( "character" );
		registerKeyword( "check" );
		registerKeyword( "close" );
		registerKeyword( "commit" );
		registerKeyword( "continue" );
		registerKeyword( "create" );
		registerKeyword( "current" );
		registerKeyword( "cursor" );
		registerKeyword( "decimal" );
		registerKeyword( "declare" );
		registerKeyword( "default" );
		registerKeyword( "delete" );
		registerKeyword( "desc" );
		registerKeyword( "distinct" );
		registerKeyword( "double" );
		registerKeyword( "drop" );
		registerKeyword( "escape" );
		registerKeyword( "exists" );
		registerKeyword( "fetch" );
		registerKeyword( "float" );
		registerKeyword( "for" );
		registerKeyword( "foreign" );
		registerKeyword( "found" );
		registerKeyword( "from" );
		registerKeyword( "goto" );
		registerKeyword( "go" );
		registerKeyword( "grant " );
		registerKeyword( "group" );
		registerKeyword( "having" );
		registerKeyword( "in" );
		registerKeyword( "index" );
		registerKeyword( "indicator" );
		registerKeyword( "insert" );
		registerKeyword( "integer" );
		registerKeyword( "into" );
		registerKeyword( "is" );
		registerKeyword( "key" );
		registerKeyword( "language" );
		registerKeyword( "like" );
		registerKeyword( "nullx" );
		registerKeyword( "numeric" );
		registerKeyword( "of" );
		registerKeyword( "on" );
		registerKeyword( "open" );
		registerKeyword( "option" );
		registerKeyword( "order" );
		registerKeyword( "precision" );
		registerKeyword( "primary" );
		registerKeyword( "privileges" );
		registerKeyword( "procedure" );
		registerKeyword( "public" );
		registerKeyword( "real" );
		registerKeyword( "references" );
		registerKeyword( "rollback" );
		registerKeyword( "schema" );
		registerKeyword( "select" );
		registerKeyword( "set" );
		registerKeyword( "smallint" );
		registerKeyword( "some" );
		registerKeyword( "sqlcode" );
		registerKeyword( "sqlerror" );
		registerKeyword( "table" );
		registerKeyword( "to" );
		registerKeyword( "union" );
		registerKeyword( "unique" );
		registerKeyword( "update" );
		registerKeyword( "user" );
		registerKeyword( "values" );
		registerKeyword( "view" );
		registerKeyword( "whenever" );
		registerKeyword( "where" );
		registerKeyword( "with" );
		registerKeyword( "work" );
		registerKeyword( "continues" );
		registerKeyword( "object_id" );
		registerKeyword( "under" );
		registerKeyword( "clustered" );
		registerKeyword( "varchar" );
		registerKeyword( "varbinary" );
		registerKeyword( "long" );
		registerKeyword( "replacing" );
		registerKeyword( "soft" );
		registerKeyword( "shutdown" );
		registerKeyword( "checkpoint" );
		registerKeyword( "backup" );
		registerKeyword( "replication" );
		registerKeyword( "sync" );
		registerKeyword( "alter" );
		registerKeyword( "add" );
		registerKeyword( "rename" );
		registerKeyword( "disconnect" );
		registerKeyword( "before" );
		registerKeyword( "after" );
		registerKeyword( "instead" );
		registerKeyword( "trigger" );
		registerKeyword( "referencing" );
		registerKeyword( "old" );
		registerKeyword( "procedure" );
		registerKeyword( "function" );
		registerKeyword( "out" );
		registerKeyword( "inout" );
		registerKeyword( "handler" );
		registerKeyword( "if" );
		registerKeyword( "then" );
		registerKeyword( "else" );
		registerKeyword( "elseif" );
		registerKeyword( "while" );
		registerKeyword( "beginx" );
		registerKeyword( "endx" );
		registerKeyword( "equals" );
		registerKeyword( "return" );
		registerKeyword( "call" );
		registerKeyword( "returns" );
		registerKeyword( "do" );
		registerKeyword( "exclusive" );
		registerKeyword( "prefetch" );
		registerKeyword( "sqlstate" );
		registerKeyword( "found" );
		registerKeyword( "revoke" );
		registerKeyword( "password" );
		registerKeyword( "off" );
		registerKeyword( "logx" );
		registerKeyword( "sqlstate" );
		registerKeyword( "timestamp" );
		registerKeyword( "date" );
		registerKeyword( "datetime" );
		registerKeyword( "time" );
		registerKeyword( "execute" );
		registerKeyword( "owner" );
		registerKeyword( "begin_fn_x" );
		registerKeyword( "begin_oj_x" );
		registerKeyword( "convert" );
		registerKeyword( "case" );
		registerKeyword( "when" );
		registerKeyword( "then" );
		registerKeyword( "identity" );
		registerKeyword( "left" );
		registerKeyword( "right" );
		registerKeyword( "full" );
		registerKeyword( "outer" );
		registerKeyword( "join" );
		registerKeyword( "use" );

	}

//???
//	public String getAddColumnString() {
//		return " add";
//	}
//	public String getNullColumnString() {
//		return " null";
//	}


	// IDENTITY support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/**
	 * Does this dialect support identity column key generation?
	 *
	 * @return True if IDENTITY columns are supported; false otherwise.
	 */
	public boolean supportsIdentityColumns() {
		return true;
	}

	/**
	 * Get the select command to use to retrieve the last generated IDENTITY
	 * value.
	 *
	 * @return The appropriate select command
	 * @throws MappingException If IDENTITY generation is not supported.
	 */
	protected String getIdentitySelectString() throws MappingException{
		return "select identity_value()";
	}

	/**
	 * The syntax used during DDL to define a column as being an IDENTITY.
	 *
	 * @return The appropriate DDL fragment.
	 * @throws MappingException If IDENTITY generation is not supported.
	 */
	protected String getIdentityColumnString() throws MappingException {
		// The keyword used to specify an identity column, if identity column key generation is supported.
		return " identity";
	}

	/**
	 * Does the dialect support some form of inserting and selecting
	 * the generated IDENTITY value all in the same statement.
	 *
	 * @return True if the dialect supports selecting the just
	 * generated IDENTITY in the insert statement.
	 */
	public boolean supportsInsertSelectIdentity() {
		return false;
	}


	// SEQUENCE support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/**
	 * Does this dialect support sequences?
	 *
	 * @return True if sequences supported; false otherwise.
	 */
	public boolean supportsSequences() {
		return true;
	}

	/**
	 * Does this dialect support "pooled" sequences.  Not aware of a better
	 * name for this.  Essentially can we specify the initial and increment values?
	 *
	 * @return True if such "pooled" sequences are supported; false otherwise.
	 * @see #getCreateSequenceString(String, int, int)
	 */
	public boolean supportsPooledSequences() {
	    return true;
	}


	/**
	 * Typically dialects which support sequences can create a sequence
	 * with a single command.  This is convenience form of
	 * {@link #getCreateSequenceStrings} to help facilitate that.
	 * <p/>
	 * Dialects which support sequences and can create a sequence in a
	 * single command need *only* override this method.  Dialects
	 * which support sequences but require multiple commands to create
	 * a sequence should instead override {@link #getCreateSequenceStrings}.
	 *
	 * @param sequenceName The name of the sequence
	 * @return The sequence creation command
	 * @throws MappingException If sequences are not supported.
	 */
	protected String getCreateSequenceString(String sequenceName) throws MappingException {
		return "sequence_set('" + sequenceName+"', 0, 1)";
	}

//??NOT SUPPORTED
//	public String getDropSequenceString(String sequenceName) {
//		return "drop sequence " + sequenceName;
//	}

	/**
	 * Generate the select expression fragment that will retreive the next
	 * value of a sequence as part of another (typically DML) statement.
	 * <p/>
	 * This differs from {@link #getSequenceNextValString(String)} in that this
	 * should return an expression usable within another statement.
	 *
	 * @param sequenceName the name of the sequence
	 * @return The "nextval" fragment.
	 * @throws MappingException If sequences are not supported.
	 */
	public String getSelectSequenceNextValString(String sequenceName) throws MappingException {
		return "sequence_next('" + sequenceName +"')";
	}

	/**
	 * Generate the appropriate select statement to to retreive the next value
	 * of a sequence.
	 * <p/>
	 * This should be a "stand alone" select statement.
	 *
	 * @param sequenceName the name of the sequence
	 * @return String The "nextval" select string.
	 * @throws MappingException If sequences are not supported.
	 */
	public String getSequenceNextValString(String sequenceName) throws MappingException {
		return "select sequence_next('" + sequenceName +"')";
	}



	// limit/offset support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	/**
	 * Does this dialect support some form of limiting query results
	 * via a SQL clause?
	 *
	 * @return True if this dialect supports some form of LIMIT.
	 */
	public boolean supportsLimit() {
		return true;
	}


	/**
	 * Does the <tt>LIMIT</tt> clause come at the start of the
	 * <tt>SELECT</tt> statement, rather than at the end?
	 *
	 * @return true if limit parameters should come before other parameters
	 */
	public boolean bindLimitParametersFirst() {
		return true;
	}


	/**
	 * Given a limit and an offset, apply the limit clause to the query.
	 *
	 * @param query The query to which to apply the limit.
	 * @param offset The offset of the limit
	 * @param limit The limit of the limit ;)
	 * @return The modified query statement with the limit applied.
	 */
	public String getLimitString(String sql, int offset, int limit) {
		int insertionPoint = sql.toLowerCase().startsWith( "select distinct" ) ? 15 : 6;
		StringBuffer ret = new StringBuffer(sql.length() + 64);

		ret.append(sql);

		if (offset > 0)
		  ret.insert(insertionPoint, " TOP "+offset+","+limit+" ");
		else
		  ret.insert(insertionPoint, " TOP "+limit+" ");

		return ret.toString();
	}

	/**
	 * Apply s limit clause to the query.
	 * <p/>
	 * Typically dialects utilize {@link #supportsVariableLimit() variable}
	 * limit caluses when they support limits.  Thus, when building the
	 * select command we do not actually need to know the limit or the offest
	 * since we will just be using placeholders.
	 * <p/>
	 * Here we do still pass along whether or not an offset was specified
	 * so that dialects not supporting offsets can generate proper exceptions.
	 * In general, dialects will override one or the other of this method and
	 * {@link #getLimitString(String, int, int)}.
	 *
	 * @param query The query to which to apply the limit.
	 * @param hasOffset Is the query requesting an offset?
	 * @return the modified SQL
	 */
	protected String getLimitString(String sql, boolean hasOffset) {
		int insertionPoint = sql.toLowerCase().startsWith( "select distinct" ) ? 15 : 6;

		return new StringBuffer( sql.length() + 16 )
				.append( sql )
				.insert( insertionPoint, (hasOffset ? " TOP ? " : " TOP ?,? " ))
				.toString();

	}


	// callable statement support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	/**
	 * Registers an OUT parameter which will be returing a
	 * {@link java.sql.ResultSet}.  How this is accomplished varies greatly
	 * from DB to DB, hence its inclusion (along with {@link #getResultSet}) here.
	 *
	 * @param statement The callable statement.
	 * @param position The bind position at which to register the OUT param.
	 * @return The number of (contiguous) bind positions used.
	 * @throws SQLException Indicates problems registering the OUT param.
	 */
	public int registerResultSetOutParameter(CallableStatement statement, int position) throws SQLException {
		return position;
	}

	/**
	 * Given a callable statement previously processed by {@link #registerResultSetOutParameter},
	 * extract the {@link java.sql.ResultSet} from the OUT parameter.
	 *
	 * @param statement The callable statement.
	 * @return The extracted result set.
	 * @throws SQLException Indicates problems extracting the result set.
	 */
	public ResultSet getResultSet(CallableStatement ps) throws SQLException {
		boolean isResultSet = ps.execute();
		// This assumes you will want to ignore any update counts
		while ( !isResultSet && ps.getUpdateCount() != -1 ) {
			isResultSet = ps.getMoreResults();
		}
		// You may still have other ResultSets or update counts left to process here
		// but you can't do it now or the ResultSet you just got will be closed
		return ps.getResultSet();
	}


	// current timestamp support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	/**
	 * Does this dialect support a way to retrieve the database's current
	 * timestamp value?
	 *
	 * @return True if the current timestamp can be retrieved; false otherwise.
	 */
	public boolean supportsCurrentTimestampSelection() {
		return true;
	}

	/**
	 * Should the value returned by {@link #getCurrentTimestampSelectString}
	 * be treated as callable.  Typically this indicates that JDBC escape
	 * sytnax is being used...
	 *
	 * @return True if the {@link #getCurrentTimestampSelectString} return
	 * is callable; false otherwise.
	 */
	public boolean isCurrentTimestampSelectStringCallable() {
		return false;
	}

	/**
	 * Retrieve the command used to retrieve the current timestammp from the
	 * database.
	 *
	 * @return The command.
	 */
	public String getCurrentTimestampSelectString() {
		return "select getdate()";
	}

	/**
	 * The name of the database-specific SQL function for retrieving the
	 * current timestamp.
	 *
	 * @return The function name.
	 */
	public String getCurrentTimestampSQLFunctionName() {
		// the standard SQL function name is current_timestamp...
		return "getdate";
	}



	// SQLException support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	public ViolatedConstraintNameExtracter getViolatedConstraintNameExtracter() {
		return EXTRACTER;
	}



	private static ViolatedConstraintNameExtracter EXTRACTER = new TemplatedViolatedConstraintNameExtracter() {
		public String extractConstraintName(SQLException sqle) {
			int er = sqle.getErrorCode();
			String mess = sqle.getMessage();
			if (er == -8) {
				if (mess.startsWith("SR304:")) //DELETE
					return extractUsingTemplate("statement conflicted with COLUMN REFERENCE constraint \"","\"", mess);
				else if (mess.startsWith("SR305:")) //UPDATE
					return extractUsingTemplate("statement conflicted with COLUMN REFERENCE constraint \"","\"", mess);
				else if (mess.startsWith("SR306:")) //INSERT
					return extractUsingTemplate("__03 => 'SR306',\n",":", mess);

				else if (mess.startsWith("SR363:")) //CHECK
					return extractUsingTemplate("__03 => 'SR363',\n",":", mess);

				else if (mess.startsWith("SR175:")) //UNIQUE
					return extractUsingTemplate(": Violating unique index "," on", mess);

				else
					return null;
			} else {
				return null;
			}
		}
	};


	// union subclass support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	/**
	 * Given a {@link java.sql.Types} type code, determine an appropriate
	 * null value to use in a select clause.
	 * <p/>
	 * One thing to consider here is that certain databases might
	 * require proper casting for the nulls here since the select here
	 * will be part of a UNION/UNION ALL.
	 *
	 * @param sqlType The {@link java.sql.Types} type code.
	 * @return The appropriate select clause value fragment.
	 */
	public String getSelectClauseNullString(int sqlType) {

		switch ( sqlType ) {
			case Types.BIT:
			case Types.TINYINT:
			case Types.SMALLINT:
				return "cast(null as smallint)";

			case Types.INTEGER:
				return "cast(null as int)";
			case Types.BIGINT:
				return "cast(null as smallint)";
			case Types.FLOAT:
				return "cast(null as float)";
			case Types.REAL:
				return "cast(null as real)";
			case Types.DOUBLE:
				return "cast(null as double precision)";
			case Types.NUMERIC:
			case Types.DECIMAL:
				return "cast(null as decimal)";
			case Types.CHAR:
			case Types.VARCHAR:
				return "cast(null as varchar)";
			case Types.LONGVARCHAR:
			case Types.CLOB:
				return "cast(null as long varchar)";
			case Types.DATE:
				return "cast(null as date)";
			case Types.TIME:
				return "cast(null as time)";
			case Types.TIMESTAMP:
				return "cast(null as datetime)";
			case Types.BINARY:
			case Types.VARBINARY:
				return "cast(null as varbinary)";
			case Types.LONGVARBINARY:
			case Types.BLOB:
				return "cast(null as long varbinary)";
			default:
				return "null";
		}
	}

	/**
	 * Does this dialect support UNION ALL, which is generally a faster
	 * variant of UNION?
	 *
	 * @return True if UNION ALL is supported; false otherwise.
	 */
	public boolean supportsUnionAll() {
		return true;
	}


	// miscellaneous support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


	/**
	 * The fragment used to insert a row without specifying any column values.
	 * This is not possible on some databases.
	 *
	 * @return The appropriate empty values clause.
	 */
	public String getNoColumnsInsertString() {
		throw new UnsupportedOperationException( "Database can not insert a row without specifying any column values" );
	}


	/**
	 * What is the maximum length Hibernate can use for generated aliases?
	 *
	 * @return The maximum length.
	 */
	public int getMaxAliasLength() {
		return 100;
	}

	/**
	 * The SQL literal value to which this database maps boolean values.
	 *
	 * @param bool The boolean value
	 * @return The appropriate SQL literal.
	 */
	public String toBooleanValueString(boolean bool) {
		return bool ? "1" : "0";
	}


	// DDL support ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


	/**
	 * Do we need to drop constraints before dropping tables in this dialect?
	 *
	 * @return True if constraints must be dropped prior to dropping
	 * the table; false otherwise.
	 */
	public boolean dropConstraints() {
		return false;
	}


        /**
         * Does this dialect support adding Unique constraints via create and alter table ?
         * @return boolean
         */
	public boolean supportsUniqueConstraintInCreateAlterTable() {
	    return true;
	}

	/**
	 * The syntax used to add a column to a table (optional).
	 *
	 * @return The "add column" fragment.
	 */
	public String getAddColumnString() {
		return "add";
	}

	public String getDropForeignKeyString() {
		return " drop foreign key ";
	}

	/**
	 * The syntax used to add a foreign key constraint to a table.
	 *
	 * @param constraintName The FK constraint name.
	 * @param foreignKey The names of the columns comprising the FK
	 * @param referencedTable The table referenced by the FK
	 * @param primaryKey The explicit columns in the referencedTable referenced
	 * by this FK.
	 * @param referencesPrimaryKey if false, constraint should be
	 * explicit about which column names the constraint refers to
	 *
	 * @return the "add FK" fragment
	 */
	public String getAddForeignKeyConstraintString(
			String constraintName,
			String[] foreignKey,
			String referencedTable,
			String[] primaryKey,
			boolean referencesPrimaryKey) {
		StringBuffer res = new StringBuffer( 300 );

		res.append( " add foreign key (" )
				.append( StringHelper.join( ", ", foreignKey ) )
				.append( ") references " )
				.append( referencedTable );

		if ( !referencesPrimaryKey ) {
			res.append( " (" )
					.append( StringHelper.join( ", ", primaryKey ) )
					.append( ')' );
		}

		return res.toString();
	}

	/**
	 * The syntax used to add a primary key constraint to a table.
	 *
	 * @param constraintName The name of the PK constraint.
	 * @return The "add PK" fragment
	 */
	public String getAddPrimaryKeyConstraintString(String constraintName) {
		return " modify primary key ";
	}

	public boolean hasSelfReferentialForeignKeyBug() {
		return true;
	}

	/**
	 * The keyword used to specify a nullable column.
	 *
	 * @return String
	 */
	public String getNullColumnString() {
		return " null";
	}

	public boolean supportsIfExistsBeforeTableName() {
		return false;
	}

	public boolean supportsIfExistsAfterTableName() {
		return false;
	}



	// Informational metadata ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	/**
	 * Does this dialect support empty IN lists?
	 * <p/>
	 * For example, is [where XYZ in ()] a supported construct?
	 *
	 * @return True if empty in lists are supported; false otherwise.
	 * @since 3.2
	 */
	public boolean supportsEmptyInList() {
		return false;
	}

	/**
	 * Are string comparisons implicitly case insensitive.
	 * <p/>
	 * In other words, does [where 'XYZ' = 'xyz'] resolve to true?
	 *
	 * @return True if comparisons are case insensitive.
	 * @since 3.2
	 */
	public boolean areStringComparisonsCaseInsensitive() {
		return false;
	}

	/**
	 * Should LOBs (both BLOB and CLOB) be bound using stream operations (i.e.
	 * {@link java.sql.PreparedStatement#setBinaryStream}).
	 *
	 * @return True if BLOBs and CLOBs should be bound using stream operations.
	 * @since 3.2
	 */
	public boolean useInputStreamToInsertBlob() {
		return false;
	}


	/**
	 * Does this dialect support definition of cascade delete constraints
	 * which can cause circular chains?
	 *
	 * @return True if circular cascade delete constraints are supported; false
	 * otherwise.
	 * @since 3.2
	 */
//??
	public boolean supportsCircularCascadeDeleteConstraints() {
		return true;
	}


	/**
	 * Does the dialect support propogating changes to LOB
	 * values back to the database?  Talking about mutating the
	 * internal value of the locator as opposed to supplying a new
	 * locator instance...
	 * <p/>
	 * For BLOBs, the internal value might be changed by:
	 * {@link java.sql.Blob#setBinaryStream},
	 * {@link java.sql.Blob#setBytes(long, byte[])},
	 * {@link java.sql.Blob#setBytes(long, byte[], int, int)},
	 * or {@link java.sql.Blob#truncate(long)}.
	 * <p/>
	 * For CLOBs, the internal value might be changed by:
	 * {@link java.sql.Clob#setAsciiStream(long)},
	 * {@link java.sql.Clob#setCharacterStream(long)},
	 * {@link java.sql.Clob#setString(long, String)},
	 * {@link java.sql.Clob#setString(long, String, int, int)},
	 * or {@link java.sql.Clob#truncate(long)}.
	 * <p/>
	 * NOTE : I do not know the correct answer currently for
	 * databases which (1) are not part of the cruise control process
	 * or (2) do not {@link #supportsExpectedLobUsagePattern}.
	 *
	 * @return True if the changes are propogated back to the
	 * database; false otherwise.
	 * @since 3.2
	 */
	public boolean supportsLobValueChangePropogation() {
		return false;
	}

	/**
	 * Is it supported to materialize a LOB locator outside the transaction in
	 * which it was created?
	 *
	 * @return True if unbounded materialization is supported; false otherwise.
	 * @since 3.2
	 */
	public boolean supportsUnboundedLobLocatorMaterialization() {
		return false;
	}

}
