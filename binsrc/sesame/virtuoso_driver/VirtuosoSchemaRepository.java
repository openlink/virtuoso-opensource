
package virtuoso_driver;

import org.apache.log4j.Logger;
import org.openrdf.model.Resource;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.*;
import org.openrdf.sesame.sail.SailUpdateException;
import org.openrdf.sesame.sail.SailChangedListener;
import org.openrdf.sesame.sail.LiteralIterator;
import org.openrdf.sesame.sail.RdfSchemaSource;
import org.openrdf.sesame.sail.StatementIterator;
import org.openrdf.sesame.sail.NamespaceIterator;
import org.openrdf.sesame.sail.query.Query;
import org.openrdf.sesame.sail.query.QueryOptimizer;
import org.openrdf.sesame.sail.SailInitializationException;

import java.util.Map;

public class VirtuosoSchemaRepository implements org.openrdf.sesame.sail.RdfSchemaRepository
{
    private boolean _transactionStarted = false;

    private Logger logger = Logger.getLogger (VirtuosoSchemaRepository.class);

    public void startTransaction()
    {
	_transactionStarted = true;
    }

    public void commitTransaction()
    {
	_transactionStarted = true;
    }

    public boolean transactionStarted()
    {
	return _transactionStarted;
    }

    public void removeListener (SailChangedListener listener)
    {
    }

    public void addListener(SailChangedListener listener)
    {
    }

    public void addStatement (Resource subj, URI pred, Value obj) throws SailUpdateException
    {
	if (!transactionStarted())
	{
	    throw new SailUpdateException ("no transaction started.");
	}

	logger.info("Adding statement (" + subj + ", " + pred + ", " + obj + ")");
    }

    public int removeStatements (Resource subj, URI pred, Value obj) throws SailUpdateException
    {
	System.out.println("VirtuosoSchemaRepository.java removeStatements");

	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}

	int removed = 0;

	logger.info ("Removing " + removed + " statements (" + subj + ", " + pred + ", " + obj + ")");

	return removed;
    }

    public void clearRepository() throws SailUpdateException
    {
	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}

    }

    public void changeNamespacePrefix(String namespace, String prefix) throws SailUpdateException
    {
	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}
    }

    public LiteralIterator getLiterals (String label, String language, URI datatype)
    {
	LiteralIterator ret = null;
	logger.info("Asking for literals");
	return ret;
    }

    public boolean isDirectType(Resource anInstance, Resource aClass)
    {
	return false;
    }

    public boolean isType (Resource anInstance, Resource aClass)
    {
	return false;
    }

    public StatementIterator getDirectType(Resource anInstance, Resource aClass)
    {
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getType(Resource anInstance, Resource aClass)
    {
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getRange(Resource prop, Resource domain)
    {
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDomain(Resource prop, Resource domain)
    {
	StatementIterator ret = null;
	return ret;
    }

    public boolean isClass(Resource resource)
    {
	return false;
    }

    public StatementIterator getProperties()
    {
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isProperty(Resource resource)
    {
	return false;
    }

    public StatementIterator getSubClassOf(Resource subClass, Resource superClass)
    {
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDirectSubClassOf(Resource subClass, Resource superClass)
    {
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isSubClassOf(Resource subClass, Resource superClass)
    {
	return false;
    }

    public boolean isDirectSubClassOf(Resource subClass, Resource superClass)
    {
	return false;
    }

    public StatementIterator getSubPropertyOf(Resource subProperty, Resource superProperty)
    {
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDirectSubPropertyOf(Resource subProperty, Resource superProperty)
    {
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isSubPropertyOf(Resource subProperty, Resource superProperty)
    {
	return false;
    }

    public boolean isDirectSubPropertyOf(Resource subProperty, Resource superProperty)
    {
	return false;
    }

    public StatementIterator getExplicitStatements(Resource subj, URI pred, Value obj) {
	StatementIterator ret = null;;
	return ret;
    }

    public boolean hasExplicitStatement(Resource subj, URI pred, Value obj)
    {
	return false;
    }

    public StatementIterator getClasses()
    {
	StatementIterator ret = null;;
	return ret;
    }

    public NamespaceIterator getNamespaces()
    {
	NamespaceIterator ret = null;;
	return ret;
    }

    public Query optimizeQuery(Query qc)
    {
	return qc;
    }

    public boolean hasStatement(Resource subj, URI pred, Value obj)
    {
	return false;
    }

    public StatementIterator getStatements(Resource subj, URI pred, Value obj)
    {
	StatementIterator ret = null;;
	return ret;
    }

    public void shutDown()
    {
    }

    public ValueFactory getValueFactory()
    {
	ValueFactory ret = null;;
	return ret;
    }

    public void initialize(Map configParams) throws SailInitializationException
    {
    }
}
