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

package virtuoso.jdbc4;

import java.sql.*;

/**
 * An exception thrown when an error
 * occurs during a batch update operation.A
 * <code>BatchUpdateException</code> provides the update
 * counts for all commands that were executed successfully during the
 * batch update, that is, all commands that were executed before the error
 * occurred.  The order of elements in an array of update counts
 * corresponds to the order in which commands were added to the batch.
 *
 * @version 1.0 (JDBC API 1.2 implementation)
 */
public class BatchUpdateException extends SQLException
{
   private int[] updateCounts;

   /**
    * Constructs a <code>BatchUpdateException</code> initialized to
    * <code>null</code> for the reason and SQLState and 0 for the
    * vendor code.
    * @param updateCounts an array of <code>int</code>, with each element
    * indicating the update count for a SQL command that executed
    * successfully before the exception was thrown
    */
   public BatchUpdateException(String err, int[] updateCounts)
   {
      super(err);
      this.updateCounts = updateCounts;
   }

   public BatchUpdateException(int[] updateCounts)
   {
      super();
      this.updateCounts = updateCounts;
   }

   /**
    * Retrieves the update count for each update statement in the batch
    * update that executed successfully before this exception occurred.
    * @return an array of <code>int</code> containing the update counts
    * for the updates that were executed successfully before this error
    * occurred
    */
   public int[] getUpdateCounts()
   {
      return updateCounts;
   }

}

