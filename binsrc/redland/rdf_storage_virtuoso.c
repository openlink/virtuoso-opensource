/* -*- Mode: c; c-basic-offset: 2 -*-
 *
 * rdf_storage_virtuoso.c - RDF Storage in Virtuoso DBMS interface definition.
 *
 * $Id$
 *
 * Based in part on rdf_storage_mysql.
 *
 * Copyright (C) 2000-2006, Openlink Software,  http://www.openlinksw.com/
 *
 * This package is Free Software and part of Redland http://librdf.org/
 *
 * It is licensed under the following three licenses as alternatives:
 *   1. GNU Lesser General Public License (LGPL) V2.1 or any newer version
 *   2. GNU General Public License (GPL) V2 or any newer version
 *   3. Apache License, V2.0 or any newer version
 *
 * You may not use this file except in compliance with at least one of
 * the above three licenses.
 *
 * See LICENSE.html or LICENSE.txt at the top of this package for the
 * complete terms and further detail along with the license texts for
 * the licenses in COPYING.LIB, COPYING and LICENSE-2.0.txt respectively.
 *
 *
 */

#ifdef HAVE_CONFIG_H
#include <rdf_config.h>
#endif

#ifdef WIN32
#include <win32_rdf_config.h>
#include <config-win.h>
#include <winsock.h>
#include <assert.h>
#endif

#include <stdio.h>
#include <string.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h> /* for abort() as used in errors */
#endif
#include <sys/types.h>

#include <redland.h>
#include <rdf_types.h>

/* Virtuoso specific */
#include <odbcinst.h>
#define VIRT_DEBUG 1

typedef enum {
  VITUOSO_CONNECTION_CLOSED = 0,
  VITUOSO_CONNECTION_OPEN = 1,
  VITUOSO_CONNECTION_BUSY = 2
} librdf_storage_virtuoso_connection_status;

typedef struct {
   /* A ODBC connection */
   librdf_storage_virtuoso_connection_status status;
   HDBC handle;
} librdf_storage_virtuoso_connection;

typedef struct {
  /* Virtuoso connection parameters */
  librdf_storage *storage;
  librdf_node *current;
  librdf_storage_virtuoso_connection *connections;
  const char *database;
  const char *user;
  const char *password;
  const char *text_query;
  const char *dsn;
  HENV henv;
  HDBC hdbc;
  HSTMT stmt;
  short numCols;
  int connections_count;
  int bulk;
  int merge;
  int reconnect;
  int res_count;
  librdf_world *world;
} librdf_storage_virtuoso_context;

static int librdf_storage_virtuoso_init(librdf_storage* storage, const char *name,
                                     librdf_hash* options);

static void librdf_storage_virtuoso_terminate(librdf_storage* storage);
static int librdf_storage_virtuoso_open(librdf_storage* storage,
                                     librdf_model* model);
static int librdf_storage_virtuoso_close(librdf_storage* storage);
static int librdf_storage_virtuoso_sync(librdf_storage* storage);
static int librdf_storage_virtuoso_size(librdf_storage* storage);
static int librdf_storage_virtuoso_add_statement(librdf_storage* storage,
                                              librdf_statement* statement);
static int librdf_storage_virtuoso_add_statements(librdf_storage* storage,
                                               librdf_stream* statement_stream);
static int librdf_storage_virtuoso_remove_statement(librdf_storage* storage,
                                                 librdf_statement* statement);
static int librdf_storage_virtuoso_contains_statement(librdf_storage* storage,
                                                   librdf_statement* statement);
static librdf_stream*
       librdf_storage_virtuoso_serialise(librdf_storage* storage);
static librdf_stream*
       librdf_storage_virtuoso_find_statements(librdf_storage* storage,
                                            librdf_statement* statement);
static librdf_stream*
       librdf_storage_virtuoso_find_statements_with_options(librdf_storage* storage,
                                                         librdf_statement* statement,
                                                         librdf_node* context_node,
                                                         librdf_hash* options);

/* context functions */
static int librdf_storage_virtuoso_context_add_statement(librdf_storage* storage,
                                                      librdf_node* context_node,
                                                      librdf_statement* statement);
