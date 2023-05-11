/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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

package virtuoso.jena.driver;

import org.apache.jena.graph.Triple;
import org.apache.jena.riot.system.StreamRDF;
import org.apache.jena.shared.JenaException;
import org.apache.jena.sparql.core.Quad;

import java.sql.SQLException;
import java.util.ArrayList;

public class VirtStreamRDF implements StreamRDF
{
        protected final VirtModel vm;
        protected final VirtGraph vg;
        protected final int batchSize;
        protected final boolean useAutoCommit;
        protected ArrayList<Quad> buff;
        protected final DeadLockHandler dhandler;


        protected VirtStreamRDF(VirtModel vm, boolean useAutoCommit, int batchSize, DeadLockHandler dhandler) {
            this.vm = vm;
            this.vg = (VirtGraph)vm.getGraph();
            this.useAutoCommit = useAutoCommit;
            this.dhandler = dhandler;
            vm.setResetBNodesDictAfterCommit(false);
            if (batchSize > 0)
                vg.setBatchSize(batchSize);
            this.batchSize = vg.getBatchSize();
            this.buff = new ArrayList<>(batchSize);
        }

        @Override
        public void start() {
            if (!useAutoCommit)
                vm.begin();
            try {
              vg.startBatchAdd();
            } catch(Exception e) {
              throw new JenaException(e);
            }
        }

        @Override
        public void triple(Triple triple) {
            buff.add(new Quad(null, triple));
            check_flush(false);
        }

        @Override
        public void quad(Quad quad) {
            buff.add(quad);
            check_flush(false);
        }

        @Override
        public void base(String base) {
        }

        @Override
        public void prefix(String prefix, String iri) {
            vm.setNsPrefix(prefix, iri);
        }

        @Override
        public void finish() {
            check_flush(true);
            try {
              vg.stopBatchAdd();
            } catch (Exception e) {
              throw new JenaException(e);
            } finally {
              vm.setResetBNodesDictAfterCommit(true);
            }
        }

        void check_flush(boolean end) throws JenaException
        {
            if (buff.size() >= batchSize || end) {
                int pass = 0;

                while(true) {
                    try {
                        if (!useAutoCommit)
                            vm.begin();

                        vg.streamAdd(buff.iterator());

                        if (!useAutoCommit)
                            vm.commit();

                    } catch (Exception e) {
                        Throwable ex = e.getCause();
                        boolean deadlock = (ex instanceof SQLException) && ((SQLException) ex).getSQLState().equals("40001");
                        if (deadlock && dhandler != null) {
                            pass++;
                            vm.abort();

                            boolean rc = dhandler.deadLockFired(pass);
                            if (rc)
                                continue;
                        }
                        throw e;
                    }
                    break;
                }
                buff.clear();
            }

        }


        public static class DeadLockHandler {
            protected final int maxDeadLockCount;

            public DeadLockHandler(int maxDeadLockCount)
            {
                this.maxDeadLockCount = maxDeadLockCount > 0 ? maxDeadLockCount : 0;
            }

            /**
             *
             * @param pass - deadlock attemps for current data chunk
             * @return true - for try insert data chunk again
             *         false - throw DEADLOCK exception
             */
            public boolean deadLockFired(int pass)
            {
                if (maxDeadLockCount == 0 || pass <= maxDeadLockCount)
                    return true; // try insert data chunk again
                else
                    return false; // throw DEADLOCK exception
            }
        }
}
