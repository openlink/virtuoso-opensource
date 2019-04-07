package benchmark.testdriver;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;

import benchmark.qualification.QueryResult;

import java.sql.*;

public class SQLConnection implements ServerConnection {
	private Statement statement;
	private Connection conn;
	private static Logger logger = Logger.getLogger( SQLConnection.class );

	public SQLConnection(String serviceURL, String driverClassName, String connUser, String connPwd, int timeout)
	{
		try {
			Class.forName(driverClassName);
		} catch(ClassNotFoundException e) {
			e.printStackTrace();
			System.exit(-1);
		}
		try {
			conn = DriverManager.getConnection(serviceURL, connUser, connPwd);
			statement = conn.createStatement();

			statement.setQueryTimeout(timeout/1000);
                        statement.setFetchSize(TestDriverDefaultValues.fetchSize);

		} catch(SQLException e) {
			while(e!=null) {
				e.printStackTrace();
				e=e.getNextException();
			}
			System.exit(-1);
		}
	}

	/*
	 * Execute Query with Query Object
	 */
	public void executeQuery(Query query, byte queryType) {
		String qs = query.getQueryString();
		if (query.querySyntax == TestDriver.VIRTUOSO_FAMILY && query.queryLang == TestDriver.SPARQL_LANG)
			qs = "SPARQL define input:default-graph-uri <" + query.defaultGraph + "> " + qs;
		executeQuery(qs, queryType, query.getNr(), query.getQueryMix());
	}

	/*
	 * execute Query with Query String
	 */
	private void executeQuery(String queryString, byte queryType, int queryNr, QueryMix queryMix) {
		double timeInSeconds;
		try {
			long start = System.nanoTime();
			ResultSet results = statement.executeQuery(queryString);

			int resultCount = 0;
			while(results.next())
				resultCount++;

			Long stop = System.nanoTime();
			Long interval = stop-start;

			timeInSeconds = interval.doubleValue()/1000000000;

			int queryMixRun = queryMix.getRun() + 1;

			if(logger.isEnabledFor( Level.ALL ) && queryType!=3 && queryMixRun > 0)
				logResultInfo(queryNr, queryMixRun, timeInSeconds,
		                   queryString, queryType, 0,
		                   resultCount);

			queryMix.setCurrent(resultCount, timeInSeconds);
			results.close();
		} catch(SQLException e) {
			while(e!=null) {
				e.printStackTrace();
				e=e.getNextException();
			}
			System.err.println("\n\nError for Query " + queryNr + ":\n\n" + queryString);
			System.exit(-1);
		}
	}

	public void executeQuery(CompiledQuery query, CompiledQueryMix queryMix) {
		double timeInSeconds;
		String queryString = query.getQueryString();
		byte queryType = query.getQueryType();
		int queryNr = query.getNr();
		if (query.source.querySyntax == TestDriver.VIRTUOSO_FAMILY && query.source.queryLang == TestDriver.SPARQL_LANG)
			queryString = "SPARQL define input:default-graph-uri <" + query.source.defaultGraph + "> " + queryString;

		try {
			long start = System.nanoTime();
			ResultSet results = statement.executeQuery(queryString);

			int resultCount = 0;
			while(results.next())
				resultCount++;

			Long stop = System.nanoTime();
			Long interval = stop-start;

			timeInSeconds = interval.doubleValue()/1000000000;

			int queryMixRun = queryMix.getRun() + 1;

			if(logger.isEnabledFor( Level.ALL ) && queryType!=3 && queryMixRun > 0)
				logResultInfo(queryNr, queryMixRun, timeInSeconds,
		                   queryString, queryType, 0,
		                   resultCount);

			queryMix.setCurrent(resultCount, timeInSeconds);
			results.close();
		} catch(SQLException e) {
			while(e!=null) {
				e.printStackTrace();
				e=e.getNextException();
			}
			System.err.println("\n\nError for Query " + queryNr + ":\n\n" + queryString);
			System.exit(-1);
		}
	}

	private void logResultInfo(int queryNr, int queryMixRun, double timeInSeconds,
			                   String queryString, byte queryType, int resultSizeInBytes,
			                   int resultCount) {
		StringBuffer sb = new StringBuffer(1000);
		sb.append("\n\n\tQuery " + queryNr + " of run " + queryMixRun + " has been executed ");
		sb.append("in " + String.format("%.6f",timeInSeconds) + " seconds.\n" );
		sb.append("\n\tQuery string:\n\n");
		sb.append(queryString);
		sb.append("\n\n");

		//Log results
		if(queryType==Query.DESCRIBE_TYPE)
			sb.append("\tQuery(Describe) result (" + resultSizeInBytes + " Bytes): \n\n");
		else
			sb.append("\tQuery results (" + resultCount + " results): \n\n");


//		sb.append(result);
		sb.append("\n__________________________________________________________________________________\n");
		logger.log(Level.ALL, sb.toString());
	}

	public void close() {
		try {
		conn.close();
		} catch(SQLException e) {
			e.printStackTrace();
			System.exit(-1);
		}
	}

	public QueryResult executeValidation(Query query, byte queryType) {
		// TODO Auto-generated method stub
		return null;
	}
}
