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

package virtuoso.jdbc2;

import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;
#if JDK_VER >= 16
import java.sql.RowIdLifetime;
#endif

public class DatabaseMetaDataWrapper implements DatabaseMetaData {

  private ConnectionWrapper wconn;
  private DatabaseMetaData dbmd;

  protected DatabaseMetaDataWrapper(ConnectionWrapper _wconn, DatabaseMetaData _dbmd) {
    wconn = _wconn;
    dbmd = _dbmd;
  }

  private void exceptionOccurred(SQLException sqlEx) {
    if (wconn != null)
      wconn.exceptionOccurred(sqlEx);
  }

  public synchronized void finalize () throws Throwable {
    close();
  }

  protected void close() throws SQLException {
    if (dbmd == null)
      return;
    dbmd = null;
    wconn = null;
  }

  public boolean allProceduresAreCallable() throws SQLException {
    check_close();
    try {
      return dbmd.allProceduresAreCallable();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean allTablesAreSelectable() throws SQLException {
    check_close();
    try {
      return dbmd.allTablesAreSelectable();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getURL() throws SQLException {
    check_close();
    try {
      return dbmd.getURL();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getUserName() throws SQLException {
    check_close();
    try {
      return dbmd.getUserName();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isReadOnly() throws SQLException {
    check_close();
    try {
      return dbmd.isReadOnly();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean nullsAreSortedHigh() throws SQLException {
    check_close();
    try {
      return dbmd.nullsAreSortedHigh();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean nullsAreSortedLow() throws SQLException {
    check_close();
    try {
      return dbmd.nullsAreSortedLow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean nullsAreSortedAtStart() throws SQLException {
    check_close();
    try {
      return dbmd.nullsAreSortedAtStart();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean nullsAreSortedAtEnd() throws SQLException {
    check_close();
    try {
      return dbmd.nullsAreSortedAtEnd();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getDatabaseProductName() throws SQLException {
    check_close();
    try {
      return dbmd.getDatabaseProductName();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getDatabaseProductVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getDatabaseProductVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getDriverName() throws SQLException {
    check_close();
    try {
      return dbmd.getDriverName();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getDriverVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getDriverVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getDriverMajorVersion(){
    return dbmd.getDriverMajorVersion();
  }

  public int getDriverMinorVersion(){
    return dbmd.getDriverMinorVersion();
  }

  public boolean usesLocalFiles() throws SQLException {
    check_close();
    try {
      return dbmd.usesLocalFiles();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean usesLocalFilePerTable() throws SQLException {
    check_close();
    try {
      return dbmd.usesLocalFilePerTable();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMixedCaseIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMixedCaseIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesUpperCaseIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesUpperCaseIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesLowerCaseIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesLowerCaseIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesMixedCaseIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesMixedCaseIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMixedCaseQuotedIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMixedCaseQuotedIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesUpperCaseQuotedIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesUpperCaseQuotedIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesLowerCaseQuotedIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesLowerCaseQuotedIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean storesMixedCaseQuotedIdentifiers() throws SQLException {
    check_close();
    try {
      return dbmd.storesMixedCaseQuotedIdentifiers();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getIdentifierQuoteString() throws SQLException {
    check_close();
    try {
      return dbmd.getIdentifierQuoteString();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSQLKeywords() throws SQLException {
    check_close();
    try {
      return dbmd.getSQLKeywords();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getNumericFunctions() throws SQLException {
    check_close();
    try {
      return dbmd.getNumericFunctions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getStringFunctions() throws SQLException {
    check_close();
    try {
      return dbmd.getStringFunctions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSystemFunctions() throws SQLException {
    check_close();
    try {
      return dbmd.getSystemFunctions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getTimeDateFunctions() throws SQLException {
    check_close();
    try {
      return dbmd.getTimeDateFunctions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSearchStringEscape() throws SQLException {
    check_close();
    try {
      return dbmd.getSearchStringEscape();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getExtraNameCharacters() throws SQLException {
    check_close();
    try {
      return dbmd.getExtraNameCharacters();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsAlterTableWithAddColumn() throws SQLException {
    check_close();
    try {
      return dbmd.supportsAlterTableWithAddColumn();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsAlterTableWithDropColumn() throws SQLException {
    check_close();
    try {
      return dbmd.supportsAlterTableWithDropColumn();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsColumnAliasing() throws SQLException {
    check_close();
    try {
      return dbmd.supportsColumnAliasing();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean nullPlusNonNullIsNull() throws SQLException {
    check_close();
    try {
      return dbmd.nullPlusNonNullIsNull();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsConvert() throws SQLException {
    check_close();
    try {
      return dbmd.supportsConvert();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsConvert(int fromType, int toType) throws SQLException {
    check_close();
    try {
      return dbmd.supportsConvert(fromType, toType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsTableCorrelationNames() throws SQLException {
    check_close();
    try {
      return dbmd.supportsTableCorrelationNames();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsDifferentTableCorrelationNames() throws SQLException {
    check_close();
    try {
      return dbmd.supportsDifferentTableCorrelationNames();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsExpressionsInOrderBy() throws SQLException {
    check_close();
    try {
      return dbmd.supportsExpressionsInOrderBy();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOrderByUnrelated() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOrderByUnrelated();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsGroupBy() throws SQLException {
    check_close();
    try {
      return dbmd.supportsGroupBy();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsGroupByUnrelated() throws SQLException {
    check_close();
    try {
      return dbmd.supportsGroupByUnrelated();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsGroupByBeyondSelect() throws SQLException {
    check_close();
    try {
      return dbmd.supportsGroupByBeyondSelect();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsLikeEscapeClause() throws SQLException {
    check_close();
    try {
      return dbmd.supportsLikeEscapeClause();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMultipleResultSets() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMultipleResultSets();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMultipleTransactions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMultipleTransactions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsNonNullableColumns() throws SQLException {
    check_close();
    try {
      return dbmd.supportsNonNullableColumns();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMinimumSQLGrammar() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMinimumSQLGrammar();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCoreSQLGrammar() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCoreSQLGrammar();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsExtendedSQLGrammar() throws SQLException {
    check_close();
    try {
      return dbmd.supportsExtendedSQLGrammar();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsANSI92EntryLevelSQL() throws SQLException {
    check_close();
    try {
      return dbmd.supportsANSI92EntryLevelSQL();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsANSI92IntermediateSQL() throws SQLException {
    check_close();
    try {
      return dbmd.supportsANSI92IntermediateSQL();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsANSI92FullSQL() throws SQLException {
    check_close();
    try {
      return dbmd.supportsANSI92FullSQL();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsIntegrityEnhancementFacility() throws SQLException {
    check_close();
    try {
      return dbmd.supportsIntegrityEnhancementFacility();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOuterJoins() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOuterJoins();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsFullOuterJoins() throws SQLException {
    check_close();
    try {
      return dbmd.supportsFullOuterJoins();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsLimitedOuterJoins() throws SQLException {
    check_close();
    try {
      return dbmd.supportsLimitedOuterJoins();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSchemaTerm() throws SQLException {
    check_close();
    try {
      return dbmd.getSchemaTerm();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getProcedureTerm() throws SQLException {
    check_close();
    try {
      return dbmd.getProcedureTerm();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getCatalogTerm() throws SQLException {
    check_close();
    try {
      return dbmd.getCatalogTerm();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isCatalogAtStart() throws SQLException {
    check_close();
    try {
      return dbmd.isCatalogAtStart();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getCatalogSeparator() throws SQLException {
    check_close();
    try {
      return dbmd.getCatalogSeparator();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSchemasInDataManipulation() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSchemasInDataManipulation();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSchemasInProcedureCalls() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSchemasInProcedureCalls();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSchemasInTableDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSchemasInTableDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSchemasInIndexDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSchemasInIndexDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSchemasInPrivilegeDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSchemasInPrivilegeDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCatalogsInDataManipulation() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCatalogsInDataManipulation();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCatalogsInProcedureCalls() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCatalogsInProcedureCalls();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCatalogsInTableDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCatalogsInTableDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCatalogsInIndexDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCatalogsInIndexDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCatalogsInPrivilegeDefinitions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCatalogsInPrivilegeDefinitions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsPositionedDelete() throws SQLException {
    check_close();
    try {
      return dbmd.supportsPositionedDelete();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsPositionedUpdate() throws SQLException {
    check_close();
    try {
      return dbmd.supportsPositionedUpdate();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSelectForUpdate() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSelectForUpdate();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsStoredProcedures() throws SQLException {
    check_close();
    try {
      return dbmd.supportsStoredProcedures();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSubqueriesInComparisons() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSubqueriesInComparisons();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSubqueriesInExists() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSubqueriesInExists();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSubqueriesInIns() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSubqueriesInIns();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsSubqueriesInQuantifieds() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSubqueriesInQuantifieds();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsCorrelatedSubqueries() throws SQLException {
    check_close();
    try {
      return dbmd.supportsCorrelatedSubqueries();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsUnion() throws SQLException {
    check_close();
    try {
      return dbmd.supportsUnion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsUnionAll() throws SQLException {
    check_close();
    try {
      return dbmd.supportsUnionAll();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOpenCursorsAcrossCommit() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOpenCursorsAcrossCommit();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOpenCursorsAcrossRollback() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOpenCursorsAcrossRollback();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOpenStatementsAcrossCommit() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOpenStatementsAcrossCommit();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsOpenStatementsAcrossRollback() throws SQLException {
    check_close();
    try {
      return dbmd.supportsOpenStatementsAcrossRollback();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxBinaryLiteralLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxBinaryLiteralLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxCharLiteralLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxCharLiteralLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnsInGroupBy() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnsInGroupBy();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnsInIndex() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnsInIndex();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnsInOrderBy() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnsInOrderBy();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnsInSelect() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnsInSelect();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxColumnsInTable() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxColumnsInTable();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxConnections() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxConnections();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxCursorNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxCursorNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxIndexLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxIndexLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxSchemaNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxSchemaNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxProcedureNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxProcedureNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxCatalogNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxCatalogNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxRowSize() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxRowSize();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean doesMaxRowSizeIncludeBlobs() throws SQLException {
    check_close();
    try {
      return dbmd.doesMaxRowSizeIncludeBlobs();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxStatementLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxStatementLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxStatements() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxStatements();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxTableNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxTableNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxTablesInSelect() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxTablesInSelect();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getMaxUserNameLength() throws SQLException {
    check_close();
    try {
      return dbmd.getMaxUserNameLength();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getDefaultTransactionIsolation() throws SQLException {
    check_close();
    try {
      return dbmd.getDefaultTransactionIsolation();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsTransactions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsTransactions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsTransactionIsolationLevel(int level) throws SQLException {
    check_close();
    try {
      return dbmd.supportsTransactionIsolationLevel(level);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsDataDefinitionAndDataManipulationTransactions() throws SQLException {
    check_close();
    try {
      return dbmd.supportsDataDefinitionAndDataManipulationTransactions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsDataManipulationTransactionsOnly() throws SQLException {
    check_close();
    try {
      return dbmd.supportsDataManipulationTransactionsOnly();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean dataDefinitionCausesTransactionCommit() throws SQLException {
    check_close();
    try {
      return dbmd.dataDefinitionCausesTransactionCommit();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean dataDefinitionIgnoredInTransactions() throws SQLException {
    check_close();
    try {
      return dbmd.dataDefinitionIgnoredInTransactions();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getProcedures(String catalog, String schemaPattern, String procedureNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getProcedures(catalog, schemaPattern, procedureNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getProcedureColumns(String catalog, String schemaPattern, String procedureNamePattern, String columnNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getProcedureColumns(catalog, schemaPattern, procedureNamePattern, columnNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getTables(String catalog, String schemaPattern, String tableNamePattern, String[] types) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getTables(catalog, schemaPattern, tableNamePattern, types);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getSchemas() throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getSchemas();
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getCatalogs() throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getCatalogs();
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getTableTypes() throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getTableTypes();
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getColumns(String catalog, String schemaPattern, String tableNamePattern, String columnNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getColumns(catalog, schemaPattern, tableNamePattern, columnNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getColumnPrivileges(String catalog, String schema, String table, String columnNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getColumnPrivileges(catalog, schema, table, columnNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getTablePrivileges(String catalog, String schemaPattern, String tableNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getTablePrivileges(catalog, schemaPattern, tableNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getBestRowIdentifier(String catalog, String schema, String table, int scope, boolean nullable) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getBestRowIdentifier(catalog, schema, table, scope, nullable);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getVersionColumns(String catalog, String schema, String table) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getVersionColumns(catalog, schema, table);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getPrimaryKeys(String catalog, String schema, String table) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getPrimaryKeys(catalog, schema, table);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getImportedKeys(String catalog, String schema, String table) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getImportedKeys(catalog, schema, table);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getExportedKeys(String catalog, String schema, String table) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getExportedKeys(catalog, schema, table);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getCrossReference(String primaryCatalog, String primarySchema, String primaryTable, String foreignCatalog, String foreignSchema, String foreignTable) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getCrossReference(primaryCatalog, primarySchema, primaryTable, foreignCatalog, foreignSchema, foreignTable);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getTypeInfo() throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getTypeInfo();
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getIndexInfo(String catalog, String schema, String table, boolean unique, boolean approximate) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getIndexInfo(catalog, schema, table, unique, approximate);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsResultSetType(int type) throws SQLException {
    check_close();
    try {
      return dbmd.supportsResultSetType(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsResultSetConcurrency(int type, int concurrency) throws SQLException {
    check_close();
    try {
      return dbmd.supportsResultSetConcurrency(type, concurrency);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean ownUpdatesAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.ownUpdatesAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean ownDeletesAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.ownDeletesAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean ownInsertsAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.ownInsertsAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean othersUpdatesAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.othersUpdatesAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean othersDeletesAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.othersDeletesAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean othersInsertsAreVisible(int type) throws SQLException {
    check_close();
    try {
      return dbmd.othersInsertsAreVisible(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean updatesAreDetected(int type) throws SQLException {
    check_close();
    try {
      return dbmd.updatesAreDetected(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean deletesAreDetected(int type) throws SQLException {
    check_close();
    try {
      return dbmd.deletesAreDetected(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean insertsAreDetected(int type) throws SQLException {
    check_close();
    try {
      return dbmd.insertsAreDetected(type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsBatchUpdates() throws SQLException {
    check_close();
    try {
      return dbmd.supportsBatchUpdates();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getUDTs(String catalog, String schemaPattern, String typeNamePattern, int[] types) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getUDTs(catalog, schemaPattern, typeNamePattern, types);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Connection getConnection() throws SQLException {
    check_close();
    return wconn;
  }

#if JDK_VER >= 14
    // ------------------- JDBC 3.0 -------------------------

  public boolean supportsSavepoints() throws SQLException {
    check_close();
    try {
      return dbmd.supportsSavepoints();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsNamedParameters() throws SQLException {
    check_close();
    try {
      return dbmd.supportsNamedParameters();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsMultipleOpenResults() throws SQLException {
    check_close();
    try {
      return dbmd.supportsMultipleOpenResults();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsGetGeneratedKeys() throws SQLException {
    check_close();
    try {
      return dbmd.supportsGetGeneratedKeys();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getSuperTypes(String catalog, String schemaPattern,
			    String typeNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getSuperTypes(catalog, schemaPattern, typeNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getSuperTables(String catalog, String schemaPattern,
			     String tableNamePattern) throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getSuperTables(catalog, schemaPattern, tableNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getAttributes(String catalog, String schemaPattern,
			    String typeNamePattern, String attributeNamePattern)
	throws SQLException {
    check_close();
    try {
      ResultSet rs = dbmd.getAttributes(catalog, schemaPattern, typeNamePattern, attributeNamePattern);
      if (rs != null)
        return new ResultSetWrapper(wconn, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsResultSetHoldability(int holdability) throws SQLException {
    check_close();
    try {
      return dbmd.supportsResultSetHoldability(holdability);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getResultSetHoldability() throws SQLException {
    check_close();
    try {
      return dbmd.getResultSetHoldability();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getDatabaseMajorVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getDatabaseMajorVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getDatabaseMinorVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getDatabaseMinorVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getJDBCMajorVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getJDBCMajorVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getJDBCMinorVersion() throws SQLException {
    check_close();
    try {
      return dbmd.getJDBCMinorVersion();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int getSQLStateType() throws SQLException {
    check_close();
    try {
      return dbmd.getSQLStateType();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean locatorsUpdateCopy() throws SQLException {
    check_close();
    try {
      return dbmd.locatorsUpdateCopy();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsStatementPooling() throws SQLException {
    check_close();
    try {
      return dbmd.supportsStatementPooling();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }
#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------

  public RowIdLifetime getRowIdLifetime() throws SQLException
  {
    check_close();
    try {
      return dbmd.getRowIdLifetime();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getSchemas(String catalog, String schemaPattern) throws SQLException
  {
    check_close();
    try {
      return dbmd.getSchemas(catalog, schemaPattern);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean supportsStoredFunctionsUsingCallSyntax() throws SQLException
  {
    check_close();
    try {
      return dbmd.supportsStoredFunctionsUsingCallSyntax();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean autoCommitFailureClosesAllResultSets() throws SQLException
  {
    check_close();
    try {
      return dbmd.autoCommitFailureClosesAllResultSets();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getClientInfoProperties() throws SQLException
  {
    check_close();
    try {
      return dbmd.getClientInfoProperties();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getFunctions(String catalog, String schemaPattern,
			    String functionNamePattern) throws SQLException
  {
    check_close();
    try {
      return dbmd.getFunctions(catalog, schemaPattern, functionNamePattern);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSet getFunctionColumns(String catalog,
				  String schemaPattern,
				  String functionNamePattern,
				  String columnNamePattern) throws SQLException
  {
    check_close();
    try {
      return dbmd.getFunctionColumns(catalog, schemaPattern, functionNamePattern, columnNamePattern);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    check_close();
    try {
      return dbmd.unwrap(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    check_close();
    try {
      return dbmd.isWrapperFor(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#endif
#endif


  private void check_close()
    throws SQLException
  {
    if (dbmd == null)
      throw new VirtuosoException("The connection is closed.",VirtuosoException.OK);
  }
}
