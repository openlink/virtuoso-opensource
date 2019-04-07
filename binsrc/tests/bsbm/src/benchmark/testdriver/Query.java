package benchmark.testdriver;

import java.io.*;
import java.util.*;

public class Query {
	public Byte queryType;
	private String[] parameterNames;
	private Object[] parameters;
	private Integer[] parameterFills;
	private Byte[] parameterTypes;
	private Vector<String> queryStrings;
	private int nr;
	private QueryMix queryMix;
	private String parameterChar;
	private String parametrizedQueryString;
        public final String defaultGraph;
	public final byte queryLang;
	public final byte querySyntax;
	public final boolean isParametrized;
	private String[] rowNames;//which rows to look at for validation

	//Parameter constants
	public static final byte PRODUCT_PROPERTY_NUMERIC = 1;
	public static final byte PRODUCT_FEATURE_URI = 2;
	public static final byte PRODUCT_TYPE_URI = 3;
	public static final byte CURRENT_DATE = 4;
	public static final byte WORD_FROM_DICTIONARY1 = 5;
	public static final byte WORD_FROM_DICTIONARY1_QUOTED = 6;
	public static final byte PRODUCT_URI = 7;
	public static final byte REVIEW_URI = 8;
	public static final byte COUNTRY_URI = 9;
	public static final byte OFFER_URI = 10;

	//query type constants
	public static final byte SELECT_TYPE = 1;
	public static final byte DESCRIBE_TYPE = 2;
	public static final byte CONSTRUCT_TYPE = 3;

	public Query(String queryString, String parameterDescription, byte ql, byte qs, String dg, boolean isP)
	{
		queryLang = ql;
		querySyntax = qs;
		if (TestDriver.VIRTUOSO_FAMILY == qs)
			parameterChar = "%";
		else
			parameterChar = "@";
                defaultGraph = dg;
                isParametrized = isP;
		init(queryString, parameterDescription);
	}

	public Query(File queryFile, File parameterDescriptionFile, byte ql, byte qs, String dg, boolean isP)
	{
		queryLang = ql;
		querySyntax = qs;
		if (TestDriver.SPARQL_LANG == ql)
			parameterChar = "%";
		else
			parameterChar = "@";
                defaultGraph = dg;
                isParametrized = isP;
		String queryString = "";
		String parameterDescriptionString = "";

		try{
			BufferedReader queryReader = new BufferedReader(new InputStreamReader(new FileInputStream(queryFile)));
			StringBuffer sb = new StringBuffer();

			while(true) {
				String line = queryReader.readLine();
				if(line==null)
					break;
				else {
					sb.append(line);
					sb.append("\n");
				}
			}
			queryString = sb.toString();

			//Now the parameter description
			BufferedReader descriptionReader = new BufferedReader(new InputStreamReader(new FileInputStream(parameterDescriptionFile)));
			sb = new StringBuffer();

			while(true) {
				String line = descriptionReader.readLine();
				if(line==null)
					break;
				else {
					sb.append(line);
					sb.append("\n");
				}
			}
			parameterDescriptionString = sb.toString();

		} catch(IOException e){
			System.err.println(e.getMessage());
			System.exit(-1);
		}

		init(queryString, parameterDescriptionString);
	}

	/*
	 * Initialize the Query
	 */
	private void init(String queryString, String parameterDescription) {
		queryStrings = prepareQueryStrings(queryString);
		parametrizedQueryString = prepareParametrizedQueryString(queryString);
		queryType = SELECT_TYPE;//default: Select query

		if(queryStrings == null) {
			System.err.println("Error in Query");
			System.exit(-1);
		}

		processParameters(queryString, parameterDescription);

		parameters = new Object[parameterTypes.length];
	}

	/*
	 * Sets the Query Parameter Types and their places in the query,
	 * namely the two arrays parameterFills and parameterTypes
	 */
	private void processParameters(String queryString, String parameterDescription) {
                Vector<String> parameterN = new Vector<String>();
		//parameterType Array
		Vector<Byte> parameterT = new Vector<Byte>();
		//StringTokenizer for the parameter description String
		StringTokenizer paramTokenizer = new StringTokenizer(parameterDescription);
		//Mapping of Parameter names to their array position
		HashMap<String, Integer> mapping = new HashMap<String, Integer>();

		Integer index = 0;//Array index for ParameterTypes

		//Read Query Description
		while(paramTokenizer.hasMoreTokens()) {
			String line = paramTokenizer.nextToken();
			//Skip uninteresting lines
			if(!line.contains("="))
				continue;

			int offset = line.indexOf("=");
			//Parameter name
			String parameter = line.substring(0,offset);

			offset++;
			//Parameter Type
			String paramType = line.substring(offset);

			//If special parameter querytype is given save query type for later use
			if(parameter.toLowerCase().equals("querytype")) {
				byte qType = getQueryType(paramType);
				if(qType==0) {
					System.err.println("Invalid query type chosen. Use Select or Describe." +
									" Using default: Select");
				}
				else
					queryType = qType;
			}//else get Parameter
			else {
				Byte byteType = getParamType(paramType);
				if(byteType==0) {
					System.err.println("Unknown Type: " + paramType);
					System.exit(-1);
				}
				mapping.put(parameter, index++);
				parameterN.add(parameter);
				parameterT.add(byteType);
			}
		}

		parameterNames = new String[parameterN.size()];
		parameterTypes = new Byte[parameterT.size()];
		for(int i=0;i<parameterT.size();i++) {
			parameterNames[i] = parameterN.elementAt(i);
			parameterTypes[i] = parameterT.elementAt(i);
		}

		//fill parameterFills
		Vector<Integer> paramFills = new Vector<Integer>();
		index = 0;//Array index
		int index1 = 0;
		int index2 = -1;
		while(queryString.indexOf(parameterChar,index2+1)!=-1) {

			index1 = queryString.indexOf(parameterChar, index2+1);

			index2 = queryString.indexOf(parameterChar, index1+1);

			String parameter = queryString.substring(index1+1, index2);

			paramFills.add(mapping.get(parameter));
		}

		parameterFills = new Integer[paramFills.size()];
		for(int i=0;i<paramFills.size();i++)
			parameterFills[i] = paramFills.elementAt(i);
	}

