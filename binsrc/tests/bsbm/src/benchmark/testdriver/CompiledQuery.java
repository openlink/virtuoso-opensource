package benchmark.testdriver;

public class CompiledQuery {
        public final Query source;
	private String queryString;
	private String encodedParamString;
//	private int nr;
	int queryMix;
	CompiledQuery(Query source, String queryString, String encodedParamString) {
		this.source = source;
		this.queryString = queryString;
		this.encodedParamString = encodedParamString;
	}

	public String getQueryString() {
		return queryString;
	}

	public String getParametrizedQueryString()
	{
		return source.getParametrizedQueryString();
	}

	public String getEncodedParamString()
	{
		return encodedParamString;
	}

	public byte getQueryType()
	{
		return source.queryType;
	}

//	public int getQueryMix() {
//		return queryMix;
//	}

//	public void setQueryMix(int queryMix) {
//		this.queryMix = queryMix;
//	}

	public int getNr() {
		return source.getNr();
	}
}
