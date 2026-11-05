#
# Graph analytics library for Virtuoso core.
#
noinst_LTLIBRARIES = libgraph.la

libgraph_la_SOURCES = \
	graph_core.c \
	graph_delta.c \
	graph_snapshot.c \
	graph_cache.c \
	graph_quad.c \
	graph_algo.c \
	graph_algo_centrality.c \
	graph_algo_advanced.c \
	graph_algo_community.c \
	graph_mmap.c \
	graph_reduce.c \
	graph_parallel.c

libgraph_la_CFLAGS = $(VIRT_AM_CFLAGS) -I$(top_srcdir)/libsrc -I$(top_srcdir)/libsrc/Dk -I$(top_srcdir)/libsrc/Thread
libgraph_la_LIBADD = -lm

noinst_HEADERS = graph.h graph_algo.h graph_algo_advanced.h \
	graph_cache.h graph_quad.h graph_internal.h graph_mmap.h graph_neighbor.h \
	graph_optim.h graph_reduce.h
