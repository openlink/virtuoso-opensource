/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
import java.util.*;
import java.sql.*;

public class VirtuosoPoint
{
    public double x;
    public double y;


    public VirtuosoPoint (double _x, double _y)
    {
    	this.x = _x;
    	this.y = _y;
    }

    public VirtuosoPoint (String data) throws IllegalArgumentException
    {
        if (data == null)
            throw new IllegalArgumentException();
        StringTokenizer strtok = new StringTokenizer(data," ");
        if (strtok.hasMoreTokens()) {
            this.x = Double.parseDouble(strtok.nextToken());
            if (strtok.hasMoreTokens())
                this.y = Double.parseDouble(strtok.nextToken());
            else
                throw new IllegalArgumentException();
        } else {
            throw new IllegalArgumentException();
        }
    }

    public String toString ()
    {
    	return "POINT("+x+" "+y+")";
    }
}

