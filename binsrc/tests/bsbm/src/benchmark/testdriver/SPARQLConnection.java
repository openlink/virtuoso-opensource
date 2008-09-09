package benchmark.testdriver;

import java.io.*;
import javax.xml.parsers.*;
import org.xml.sax.*;
import org.xml.sax.helpers.DefaultHandler;

import org.apache.log4j.Logger;
import org.apache.log4j.Level;

public class SPARQLConnection implements ServerConnection{
	private String serverURL;
	private String defaultGraph;
	private boolean isParametrized;
	private static Logger logger = Logger.getLogger( SPARQLConnection.class );
	
	public SPARQLConnection(String serviceURL, String defaultGraph, boolean isParametrized) {
		this.serverURL = serviceURL;
		this.defaultGraph = defaultGraph;
		this.isParametrized = isParametrized;
	}
	
	/*
	 * Execute Query with Query Object
	 */
	public void executeQuery(Query query, byte queryType) {
		if (isParametrized)
			executeQuery(query.getParametrizedQueryString(), query.getEncodedParamString(), queryType, query.getNr(), query.getQueryMix());
		else
			executeQuery(query.getQueryString(), "", queryType, query.getNr(), query.getQueryMix());
	}
	
	/*
	 * execute Query with Query String
	 */
	private void executeQuery(String queryString, String encodedParamString, byte queryType, int queryNr, QueryMix queryMix)
	{
		double timeInSeconds;

		NetQuery qe = new NetQuery(serverURL, queryString, encodedParamString, queryType, defaultGraph);
		int queryMixRun = queryMix.getRun() + 1;

		InputStream is = qe.exec();
			
		int resultCount = 0;
		//Write XML result into result
		if(queryType==Query.SELECT_TYPE)
			resultCount = countResults(is);
		else
			resultCount = countBytes(is);
		
		timeInSeconds = qe.getExecutionTimeInSeconds();

		if(logger.isEnabledFor( Level.ALL ) && queryMixRun > 0)
			logResultInfo(queryNr, queryMixRun, timeInSeconds,
	                   queryString, queryType,
	                   resultCount);
		
		queryMix.setCurrent(resultCount, timeInSeconds);
		qe.close();
	}
	
	public void executeQuery(CompiledQuery query, CompiledQueryMix queryMix) {
		double timeInSeconds;

		String queryString = query.getQueryString();
		String parametrizedQueryString = query.getParametrizedQueryString();
		String encodedParamString = query.getEncodedParamString();
		byte queryType = query.getQueryType();
		int queryNr = query.getNr();
                NetQuery qe;
		if (isParametrized)
			qe = new NetQuery(serverURL, parametrizedQueryString, encodedParamString, queryType, defaultGraph);
		else
			qe = new NetQuery(serverURL, queryString, "", queryType, defaultGraph);
		int queryMixRun = queryMix.getRun() + 1;

		InputStream is = qe.exec();

		if(is==null) {//then Timeout!
			double timeout = TestDriverDefaultValues.timeoutInMs/1000.0;
			System.out.println("Query " + queryNr + ": " + timeout + " seconds timeout!");
			queryMix.reportTimeOut();//inc. timeout counter
			queryMix.setCurrent(0, timeout);
			qe.close();
			return;
		}
		
		int resultCount = 0;
		//Write XML result into result
		if(queryType==Query.SELECT_TYPE)
			resultCount = countResults(is);
		else
			resultCount = countBytes(is);
		
		timeInSeconds = qe.getExecutionTimeInSeconds();
		

		if(logger.isEnabledFor( Level.ALL ) && queryMixRun > 0)
			logResultInfo(queryNr, queryMixRun, timeInSeconds,
	                   queryString, queryType,
	                   resultCount);
		
		queryMix.setCurrent(resultCount, timeInSeconds);
		qe.close();
	}
	
private int countBytes(InputStream is) {
	int nrBytes=0;
	byte[] buf = new byte[10000];
	int len=0;
//	StringBuffer sb = new StringBuffer(1000);
	try {
		while((len=is.read(buf))!=-1) {
			nrBytes += len;//resultCount counts the returned bytes
//			String temp = new String(buf,0,len);
//			temp = "\n\n" + temp + "\n\n";
//			logger.log(Level.ALL, temp);
//			sb.append(temp);
		}
	} catch(IOException e) {
		System.err.println("Could not read result from input stream");
	}
//	System.out.println(sb.toString());
	return nrBytes;
}
	
	private void logResultInfo(int queryNr, int queryMixRun, double timeInSeconds,
			                   String queryString, byte queryType,
			                   int resultCount) {
		StringBuffer sb = new StringBuffer(1000);
		sb.append("\n\n\tQuery " + queryNr + " of run " + queryMixRun + " has been executed ");
		sb.append("in " + String.format("%.6f",timeInSeconds) + " seconds.\n" );
		sb.append("\n\tQuery string:\n\n");
		sb.append(queryString);
		sb.append("\n\n");
	
		//Log results
		if(queryType==Query.DESCRIBE_TYPE)
			sb.append("\tQuery(Describe) result (" + resultCount + " Bytes): \n\n");
		else if(queryType==Query.CONSTRUCT_TYPE)
			sb.append("\tQuery(Construct) result (" + resultCount + " Bytes): \n\n");
		else
			sb.append("\tQuery results (" + resultCount + " results): \n\n");
		

		sb.append("\n__________________________________________________________________________________\n");
		logger.log(Level.ALL, sb.toString());
	}
	
	private int countResults(InputStream s) {
		ResultHandler handler = new ResultHandler();
		int count=0;
		try {
		  SAXParser saxParser = SAXParserFactory.newInstance().newSAXParser();
//		  ByteArrayInputStream bis = new ByteArrayInputStream(s.getBytes("UTF-8"));
	      saxParser.parse( s, handler );
	      count = handler.getCount();
		} catch(Exception e) {
			System.err.println("SAX Error");
			e.printStackTrace();
			return -1;
		}
		return count;
	}
	
	private class ResultHandler extends DefaultHandler {
		private int count;
		
		ResultHandler() {
			count = 0;
		}
		
		public void startElement( String namespaceURI,
                String localName,   // local name
                String qName,       // qualified name
                Attributes attrs ) {
			if(qName.equals("result"))
				count++;
		}

		public int getCount() {
			return count;
		}
	}
	
	public void close() {
		//nothing to close
	}
}