	/*
	 * get the byte type representation of this parameter string
	 */
	private byte getParamType(String stringType) {
		if(stringType.equals("ProductPropertyNumericValue"))
			return PRODUCT_PROPERTY_NUMERIC;
		else if(stringType.equals("ProductFeatureURI"))
			return PRODUCT_FEATURE_URI;
		else if(stringType.equals("ProductTypeURI"))
			return PRODUCT_TYPE_URI;
		else if(stringType.equals("CurrentDate"))
			return CURRENT_DATE;
		else if(stringType.equals("Dictionary1"))
			return WORD_FROM_DICTIONARY1;
		else if(stringType.equals("Dictionary1Quoted"))
			return WORD_FROM_DICTIONARY1_QUOTED;
		else if(stringType.equals("ProductURI"))
			return PRODUCT_URI;
		else if(stringType.equals("ReviewURI"))
			return REVIEW_URI;
		else if(stringType.equals("CountryURI"))
			return COUNTRY_URI;
		else if(stringType.equals("OfferURI"))
			return OFFER_URI;
		else
			return 0;
	}

	/*
	 * get the byte type representation of this query type string
	 */
	private byte getQueryType(String stringType) {
		if(stringType.toLowerCase().equals("select"))
			return SELECT_TYPE;
		else if(stringType.toLowerCase().equals("describe"))
			return DESCRIBE_TYPE;
		else if(stringType.toLowerCase().equals("construct"))
			return CONSTRUCT_TYPE;
		else
			return 0;
	}

	/*
	 * Get the Query String components without the parameter Strings
	 */
	private Vector<String> prepareQueryStrings(String queryString) {
		Vector<String> queryStrings = new Vector<String>();

		int index1 = 0;
		int index2 = -1;
		while(queryString.contains(parameterChar)) {

			index1 = queryString.indexOf(parameterChar, index2+1);
			if(index1==-1) {
				index2++;
				break;
			}

			queryStrings.add(queryString.substring(index2+1, index1));

			index2 = queryString.indexOf(parameterChar, index1+1);
			if(index2==-1)
				return null;//Error: Shouldn't happen
		}

		if(index2==-1)
			index2++;

		queryStrings.add(queryString.substring(index2));
		return queryStrings;
	}

	/*
	 * Get the string with parameter palceholders replaced with parameter variables
	 */
	private String prepareParametrizedQueryString(String queryString)
	{
		StringBuffer res = new StringBuffer();
		int index1 = 0;
		int index2 = -1;
		while (queryString.contains(parameterChar))
		{
			index1 = queryString.indexOf(parameterChar, index2 + 1);
			if (index1 == -1)
			{
				index2++;
				break;
			}
			res.append (queryString.substring(index2 + 1, index1));
			index2 = queryString.indexOf(parameterChar, index1 + 1);
			if (index2 == -1)
				return null;//Error: Shouldn't happen
			String parameter = queryString.substring(index1 + 1, index2);
			res.append("?");
			res.append(parameter);
		}
		if (index2 == -1)
			index2++;
		res.append(queryString.substring(index2));
		return res.toString();
	}

	public void setParameters(Object[] param) {
		if(parameters.length==param.length)
			parameters = param;
		else {
			System.err.println("Invalid parameter count.");
			System.exit(-1);
		}
	}

	/*
	 * returns a String of the Query with query parameters filled in.
	 */
	public String getQueryString() {
		StringBuffer s = new StringBuffer();

		s.append(queryStrings.get(0));
		for(int i=1;i<queryStrings.size();i++) {
			s.append(parameters[parameterFills[i-1]]);
			s.append(queryStrings.get(i));
		}

		return s.toString();
	}
	public String getParametrizedQueryString() {
		return parametrizedQueryString;
	}
	public String getEncodedParamString()
	{
		StringBuffer s = new StringBuffer();
		try {
			for (int i = 0; i < parameterNames.length; i++)
			{
				StringBuffer s1 = new StringBuffer();
				s.append("&%3F");
				s.append(parameterNames[i]);
				s.append("=");
				s1.append(parameters[i]);
				s.append(java.net.URLEncoder.encode(s1.toString(), "UTF-8"));
			}
		} catch(UnsupportedEncodingException e) {
			System.err.println(e.toString());
			System.exit(-1);
		}
		return s.toString();
	}

	public Byte[] getParameterTypes() {
		return parameterTypes;
	}

	public int getNr() {
		return nr;
	}

	public void setNr(int nr) {
		this.nr = nr;
	}

	public Byte getQueryType() {
		return queryType;
	}

	public QueryMix getQueryMix() {
		return queryMix;
	}

	public void setQueryMix(QueryMix queryMix) {
		this.queryMix = queryMix;
	}

	public String[] getRowNames() {
		return rowNames;
	}

	public void setRowNames(String rowNames[]) {
		this.rowNames = rowNames;
	}
}
