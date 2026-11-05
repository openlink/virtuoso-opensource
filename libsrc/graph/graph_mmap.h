/*
 *  graph_mmap.h
 *
 *  Memory-mapped graph file format
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
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

#ifndef GRAPH_MMAP_H
#define GRAPH_MMAP_H

#include "graph.h"

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * FILE FORMAT CONSTANTS
 * ============================================================================ */

#define GRAPH_MMAP_MAGIC        0x47524150484D4D50ULL	/* "GRAPHMMP" */
#define GRAPH_MMAP_VERSION      1
#define GRAPH_MMAP_HEADER_SIZE  4096

/* ============================================================================
 * FILE HEADER
 * ============================================================================ */

  typedef struct graph_mmap_header
  {
    uint64_t magic;		/* GRAPH_MMAP_MAGIC */
    uint32_t version;		/* File format version */
    uint32_t flags;		/* Feature flags */

    uint64_t node_count;	/* Total unique nodes */
    uint64_t triple_count;	/* Total triples */
    uint64_t predicate_count;	/* Unique predicates */

    uint64_t node_section_offset;
    uint64_t node_section_size;

    uint64_t edge_offset_section_offset;
    uint64_t edge_offset_section_size;

    uint64_t edge_section_offset;
    uint64_t edge_section_size;

    uint64_t inv_offset_section_offset;
    uint64_t inv_offset_section_size;

    uint64_t inv_edge_section_offset;
    uint64_t inv_edge_section_size;

    uint64_t delta_section_offset;
    uint64_t delta_section_size;

    uint64_t checksum;		/* CRC64 of data sections */

    uint8_t reserved[GRAPH_MMAP_HEADER_SIZE - 144];
  } graph_mmap_header_t;

   _Static_assert (sizeof (graph_mmap_header_t) == GRAPH_MMAP_HEADER_SIZE,
      "graph_mmap_header_t must be exactly GRAPH_MMAP_HEADER_SIZE bytes");

/* ============================================================================
 * FILE FLAGS
 * ============================================================================ */

#define GRAPH_MMAP_FLAG_INVERSE     (1 << 0)	/* Has inverse index */
#define GRAPH_MMAP_FLAG_DELTAS      (1 << 1)	/* Has delta section */
#define GRAPH_MMAP_FLAG_COMPRESSED  (1 << 2)	/* Data is compressed */
#define GRAPH_MMAP_FLAG_SORTED      (1 << 3)	/* Edges are sorted */

/* ============================================================================
 * FILE I/O FUNCTIONS
 * ============================================================================ */

/* Open a memory-mapped graph file */
  graph_error_t graph_mmap_open (const char *path, graph_t ** out_graph);

/* Close and unmap a memory-mapped graph */
  graph_error_t graph_mmap_close (graph_t * graph);

/* Write a graph to a file */
  graph_error_t graph_write_to_file (const graph_t * graph, const graph_snapshot_t * snapshot, const char *path);

/* Read a graph from a file (non-mmap, copies data) */
  graph_error_t graph_read_from_file (const char *path, graph_t ** out_graph);

/* Sync memory-mapped changes to disk */
  graph_error_t graph_mmap_sync (graph_t * graph);

/* Get file information */
  graph_error_t graph_mmap_get_info (const char *path, graph_mmap_header_t * out_header);

/* ============================================================================
 * DELTA PERSISTENCE
 * ============================================================================ */

/* Save uncommitted deltas to file */
  graph_error_t graph_delta_save (const graph_t * graph, const char *path);

/* Load deltas from file and apply to graph */
  graph_error_t graph_delta_load (graph_t * graph, const char *path);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_MMAP_H */
