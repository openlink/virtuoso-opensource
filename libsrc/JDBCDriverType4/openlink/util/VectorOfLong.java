/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
 */

package openlink.util;

import java.util.*;

/**
 * The VectorOfLong class is an implementation to store Long objects.
 *
 * @see java.util.Vector
 */
public class VectorOfLong extends openlink.util.Vector
{
   /**
    * Constructs an empty vector of Long objects.
    */
   public VectorOfLong()
   {
      super();
   }

   /**
    * Constructs an empty vector with the specified initial capacity.
    *
    * @parameter initialCapacity	The initial capacity of the vector.
    */
   public VectorOfLong(int initialCapacity)
   {
      super(initialCapacity);
   }

   /**
    *	Constructs an empty vector with the specified initial capacity
    * and capacity increment.
    *
    * @parameter initialCapacity	The initial capacity of the vector.
    * @parameter capacityIncrement	The amount by which the capacity is increased when the vector overflows.
    */
   public VectorOfLong(int initialCapacity, int capacityIncrement)
   {
      super(initialCapacity,capacityIncrement);
   }

   /**
    *	Constructs a vector from an array of Long.
    *
    * @parameter array	The array of long to copy into the vector.
    */
   public VectorOfLong(Object[] array)
   {
      super(array);
   }

}

