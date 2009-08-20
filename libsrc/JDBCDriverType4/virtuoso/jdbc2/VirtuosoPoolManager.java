package virtuoso.jdbc2;

import java.util.*;

class VirtuosoPoolManager {

#if JDK_VER >= 16
  private static WeakHashMap<Object,Object> connPools = new WeakHashMap<Object,Object>(50);
#else
  private static WeakHashMap connPools = new WeakHashMap(50);
#endif
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

}
