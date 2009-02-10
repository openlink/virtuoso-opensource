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
	public static final int timeoutInMs = 0;
	public static final String driverClassName = "com.mysql.jdbc.Driver";
	public static final String defaultUser = "d2r";
	public static final String defaultUserPassword = "d2rbsbm";
	public static final int fetchSize = 100;
	public static final boolean qualification = false;
	public static String qualificationFile = "run.qual";
}
