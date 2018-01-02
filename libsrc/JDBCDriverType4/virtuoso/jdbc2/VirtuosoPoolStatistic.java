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

import java.util.*;

public class VirtuosoPoolStatistic implements Cloneable {

  protected String name;
#if JDK_VER >= 16
  protected volatile int conn_unUsed;
  protected volatile int connIn_Use;
  protected volatile int cacheSize = 0;
  protected volatile int _hits = 0;
  protected volatile int _misses = 0;
  protected volatile long _max_wtime = 0L;
  protected volatile long _min_wtime = 0L;
  protected volatile long _cum_wtime = 0L;
#else
  protected int conn_unUsed;
  protected int connIn_Use;
  protected int cacheSize = 0;
  protected int _hits = 0;
  protected int _misses = 0;
  protected long _max_wtime = 0L;
  protected long _min_wtime = 0L;
  protected long _cum_wtime = 0L;
#endif

  protected VirtuosoPoolStatistic() {
  }

  protected void setCacheParam(String _name, int _cacheSize, int _conn_unUsed, int _connIn_Use) {
    name = _name;
    cacheSize = _cacheSize;
    conn_unUsed = _conn_unUsed;
    connIn_Use = _connIn_Use;
  }

  protected void setWaitingTime(long tm) {
    if(_min_wtime == 0L || tm < _min_wtime )
       _min_wtime = tm;
    if(tm > _max_wtime)
       _max_wtime = tm;
    _cum_wtime += tm;
  }


  protected synchronized Object clone() {
    try {
      VirtuosoPoolStatistic v = (VirtuosoPoolStatistic)super.clone();
      v._hits = _hits;
      v._misses = _misses;
      v._max_wtime = _max_wtime;
      v._min_wtime = _min_wtime;
      v._cum_wtime = _cum_wtime;
      return v;
    } catch (CloneNotSupportedException e) {
      // this shouldn't happen, since we are Cloneable
      throw new InternalError();
    }
  }


  /**
   * Returns the amount of the connection pool hits.
   */
  public int getHits() {
    return _hits;
  }

  /**
   * Returns the amount of the connection pool misses.
   */
  public int getMisses() {
    return _misses;
  }

  /**
   * Returns the maximal waiting time for the connection pool.
   */
  public long getMaxWaitTime() {
    return _max_wtime;
  }

  /**
   * Returns the minimal waiting time for the connection pool.
   */
  public long getMinWaitTime() {
    return _min_wtime;
  }

  /**
   * Returns the sum of all waiting time for the connection pool.
   */
  public long getCumWaitTime() {
    return _cum_wtime;
  }

  /**
   * Returns the connection pool size.
   */
  public int getCacheSize() {
    return cacheSize;
  }

  /**
   * Returns the amount of used connections in the connection pool size.
   */
  public int getConnsInUse() {
    return connIn_Use;
  }

  /**
   * Returns the amount of unused connections in the connection pool size.
   */
  public int getConnsUnUsed() {
    return conn_unUsed;
  }

  /**
   * Returns the name of ConectionPoolDataSource.
   */
  public String getName() {
    return name;
  }



  public String toString() {
    StringBuffer buf = new StringBuffer(128);
    buf.append("--------------------------------------\n");
    buf.append("  ** Cache Statistics for the ["+name+"] **\n");
    buf.append("--------------------------------------\n");
    buf.append(" connection's cacheSize= ");  buf.append(cacheSize); buf.append('\n');
    buf.append("      used connections = ");  buf.append(connIn_Use); buf.append('\n');
    buf.append("    unused connections = ");  buf.append(conn_unUsed); buf.append('\n');
    buf.append("      total cache hits = ");  buf.append(_hits); buf.append('\n');
    buf.append("    total cache misses = ");  buf.append(_misses); buf.append('\n');
    buf.append(" min waiting time (millisec)= ");  buf.append(_min_wtime); buf.append('\n');
    buf.append(" max waiting time (millisec)= ");  buf.append(_max_wtime); buf.append('\n');
    buf.append(" avg waiting time (millisec)= ");  buf.append((_misses==0 ? 0 : _cum_wtime/_misses)); buf.append('\n');
    return buf.toString();
  }
}
