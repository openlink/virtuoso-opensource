package benchmark.testdriver;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;

import java.util.Locale;

import org.apache.log4j.xml.DOMConfigurator;
import org.apache.log4j.Logger;
import org.apache.log4j.Level;

import java.io.*;
//import java.util.StringTokenizer;

public class TestDriver {
	private QueryMix queryMix;//The Benchmark Querymix
	private int warmups = 10;//how many Query mixes are run for warm up
	private AbstractParameterPool parameterPool;
	private ServerConnection server;
	private String queryMixFN = null;
	private File queryDir = new File("queries");
	private int totalRuns = 50;
	private String sparqlEndpoint = null;
	private String defaultGraph = null;
	private String resourceDir = "td_data";
	private String xmlResultFile = "benchmark_result.xml";
	private static Logger logger = Logger.getLogger( TestDriver.class );
	
	public TestDriver(String[] args) {
		processProgramParameters(args);
		parameterPool = new LocalParameterPool(new File(resourceDir),808080L);
		if(sparqlEndpoint!=null)
			server = new ServerConnection(sparqlEndpoint, defaultGraph);
		else {
			printUsageInfos();
			System.exit(-1);
		}
	}
	
	public void init() {
		Query[] queries = null;
		Integer[] queryRun = null;
		
		if(queryMixFN==null) {
			Integer[] temp = { 1, 2, 2, 3, 2, 2, 2, 4, 2, 2, 5, 7, 7, 6, 7, 7, 8, 9, 9, 8, 9, 9, 10, 10, 10};
//			Integer[] temp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
//			Integer[] temp = { 2 };

			queryRun = temp;
		}
		else {
			queryRun = getQueryMixInfo(queryMixFN);
		}
		
		Integer maxQueryNr = 0;
		for(int i=0;i<queryRun.length;i++) {
			if(queryRun != null || queryRun[i] > maxQueryNr)
				maxQueryNr = queryRun[i];
		}

		queries = new Query[maxQueryNr];
		
		for(int i=0;i<queries.length;i++) {
			queries[i] = null;
		}
		
		for(int i=0;i<queryRun.length;i++) {
			int qnr = queryRun[i];
			if(queries[qnr-1]==null) {
				File queryFile = new File(queryDir, "query" + qnr + ".txt");
				File queryDescFile = new File(queryDir, "query" + qnr + "desc.txt");
				queries[qnr-1] = new Query(queryFile, queryDescFile);
			}
		}
		
		
		queryMix = new QueryMix(queries, queryRun);
	}
	
	private Integer[] getQueryMixInfo(String queryMixFilename) {
		File file = new File(queryMixFilename);
		try {
			BufferedReader qmReader = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
			char[] data = new char[10];
			qmReader.read(data);
//			StringTokenizer st = new StringTokenizer(new String(data));
			System.out.println();
			//TODO: Implement QueryMix reader 
		} catch(IOException e) {
			System.err.println("Error processing query mix file: " + queryMixFilename);
			System.exit(-1);
		}
		return new Integer[2];
	}
	
