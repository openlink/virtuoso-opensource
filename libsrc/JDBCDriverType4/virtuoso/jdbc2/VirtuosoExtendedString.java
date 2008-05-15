/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2008 OpenLink Software
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

package virtuoso.jdbc2;

import java.lang.*;
import java.io.*;

public class VirtuosoExtendedString 
{
    public String str;
    public int strType;
    public int iriType;

    public static final int IRI = 1;
    public static final int BNODE = 2;

    public VirtuosoExtendedString (String str, int type)
    {
	this.str = str;
	this.strType = type;
	if (str.indexOf ("nodeID://") == 0)
	    this.iriType = VirtuosoExtendedString.BNODE;
	else
	    this.iriType = VirtuosoExtendedString.IRI;
    }
    
    public VirtuosoExtendedString (int type)
    {
	this.str = new String ();
	this.strType = type;
	this.iriType = VirtuosoExtendedString.IRI;
    }
    
    public String toString ()
    {
	return this.str;
    }
}
