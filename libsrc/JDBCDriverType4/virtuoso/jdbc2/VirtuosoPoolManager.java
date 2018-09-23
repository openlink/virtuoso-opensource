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

class VirtuosoPoolManager {

  private static WeakHashMap<Object,Object> connPools = new WeakHashMap<Object,Object>(50);
  private static VirtuosoPoolManager poolMgr = null;
  private static Object lock = new Object();
  private static ThreadGroup thrGroup = null;
  private static Thread poolChecker = null;
  private static Thread propertyChecker = null;


  protected static VirtuosoPoolManager getInstance() {
    synchronized(lock) {
      if (poolMgr == null) {
        poolMgr = new VirtuosoPoolManager();
        thrGroup = new ThreadGroup("Virtuoso Pool Manager");
        thrGroup.setDaemon(true);

        poolChecker = new Thread(thrGroup, "Virtuoso Pool Checker") {
          public void run() {
            Object[] poolTmp;
            VirtuosoConnectionPoolDataSource pds;
            while(true) {
              try {
                sleep(500L);
              } catch (InterruptedException e) { }
              synchronized(lock) {
                  poolTmp = connPools.keySet().toArray();
              }
              for(int i = 0; i < poolTmp.length; i++) {
                  pds = (VirtuosoConnectionPoolDataSource)poolTmp[i];
                  if (pds != null)
                    pds.checkPool();
                  poolTmp[i] = null;
              }
              pds = null;
            }
          }
        };
        poolChecker.setDaemon(true);
        poolChecker.start();

        propertyChecker = new Thread(thrGroup, "Virtuoso Property Checker") {
          public void run() {
            Object[] poolTmp;
            VirtuosoConnectionPoolDataSource pds;
            while(true) {
              try {
                sleep(500L);
              } catch (InterruptedException e) { }
              synchronized(lock) {
                  poolTmp = connPools.keySet().toArray();
              }
              for(int i = 0; i < poolTmp.length; i++) {
                  pds = (VirtuosoConnectionPoolDataSource)poolTmp[i];
                  if (pds != null)
                    pds.checkPropQueue();
                  poolTmp[i] = null;
              }
              pds = null;
            }
          }
        };
        propertyChecker.setDaemon(true);
        propertyChecker.start();
      }
    }
    return poolMgr;
  }


  protected void addPool(VirtuosoConnectionPoolDataSource pool) {
    synchronized(lock) {
     connPools.put(pool, null);
    }
  }


  protected VirtuosoPoolStatistic[] getAll_statistics() {
   VirtuosoConnectionPoolDataSource[] poolTmp = (VirtuosoConnectionPoolDataSource[])(connPools.keySet().toArray(new VirtuosoConnectionPoolDataSource[0]));
   VirtuosoPoolStatistic[] retVal = new VirtuosoPoolStatistic[poolTmp.length];
   for(int i = 0; i < poolTmp.length; i++) {
      retVal[i] = poolTmp[i].get_statistics();
      poolTmp[i] = null;
    }
    return retVal;
  }
}
