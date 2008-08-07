package benchmark.testdriver;

import java.io.*;
import javax.xml.parsers.*;
import org.xml.sax.*;
import org.xml.sax.helpers.DefaultHandler;

import org.apache.log4j.Logger;
import org.apache.log4j.Level;

public class ServerConnection {
	private String serverURL;
	private String defaultGraph;
	private static Logger logger = Logger.getLogger( ServerConnection.class );
	
	public ServerConnection(String serviceURL, String defaultGraph) {
		this.serverURL = serviceURL;
		this.defaultGraph = defaultGraph;
	}
	
	/*
	 * Execute Query with Query Object
	 */
	public void executeQuery(Query query, byte queryType) {
		executeQuery(query.getQueryString(), queryType, query.getNr(), query.getQueryMix());
	}
	
	/*
	 * execute Query with Query String
	 */
	private void executeQuery(String queryString, byte queryType, int queryNr, QueryMix queryMix) {
		double timeInSeconds;
		NetQuery qe = new NetQuery(serverURL, queryString, queryType, defaultGraph);
		StringBuffer result = new StringBuffer(1000);
		int queryMixRun = queryMix.getRun() + 1;
		
		InputStream is = qe.exec();
			
		//Write XML result into result
		int resultCount = countResults(is);
		timeInSeconds = qe.getExecutionTimeInSeconds();
		

		if(logger.isEnabledFor( Level.ALL ) && queryType!=3 && queryMixRun > 0)
			logResultInfo(queryNr, queryMixRun, timeInSeconds,
	                   queryString, queryType, 0,
	                   resultCount, result);
		
		queryMix.setCurrent(resultCount, timeInSeconds);
		qe.close();
	}
	
//	private int getResult(StringBuffer result, InputStream is) {
//		byte[] buf = new byte[100];
//		int resultSizeInBytes=0;
//		int len=0;
//		try {
//			while((len=is.read(buf))!=-1) {
//				String temp = new String(buf,0,len);
//				result.append(temp);
//				resultSizeInBytes += len;
//			}
//		} catch(IOException e) {
//			System.err.println("Could not read result from input stream");
//		}
//		return resultSizeInBytes;
//	}
	
	private void logResultInfo(int queryNr, int queryMixRun, double timeInSeconds,
			                   String queryString, byte queryType, int resultSizeInBytes,
			                   int resultCount, StringBuffer result) {
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
}
