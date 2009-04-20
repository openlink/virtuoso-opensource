package benchmark.vocabulary;

import java.util.*;

public class BSBM {
	//The Namespace of this vocabulary as String
	public static final String NS = "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/";

	public static final String PREFIX = "bsbm:";

	private static HashMap<String, String> uriMap = new HashMap<String, String>();

	/*
	 * For prefixed versions
	 */
	public static String prefixed(String string) {
		if(uriMap.containsKey(string)) {
			return uriMap.get(string);
		}
		else {
			String newValue = PREFIX + string;
			uriMap.put(string, newValue);
			return newValue;
		}
	}

	//Namespace of the instances for single source RDF stores
	public static final String INST_NS = "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/";

	public static final String INST_PREFIX = "bsbm-inst:";

	//Get the URI of this vocabulary
	public static String getURI() { return NS; }

	//Resource type: Offer
	public static final String Offer = (NS+ "Offer");

	//Resource type: Vendor
	public static final String Vendor = (NS + "Vendor");

	//Resource type: Producer
	public static final String Producer = (NS + "Producer");

	//Resource type: ProductFeature
	public static final String ProductFeature = (NS + "ProductFeature");

	//Resource type: ProductCategory
	public static final String ProductCategory = (NS + "ProductCategory");

	//Resource type: ProductType
	public static final String ProductType = (NS + "ProductType");

	//Resource type: Product
	public static final String Product = (NS + "Product");

	//Property: productFeature
	public static final String productFeature = (NS + "productFeature");

	//Property: productCategory
	public static final String productCategory = (NS + "productCategory");

	//Property: producer
	public static final String producer = (NS + "producer");

	//Property: productStringTextual1
	public static final String productPropertyTextual1 = (NS + "productPropertyTextual1");

	//Property: productPropertyTextual2
	public static final String productPropertyTextual2 = (NS + "productPropertyTextual2");

	//Property: productPropertyTextual3
	public static final String productPropertyTextual3 = (NS + "productPropertyTextual3");

	//Property: productPropertyTextual4
	public static final String productPropertyTextual4 = (NS + "productPropertyTextual4");

	//Property: productPropertyTextual5
	public static final String productPropertyTextual5 = (NS + "productPropertyTextual5");

	//Property: productPropertyTextual6
	public static final String productPropertyTextual6 = (NS + "productPropertyTextual6");

	//Property: productPropertyNumeric1
	public static final String productPropertyNumeric1 = (NS + "productPropertyNumeric1");

	//Property: productPropertyNumeric2
	public static final String productPropertyNumeric2 = (NS + "productPropertyNumeric2");

	//Property: productPropertyNumeric3
	public static final String productPropertyNumeric3 = (NS + "productPropertyNumeric3");

	//Property: productPropertyNumeric4
	public static final String productPropertyNumeric4 = (NS + "productPropertyNumeric4");

	//Property: productPropertyNumeric5
	public static final String productPropertyNumeric5 = (NS + "productPropertyNumeric5");

	//Property: productPropertyNumeric6
	public static final String productPropertyNumeric6 = (NS + "productPropertyNumeric6");

	//Function creating the above numeric properties
	public static String getProductPropertyNumeric(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(NS);
		s.append("productPropertyNumeric");
		s.append(nr);

		return s.toString();
	}

	//Function creating the above numeric properties as prefix version
	public static String getProductPropertyNumericPrefix(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(PREFIX);
		s.append("productPropertyNumeric");
		s.append(nr);

		return s.toString();
	}

	//Function creating the above textual properties
	public static String getProductPropertyTextual(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(NS);
		s.append("productPropertyTextual");
		s.append(nr);

		return s.toString();
	}

	//Function creating the above textual properties
	public static String getProductPropertyTextualPrefix(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(PREFIX);
		s.append("productPropertyTextual");
		s.append(nr);

		return s.toString();
	}

	//Property: country
	public static final String country = (NS + "country");

	//Property: product
	public static final String product = (NS + "product");

	//Property: productType
	public static final String productType = (NS + "productType");

	//Property: vendor
	public static final String vendor = (NS + "vendor");

	//Property: price
	public static final String price = (NS + "price");

	//Data type USD
	public static final String USD = (NS + "USD");

	//Property: validFrom
	public static final String validFrom = (NS + "validFrom");

	//Property: validTo
	public static final String validTo = (NS + "validTo");

	//Property: deliveryDays
	public static final String deliveryDays = (NS + "deliveryDays");

	//Property: offerWebpage
	public static final String offerWebpage = (NS + "offerWebpage");

	//Property: reviewFor
	public static final String reviewFor = (NS + "reviewFor");

	//Property: reviewDate
	public static final String reviewDate = (NS + "reviewDate");

	//Property: rating1
	public static final String rating1 = (NS + "rating1");

	//Property: rating2
	public static final String rating2 = (NS + "rating2");

	//Property: rating3
	public static final String rating3 = (NS + "rating3");

	//Property: rating4
	public static final String rating4 = (NS + "rating4");

	//Function creating the above textual properties
	public static String getRating(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(NS);
		s.append("rating");
		s.append(nr);

		return s.toString();
	}

	//Function creating the above textual properties
	public static String getRatingPrefix(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(PREFIX);
		s.append("rating");
		s.append(nr);

		return s.toString();
	}

	public static String getStandardizationInstitution(int nr)
	{
		StringBuffer s = new StringBuffer();

		s.append(INST_NS);
		s.append("StandardizationInstitution");
		s.append(nr);

		return s.toString();
	}
}
