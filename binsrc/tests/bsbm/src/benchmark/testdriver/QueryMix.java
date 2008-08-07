package benchmark.testdriver;

public class QueryMix {
	private Query[] queries;
	private Integer[] queryMix;
	
	private double[] aqet;//arithmetic mean query execution time
	private double[] qmin;//Query minimum execution time
	private double[] qmax;//Query maximum execution time
	private double[] avgResults;
	private double[] aqetg;//Query geometric mean execution time
	private int[] minResults;
	private int[] maxResults;
	private int[] runsPerQuery;//Runs Per Query
	private int run;//run: negative values are warm up runs
	
	private int currentQueryIndex;//Index of current query for queryMix
	private int queryMixRuns;//number of query mix runs
	private double queryMixRuntime;//whole runtime of actual run in seconds
	private double minQueryMixRuntime;
	private double maxQueryMixRuntime;
	private double queryMixGeoMean;
	private double totalRuntime;//Total runtime of all runs
	
	public QueryMix(Query[] queries, Integer[] queryMix) {
		this.queries = queries;
		this.queryMix = queryMix;
		
		aqet = new double[queries.length];
		qmin = new double[queries.length];
		qmax = new double[queries.length];
		
		avgResults = new double[queries.length];
		aqetg = new double[queries.length];
		minResults = new int[queries.length];
		maxResults = new int[queries.length];
		
		runsPerQuery = new int[queries.length];
		
		currentQueryIndex = 0;
		queryMixRuns = 0;
		queryMixRuntime = 0;
		totalRuntime = 0;
		minQueryMixRuntime = Double.MAX_VALUE;
		maxQueryMixRuntime = Double.MIN_VALUE;
		queryMixGeoMean = 0;
		run = 0;

		//Init qmax array
		for(int i=0; i<qmax.length;i++) {
			qmax[i] = Double.MIN_VALUE;
			maxResults[i] = Integer.MIN_VALUE;
		}
		
		//Init qmin array
		for(int i=0; i<qmin.length;i++) {
			qmin[i] = Double.MAX_VALUE;
			minResults[i] = Integer.MAX_VALUE;
		}
		
		//Queries are enumerated starting with 1
		for(int i=0;i<queries.length;i++) {
			if(queries[i]!=null) {
				queries[i].setNr(i+1);
				queries[i].setQueryMix(this);
			}
		}
		
		//same reason
		for(int i=0;i<queryMix.length;i++)
			queryMix[i]--;
	}
	
	public void init(int run) {
		this.run = run;
	}
	
	/*
	 * Calculate metrics for this run
	 */
	public void finishRun() {
		currentQueryIndex = 0;
		
		if(run>=0) {
			
			queryMixRuns++;
			
			if(queryMixRuntime < minQueryMixRuntime)
				minQueryMixRuntime = queryMixRuntime;
			
			if(queryMixRuntime > maxQueryMixRuntime)
				maxQueryMixRuntime = queryMixRuntime;
			
			queryMixGeoMean += Math.log10(queryMixRuntime);
			totalRuntime += queryMixRuntime;
		}
		
		//Reset queryMixRuntime
		queryMixRuntime = 0;
	}
	
	public Query getNext() {
		return queries[queryMix[currentQueryIndex]];
	}
	
	public Boolean hasNext() {
		return currentQueryIndex < queryMix.length;
	}
	
	/*
	 * Set the time (seconds) of the current Query
	 */
	public void setCurrent(int numberResults, Double timeInSeconds) {
		if(run>=0) {
			int queryNr = queryMix[currentQueryIndex];
	
			int nrRuns = runsPerQuery[queryNr]++;
			aqet[queryNr] = (aqet[queryNr] * nrRuns + timeInSeconds) / (nrRuns+1);
			avgResults[queryNr] = (avgResults[queryNr] * nrRuns + numberResults) / (nrRuns+1);
			aqetg[queryNr] += Math.log10(timeInSeconds);
			
			if(timeInSeconds < qmin[queryNr])
				qmin[queryNr] = timeInSeconds;
			
			if(timeInSeconds > qmax[queryNr])
				qmax[queryNr] = timeInSeconds;
			
			if(numberResults < minResults[queryNr])
				minResults[queryNr] = numberResults;
			
			if(numberResults > maxResults[queryNr])
				maxResults[queryNr] = numberResults;
				
			queryMixRuntime += timeInSeconds;
		}
		
		currentQueryIndex++;
	}

	public Query[] getQueries() {
		return queries;
	}

	public Integer[] getQueryMix() {
		return queryMix;
	}

	public double[] getAqet() {
		return aqet;
	}

	public double[] getQmin() {
		return qmin;
	}

	public double[] getQmax() {
		return qmax;
	}

	public int[] getRunsPerQuery() {
		return runsPerQuery;
	}

	public int getQueryMixRuns() {
		return queryMixRuns;
	}

	public double getQmph() {
		return 3600 / (totalRuntime / queryMixRuns);
	}

	public double getQueryMixRuntime() {
		return queryMixRuntime;
	}

	public double getTotalRuntime() {
		return totalRuntime;
	}
	
	public double getCQET() {
		return totalRuntime / queryMixRuns;
	}

	public double getMinQueryMixRuntime() {
		return minQueryMixRuntime;
	}

	public double getMaxQueryMixRuntime() {
		return maxQueryMixRuntime;
	}

	public void setQueryMixRuntime(double queryMixRuntime) {
		this.queryMixRuntime = queryMixRuntime;
	}

	public int getRun() {
		return run;
	}

	public double[] getAvgResults() {
		return avgResults;
	}

	public int[] getMinResults() {
		return minResults;
	}

	public int[] getMaxResults() {
		return maxResults;
	}

	public double[] getGeoMean() {
		double[] temp = new double[aqetg.length];
		for(int i=0;i<temp.length;i++)
			temp[i] = Math.pow(10, aqetg[i]/runsPerQuery[i]);

		return temp;
	}

	public double getQueryMixGeoMean() {
		return Math.pow(10, (queryMixGeoMean/queryMixRuns));
	}
}