static int librdf_storage_virtuoso_context_add_statements(librdf_storage* storage,
                                                       librdf_node* context_node,
                                                       librdf_stream* statement_stream);
static int librdf_storage_virtuoso_context_remove_statement(librdf_storage* storage,
                                                         librdf_node* context_node,
                                                         librdf_statement* statement);
static int librdf_storage_virtuoso_context_remove_statements(librdf_storage* storage,
                                                          librdf_node* context_node);
static librdf_stream*
       librdf_storage_virtuoso_context_serialise(librdf_storage* storage,
                                              librdf_node* context_node);
static librdf_stream* librdf_storage_virtuoso_find_statements_in_context(librdf_storage* storage,
                                               librdf_statement* statement,
                                               librdf_node* context_node);
static librdf_iterator* librdf_storage_virtuoso_get_contexts(librdf_storage* storage);

static void librdf_storage_virtuoso_register_factory(librdf_storage_factory *factory);

static librdf_node*
librdf_storage_virtuoso_get_feature(librdf_storage* storage, librdf_uri* feature);

static int
librdf_storage_virtuoso_transaction_start(librdf_storage* storage);

static int
librdf_storage_virtuoso_transaction_start_with_handle(librdf_storage* storage,
                                                   void* handle);
static int
librdf_storage_virtuoso_transaction_commit(librdf_storage* storage);

static int
librdf_storage_virtuoso_transaction_rollback(librdf_storage* storage);

static void*
librdf_storage_virtuoso_transaction_get_handle(librdf_storage* storage);

int
rdf_virtuoso_ODBC_Errors (char *where, librdf_storage_virtuoso_context* context);


