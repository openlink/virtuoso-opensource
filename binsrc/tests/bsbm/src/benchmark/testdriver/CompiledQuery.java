package benchmark.testdriver;

public class CompiledQuery {
	private String queryString;
        private String parametrizedQueryString;
	private String encodedParamString;
	private byte queryType;
	private int nr;
	private int queryMix;
	
	CompiledQuery(String queryString, String parametrizedQueryString, String encodedParamString, byte queryType, int queryNr) {
		this.queryString = queryString;
		this.parametrizedQueryString = parametrizedQueryString;
		this.encodedParamString = encodedParamString;
		this.queryType = queryType;
		this.nr = queryNr;
	}

	public String getQueryString() {
		return queryString;
	}

	public String getParametrizedQueryString()
	{
		return parametrizedQueryString;
	}

	public String getEncodedParamString()
	{
		return encodedParamString;
	}

	public byte getQueryType()
	{
		return queryType;
	}

	public int getQueryMix() {
		return queryMix;
	}

	public void setQueryMix(int queryMix) {
		this.queryMix = queryMix;
	}

	public int getNr() {
		return nr;
	}
}
