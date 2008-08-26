package benchmark.testdriver;

	
public interface ServerConnection {
	/*
	 * Execute Query with Query Object
	 */
	public void executeQuery(Query query, byte queryType);
	
	public void executeQuery(CompiledQuery query, CompiledQueryMix queryMix);
	
	public void close();
}