int
rdf_virtuoso_ODBC_Errors (char *where, librdf_storage_virtuoso_context* context)
{
  char buf[250];
  char sqlstate[15];

  while (SQLError (context->henv, context->hdbc, context->stmt, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  while (SQLError (context->henv, context->hdbc, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  while (SQLError (context->henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  return -1;
}


static unsigned char *
librdf_storage_virtuoso_str_esc (const unsigned char *raw, size_t raw_len, size_t *len_p)
{
  int escapes=0;
  unsigned char *p;
  unsigned char *escaped;
  int len;

  for(p=(unsigned char*)raw, len=(int)raw_len; len>0; p++, len--) {
    if(*p == '\'')
      escapes++;
  }

  len= raw_len+escapes+2; /* for '' */
  escaped=(unsigned char*)LIBRDF_MALLOC(cstring, len+1);

  p=escaped;
  *p++='\'';
  while(raw_len > 0) {
    if(*raw == '\'') {
      *p++='\'';
    }
    *p++=*raw++;
    raw_len--;
  }
  *p++='\'';
  *p='\0';

  if(len_p)
    *len_p=len;

  return escaped;
}


static int librdf_storage_virtuoso_init(librdf_storage* storage, const char *name,
                                     librdf_hash* options)
{
  int rc;
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_init \n");
#endif

  rc = SQLAllocEnv (&context->henv);
  rc = SQLAllocConnect (context->henv, &context->hdbc);

  context->connections=NULL;
  context->connections_count=0;
  context->res_count=1; // XXX Debug
  context->storage=storage;
  context->password=librdf_hash_get_del(options, "password");
  context->user=librdf_hash_get_del(options, "user");
  context->text_query=librdf_hash_get_del(options, "query");
  context->dsn=librdf_hash_get_del(options, "dsn");
  context->database=name;

  rc = SQLConnect (context->hdbc, (UCHAR *) context->dsn, SQL_NTS, (UCHAR *) context->user, SQL_NTS,
      (UCHAR *) context->password, SQL_NTS);

  if (rc != SQL_SUCCESS_WITH_INFO)
    {
      SWORD len;
      char state[10];
      char message[1000];
      SQLError (SQL_NULL_HENV, context->hdbc, SQL_NULL_HSTMT, (UCHAR *) state, NULL, (UCHAR *) &message, sizeof (message), &len);
      printf ("\n*** Error %s: %s\n", state, message);
    }


  SQLSetConnectOption (context->hdbc, SQL_AUTOCOMMIT, 0);

  rc = SQLAllocHandle(SQL_HANDLE_STMT, context->hdbc, &context->henv);

  if (context->text_query)
    {

      if (SQLExecDirect(context->henv, (UCHAR *)context->text_query, SQL_NTS) != SQL_SUCCESS)
	rdf_virtuoso_ODBC_Errors ((char *)"SQLExecDirect", context);
      /*
	 if (SQLPrepare(context->henv, (UCHAR *)context->text_query, SQL_NTS) != SQL_SUCCESS)
	 rdf_virtuoso_ODBC_Errors ((char *)"SQLExecDirect", context);
       */
      rc = SQLNumResultCols (context->henv, &context->numCols);
    }

  return 0;
}

static int
librdf_storage_virtuoso_add_remove_statement(librdf_storage* storage,
                                           librdf_statement* statement,
                                           librdf_node* context_node,
                                           int is_addition)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  int i;
  int status=0;


#ifdef VIRT_DEBUG
  if(is_addition)
     fprintf(stderr, "Adding statement: \n");
  else
     fprintf(stderr, "Removing statement: \n");

  librdf_statement_print(statement, stderr);
  fputc('\n', stderr);
#endif


    unsigned char *s;
    char buf[1024];
    unsigned char *s_e;
    size_t uri_e_len;
    size_t uri_len;
    const unsigned char *uri_string;

    s=librdf_statement_to_string(statement);

    s_e=librdf_storage_virtuoso_str_esc(s, strlen (s), &uri_e_len);


    sprintf (buf, "DB.DBA.LIBRDF_ADD ('<%s>', %s)", "test", s_e);

#ifdef VIRT_DEBUG
  fprintf(stderr, "buf = %s \n", buf);
  fprintf(stderr, "s_e = %s \n", s_e);
  fprintf(stderr, "s   = %s \n", s  );
#endif

/*  if (SQLExecDirect(context->henv, (UCHAR *) buf, SQL_NTS) != SQL_SUCCESS)
      rdf_virtuoso_ODBC_Errors ((char *)"SQLExecDirect", context); */

    SQLExecDirect(context->henv, (UCHAR *) buf, SQL_NTS);

    LIBRDF_FREE(cstring, s_e);
    return 1;
    return status; /* FIXME */
}

static void librdf_storage_virtuoso_terminate(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_terminate \n");
#endif
}

static int librdf_storage_virtuoso_open(librdf_storage* storage,
                                     librdf_model* model)
{
  /*librdf_storage_virtuoso_context* scontext=(librdf_storage_virtuoso_context*)storage->context;*/
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_open \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_close(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_close \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_sync(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_sync \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_size(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_size \n");
#endif
  return 1; /* FIXME */
}

static int librdf_storage_virtuoso_add_statement(librdf_storage* storage,
                                              librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_add_statement \n");
#endif
  if(librdf_storage_virtuoso_contains_statement(storage, statement))
    return 0;

  return librdf_storage_virtuoso_add_remove_statement (storage, statement, NULL, 1);
}

static int librdf_storage_virtuoso_add_statements(librdf_storage* storage,
                                               librdf_stream* statement_stream)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_add_statements \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_remove_statement(librdf_storage* storage,
                                                 librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_remove_statement \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_contains_statement(librdf_storage* storage,
                                                   librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_contains_statement \n");
#endif
  return 0;
}

static int
librdf_storage_virtuoso_find_statements_in_context_end_of_stream(void* context)
{
  librdf_storage_virtuoso_context* scontext=(librdf_storage_virtuoso_context*)context;
#ifdef VIRT_DEBUG
  fprintf(stderr, "STREAM ------> librdf_storage_virtuoso_find_statements_in_context_end_of_stream\n");
#endif
  return scontext->res_count==0;
}

static int
librdf_storage_virtuoso_find_statements_in_context_next_statement (void* context)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "STREAM ------> librdf_storage_virtuoso_find_statements_in_context_next_statement \n");
#endif
  return 0;
}

typedef struct _out
{
       char o_title[51];
       SQLULEN o_width;
       SQLULEN o_allocated_buflen;
       SWORD o_type;
       char *o_buffer;
       SQLLEN o_col_len;
       SWORD o_nullable;
}
stmt_out_t;


static void*
librdf_storage_virtuoso_find_statements_in_context_get_statement(void* context, int flags)
{
  librdf_storage_virtuoso_context* scontext=(librdf_storage_virtuoso_context*)context;
  short colNum;
  SDWORD colIndicator;
  stmt_out_t out_cols[5];
  stmt_out_t *out;

#ifdef VIRT_DEBUG
  fprintf(stderr, "STREAM ------> librdf_storage_virtuoso_find_statements_in_context_get_statement \n");
#endif

  switch(flags) {
    case LIBRDF_ITERATOR_GET_METHOD_GET_OBJECT:
    case LIBRDF_ITERATOR_GET_METHOD_GET_CONTEXT:

        if(flags==LIBRDF_ITERATOR_GET_METHOD_GET_OBJECT)
	{
	  librdf_world *world;
	  librdf_statement *current_statement;
	  int rc;
	  world = NULL;
	  current_statement = librdf_new_statement(scontext->storage->world);
/*     	  librdf_statement_set_subject(current_statement,
	      librdf_new_node_from_uri_string (scontext->storage->world, (const unsigned char*)"a"));
          librdf_statement_set_predicate(current_statement,
	      librdf_new_node_from_uri_string (scontext->storage->world, (const unsigned char*)"b"));
          librdf_statement_set_object(current_statement,
	    librdf_new_node_from_uri_string (scontext->storage->world, (const unsigned char*)"c"));*/

	  /* Begin */


	  for (colNum = 1; colNum <= scontext->numCols; colNum++)
	    {
	      out = &out_cols[colNum - 1];

	      if (SQLDescribeCol (scontext->henv, colNum, (UCHAR *) out->o_title,
		    sizeof (out->o_title), NULL, &out->o_type, &out->o_width, NULL, &out->o_nullable) != SQL_SUCCESS)
		  rdf_virtuoso_ODBC_Errors ((char *)"SQLDescribeCol", scontext);
#ifdef VIRT_DEBUG
	      fprintf (stderr, "colName = %s\n", out->o_title);
#endif

	      out->o_buffer = (char *) malloc (2001);

	      if (SQLBindCol (scontext->henv, colNum, SQL_C_CHAR, out->o_buffer, 2002,
		    &out->o_col_len) != SQL_SUCCESS)
		rdf_virtuoso_ODBC_Errors ((char *)"SQLDescribeCol", scontext);

	    }

	  rc = SQLFetch (scontext->henv);

	  if (rc == SQL_NO_DATA_FOUND)
	    {
	      scontext->res_count--;
	      return NULL;
	    }
	  else if (rc != SQL_SUCCESS)
	    {
	      scontext->res_count--;
	      rdf_virtuoso_ODBC_Errors ((char *)"SQLFetch", scontext);
	      return NULL;
	    }

	  for (colNum = 1; colNum <= scontext->numCols; colNum++)
	    {
	      out = &out_cols[colNum - 1];
	      rc = SQLGetData (scontext->henv, colNum, SQL_CHAR, out->o_buffer, 2002, &colIndicator);
#ifdef VIRT_DEBUG
	      fprintf (stderr, "rc    = %i  ", rc);
	      fprintf (stderr, "data  = %s\n", out->o_buffer);
#endif
/*
	      librdf_statement_set_subject(current_statement,
		  librdf_new_node_from_uri_string (scontext->storage->world,
		    (const unsigned char*)"-"));
	      librdf_statement_set_predicate(current_statement,
		  librdf_new_node_from_uri_string (scontext->storage->world,
		    (const unsigned char*)"-"));
	      librdf_statement_set_object(current_statement,
		  librdf_new_node_from_uri_string (scontext->storage->world,
		    (const unsigned char*)"-"));
*/
	      if (strstr (out->o_title, "s"))
		  librdf_statement_set_subject(current_statement,
		      librdf_new_node_from_uri_string (scontext->storage->world,
			(const unsigned char*)out_cols[colNum - 1].o_buffer));
	      else if (strstr (out->o_title, "p"))
		librdf_statement_set_predicate(current_statement,
		    librdf_new_node_from_uri_string (scontext->storage->world,
		      (const unsigned char*)out_cols[colNum - 1].o_buffer));
	      else if (strstr (out->o_title, "o"))
		librdf_statement_set_object(current_statement,
		    librdf_new_node_from_uri_string (scontext->storage->world,
		      (const unsigned char*)out_cols[colNum - 1].o_buffer));

	      free (out_cols[colNum - 1].o_buffer);
	    }

	  /* END */

	  return current_statement;
	}
      else
	{
	  librdf_node *current_context;
	  current_context = NULL;
	  return librdf_new_node_from_uri_string (scontext->storage->world, (const unsigned char*)"z");
	}
    default:
      return NULL;
  }

}

static void
librdf_storage_virtuoso_find_statements_in_context_finished(void* context)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "STREAM ------> librdf_storage_virtuoso_find_statements_in_context_finished\n");
#endif
}

static librdf_stream*
       librdf_storage_virtuoso_find_statements(librdf_storage* storage, librdf_statement* statement)
{
  librdf_storage_virtuoso_context* sos = (librdf_storage_virtuoso_context*)storage->context;
  librdf_stream *stream;
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_find_statements \n");
#endif
  stream=librdf_new_stream(storage->world,(void*)sos,
                           &librdf_storage_virtuoso_find_statements_in_context_end_of_stream,
                           &librdf_storage_virtuoso_find_statements_in_context_next_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_get_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_finished);
  return stream;
}

static librdf_stream*
       librdf_storage_virtuoso_serialise(librdf_storage* storage)
{
  librdf_stream *ret;
  librdf_storage_virtuoso_context* sos = (librdf_storage_virtuoso_context*)storage->context;
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_serialise \n");
#endif
  ret = librdf_new_stream(storage->world,(void*)sos,
      &librdf_storage_virtuoso_find_statements_in_context_end_of_stream,
      &librdf_storage_virtuoso_find_statements_in_context_next_statement,
      &librdf_storage_virtuoso_find_statements_in_context_get_statement,
      &librdf_storage_virtuoso_find_statements_in_context_finished);


  if (SQLExecDirect(sos->henv, (UCHAR *)"sparql SELECT ?q ?o ?p WHERE { ?q ?p ?o }", SQL_NTS) != SQL_SUCCESS)
    rdf_virtuoso_ODBC_Errors ((char *)"SQLExecDirect", sos);

  SQLNumResultCols (sos->henv, &sos->numCols);

  return ret;
}

static librdf_stream*
       librdf_storage_virtuoso_find_statements_with_options(librdf_storage* storage,
                                                         librdf_statement* statement,
                                                         librdf_node* context_node,
                                                         librdf_hash* options)
{
  librdf_stream *stream;
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_find_statements_with_options \n");
#endif
  return stream; /* Only for warning */
}


/* context functions */
static int librdf_storage_virtuoso_context_add_statement(librdf_storage* storage,
                                                      librdf_node* context_node,
                                                      librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_context_add_statement \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_context_add_statements(librdf_storage* storage,
                                                       librdf_node* context_node,
                                                       librdf_stream* statement_stream)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_context_add_statements \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_context_remove_statement(librdf_storage* storage,
                                                         librdf_node* context_node,
                                                         librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_context_remove_statement \n");
#endif
  return 0;
}

static int librdf_storage_virtuoso_context_remove_statements(librdf_storage* storage,
                                                          librdf_node* context_node)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_context_remove_statements \n");
#endif
  return 0;
}

static librdf_stream*
       librdf_storage_virtuoso_context_serialise(librdf_storage* storage,
                                              librdf_node* context_node)
{
  librdf_storage_virtuoso_context* sos = (librdf_storage_virtuoso_context*)storage->context;
  librdf_stream *stream;
  stream=librdf_new_stream(storage->world,(void*)sos,
                           &librdf_storage_virtuoso_find_statements_in_context_end_of_stream,
                           &librdf_storage_virtuoso_find_statements_in_context_next_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_get_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_finished);
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_context_serialise \n");
#endif
  return 0;
  return stream;
}

static librdf_stream* librdf_storage_virtuoso_find_statements_in_context(librdf_storage* storage,
                                               librdf_statement* statement,
                                               librdf_node* context_node)
{
  librdf_stream *stream;
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_find_statements_in_context \n");
#endif
  return stream; /* Only for warning */
}

static librdf_iterator* librdf_storage_virtuoso_get_contexts(librdf_storage* storage)
{
  librdf_iterator *iterator;
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_get_contexts \n");
#endif
  return iterator;
}


static librdf_node*
librdf_storage_virtuoso_get_feature(librdf_storage* storage, librdf_uri* feature)
{
  //librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  unsigned char *uri_string;

#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_get_feature \n");
#endif

  if(!feature)
    return NULL;

  uri_string=librdf_uri_as_string(feature);

  if(!uri_string)
    return NULL;

  if (!strcmp((const char*)uri_string, LIBRDF_MODEL_FEATURE_CONTEXTS))
    {
      unsigned char value[2];
      sprintf((char*)value, "%d", 0);

      return librdf_new_node_from_typed_literal(storage->world,
	  value, NULL, NULL);
    }

  return NULL;
}


static int
librdf_storage_virtuoso_transaction_start(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_transaction_start \n");
#endif
  return 0;
}


static int
librdf_storage_virtuoso_transaction_start_with_handle(librdf_storage* storage,
                                                   void* handle)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_transaction_start_with_handle \n");
#endif
  return 0;
}

static int
librdf_storage_virtuoso_transaction_commit(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_transaction_commit \n");
#endif
  return 0;
}


static int
librdf_storage_virtuoso_transaction_rollback(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_transaction_rollback \n");
#endif
  return 0;
}


static void*
librdf_storage_virtuoso_transaction_get_handle(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "CONTEXT - librdf_storage_virtuoso_transaction_get_handle \n");
#endif
  return NULL;
}






/* local function to register Virtuoso storage functions */
static void
librdf_storage_virtuoso_register_factory(librdf_storage_factory *factory)
{
  factory->context_length     = sizeof(librdf_storage_virtuoso_context);
  factory->init               = librdf_storage_virtuoso_init;
  factory->terminate          = librdf_storage_virtuoso_terminate;
  factory->open               = librdf_storage_virtuoso_open;
  factory->close              = librdf_storage_virtuoso_close;
  factory->sync               = librdf_storage_virtuoso_sync;
  factory->size               = librdf_storage_virtuoso_size;
  factory->add_statement      = librdf_storage_virtuoso_add_statement;
  factory->add_statements     = librdf_storage_virtuoso_add_statements;
  factory->remove_statement   = librdf_storage_virtuoso_remove_statement;
  factory->contains_statement = librdf_storage_virtuoso_contains_statement;
  factory->serialise          = librdf_storage_virtuoso_serialise;
  factory->find_statements    = librdf_storage_virtuoso_find_statements;
  factory->find_statements_with_options    = librdf_storage_virtuoso_find_statements_with_options;
  factory->context_add_statement      = librdf_storage_virtuoso_context_add_statement;
  factory->context_add_statements     = librdf_storage_virtuoso_context_add_statements;
  factory->context_remove_statement   = librdf_storage_virtuoso_context_remove_statement;
  factory->context_remove_statements  = librdf_storage_virtuoso_context_remove_statements;
  factory->context_serialise          = librdf_storage_virtuoso_context_serialise;
  factory->find_statements_in_context = librdf_storage_virtuoso_find_statements_in_context;
  factory->get_contexts               = librdf_storage_virtuoso_get_contexts;
  factory->get_feature                = librdf_storage_virtuoso_get_feature;

  factory->transaction_start             = librdf_storage_virtuoso_transaction_start;
  factory->transaction_start_with_handle = librdf_storage_virtuoso_transaction_start_with_handle;
  factory->transaction_commit            = librdf_storage_virtuoso_transaction_commit;
  factory->transaction_rollback          = librdf_storage_virtuoso_transaction_rollback;
  factory->transaction_get_handle        = librdf_storage_virtuoso_transaction_get_handle;
}

void
librdf_init_storage_virtuoso(librdf_world *world)
{
  librdf_storage_register_factory(world, "virtuoso", "OpenLink Virtuoso Universal Server store",
                                  &librdf_storage_virtuoso_register_factory);
}
