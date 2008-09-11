package benchmark.testdriver;

import java.io.File;

public class TestDriverDefaultValues {
	public static final int warmups = 32;//how many Query mixes are run for warm up
	public static final File queryDir = new File("queries");
	public static final int nrRuns = 128;
	public static final long seed = 808080L;
	public static final String defaultGraph = null;
	public static final String resourceDir = "td_data";
	public static final String xmlResultFile = "benchmark_result.xml";
	public static final int timeoutInMs = 60000;
	public static final int fetchSize = 100;
}