	public void run() {
		
		for(int nrRun=-warmups;nrRun<totalRuns;nrRun++) {
			long startTime = System.currentTimeMillis();
			queryMix.init(nrRun);
			while(queryMix.hasNext()) {
				Query next = queryMix.getNext();
				Object[] queryParameters = parameterPool.getParametersForQuery(next);
				next.setParameters(queryParameters);

				server.executeQuery(next, next.getQueryType());
			}
			System.out.println(nrRun + ": " + String.format(Locale.US, "%.2f", queryMix.getQueryMixRuntime()*1000)
					+ "ms, total: " + (System.currentTimeMillis()-startTime) + "ms");
			queryMix.finishRun();
		}
		logger.log(Level.ALL, printResults(true));
		try {
			FileWriter resultWriter = new FileWriter(xmlResultFile);
			resultWriter.append(printXMLResults(true));
			resultWriter.flush();
			resultWriter.close();
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	/*
	 * Process the program parameters typed on the command line.
	 */
	private void processProgramParameters(String[] args) {
		int i=0;
		while(i<args.length) {
			try {
				if(args[i].equals("-runs")) {
					totalRuns = Integer.parseInt(args[i++ + 1]);
				}
				else if(args[i].equals("-idir")) {
					resourceDir = args[i++ + 1];
				}
				else if(args[i].equals("-qdir")) {
					queryDir = new File(args[i++ + 1]);
				}
				else if(args[i].equals("-w")) {
					warmups = Integer.parseInt(args[i++ + 1]);
				}
				else if(args[i].equals("-o")) {
					xmlResultFile = args[i++ + 1];
				}
				else if(args[i].equals("-dg")) {
					defaultGraph = args[i++ + 1];
				}
				else if(!args[i].startsWith("-")) {
					sparqlEndpoint = args[i];
				}
				else {
					printUsageInfos();
					System.exit(-1);
				}
				
				i++;
							
			} catch(Exception e) {
				System.err.println("Invalid arguments\n");
				printUsageInfos();
				System.exit(-1);
			}
		}
	}
	
	/*
	 * Get Result String
	 */
	public String printResults(boolean all) {
		StringBuffer sb = new StringBuffer(100);
		
		sb.append("Scale factor: " + parameterPool.getScalefactor() + "\n");
		sb.append("Number of query mix runs: " + queryMix.getQueryMixRuns() + " times\n");
		sb.append("min/max Querymix runtime: " + String.format(Locale.US, "%.4fs",queryMix.getMinQueryMixRuntime()) +
				  " / " + String.format(Locale.US, "%.4fs",queryMix.getMaxQueryMixRuntime()) + "\n");
		sb.append("Total runtime: " + String.format(Locale.US, "%.3f",queryMix.getTotalRuntime()) + " seconds\n");
		sb.append("QMpH: " + String.format(Locale.US, "%.2f",queryMix.getQmph()) + " query mixes per hour\n");
		sb.append("CQET: " + String.format(Locale.US, "%.5f",queryMix.getCQET()) + " seconds average runtime of query mix\n");
		sb.append("CQET (geom.): " + String.format(Locale.US, "%.5f",queryMix.getQueryMixGeoMean()) + " seconds geometric mean runtime of query mix\n");
		
		if(all) {
			sb.append("\n");
			//Print per query statistics
			Query[] queries = queryMix.getQueries();
			double[] qmin = queryMix.getQmin();
			double[] qmax = queryMix.getQmax();
			double[] qavga = queryMix.getAqet();//Arithmetic mean
			double[] avgResults = queryMix.getAvgResults();
			double[] qavgg = queryMix.getGeoMean();
			int[] minResults = queryMix.getMinResults();
			int[] maxResults = queryMix.getMaxResults();
			int[] nrq = queryMix.getRunsPerQuery();
			for(int i=0;i<qmin.length;i++) {
				if(queries[i]!=null) {
					sb.append("Metrics for Query " + (i+1) + ":\n");
					sb.append("Count: " + nrq[i] + " times executed in whole run\n");
					sb.append("AQET: " + String.format(Locale.US, "%.6f",qavga[i]) + " seconds (arithmetic mean)\n");
					sb.append("AQET(geom.): " + String.format(Locale.US, "%.6f",qavgg[i]) + " seconds (geometric mean)\n");
					sb.append("QPS: " + String.format(Locale.US, "%.2f",1/qavga[i]) + " Queries per second\n");
					sb.append("minQET/maxQET: " + String.format(Locale.US, "%.8fs",qmin[i]) + " / " + 
							String.format(Locale.US, "%.8fs",qmax[i]) + "\n");
					sb.append("Average result count: " + String.format(Locale.US, "%.1f",avgResults[i]) + "\n");
					sb.append("min/max result count: " + minResults[i] + " / " + maxResults[i] + "\n\n");
				}
			}
		}
		
		return sb.toString();
	}
	
	/*
	 * Get XML Result String
	 */
	public String printXMLResults(boolean all) {
		StringBuffer sb = new StringBuffer(100);
		sb.append("<?xml version=\"1.0\"?>");
		sb.append("<bsbm>\n");
		sb.append("  <querymix>\n");
		sb.append("     <scalefactor>" + parameterPool.getScalefactor() + "</scalefactor>\n");
		sb.append("     <querymixruns>" + queryMix.getQueryMixRuns() + "</querymixruns>\n");
		sb.append("     <minquerymixruntime>" + 
				  String.format(Locale.US, "%.4f",queryMix.getMinQueryMixRuntime()) + "</minquerymixruntime>\n");
		sb.append("     <maxquerymixruntime>" + 
				  String.format(Locale.US, "%.4f",queryMix.getMaxQueryMixRuntime()) + "</maxquerymixruntime>\n");
		sb.append("     <totalruntime>" + String.format(Locale.US, "%.3f",queryMix.getTotalRuntime()) + "</totalruntime>\n");
		sb.append("     <qmph>" + String.format(Locale.US, "%.2f",queryMix.getQmph()) + "</qmph>\n");
		sb.append("     <cqet>" + String.format(Locale.US, "%.5f",queryMix.getCQET()) + "</cqet>\n");
		sb.append("     <cqetg>" + String.format(Locale.US, "%.5f",queryMix.getQueryMixGeoMean()) + "</cqetg>\n");
		sb.append("  </querymix>\n");
		
		if(all) {
			sb.append("  <queries>\n");
			//Print per query statistics
			Query[] queries = queryMix.getQueries();
			double[] qmin = queryMix.getQmin();
			double[] qmax = queryMix.getQmax();
			double[] qavga = queryMix.getAqet();
			double[] avgResults = queryMix.getAvgResults();
			double[] qavgg = queryMix.getGeoMean();
			int[] minResults = queryMix.getMinResults();
			int[] maxResults = queryMix.getMaxResults();
			int[] nrq = queryMix.getRunsPerQuery();
			for(int i=0;i<qmin.length;i++) {
				if(queries[i]!=null) {
					sb.append("    <query nr=\"" + (i+1) + "\">\n");
					sb.append("      <executecount>" + nrq[i] + "</executecount>\n");
					sb.append("      <aqet>" + String.format(Locale.US, "%.6f",qavga[i]) + "</aqet>\n");
					sb.append("      <aqetg>" + String.format(Locale.US, "%.6f",qavgg[i]) + "</aqetg>\n");
					sb.append("      <qps>" + String.format(Locale.US, "%.2f",1/qavga[i]) + "</qps>\n");
					sb.append("      <minqet>" + String.format(Locale.US, "%.8f",qmin[i]) + "</minqet>\n");
					sb.append("      <maxqet>" + String.format(Locale.US, "%.8f",qmax[i]) + "</maxqet>\n");
					sb.append("      <avgresults>" + String.format(Locale.US, "%.1f",avgResults[i]) + "</avgresults>\n");
					sb.append("      <minresults>" + minResults[i] + "</minresults>\n");
					sb.append("      <maxresults>" + maxResults[i] + "</maxresults>\n");
					sb.append("    </query>\n");
				}
			}
			sb.append("  </queries>\n");
		}
		sb.append("</bsbm>\n");
		return sb.toString();
	}
	
	/*
	 * print command line options
	 */
	private void printUsageInfos() {
		String output = "Usage: java benchmark.testdriver.TestDriver <options> SPARQL-Endpoint\n\n" +
						"SPARQL-Endpoint: The URL of the HTTP SPARQL Endpoint\n\n" +
						"Possible options are:\n" +
						"\t-runs <number of query mix runs>\n" +
						"\t\tdefault: " + totalRuns + "\n" +
						"\t-idir <data input directory>\n" +
						"\t\tThe input directory for the Test Driver data\n" +
						"\t\tdefault: " + resourceDir + "\n" +
//						"\t-qdir <query directory>\n" +
//						"\t\tThe directory containing the query data\n" +
//						"\t\tdefault: " + queryDir.getName() + "\n" +
						"\t-w <number of warm up runs before actual measuring>\n" +
						"\t\tdefault: " + warmups + "\n"+
						"\t-o <benchmark results output file>\n" +
						"\t\tdefault: " + xmlResultFile + "\n" +
						"\t-dg <Default Graph>\n" +
						"\t\tdefault: null\n";
		
		System.out.print(output);
	}
	
	public static void main(String argv[]) {
		DOMConfigurator.configureAndWatch( "log4j.xml", 60*1000 );
		TestDriver testDriver = new TestDriver(argv);
		testDriver.init();
		System.out.println("\nStarting test...\n");
		testDriver.run();
		System.out.println("\n" + testDriver.printResults(true));
	}
}
