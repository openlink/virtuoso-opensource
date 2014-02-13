/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

package virtuoso.sesame3.driver;


import java.util.Properties;
import java.util.ArrayList;
import java.util.List;
import java.util.Collection;
import java.net.URL;
import java.io.IOException;
import java.io.InputStream;

import org.openrdf.OpenRDFUtil;
import org.openrdf.query.QueryLanguage;

import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFParserFactory;
import org.openrdf.rio.RDFParserRegistry;
import org.openrdf.rio.RDFWriterFactory;
import org.openrdf.rio.RDFWriterRegistry;

import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryMetaData;
import org.openrdf.store.StoreException;



public class VirtuosoRepositoryMetaData implements RepositoryMetaData  {
	
	private VirtuosoRepository repository;

	VirtuosoRepositoryMetaData(VirtuosoRepository repository) {
		this.repository = repository;
	}


	public String[] getInferenceRules() {
		return new String[0];
	}

	public URL getLocation() {
		return null;
	}

	public int getMaxLiteralLength() {
		return 0;
	}

	public int getMaxURILength() {
		return 0;
	}

	public String[] getQueryFunctions() {
		return new String[0];
	}

	public String[] getReasoners() {
		return new String[0];
	}

	public int getSesameMajorVersion() {
		String version = getSesameVersion();
		if (version == null)
			return 0;
		int idx = version.indexOf('.');
		if (idx < 0)
			return 0;
		try {
			return Integer.parseInt(version.substring(0, idx));
		}
		catch (NumberFormatException e) {
			return 0;
		}
	}

	public int getSesameMinorVersion() {
		String version = getSesameVersion();
		if (version == null)
			return 0;
		int idx = version.indexOf('.');
		if (idx < 0)
			return 0;
		int dot = version.indexOf('.', idx + 1);
		int dash = version.indexOf('-', idx + 1);
		if (dot < 0 && dash < 0)
			return 0;
		int end = 0 < dot && dot < dash ? dot : dash;
		try {
			return Integer.parseInt(version.substring(idx + 1, end));
		}
		catch (NumberFormatException e) {
			return 0;
		}
	}


	public String getSesameVersion() {
		return OpenRDFUtil.findVersion(org.openrdf.sail.helpers.SailMetaDataImpl.class, "org.openrdf.sesame", "sesame-sail-api");
	}

	public boolean isHierarchicalInferencing() {
		return false;
	}

	public boolean isInferencing() {
		return false;
	}


	public boolean isMatchingOnlySameTerm() {
		return false;
	}

	public boolean isOWLInferencing() {
		return false;
	}

	public boolean isRDFSInferencing() {
		return false;
	}

	public QueryLanguage[] getQueryLanguages() {
		QueryLanguage[] val = new QueryLanguage[1];
                val[0] = QueryLanguage.SPARQL;
		return val;
	}


	public RDFFormat[] getAddRDFFormats() {
		Collection<RDFParserFactory> parsers = RDFParserRegistry.getInstance().getAll();
		List<RDFFormat> list = new ArrayList<RDFFormat>(parsers.size());
		for (RDFParserFactory parser : parsers) {
			list.add(parser.getRDFFormat());
		}
		return list.toArray(new RDFFormat[list.size()]);
	}

	public RDFFormat[] getExportRDFFormats() {
		Collection<RDFWriterFactory> writers = RDFWriterRegistry.getInstance().getAll();
		List<RDFFormat> list = new ArrayList<RDFFormat>(writers.size());
		for (RDFWriterFactory writer : writers) {
			list.add(writer.getRDFFormat());
		}
		return list.toArray(new RDFFormat[list.size()]);
	}


	public boolean isRemoteDatasetSupported() {
		return true;
	}

	public boolean isReadOnly() {
		return repository.isReadOnly();
	}

	public boolean isEmbedded() {
		return false;
	}

	public String getStoreName() {
		return "Virtuoso";
	}

	public String getStoreVersion() {
		return "1.1";
	}

	public int getStoreMajorVersion() {
		return 1;
	}

	public int getStoreMinorVersion() {
		return 1;
	}

	public boolean isContextSupported() {
		return true;
	}

	public boolean isContextBNodesSupported() {
		return true;
	}

	public boolean isBNodeIDPreserved() {
		return false;
	}

	public boolean isLiteralDatatypePreserved() {
		return true;
	}

	public boolean isLiteralLabelPreserved() {
		return true;
	}

}
