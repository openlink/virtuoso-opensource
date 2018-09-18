/*  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 2011-2018 OpenLink Software
 *
 *  The file is a modified version of source file of the Shapelib library.
 *  The original version was obtained via http://shapelib.maptools.org
 *  Authors of the original version are not responsible for possible errors
 *  in this modified version.
 *  The original copyright and licensing info is as follows:
 */

/******************************************************************************
 * Original Id: shpopen.c,v 1.70 2011-07-24 05:59:25 fwarmerdam Exp $
 *
 * Project:  Shapelib
 * Purpose:  Implementation of core Shapefile read/write functions.
 * Author:   Frank Warmerdam, warmerdam@pobox.com
 *
 ******************************************************************************
 * Copyright (c) 1999, 2001, Frank Warmerdam
 *
 * This software is available under the following "MIT Style" license,
 * or at the option of the licensee under the LGPL (see LICENSE.LGPL).  This
 * option is discussed in more detail in shapelib.html.
 *
 * --
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 ******************************************************************************/

#include "shapefil.h"

SHP_CVSID("$Id$")

typedef unsigned char uchar;

#if 0
#if UINT_MAX == 65535
typedef unsigned long	      int32;
#else
typedef unsigned int	      int32;
#endif
#endif

#ifndef FALSE
#  define FALSE		0
#  define TRUE		1
#endif

#define ByteCopy( a, b, c )	memcpy( b, a, c )
#ifndef MAX
#  define MIN(a,b)      ((a<b) ? a : b)
#  define MAX(a,b)      ((a>b) ? a : b)
#endif

#if defined(WIN32) || defined(_WIN32)
#  ifndef snprintf
#     define snprintf _snprintf
#  endif
#endif

static int 	bBigEndian;


/************************************************************************/
/*                              SwapWord()                              */
/*                                                                      */
/*      Swap a 2, 4 or 8 byte word.                                     */
/************************************************************************/

static void	SwapWord( int length, void * wordP )

{
    int		i;
    uchar	temp;

    for( i=0; i < length/2; i++ )
    {
	temp = ((uchar *) wordP)[i];
	((uchar *)wordP)[i] = ((uchar *) wordP)[length-i-1];
	((uchar *) wordP)[length-i-1] = temp;
    }
}

/************************************************************************/
/*                             SfRealloc()                              */
/*                                                                      */
/*      A realloc cover function that will access a NULL pointer as     */
/*      a valid input.                                                  */
/************************************************************************/

static void * SfRealloc( void * pMem, int nNewSize )

{
    if( pMem == NULL )
        return( (void *) dk_alloc (nNewSize) );
    else
      {
        dk_free (pMem, -1);
        return( (void *) dk_alloc (nNewSize) );
      }
}

/************************************************************************/
/*                          SHPWriteHeader()                            */
/*                                                                      */
/*      Write out a header for the .shp and .shx files as well as the	*/
/*	contents of the index (.shx) file.				*/
/************************************************************************/

void SHPAPI_CALL SHPWriteHeader( SHPHandle psSHP )

{
    uchar     	abyHeader[100];
    int		i;
    int32	i32;
    double	dValue;
    int32	*panSHX;
    
    if (psSHP->fpSHX == NULL)
    {
        psSHP->sHooks.Error( "SHPWriteHeader failed : SHX file is closed");
        return;
    }

/* -------------------------------------------------------------------- */
/*      Prepare header block for .shp file.                             */
/* -------------------------------------------------------------------- */
    for( i = 0; i < 100; i++ )
        abyHeader[i] = 0;

    abyHeader[2] = 0x27;				/* magic cookie */
    abyHeader[3] = 0x0a;

    i32 = psSHP->nFileSize/2;				/* file size */
    ByteCopy( &i32, abyHeader+24, 4 );
    if( !bBigEndian ) SwapWord( 4, abyHeader+24 );
    
    i32 = 1000;						/* version */
    ByteCopy( &i32, abyHeader+28, 4 );
    if( bBigEndian ) SwapWord( 4, abyHeader+28 );
    
    i32 = psSHP->nShapeType;				/* shape type */
    ByteCopy( &i32, abyHeader+32, 4 );
    if( bBigEndian ) SwapWord( 4, abyHeader+32 );

    dValue = psSHP->adBoundsMin[0];			/* set bounds */
    ByteCopy( &dValue, abyHeader+36, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+36 );

    dValue = psSHP->adBoundsMin[1];
    ByteCopy( &dValue, abyHeader+44, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+44 );

    dValue = psSHP->adBoundsMax[0];
    ByteCopy( &dValue, abyHeader+52, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+52 );

    dValue = psSHP->adBoundsMax[1];
    ByteCopy( &dValue, abyHeader+60, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+60 );

    dValue = psSHP->adBoundsMin[2];			/* z */
    ByteCopy( &dValue, abyHeader+68, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+68 );

    dValue = psSHP->adBoundsMax[2];
    ByteCopy( &dValue, abyHeader+76, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+76 );

    dValue = psSHP->adBoundsMin[3];			/* m */
    ByteCopy( &dValue, abyHeader+84, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+84 );

    dValue = psSHP->adBoundsMax[3];
    ByteCopy( &dValue, abyHeader+92, 8 );
    if( bBigEndian ) SwapWord( 8, abyHeader+92 );

/* -------------------------------------------------------------------- */
/*      Write .shp file header.                                         */
/* -------------------------------------------------------------------- */
    if( psSHP->sHooks.FSeek( psSHP->fpSHP, 0, 0 ) != 0 
        || psSHP->sHooks.FWrite( abyHeader, 100, 1, psSHP->fpSHP ) != 1 )
    {
        psSHP->sHooks.Error( "Failure writing .shp header" );
        return;
    }

/* -------------------------------------------------------------------- */
/*      Prepare, and write .shx file header.                            */
/* -------------------------------------------------------------------- */
    i32 = (psSHP->nRecords * 2 * sizeof(int32) + 100)/2;   /* file size */
    ByteCopy( &i32, abyHeader+24, 4 );
    if( !bBigEndian ) SwapWord( 4, abyHeader+24 );
    
    if( psSHP->sHooks.FSeek( psSHP->fpSHX, 0, 0 ) != 0 
        || psSHP->sHooks.FWrite( abyHeader, 100, 1, psSHP->fpSHX ) != 1 )
    {
        psSHP->sHooks.Error( "Failure writing .shx header" );
        return;
    }

/* -------------------------------------------------------------------- */
/*      Write out the .shx contents.                                    */
/* -------------------------------------------------------------------- */
    panSHX = (int32 *) dk_alloc (sizeof(int32) * 2 * psSHP->nRecords);

    for( i = 0; i < psSHP->nRecords; i++ )
    {
        panSHX[i*2  ] = psSHP->panRecOffset[i]/2;
        panSHX[i*2+1] = psSHP->panRecSize[i]/2;
        if( !bBigEndian ) SwapWord( 4, panSHX+i*2 );
        if( !bBigEndian ) SwapWord( 4, panSHX+i*2+1 );
    }

    if( (int)psSHP->sHooks.FWrite( panSHX, sizeof(int32)*2, psSHP->nRecords, psSHP->fpSHX ) 
        != psSHP->nRecords )
    {
        psSHP->sHooks.Error( "Failure writing .shx contents" );
    }

    dk_free( panSHX, -1 );

/* -------------------------------------------------------------------- */
/*      Flush to disk.                                                  */
/* -------------------------------------------------------------------- */
    psSHP->sHooks.FFlush( psSHP->fpSHP );
    psSHP->sHooks.FFlush( psSHP->fpSHX );
}

/************************************************************************/
/*                              SHPOpen()                               */
/************************************************************************/

SHPHandle SHPAPI_CALL
SHPOpen( const char * pszLayer, const char * pszAccess )

{
    SAHooks sHooks;

    SASetupDefaultHooks( &sHooks );

    return SHPOpenLL( pszLayer, pszAccess, &sHooks );
}

/************************************************************************/
/*                              SHPOpen()                               */
/*                                                                      */
/*      Open the .shp and .shx files based on the basename of the       */
/*      files or either file name.                                      */
/************************************************************************/
   
SHPHandle SHPAPI_CALL
SHPOpenLL( const char * pszLayer, const char * pszAccess, SAHooks *psHooks )

{
    char		*pszFullname, *pszBasename;
    SHPHandle		psSHP;
    
    uchar		*pabyBuf;
    int			i;
    double		dValue;
    
/* -------------------------------------------------------------------- */
/*      Ensure the access string is one of the legal ones.  We          */
/*      ensure the result string indicates binary to avoid common       */
/*      problems on Windows.                                            */
/* -------------------------------------------------------------------- */
    if( strcmp(pszAccess,"rb+") == 0 || strcmp(pszAccess,"r+b") == 0
        || strcmp(pszAccess,"r+") == 0 )
        pszAccess = "r+b";
    else
        pszAccess = "rb";
    
/* -------------------------------------------------------------------- */
/*	Establish the byte order on this machine.			*/
/* -------------------------------------------------------------------- */
    i = 1;
    if( *((uchar *) &i) == 1 )
        bBigEndian = FALSE;
    else
        bBigEndian = TRUE;

/* -------------------------------------------------------------------- */
/*	Initialize the info structure.					*/
/* -------------------------------------------------------------------- */
    psSHP = (SHPHandle) dk_alloc (sizeof(SHPInfo));
    memset (psSHP, 0, sizeof(SHPInfo));
    psSHP->bUpdated = FALSE;
    memcpy( &(psSHP->sHooks), psHooks, sizeof(SAHooks) );

/* -------------------------------------------------------------------- */
/*	Compute the base (layer) name.  If there is any extension	*/
/*	on the passed in filename we will strip it off.			*/
/* -------------------------------------------------------------------- */
    pszBasename = (char *) dk_alloc (strlen(pszLayer)+5);
    strcpy( pszBasename, pszLayer );
    for( i = strlen(pszBasename)-1; 
         i > 0 && pszBasename[i] != '.' && pszBasename[i] != '/'
             && pszBasename[i] != '\\';
         i-- ) {}

    if( pszBasename[i] == '.' )
        pszBasename[i] = '\0';

/* -------------------------------------------------------------------- */
/*	Open the .shp and .shx files.  Note that files pulled from	*/
/*	a PC to Unix with upper case filenames won't work!		*/
/* -------------------------------------------------------------------- */
    pszFullname = (char *) dk_alloc (strlen(pszBasename) + 5);
    sprintf( pszFullname, "%s.shp", pszBasename ) ;
    psSHP->fpSHP = psSHP->sHooks.FOpen(pszFullname, pszAccess );
    if( psSHP->fpSHP == NULL )
    {
        sprintf( pszFullname, "%s.SHP", pszBasename );
        psSHP->fpSHP = psSHP->sHooks.FOpen(pszFullname, pszAccess );
    }
    
    if( psSHP->fpSHP == NULL )
    {
        char *pszMessage = (char *) dk_alloc (strlen(pszBasename)*2+256);
        sprintf( pszMessage, "Unable to open %s.shp or %s.SHP.", 
                  pszBasename, pszBasename );
        psHooks->Error( pszMessage );
        dk_free( pszMessage, -1 );
    }

    sprintf( pszFullname, "%s.shx", pszBasename );
    psSHP->fpSHX =  psSHP->sHooks.FOpen(pszFullname, pszAccess );
    if( psSHP->fpSHX == NULL )
    {
        sprintf( pszFullname, "%s.SHX", pszBasename );
        psSHP->fpSHX = psSHP->sHooks.FOpen(pszFullname, pszAccess );
    }
    
    if( psSHP->fpSHX == NULL )
    {
        char *pszMessage = (char *) dk_alloc (strlen(pszBasename)*2+256);
        sprintf( pszMessage, "Unable to open %s.shx or %s.SHX.", 
                  pszBasename, pszBasename );
        psHooks->Error( pszMessage );
        dk_free( pszMessage, -1 );

        psSHP->sHooks.FClose( psSHP->fpSHP );
        dk_free( psSHP, -1 );
        dk_free( pszBasename, -1 );
        dk_free( pszFullname, -1 );
        return( NULL );
    }

    dk_free( pszFullname, -1 );
    dk_free( pszBasename, -1 );

/* -------------------------------------------------------------------- */
/*  Read the file size from the SHP file.				*/
/* -------------------------------------------------------------------- */
    pabyBuf = (uchar *) dk_alloc (100);
    psSHP->sHooks.FRead( pabyBuf, 100, 1, psSHP->fpSHP );

    psSHP->nFileSize = ((unsigned int)pabyBuf[24] * 256 * 256 * 256
                        + (unsigned int)pabyBuf[25] * 256 * 256
                        + (unsigned int)pabyBuf[26] * 256
                        + (unsigned int)pabyBuf[27]) * 2;

/* -------------------------------------------------------------------- */
/*  Read SHX file Header info                                           */
/* -------------------------------------------------------------------- */
    if( psSHP->sHooks.FRead( pabyBuf, 100, 1, psSHP->fpSHX ) != 1 
        || pabyBuf[0] != 0 
        || pabyBuf[1] != 0 
        || pabyBuf[2] != 0x27 
        || (pabyBuf[3] != 0x0a && pabyBuf[3] != 0x0d) )
    {
        psSHP->sHooks.Error( ".shx file is unreadable, or corrupt." );
        psSHP->sHooks.FClose( psSHP->fpSHP );
        psSHP->sHooks.FClose( psSHP->fpSHX );
        dk_free( psSHP, -1 );

        return( NULL );
    }

    psSHP->nRecords = pabyBuf[27] + pabyBuf[26] * 256
        + pabyBuf[25] * 256 * 256 + pabyBuf[24] * 256 * 256 * 256;
    psSHP->nRecords = (psSHP->nRecords*2 - 100) / 8;

    psSHP->nShapeType = pabyBuf[32];

    if( psSHP->nRecords < 0 || psSHP->nRecords > 256000000 )
    {
        char szError[200];
        
        sprintf( szError, 
                 "Record count in .shp header is %d, which seems\n"
                 "unreasonable.  Assuming header is corrupt.",
                 psSHP->nRecords );
        psSHP->sHooks.Error( szError );				       
        psSHP->sHooks.FClose( psSHP->fpSHP );
        psSHP->sHooks.FClose( psSHP->fpSHX );
        dk_free( psSHP, -1 );
        dk_free(pabyBuf, -1);

        return( NULL );
    }

/* -------------------------------------------------------------------- */
/*      Read the bounds.                                                */
/* -------------------------------------------------------------------- */
    if( bBigEndian ) SwapWord( 8, pabyBuf+36 );
    memcpy( &dValue, pabyBuf+36, 8 );
    psSHP->adBoundsMin[0] = dValue;

    if( bBigEndian ) SwapWord( 8, pabyBuf+44 );
    memcpy( &dValue, pabyBuf+44, 8 );
    psSHP->adBoundsMin[1] = dValue;

    if( bBigEndian ) SwapWord( 8, pabyBuf+52 );
    memcpy( &dValue, pabyBuf+52, 8 );
    psSHP->adBoundsMax[0] = dValue;

    if( bBigEndian ) SwapWord( 8, pabyBuf+60 );
    memcpy( &dValue, pabyBuf+60, 8 );
    psSHP->adBoundsMax[1] = dValue;

    if( bBigEndian ) SwapWord( 8, pabyBuf+68 );		/* z */
    memcpy( &dValue, pabyBuf+68, 8 );
    psSHP->adBoundsMin[2] = dValue;
    
    if( bBigEndian ) SwapWord( 8, pabyBuf+76 );
    memcpy( &dValue, pabyBuf+76, 8 );
    psSHP->adBoundsMax[2] = dValue;
    
    if( bBigEndian ) SwapWord( 8, pabyBuf+84 );		/* z */
    memcpy( &dValue, pabyBuf+84, 8 );
    psSHP->adBoundsMin[3] = dValue;

    if( bBigEndian ) SwapWord( 8, pabyBuf+92 );
    memcpy( &dValue, pabyBuf+92, 8 );
    psSHP->adBoundsMax[3] = dValue;

    dk_free( pabyBuf, -1 );

/* -------------------------------------------------------------------- */
/*	Read the .shx file to get the offsets to each record in 	*/
/*	the .shp file.							*/
/* -------------------------------------------------------------------- */
    psSHP->nMaxRecords = psSHP->nRecords;

    psSHP->panRecOffset = (unsigned int *)
        dk_alloc (sizeof(unsigned int) * MAX(1,psSHP->nMaxRecords) );
    psSHP->panRecSize = (unsigned int *)
        dk_alloc (sizeof(unsigned int) * MAX(1,psSHP->nMaxRecords) );
    pabyBuf = (uchar *) dk_alloc (8 * MAX(1,psSHP->nRecords) );

    if (psSHP->panRecOffset == NULL ||
        psSHP->panRecSize == NULL ||
        pabyBuf == NULL)
    {
        char szError[200];

        sprintf(szError, 
                "Not enough memory to allocate requested memory (nRecords=%d).\n"
                "Probably broken SHP file", 
                psSHP->nRecords );
        psSHP->sHooks.Error( szError );
        psSHP->sHooks.FClose( psSHP->fpSHP );
        psSHP->sHooks.FClose( psSHP->fpSHX );
        if (psSHP->panRecOffset) dk_free( psSHP->panRecOffset, -1 );
        if (psSHP->panRecSize) dk_free( psSHP->panRecSize, -1 );
        if (pabyBuf) dk_free( pabyBuf, -1 );
        dk_free( psSHP, -1 );
        return( NULL );
    }

    if( (int) psSHP->sHooks.FRead( pabyBuf, 8, psSHP->nRecords, psSHP->fpSHX ) 
        != psSHP->nRecords )
    {
        char szError[200];

        sprintf( szError, 
                 "Failed to read all values for %d records in .shx file.",
                 psSHP->nRecords );
        psSHP->sHooks.Error( szError );

        /* SHX is short or unreadable for some reason. */
        psSHP->sHooks.FClose( psSHP->fpSHP );
        psSHP->sHooks.FClose( psSHP->fpSHX );
        dk_free( psSHP->panRecOffset, -1 );
        dk_free( psSHP->panRecSize, -1 );
        dk_free( pabyBuf, -1 );
        dk_free( psSHP, -1 );

        return( NULL );
    }
    
    /* In read-only mode, we can close the SHX now */
    if (strcmp(pszAccess, "rb") == 0)
    {
        psSHP->sHooks.FClose( psSHP->fpSHX );
        psSHP->fpSHX = NULL;
    }

    for( i = 0; i < psSHP->nRecords; i++ )
    {
        int32		nOffset, nLength;

        memcpy( &nOffset, pabyBuf + i * 8, 4 );
        if( !bBigEndian ) SwapWord( 4, &nOffset );

        memcpy( &nLength, pabyBuf + i * 8 + 4, 4 );
        if( !bBigEndian ) SwapWord( 4, &nLength );

        psSHP->panRecOffset[i] = nOffset*2;
        psSHP->panRecSize[i] = nLength*2;
    }
    dk_free( pabyBuf, -1 );

    return( psSHP );
}

/************************************************************************/
/*                              SHPClose()                              */
/*								       	*/
/*	Close the .shp and .shx files.					*/
/************************************************************************/

void SHPAPI_CALL
SHPClose(SHPHandle psSHP )

{
    if( psSHP == NULL )
        return;

/* -------------------------------------------------------------------- */
/*	Update the header if we have modified anything.			*/
/* -------------------------------------------------------------------- */
    if( psSHP->bUpdated )
	SHPWriteHeader( psSHP );

/* -------------------------------------------------------------------- */
/*      Free all resources, and close files.                            */
/* -------------------------------------------------------------------- */
    dk_free( psSHP->panRecOffset, -1 );
    dk_free( psSHP->panRecSize, -1 );

    if ( psSHP->fpSHX != NULL)
        psSHP->sHooks.FClose( psSHP->fpSHX );
    psSHP->sHooks.FClose( psSHP->fpSHP );

    if( psSHP->pabyRec != NULL )
    {
        dk_free( psSHP->pabyRec, -1 );
    }
    
    dk_free( psSHP, -1 );
}

/************************************************************************/
/*                             SHPGetInfo()                             */
/*                                                                      */
/*      Fetch general information about the shape file.                 */
/************************************************************************/

void SHPAPI_CALL
SHPGetInfo(SHPHandle psSHP, int * pnEntities, int * pnShapeType,
           double * padfMinBound, double * padfMaxBound )

{
    int		i;

    if( psSHP == NULL )
        return;
    
    if( pnEntities != NULL )
        *pnEntities = psSHP->nRecords;

    if( pnShapeType != NULL )
        *pnShapeType = psSHP->nShapeType;

    for( i = 0; i < 4; i++ )
    {
        if( padfMinBound != NULL )
            padfMinBound[i] = psSHP->adBoundsMin[i];
        if( padfMaxBound != NULL )
            padfMaxBound[i] = psSHP->adBoundsMax[i];
    }
}

/************************************************************************/
/*                             SHPCreate()                              */
/*                                                                      */
/*      Create a new shape file and return a handle to the open         */
/*      shape file with read/write access.                              */
/************************************************************************/

SHPHandle SHPAPI_CALL
SHPCreate( const char * pszLayer, int nShapeType )

{
    SAHooks sHooks;

    SASetupDefaultHooks( &sHooks );

    return SHPCreateLL( pszLayer, nShapeType, &sHooks );
}

/************************************************************************/
/*                             SHPCreate()                              */
/*                                                                      */
/*      Create a new shape file and return a handle to the open         */
/*      shape file with read/write access.                              */
/************************************************************************/

SHPHandle SHPAPI_CALL
SHPCreateLL( const char * pszLayer, int nShapeType, SAHooks *psHooks )

{
    char	*pszBasename = NULL, *pszFullname = NULL;
    int		i;
    SAFile	fpSHP = NULL, fpSHX = NULL;
    uchar     	abyHeader[100];
    int32	i32;
    double	dValue;
    
/* -------------------------------------------------------------------- */
/*      Establish the byte order on this system.                        */
/* -------------------------------------------------------------------- */
    i = 1;
    if( *((uchar *) &i) == 1 )
        bBigEndian = FALSE;
    else
        bBigEndian = TRUE;

/* -------------------------------------------------------------------- */
/*	Compute the base (layer) name.  If there is any extension	*/
/*	on the passed in filename we will strip it off.			*/
/* -------------------------------------------------------------------- */
    pszBasename = (char *) dk_alloc (strlen(pszLayer)+5);
    strcpy( pszBasename, pszLayer );
    for( i = strlen(pszBasename)-1; 
         i > 0 && pszBasename[i] != '.' && pszBasename[i] != '/'
             && pszBasename[i] != '\\';
         i-- ) {}

    if( pszBasename[i] == '.' )
        pszBasename[i] = '\0';

/* -------------------------------------------------------------------- */
/*      Open the two files so we can write their headers.               */
/* -------------------------------------------------------------------- */
    pszFullname = (char *) dk_alloc (strlen(pszBasename) + 5);
    sprintf( pszFullname, "%s.shp", pszBasename );
    fpSHP = psHooks->FOpen(pszFullname, "wb" );
    if( fpSHP == NULL )
    {
        psHooks->Error( "Failed to create file .shp file." );
        goto error;
    }

    sprintf( pszFullname, "%s.shx", pszBasename );
    fpSHX = psHooks->FOpen(pszFullname, "wb" );
    if( fpSHX == NULL )
    {
        psHooks->Error( "Failed to create file .shx file." );
        goto error;
    }

    dk_free( pszFullname, -1 ); pszFullname = NULL;
    dk_free( pszBasename, -1 ); pszBasename = NULL;

/* -------------------------------------------------------------------- */
/*      Prepare header block for .shp file.                             */
/* -------------------------------------------------------------------- */
    for( i = 0; i < 100; i++ )
        abyHeader[i] = 0;

    abyHeader[2] = 0x27;				/* magic cookie */
    abyHeader[3] = 0x0a;

    i32 = 50;						/* file size */
    ByteCopy( &i32, abyHeader+24, 4 );
    if( !bBigEndian ) SwapWord( 4, abyHeader+24 );
    
    i32 = 1000;						/* version */
    ByteCopy( &i32, abyHeader+28, 4 );
    if( bBigEndian ) SwapWord( 4, abyHeader+28 );
    
    i32 = nShapeType;					/* shape type */
    ByteCopy( &i32, abyHeader+32, 4 );
    if( bBigEndian ) SwapWord( 4, abyHeader+32 );

    dValue = 0.0;					/* set bounds */
    ByteCopy( &dValue, abyHeader+36, 8 );
    ByteCopy( &dValue, abyHeader+44, 8 );
    ByteCopy( &dValue, abyHeader+52, 8 );
    ByteCopy( &dValue, abyHeader+60, 8 );

/* -------------------------------------------------------------------- */
/*      Write .shp file header.                                         */
/* -------------------------------------------------------------------- */
    if( psHooks->FWrite( abyHeader, 100, 1, fpSHP ) != 1 )
    {
        psHooks->Error( "Failed to write .shp header." );
        goto error;
    }

/* -------------------------------------------------------------------- */
/*      Prepare, and write .shx file header.                            */
/* -------------------------------------------------------------------- */
    i32 = 50;						/* file size */
    ByteCopy( &i32, abyHeader+24, 4 );
    if( !bBigEndian ) SwapWord( 4, abyHeader+24 );
    
    if( psHooks->FWrite( abyHeader, 100, 1, fpSHX ) != 1 )
    {
        psHooks->Error( "Failed to write .shx header." );
        goto error;
    }

/* -------------------------------------------------------------------- */
/*      Close the files, and then open them as regular existing files.  */
/* -------------------------------------------------------------------- */
    psHooks->FClose( fpSHP );
    psHooks->FClose( fpSHX );

    return( SHPOpenLL( pszLayer, "r+b", psHooks ) );

error:
    if (pszFullname) dk_free(pszFullname, -1);
    if (pszBasename) dk_free(pszBasename, -1);
    if (fpSHP) psHooks->FClose( fpSHP );
    if (fpSHX) psHooks->FClose( fpSHX );
    return NULL;
}

/************************************************************************/
/*                           _SHPSetBounds()                            */
/*                                                                      */
/*      Compute a bounds rectangle for a shape, and set it into the     */
/*      indicated location in the record.                               */
/************************************************************************/

static void	_SHPSetBounds( uchar * pabyRec, SHPObject * psShape )

{
    ByteCopy( &(psShape->dfXMin), pabyRec +  0, 8 );
    ByteCopy( &(psShape->dfYMin), pabyRec +  8, 8 );
    ByteCopy( &(psShape->dfXMax), pabyRec + 16, 8 );
    ByteCopy( &(psShape->dfYMax), pabyRec + 24, 8 );

    if( bBigEndian )
    {
        SwapWord( 8, pabyRec + 0 );
        SwapWord( 8, pabyRec + 8 );
        SwapWord( 8, pabyRec + 16 );
        SwapWord( 8, pabyRec + 24 );
    }
}

/************************************************************************/
/*                         SHPComputeExtents()                          */
/*                                                                      */
/*      Recompute the extents of a shape.  Automatically done by        */
/*      SHPCreateObject().                                              */
/************************************************************************/

void SHPAPI_CALL
SHPComputeExtents( SHPObject * psObject )

{
    int		i;
    
/* -------------------------------------------------------------------- */
/*      Build extents for this object.                                  */
/* -------------------------------------------------------------------- */
    if( psObject->nVertices > 0 )
    {
        psObject->dfXMin = psObject->dfXMax = psObject->padfX[0];
        psObject->dfYMin = psObject->dfYMax = psObject->padfY[0];
        psObject->dfZMin = psObject->dfZMax = psObject->padfZ[0];
        psObject->dfMMin = psObject->dfMMax = psObject->padfM[0];
    }
    
    for( i = 0; i < psObject->nVertices; i++ )
    {
        psObject->dfXMin = MIN(psObject->dfXMin, psObject->padfX[i]);
        psObject->dfYMin = MIN(psObject->dfYMin, psObject->padfY[i]);
        psObject->dfZMin = MIN(psObject->dfZMin, psObject->padfZ[i]);
        psObject->dfMMin = MIN(psObject->dfMMin, psObject->padfM[i]);

        psObject->dfXMax = MAX(psObject->dfXMax, psObject->padfX[i]);
        psObject->dfYMax = MAX(psObject->dfYMax, psObject->padfY[i]);
        psObject->dfZMax = MAX(psObject->dfZMax, psObject->padfZ[i]);
        psObject->dfMMax = MAX(psObject->dfMMax, psObject->padfM[i]);
    }
}

/************************************************************************/
/*                          SHPCreateObject()                           */
/*                                                                      */
/*      Create a shape object.  It should be freed with                 */
/*      SHPDestroyObject().                                             */
/************************************************************************/

SHPObject SHPAPI_CALL1(*)
SHPCreateObject( int nSHPType, int nShapeId, int nParts,
                 const int * panPartStart, const int * panPartType,
                 int nVertices, const double *padfX, const double *padfY,
                 const double * padfZ, const double * padfM )

{
    SHPObject	*psObject;
    int		i, bHasM, bHasZ;

    psObject = (SHPObject *) dk_alloc (sizeof(SHPObject));
    memset (psObject, 0, sizeof(SHPObject));
    psObject->nSHPType = nSHPType;
    psObject->nShapeId = nShapeId;
    psObject->bMeasureIsUsed = FALSE;

/* -------------------------------------------------------------------- */
/*	Establish whether this shape type has M, and Z values.		*/
/* -------------------------------------------------------------------- */
    if( nSHPType == SHPT_ARCM
        || nSHPType == SHPT_POINTM
        || nSHPType == SHPT_POLYGONM
        || nSHPType == SHPT_MULTIPOINTM )
    {
        bHasM = TRUE;
        bHasZ = FALSE;
    }
    else if( nSHPType == SHPT_ARCZ
             || nSHPType == SHPT_POINTZ
             || nSHPType == SHPT_POLYGONZ
             || nSHPType == SHPT_MULTIPOINTZ
             || nSHPType == SHPT_MULTIPATCH )
    {
        bHasM = TRUE;
        bHasZ = TRUE;
    }
    else
    {
        bHasM = FALSE;
        bHasZ = FALSE;
    }

/* -------------------------------------------------------------------- */
/*      Capture parts.  Note that part type is optional, and            */
/*      defaults to ring.                                               */
/* -------------------------------------------------------------------- */
    if( nSHPType == SHPT_ARC || nSHPType == SHPT_POLYGON
        || nSHPType == SHPT_ARCM || nSHPType == SHPT_POLYGONM
        || nSHPType == SHPT_ARCZ || nSHPType == SHPT_POLYGONZ
        || nSHPType == SHPT_MULTIPATCH )
    {
        psObject->nParts = MAX(1,nParts);

        psObject->panPartStart = (int *) dk_alloc (sizeof(int) * psObject->nParts);
        memset (psObject->panPartStart, 0, sizeof(int) * psObject->nParts);
        psObject->panPartType = (int *)
            dk_alloc (sizeof(int) * psObject->nParts);
        psObject->panPartType[0] = SHPP_RING;
        
        for( i = 0; i < nParts; i++ )
        {
            if( psObject->panPartStart != NULL )
                psObject->panPartStart[i] = panPartStart[i];

            if( panPartType != NULL )
                psObject->panPartType[i] = panPartType[i];
            else
                psObject->panPartType[i] = SHPP_RING;
        }

        if( psObject->panPartStart[0] != 0 )
            psObject->panPartStart[0] = 0;
    }

/* -------------------------------------------------------------------- */
/*      Capture vertices.  Note that X, Y, Z and M are optional.        */
/* -------------------------------------------------------------------- */
    if( nVertices > 0 )
    {
        size_t padf_len = sizeof(double) * nVertices;
        psObject->padfX = (double *) dk_alloc (padf_len); memset (psObject->padfX, 0, padf_len);
        psObject->padfY = (double *) dk_alloc (padf_len); memset (psObject->padfY, 0, padf_len);
        psObject->padfZ = (double *) dk_alloc (padf_len); memset (psObject->padfZ, 0, padf_len);
        psObject->padfM = (double *) dk_alloc (padf_len); memset (psObject->padfM, 0, padf_len);
        for( i = 0; i < nVertices; i++ )
        {
            if( padfX != NULL )
                psObject->padfX[i] = padfX[i];
            if( padfY != NULL )
                psObject->padfY[i] = padfY[i];
            if( padfZ != NULL && bHasZ )
                psObject->padfZ[i] = padfZ[i];
            if( padfM != NULL && bHasM )
                psObject->padfM[i] = padfM[i];
        }
        if( padfM != NULL && bHasM )
            psObject->bMeasureIsUsed = TRUE;
    }

/* -------------------------------------------------------------------- */
/*      Compute the extents.                                            */
/* -------------------------------------------------------------------- */
    psObject->nVertices = nVertices;
    SHPComputeExtents( psObject );

    return( psObject );
}

/************************************************************************/
/*                       SHPCreateSimpleObject()                        */
/*                                                                      */
/*      Create a simple (common) shape object.  Destroy with            */
/*      SHPDestroyObject().                                             */
/************************************************************************/

SHPObject SHPAPI_CALL1(*)
SHPCreateSimpleObject( int nSHPType, int nVertices,
                       const double * padfX, const double * padfY,
                       const double * padfZ )

{
    return( SHPCreateObject( nSHPType, -1, 0, NULL, NULL,
                             nVertices, padfX, padfY, padfZ, NULL ) );
}
                                  
/************************************************************************/
/*                           SHPWriteObject()                           */
/*                                                                      */
/*      Write out the vertices of a new structure.  Note that it is     */
/*      only possible to write vertices at the end of the file.         */
/************************************************************************/

int SHPAPI_CALL
SHPWriteObject(SHPHandle psSHP, int nShapeId, SHPObject * psObject )
		      
{
    unsigned int	       	nRecordOffset, nRecordSize=0;
    int i;
    uchar	*pabyRec;
    int32	i32;

    psSHP->bUpdated = TRUE;

/* -------------------------------------------------------------------- */
/*      Ensure that shape object matches the type of the file it is     */
/*      being written to.                                               */
/* -------------------------------------------------------------------- */
    assert( psObject->nSHPType == psSHP->nShapeType 
            || psObject->nSHPType == SHPT_NULL );

/* -------------------------------------------------------------------- */
/*      Ensure that -1 is used for appends.  Either blow an             */
/*      assertion, or if they are disabled, set the shapeid to -1       */
/*      for appends.                                                    */
/* -------------------------------------------------------------------- */
    assert( nShapeId == -1 
            || (nShapeId >= 0 && nShapeId < psSHP->nRecords) );

    if( nShapeId != -1 && nShapeId >= psSHP->nRecords )
        nShapeId = -1;

/* -------------------------------------------------------------------- */
/*      Add the new entity to the in memory index.                      */
/* -------------------------------------------------------------------- */
    if( nShapeId == -1 && psSHP->nRecords+1 > psSHP->nMaxRecords )
    {
        psSHP->nMaxRecords =(int) ( psSHP->nMaxRecords * 1.3 + 100);

        psSHP->panRecOffset = (unsigned int *) 
            SfRealloc(psSHP->panRecOffset,sizeof(unsigned int) * psSHP->nMaxRecords );
        psSHP->panRecSize = (unsigned int *) 
            SfRealloc(psSHP->panRecSize,sizeof(unsigned int) * psSHP->nMaxRecords );
    }

/* -------------------------------------------------------------------- */
/*      Initialize record.                                              */
/* -------------------------------------------------------------------- */
    pabyRec = (uchar *) dk_alloc (psObject->nVertices * 4 * sizeof(double) 
                               + psObject->nParts * 8 + 128);
    
/* -------------------------------------------------------------------- */
/*  Extract vertices for a Polygon or Arc.				*/
/* -------------------------------------------------------------------- */
    if( psObject->nSHPType == SHPT_POLYGON
        || psObject->nSHPType == SHPT_POLYGONZ
        || psObject->nSHPType == SHPT_POLYGONM
        || psObject->nSHPType == SHPT_ARC 
        || psObject->nSHPType == SHPT_ARCZ
        || psObject->nSHPType == SHPT_ARCM
        || psObject->nSHPType == SHPT_MULTIPATCH )
    {
        int32		nPoints, nParts;
        int    		i;

        nPoints = psObject->nVertices;
        nParts = psObject->nParts;

        _SHPSetBounds( pabyRec + 12, psObject );

        if( bBigEndian ) SwapWord( 4, &nPoints );
        if( bBigEndian ) SwapWord( 4, &nParts );

        ByteCopy( &nPoints, pabyRec + 40 + 8, 4 );
        ByteCopy( &nParts, pabyRec + 36 + 8, 4 );

        nRecordSize = 52;

        /*
         * Write part start positions.
         */
        ByteCopy( psObject->panPartStart, pabyRec + 44 + 8,
                  4 * psObject->nParts );
        for( i = 0; i < psObject->nParts; i++ )
        {
            if( bBigEndian ) SwapWord( 4, pabyRec + 44 + 8 + 4*i );
            nRecordSize += 4;
        }

        /*
         * Write multipatch part types if needed.
         */
        if( psObject->nSHPType == SHPT_MULTIPATCH )
        {
            memcpy( pabyRec + nRecordSize, psObject->panPartType,
                    4*psObject->nParts );
            for( i = 0; i < psObject->nParts; i++ )
            {
                if( bBigEndian ) SwapWord( 4, pabyRec + nRecordSize );
                nRecordSize += 4;
            }
        }

        /*
         * Write the (x,y) vertex values.
         */
        for( i = 0; i < psObject->nVertices; i++ )
        {
            ByteCopy( psObject->padfX + i, pabyRec + nRecordSize, 8 );
            ByteCopy( psObject->padfY + i, pabyRec + nRecordSize + 8, 8 );

            if( bBigEndian )
                SwapWord( 8, pabyRec + nRecordSize );
            
            if( bBigEndian )
                SwapWord( 8, pabyRec + nRecordSize + 8 );

            nRecordSize += 2 * 8;
        }

        /*
         * Write the Z coordinates (if any).
         */
        if( psObject->nSHPType == SHPT_POLYGONZ
            || psObject->nSHPType == SHPT_ARCZ
            || psObject->nSHPType == SHPT_MULTIPATCH )
        {
            ByteCopy( &(psObject->dfZMin), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
            
            ByteCopy( &(psObject->dfZMax), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;

            for( i = 0; i < psObject->nVertices; i++ )
            {
                ByteCopy( psObject->padfZ + i, pabyRec + nRecordSize, 8 );
                if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
                nRecordSize += 8;
            }
        }

        /*
         * Write the M values, if any.
         */
        if( psObject->bMeasureIsUsed
            && (psObject->nSHPType == SHPT_POLYGONM
                || psObject->nSHPType == SHPT_ARCM
#ifndef DISABLE_MULTIPATCH_MEASURE            
                || psObject->nSHPType == SHPT_MULTIPATCH
#endif            
                || psObject->nSHPType == SHPT_POLYGONZ
                || psObject->nSHPType == SHPT_ARCZ) )
        {
            ByteCopy( &(psObject->dfMMin), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
            
            ByteCopy( &(psObject->dfMMax), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;

            for( i = 0; i < psObject->nVertices; i++ )
            {
                ByteCopy( psObject->padfM + i, pabyRec + nRecordSize, 8 );
                if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
                nRecordSize += 8;
            }
        }
    }

/* -------------------------------------------------------------------- */
/*  Extract vertices for a MultiPoint.					*/
/* -------------------------------------------------------------------- */
    else if( psObject->nSHPType == SHPT_MULTIPOINT
             || psObject->nSHPType == SHPT_MULTIPOINTZ
             || psObject->nSHPType == SHPT_MULTIPOINTM )
    {
        int32		nPoints;
        int    		i;

        nPoints = psObject->nVertices;

        _SHPSetBounds( pabyRec + 12, psObject );

        if( bBigEndian ) SwapWord( 4, &nPoints );
        ByteCopy( &nPoints, pabyRec + 44, 4 );
	
        for( i = 0; i < psObject->nVertices; i++ )
        {
            ByteCopy( psObject->padfX + i, pabyRec + 48 + i*16, 8 );
            ByteCopy( psObject->padfY + i, pabyRec + 48 + i*16 + 8, 8 );

            if( bBigEndian ) SwapWord( 8, pabyRec + 48 + i*16 );
            if( bBigEndian ) SwapWord( 8, pabyRec + 48 + i*16 + 8 );
        }

        nRecordSize = 48 + 16 * psObject->nVertices;

        if( psObject->nSHPType == SHPT_MULTIPOINTZ )
        {
            ByteCopy( &(psObject->dfZMin), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;

            ByteCopy( &(psObject->dfZMax), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
            
            for( i = 0; i < psObject->nVertices; i++ )
            {
                ByteCopy( psObject->padfZ + i, pabyRec + nRecordSize, 8 );
                if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
                nRecordSize += 8;
            }
        }

        if( psObject->bMeasureIsUsed
            && (psObject->nSHPType == SHPT_MULTIPOINTZ
                || psObject->nSHPType == SHPT_MULTIPOINTM) )
        {
            ByteCopy( &(psObject->dfMMin), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;

            ByteCopy( &(psObject->dfMMax), pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
            
            for( i = 0; i < psObject->nVertices; i++ )
            {
                ByteCopy( psObject->padfM + i, pabyRec + nRecordSize, 8 );
                if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
                nRecordSize += 8;
            }
        }
    }

/* -------------------------------------------------------------------- */
/*      Write point.							*/
/* -------------------------------------------------------------------- */
    else if( psObject->nSHPType == SHPT_POINT
             || psObject->nSHPType == SHPT_POINTZ
             || psObject->nSHPType == SHPT_POINTM )
    {
        ByteCopy( psObject->padfX, pabyRec + 12, 8 );
        ByteCopy( psObject->padfY, pabyRec + 20, 8 );

        if( bBigEndian ) SwapWord( 8, pabyRec + 12 );
        if( bBigEndian ) SwapWord( 8, pabyRec + 20 );

        nRecordSize = 28;
        
        if( psObject->nSHPType == SHPT_POINTZ )
        {
            ByteCopy( psObject->padfZ, pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
        }
        
        if( psObject->bMeasureIsUsed
            && (psObject->nSHPType == SHPT_POINTZ
                || psObject->nSHPType == SHPT_POINTM) )
        {
            ByteCopy( psObject->padfM, pabyRec + nRecordSize, 8 );
            if( bBigEndian ) SwapWord( 8, pabyRec + nRecordSize );
            nRecordSize += 8;
        }
    }

/* -------------------------------------------------------------------- */
/*      Not much to do for null geometries.                             */
/* -------------------------------------------------------------------- */
    else if( psObject->nSHPType == SHPT_NULL )
    {
        nRecordSize = 12;
    }

    else
    {
        /* unknown type */
        assert( FALSE );
    }

/* -------------------------------------------------------------------- */
/*      Establish where we are going to put this record. If we are      */
/*      rewriting and existing record, and it will fit, then put it     */
/*      back where the original came from.  Otherwise write at the end. */
/* -------------------------------------------------------------------- */
    if( nShapeId == -1 || psSHP->panRecSize[nShapeId] < nRecordSize-8 )
    {
        unsigned int nExpectedSize = psSHP->nFileSize + nRecordSize;
        if( nExpectedSize < psSHP->nFileSize ) // due to unsigned int overflow
        {
            char str[128];
            sprintf( str, "Failed to write shape object. "
                     "File size cannot reach %u + %u.",
                     psSHP->nFileSize, nRecordSize );
            psSHP->sHooks.Error( str );
            dk_free( pabyRec, -1 );
            return -1;
        }

        if( nShapeId == -1 )
            nShapeId = psSHP->nRecords++;

        psSHP->panRecOffset[nShapeId] = nRecordOffset = psSHP->nFileSize;
        psSHP->panRecSize[nShapeId] = nRecordSize-8;
        psSHP->nFileSize += nRecordSize;
    }
    else
    {
        nRecordOffset = psSHP->panRecOffset[nShapeId];
        psSHP->panRecSize[nShapeId] = nRecordSize-8;
    }
    
/* -------------------------------------------------------------------- */
/*      Set the shape type, record number, and record size.             */
/* -------------------------------------------------------------------- */
    i32 = nShapeId+1;					/* record # */
    if( !bBigEndian ) SwapWord( 4, &i32 );
    ByteCopy( &i32, pabyRec, 4 );

    i32 = (nRecordSize-8)/2;				/* record size */
    if( !bBigEndian ) SwapWord( 4, &i32 );
    ByteCopy( &i32, pabyRec + 4, 4 );

    i32 = psObject->nSHPType;				/* shape type */
    if( bBigEndian ) SwapWord( 4, &i32 );
    ByteCopy( &i32, pabyRec + 8, 4 );

/* -------------------------------------------------------------------- */
/*      Write out record.                                               */
/* -------------------------------------------------------------------- */
    if( psSHP->sHooks.FSeek( psSHP->fpSHP, nRecordOffset, 0 ) != 0 )
    {
        psSHP->sHooks.Error( "Error in psSHP->sHooks.FSeek() while writing object to .shp file." );
        dk_free( pabyRec, -1 );
        return -1;
    }
    if( psSHP->sHooks.FWrite( pabyRec, nRecordSize, 1, psSHP->fpSHP ) < 1 )
    {
        psSHP->sHooks.Error( "Error in psSHP->sHooks.Fwrite() while writing object to .shp file." );
        dk_free( pabyRec, -1 );
        return -1;
    }
    
    dk_free( pabyRec, -1 );

/* -------------------------------------------------------------------- */
/*	Expand file wide bounds based on this shape.			*/
/* -------------------------------------------------------------------- */
    if( psSHP->adBoundsMin[0] == 0.0
        && psSHP->adBoundsMax[0] == 0.0
        && psSHP->adBoundsMin[1] == 0.0
        && psSHP->adBoundsMax[1] == 0.0 )
    {
        if( psObject->nSHPType == SHPT_NULL || psObject->nVertices == 0 )
        {
            psSHP->adBoundsMin[0] = psSHP->adBoundsMax[0] = 0.0;
            psSHP->adBoundsMin[1] = psSHP->adBoundsMax[1] = 0.0;
            psSHP->adBoundsMin[2] = psSHP->adBoundsMax[2] = 0.0;
            psSHP->adBoundsMin[3] = psSHP->adBoundsMax[3] = 0.0;
        }
        else
        {
            psSHP->adBoundsMin[0] = psSHP->adBoundsMax[0] = psObject->padfX[0];
            psSHP->adBoundsMin[1] = psSHP->adBoundsMax[1] = psObject->padfY[0];
            psSHP->adBoundsMin[2] = psSHP->adBoundsMax[2] = psObject->padfZ[0];
            psSHP->adBoundsMin[3] = psSHP->adBoundsMax[3] = psObject->padfM[0];
        }
    }

    for( i = 0; i < psObject->nVertices; i++ )
    {
        psSHP->adBoundsMin[0] = MIN(psSHP->adBoundsMin[0],psObject->padfX[i]);
        psSHP->adBoundsMin[1] = MIN(psSHP->adBoundsMin[1],psObject->padfY[i]);
        psSHP->adBoundsMin[2] = MIN(psSHP->adBoundsMin[2],psObject->padfZ[i]);
        psSHP->adBoundsMin[3] = MIN(psSHP->adBoundsMin[3],psObject->padfM[i]);
        psSHP->adBoundsMax[0] = MAX(psSHP->adBoundsMax[0],psObject->padfX[i]);
        psSHP->adBoundsMax[1] = MAX(psSHP->adBoundsMax[1],psObject->padfY[i]);
        psSHP->adBoundsMax[2] = MAX(psSHP->adBoundsMax[2],psObject->padfZ[i]);
        psSHP->adBoundsMax[3] = MAX(psSHP->adBoundsMax[3],psObject->padfM[i]);
    }

    return( nShapeId  );
}

/************************************************************************/
/*                          SHPReadObject()                             */
/*                                                                      */
/*      Read the vertices, parts, and other non-attribute information	*/
/*	for one shape.							*/
/************************************************************************/

SHPObject SHPAPI_CALL1(*)
SHPReadObject( SHPHandle psSHP, int hEntity )

{
    int                  nEntitySize, nRequiredSize;
    SHPObject           *psShape;
    char                 szErrorMsg[128];

/* -------------------------------------------------------------------- */
/*      Validate the record/entity number.                              */
/* -------------------------------------------------------------------- */
    if( hEntity < 0 || hEntity >= psSHP->nRecords )
        return( NULL );

/* -------------------------------------------------------------------- */
/*      Ensure our record buffer is large enough.                       */
/* -------------------------------------------------------------------- */
    nEntitySize = psSHP->panRecSize[hEntity]+8;
    if( nEntitySize > psSHP->nBufSize )
    {
        psSHP->pabyRec = (uchar *) SfRealloc(psSHP->pabyRec,nEntitySize);
        if (psSHP->pabyRec == NULL)
        {
            char szError[200];

            /* Reallocate previous successfull size for following features */
            psSHP->pabyRec = dk_alloc (psSHP->nBufSize);

            sprintf( szError, 
                     "Not enough memory to allocate requested memory (nBufSize=%d). "
                     "Probably broken SHP file", psSHP->nBufSize );
            psSHP->sHooks.Error( szError );
            return NULL;
        }

        /* Only set new buffer size after successfull alloc */
        psSHP->nBufSize = nEntitySize;
    }

    /* In case we were not able to reallocate the buffer on a previous step */
    if (psSHP->pabyRec == NULL)
    {
        return NULL;
    }

/* -------------------------------------------------------------------- */
/*      Read the record.                                                */
/* -------------------------------------------------------------------- */
    if( psSHP->sHooks.FSeek( psSHP->fpSHP, psSHP->panRecOffset[hEntity], 0 ) != 0 )
    {
        /*
         * TODO - mloskot: Consider detailed diagnostics of shape file,
         * for example to detect if file is truncated.
         */
        char str[128];
        sprintf( str,
                 "Error in fseek() reading object from .shp file at offset %u",
                 psSHP->panRecOffset[hEntity]);

        psSHP->sHooks.Error( str );
        return NULL;
    }

    if( psSHP->sHooks.FRead( psSHP->pabyRec, nEntitySize, 1, psSHP->fpSHP ) != 1 )
    {
        /*
         * TODO - mloskot: Consider detailed diagnostics of shape file,
         * for example to detect if file is truncated.
         */
        char str[128];
        sprintf( str,
                 "Error in fread() reading object of size %u at offset %u from .shp file",
                 nEntitySize, psSHP->panRecOffset[hEntity] );

        psSHP->sHooks.Error( str );
        return NULL;
    }

/* -------------------------------------------------------------------- */
/*	Allocate and minimally initialize the object.			*/
/* -------------------------------------------------------------------- */
    psShape = (SHPObject *) dk_alloc (sizeof(SHPObject));
    memset (psShape, 0, sizeof(SHPObject));
    psShape->nShapeId = hEntity;
    psShape->bMeasureIsUsed = FALSE;

    if ( 8 + 4 > nEntitySize )
    {
        snprintf(szErrorMsg, sizeof(szErrorMsg),
                 "Corrupted .shp file : shape %d : nEntitySize = %d",
                 hEntity, nEntitySize); 
        psSHP->sHooks.Error( szErrorMsg );
        SHPDestroyObject(psShape);
        return NULL;
    }
    memcpy( &psShape->nSHPType, psSHP->pabyRec + 8, 4 );

    if( bBigEndian ) SwapWord( 4, &(psShape->nSHPType) );

/* ==================================================================== */
/*  Extract vertices for a Polygon or Arc.				*/
/* ==================================================================== */
    if( psShape->nSHPType == SHPT_POLYGON || psShape->nSHPType == SHPT_ARC
        || psShape->nSHPType == SHPT_POLYGONZ
        || psShape->nSHPType == SHPT_POLYGONM
        || psShape->nSHPType == SHPT_ARCZ
        || psShape->nSHPType == SHPT_ARCM
        || psShape->nSHPType == SHPT_MULTIPATCH )
    {
        int32		nPoints, nParts;
        int    		i, nOffset;
        size_t		padf_boxlen;

        if ( 40 + 8 + 4 > nEntitySize )
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d : nEntitySize = %d",
                     hEntity, nEntitySize); 
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }
/* -------------------------------------------------------------------- */
/*	Get the X/Y bounds.						*/
/* -------------------------------------------------------------------- */
        memcpy( &(psShape->dfXMin), psSHP->pabyRec + 8 +  4, 8 );
        memcpy( &(psShape->dfYMin), psSHP->pabyRec + 8 + 12, 8 );
        memcpy( &(psShape->dfXMax), psSHP->pabyRec + 8 + 20, 8 );
        memcpy( &(psShape->dfYMax), psSHP->pabyRec + 8 + 28, 8 );

        if( bBigEndian ) SwapWord( 8, &(psShape->dfXMin) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfYMin) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfXMax) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfYMax) );

/* -------------------------------------------------------------------- */
/*      Extract part/point count, and build vertex and part arrays      */
/*      to proper size.                                                 */
/* -------------------------------------------------------------------- */
        memcpy( &nPoints, psSHP->pabyRec + 40 + 8, 4 );
        memcpy( &nParts, psSHP->pabyRec + 36 + 8, 4 );

        if( bBigEndian ) SwapWord( 4, &nPoints );
        if( bBigEndian ) SwapWord( 4, &nParts );

        if (nPoints < 0 || nParts < 0 ||
            nPoints > 50 * 1000 * 1000 || nParts > 10 * 1000 * 1000)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d, nPoints=%d, nParts=%d.",
                     hEntity, nPoints, nParts);
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }
        
        /* With the previous checks on nPoints and nParts, */
        /* we should not overflow here and after */
        /* since 50 M * (16 + 8 + 8) = 1 600 MB */
        nRequiredSize = 44 + 8 + 4 * nParts + 16 * nPoints;
        if ( psShape->nSHPType == SHPT_POLYGONZ
             || psShape->nSHPType == SHPT_ARCZ
             || psShape->nSHPType == SHPT_MULTIPATCH )
        {
            nRequiredSize += 16 + 8 * nPoints;
        }
        if( psShape->nSHPType == SHPT_MULTIPATCH )
        {
            nRequiredSize += 4 * nParts;
        }
        if (nRequiredSize > nEntitySize)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d, nPoints=%d, nParts=%d, nEntitySize=%d.",
                     hEntity, nPoints, nParts, nEntitySize);
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }

        psShape->nVertices = nPoints;
        padf_boxlen = nPoints * sizeof(double);
        psShape->padfX = (double *) dk_alloc (padf_boxlen); memset (psShape->padfX, 0, padf_boxlen);
        psShape->padfY = (double *) dk_alloc (padf_boxlen); memset (psShape->padfY, 0, padf_boxlen);
        psShape->padfZ = (double *) dk_alloc (padf_boxlen); memset (psShape->padfZ, 0, padf_boxlen);
        psShape->padfM = (double *) dk_alloc (padf_boxlen); memset (psShape->padfM, 0, padf_boxlen);

        psShape->nParts = nParts;
        psShape->panPartStart = (int *) dk_alloc (nParts * sizeof(int));
        psShape->panPartType = (int *) dk_alloc (nParts * sizeof(int));
        
        if (psShape->padfX == NULL ||
            psShape->padfY == NULL ||
            psShape->padfZ == NULL ||
            psShape->padfM == NULL ||
            psShape->panPartStart == NULL ||
            psShape->panPartType == NULL)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Not enough memory to allocate requested memory (nPoints=%d, nParts=%d) for shape %d. "
                     "Probably broken SHP file", hEntity, nPoints, nParts );
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }

        for( i = 0; i < nParts; i++ )
            psShape->panPartType[i] = SHPP_RING;

/* -------------------------------------------------------------------- */
/*      Copy out the part array from the record.                        */
/* -------------------------------------------------------------------- */
        memcpy( psShape->panPartStart, psSHP->pabyRec + 44 + 8, 4 * nParts );
        for( i = 0; i < nParts; i++ )
        {
            if( bBigEndian ) SwapWord( 4, psShape->panPartStart+i );

            /* We check that the offset is inside the vertex array */
            if (psShape->panPartStart[i] < 0
                || (psShape->panPartStart[i] >= psShape->nVertices
                    && psShape->nVertices > 0) )
            {
                snprintf(szErrorMsg, sizeof(szErrorMsg),
                         "Corrupted .shp file : shape %d : panPartStart[%d] = %d, nVertices = %d",
                         hEntity, i, psShape->panPartStart[i], psShape->nVertices); 
                psSHP->sHooks.Error( szErrorMsg );
                SHPDestroyObject(psShape);
                return NULL;
            }
            if (i > 0 && psShape->panPartStart[i] <= psShape->panPartStart[i-1])
            {
                snprintf(szErrorMsg, sizeof(szErrorMsg),
                         "Corrupted .shp file : shape %d : panPartStart[%d] = %d, panPartStart[%d] = %d",
                         hEntity, i, psShape->panPartStart[i], i - 1, psShape->panPartStart[i - 1]); 
                psSHP->sHooks.Error( szErrorMsg );
                SHPDestroyObject(psShape);
                return NULL;
            }
        }

        nOffset = 44 + 8 + 4*nParts;

/* -------------------------------------------------------------------- */
/*      If this is a multipatch, we will also have parts types.         */
/* -------------------------------------------------------------------- */
        if( psShape->nSHPType == SHPT_MULTIPATCH )
        {
            memcpy( psShape->panPartType, psSHP->pabyRec + nOffset, 4*nParts );
            for( i = 0; i < nParts; i++ )
            {
                if( bBigEndian ) SwapWord( 4, psShape->panPartType+i );
            }

            nOffset += 4*nParts;
        }
        
/* -------------------------------------------------------------------- */
/*      Copy out the vertices from the record.                          */
/* -------------------------------------------------------------------- */
        for( i = 0; i < nPoints; i++ )
        {
            memcpy(psShape->padfX + i,
                   psSHP->pabyRec + nOffset + i * 16,
                   8 );

            memcpy(psShape->padfY + i,
                   psSHP->pabyRec + nOffset + i * 16 + 8,
                   8 );

            if( bBigEndian ) SwapWord( 8, psShape->padfX + i );
            if( bBigEndian ) SwapWord( 8, psShape->padfY + i );
        }

        nOffset += 16*nPoints;
        
/* -------------------------------------------------------------------- */
/*      If we have a Z coordinate, collect that now.                    */
/* -------------------------------------------------------------------- */
        if( psShape->nSHPType == SHPT_POLYGONZ
            || psShape->nSHPType == SHPT_ARCZ
            || psShape->nSHPType == SHPT_MULTIPATCH )
        {
            memcpy( &(psShape->dfZMin), psSHP->pabyRec + nOffset, 8 );
            memcpy( &(psShape->dfZMax), psSHP->pabyRec + nOffset + 8, 8 );
            
            if( bBigEndian ) SwapWord( 8, &(psShape->dfZMin) );
            if( bBigEndian ) SwapWord( 8, &(psShape->dfZMax) );
            
            for( i = 0; i < nPoints; i++ )
            {
                memcpy( psShape->padfZ + i,
                        psSHP->pabyRec + nOffset + 16 + i*8, 8 );
                if( bBigEndian ) SwapWord( 8, psShape->padfZ + i );
            }

            nOffset += 16 + 8*nPoints;
        }

/* -------------------------------------------------------------------- */
/*      If we have a M measure value, then read it now.  We assume      */
/*      that the measure can be present for any shape if the size is    */
/*      big enough, but really it will only occur for the Z shapes      */
/*      (options), and the M shapes.                                    */
/* -------------------------------------------------------------------- */
        if( nEntitySize >= nOffset + 16 + 8*nPoints )
        {
            memcpy( &(psShape->dfMMin), psSHP->pabyRec + nOffset, 8 );
            memcpy( &(psShape->dfMMax), psSHP->pabyRec + nOffset + 8, 8 );
            
            if( bBigEndian ) SwapWord( 8, &(psShape->dfMMin) );
            if( bBigEndian ) SwapWord( 8, &(psShape->dfMMax) );
            
            for( i = 0; i < nPoints; i++ )
            {
                memcpy( psShape->padfM + i,
                        psSHP->pabyRec + nOffset + 16 + i*8, 8 );
                if( bBigEndian ) SwapWord( 8, psShape->padfM + i );
            }
            psShape->bMeasureIsUsed = TRUE;
        }
    }

/* ==================================================================== */
/*  Extract vertices for a MultiPoint.					*/
/* ==================================================================== */
    else if( psShape->nSHPType == SHPT_MULTIPOINT
             || psShape->nSHPType == SHPT_MULTIPOINTM
             || psShape->nSHPType == SHPT_MULTIPOINTZ )
    {
        int32		nPoints;
        int    		i, nOffset;
        size_t		padf_boxlen;

        if ( 44 + 4 > nEntitySize )
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d : nEntitySize = %d",
                     hEntity, nEntitySize); 
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }
        memcpy( &nPoints, psSHP->pabyRec + 44, 4 );

        if( bBigEndian ) SwapWord( 4, &nPoints );

        if (nPoints < 0 || nPoints > 50 * 1000 * 1000)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d : nPoints = %d",
                     hEntity, nPoints); 
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }

        nRequiredSize = 48 + nPoints * 16;
        if( psShape->nSHPType == SHPT_MULTIPOINTZ )
        {
            nRequiredSize += 16 + nPoints * 8;
        }
        if (nRequiredSize > nEntitySize)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d : nPoints = %d, nEntitySize = %d",
                     hEntity, nPoints, nEntitySize); 
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }
        
        psShape->nVertices = nPoints;
        padf_boxlen = nPoints * sizeof(double);
        psShape->padfX = (double *) dk_alloc (padf_boxlen); memset (psShape->padfX, 0, padf_boxlen);
        psShape->padfY = (double *) dk_alloc (padf_boxlen); memset (psShape->padfY, 0, padf_boxlen);
        psShape->padfZ = (double *) dk_alloc (padf_boxlen); memset (psShape->padfZ, 0, padf_boxlen);
        psShape->padfM = (double *) dk_alloc (padf_boxlen); memset (psShape->padfM, 0, padf_boxlen);

        if (psShape->padfX == NULL ||
            psShape->padfY == NULL ||
            psShape->padfZ == NULL ||
            psShape->padfM == NULL)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Not enough memory to allocate requested memory (nPoints=%d) for shape %d. "
                     "Probably broken SHP file", hEntity, nPoints );
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }

        for( i = 0; i < nPoints; i++ )
        {
            memcpy(psShape->padfX+i, psSHP->pabyRec + 48 + 16 * i, 8 );
            memcpy(psShape->padfY+i, psSHP->pabyRec + 48 + 16 * i + 8, 8 );

            if( bBigEndian ) SwapWord( 8, psShape->padfX + i );
            if( bBigEndian ) SwapWord( 8, psShape->padfY + i );
        }

        nOffset = 48 + 16*nPoints;
        
/* -------------------------------------------------------------------- */
/*	Get the X/Y bounds.						*/
/* -------------------------------------------------------------------- */
        memcpy( &(psShape->dfXMin), psSHP->pabyRec + 8 +  4, 8 );
        memcpy( &(psShape->dfYMin), psSHP->pabyRec + 8 + 12, 8 );
        memcpy( &(psShape->dfXMax), psSHP->pabyRec + 8 + 20, 8 );
        memcpy( &(psShape->dfYMax), psSHP->pabyRec + 8 + 28, 8 );

        if( bBigEndian ) SwapWord( 8, &(psShape->dfXMin) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfYMin) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfXMax) );
        if( bBigEndian ) SwapWord( 8, &(psShape->dfYMax) );

/* -------------------------------------------------------------------- */
/*      If we have a Z coordinate, collect that now.                    */
/* -------------------------------------------------------------------- */
        if( psShape->nSHPType == SHPT_MULTIPOINTZ )
        {
            memcpy( &(psShape->dfZMin), psSHP->pabyRec + nOffset, 8 );
            memcpy( &(psShape->dfZMax), psSHP->pabyRec + nOffset + 8, 8 );
            
            if( bBigEndian ) SwapWord( 8, &(psShape->dfZMin) );
            if( bBigEndian ) SwapWord( 8, &(psShape->dfZMax) );
            
            for( i = 0; i < nPoints; i++ )
            {
                memcpy( psShape->padfZ + i,
                        psSHP->pabyRec + nOffset + 16 + i*8, 8 );
                if( bBigEndian ) SwapWord( 8, psShape->padfZ + i );
            }

            nOffset += 16 + 8*nPoints;
        }

/* -------------------------------------------------------------------- */
/*      If we have a M measure value, then read it now.  We assume      */
/*      that the measure can be present for any shape if the size is    */
/*      big enough, but really it will only occur for the Z shapes      */
/*      (options), and the M shapes.                                    */
/* -------------------------------------------------------------------- */
        if( nEntitySize >= nOffset + 16 + 8*nPoints )
        {
            memcpy( &(psShape->dfMMin), psSHP->pabyRec + nOffset, 8 );
            memcpy( &(psShape->dfMMax), psSHP->pabyRec + nOffset + 8, 8 );
            
            if( bBigEndian ) SwapWord( 8, &(psShape->dfMMin) );
            if( bBigEndian ) SwapWord( 8, &(psShape->dfMMax) );
            
            for( i = 0; i < nPoints; i++ )
            {
                memcpy( psShape->padfM + i,
                        psSHP->pabyRec + nOffset + 16 + i*8, 8 );
                if( bBigEndian ) SwapWord( 8, psShape->padfM + i );
            }
            psShape->bMeasureIsUsed = TRUE;
        }
    }

/* ==================================================================== */
/*      Extract vertices for a point.                                   */
/* ==================================================================== */
    else if( psShape->nSHPType == SHPT_POINT
             || psShape->nSHPType == SHPT_POINTM
             || psShape->nSHPType == SHPT_POINTZ )
    {
        int	nOffset;
        
        psShape->nVertices = 1;
        psShape->padfX = (double *) dk_alloc (sizeof(double)); memset (psShape->padfX, 0, sizeof(double));
        psShape->padfY = (double *) dk_alloc (sizeof(double)); memset (psShape->padfY, 0, sizeof(double));
        psShape->padfZ = (double *) dk_alloc (sizeof(double)); memset (psShape->padfZ, 0, sizeof(double));
        psShape->padfM = (double *) dk_alloc (sizeof(double)); memset (psShape->padfM, 0, sizeof(double));

        if (20 + 8 + (( psShape->nSHPType == SHPT_POINTZ ) ? 8 : 0)> nEntitySize)
        {
            snprintf(szErrorMsg, sizeof(szErrorMsg),
                     "Corrupted .shp file : shape %d : nEntitySize = %d",
                     hEntity, nEntitySize); 
            psSHP->sHooks.Error( szErrorMsg );
            SHPDestroyObject(psShape);
            return NULL;
        }
        memcpy( psShape->padfX, psSHP->pabyRec + 12, 8 );
        memcpy( psShape->padfY, psSHP->pabyRec + 20, 8 );

        if( bBigEndian ) SwapWord( 8, psShape->padfX );
        if( bBigEndian ) SwapWord( 8, psShape->padfY );

        nOffset = 20 + 8;
        
/* -------------------------------------------------------------------- */
/*      If we have a Z coordinate, collect that now.                    */
/* -------------------------------------------------------------------- */
        if( psShape->nSHPType == SHPT_POINTZ )
        {
            memcpy( psShape->padfZ, psSHP->pabyRec + nOffset, 8 );
        
            if( bBigEndian ) SwapWord( 8, psShape->padfZ );
            
            nOffset += 8;
        }

/* -------------------------------------------------------------------- */
/*      If we have a M measure value, then read it now.  We assume      */
/*      that the measure can be present for any shape if the size is    */
/*      big enough, but really it will only occur for the Z shapes      */
/*      (options), and the M shapes.                                    */
/* -------------------------------------------------------------------- */
        if( nEntitySize >= nOffset + 8 )
        {
            memcpy( psShape->padfM, psSHP->pabyRec + nOffset, 8 );
        
            if( bBigEndian ) SwapWord( 8, psShape->padfM );
            psShape->bMeasureIsUsed = TRUE;
        }

/* -------------------------------------------------------------------- */
/*      Since no extents are supplied in the record, we will apply      */
/*      them from the single vertex.                                    */
/* -------------------------------------------------------------------- */
        psShape->dfXMin = psShape->dfXMax = psShape->padfX[0];
        psShape->dfYMin = psShape->dfYMax = psShape->padfY[0];
        psShape->dfZMin = psShape->dfZMax = psShape->padfZ[0];
        psShape->dfMMin = psShape->dfMMax = psShape->padfM[0];
    }

    return( psShape );
}

/************************************************************************/
/*                            SHPTypeName()                             */
/************************************************************************/

const char SHPAPI_CALL1(*)
SHPTypeName( int nSHPType )

{
    switch( nSHPType )
    {
      case SHPT_NULL:
        return "NullShape";

      case SHPT_POINT:
        return "Point";

      case SHPT_ARC:
        return "Arc";

      case SHPT_POLYGON:
        return "Polygon";

      case SHPT_MULTIPOINT:
        return "MultiPoint";
        
      case SHPT_POINTZ:
        return "PointZ";

      case SHPT_ARCZ:
        return "ArcZ";

      case SHPT_POLYGONZ:
        return "PolygonZ";

      case SHPT_MULTIPOINTZ:
        return "MultiPointZ";
        
      case SHPT_POINTM:
        return "PointM";

      case SHPT_ARCM:
        return "ArcM";

      case SHPT_POLYGONM:
        return "PolygonM";

      case SHPT_MULTIPOINTM:
        return "MultiPointM";

      case SHPT_MULTIPATCH:
        return "MultiPatch";

      default:
        return "UnknownShapeType";
    }
}

/************************************************************************/
/*                          SHPPartTypeName()                           */
/************************************************************************/

const char SHPAPI_CALL1(*)
SHPPartTypeName( int nPartType )

{
    switch( nPartType )
    {
      case SHPP_TRISTRIP:
        return "TriangleStrip";
        
      case SHPP_TRIFAN:
        return "TriangleFan";

      case SHPP_OUTERRING:
        return "OuterRing";

      case SHPP_INNERRING:
        return "InnerRing";

      case SHPP_FIRSTRING:
        return "FirstRing";

      case SHPP_RING:
        return "Ring";

      default:
        return "UnknownPartType";
    }
}

/************************************************************************/
/*                          SHPDestroyObject()                          */
/************************************************************************/

void SHPAPI_CALL
SHPDestroyObject( SHPObject * psShape )

{
    if( psShape == NULL )
        return;
    
    if( psShape->padfX != NULL )
        dk_free( psShape->padfX, -1 );
    if( psShape->padfY != NULL )
        dk_free( psShape->padfY, -1 );
    if( psShape->padfZ != NULL )
        dk_free( psShape->padfZ, -1 );
    if( psShape->padfM != NULL )
        dk_free( psShape->padfM, -1 );

    if( psShape->panPartStart != NULL )
        dk_free( psShape->panPartStart, -1 );
    if( psShape->panPartType != NULL )
        dk_free( psShape->panPartType, -1 );

    dk_free( psShape, -1 );
}

/************************************************************************/
/*                          SHPRewindObject()                           */
/*                                                                      */
/*      Reset the winding of polygon objects to adhere to the           */
/*      specification.                                                  */
/************************************************************************/

int SHPAPI_CALL
SHPRewindObject( SHPHandle hSHP, SHPObject * psObject )

{
    int  iOpRing, bAltered = 0;

/* -------------------------------------------------------------------- */
/*      Do nothing if this is not a polygon object.                     */
/* -------------------------------------------------------------------- */
    if( psObject->nSHPType != SHPT_POLYGON
        && psObject->nSHPType != SHPT_POLYGONZ
        && psObject->nSHPType != SHPT_POLYGONM )
        return 0;

    if( psObject->nVertices == 0 || psObject->nParts == 0 )
        return 0;

/* -------------------------------------------------------------------- */
/*      Process each of the rings.                                      */
/* -------------------------------------------------------------------- */
    for( iOpRing = 0; iOpRing < psObject->nParts; iOpRing++ )
    {
        int      bInner, iVert, nVertCount, nVertStart, iCheckRing;
        double   dfSum, dfTestX, dfTestY;

/* -------------------------------------------------------------------- */
/*      Determine if this ring is an inner ring or an outer ring        */
/*      relative to all the other rings.  For now we assume the         */
/*      first ring is outer and all others are inner, but eventually    */
/*      we need to fix this to handle multiple island polygons and      */
/*      unordered sets of rings.                                        */
/*                                                                      */
/* -------------------------------------------------------------------- */

        /* Use point in the middle of segment to avoid testing
         * common points of rings.
         */
        dfTestX = ( psObject->padfX[psObject->panPartStart[iOpRing]]
                    + psObject->padfX[psObject->panPartStart[iOpRing] + 1] ) / 2;
        dfTestY = ( psObject->padfY[psObject->panPartStart[iOpRing]]
                    + psObject->padfY[psObject->panPartStart[iOpRing] + 1] ) / 2;

        bInner = FALSE;
        for( iCheckRing = 0; iCheckRing < psObject->nParts; iCheckRing++ )
        {
            int iEdge;

            if( iCheckRing == iOpRing )
                continue;
            
            nVertStart = psObject->panPartStart[iCheckRing];

            if( iCheckRing == psObject->nParts-1 )
                nVertCount = psObject->nVertices 
                    - psObject->panPartStart[iCheckRing];
            else
                nVertCount = psObject->panPartStart[iCheckRing+1] 
                    - psObject->panPartStart[iCheckRing];

            for( iEdge = 0; iEdge < nVertCount; iEdge++ )
            {
                int iNext;

                if( iEdge < nVertCount-1 )
                    iNext = iEdge+1;
                else
                    iNext = 0;

                /* Rule #1:
                 * Test whether the edge 'straddles' the horizontal ray from the test point (dfTestY,dfTestY)
                 * The rule #1 also excludes edges collinear with the ray.
                 */
                if ( ( psObject->padfY[iEdge+nVertStart] < dfTestY
                       && dfTestY <= psObject->padfY[iNext+nVertStart] )
                     || ( psObject->padfY[iNext+nVertStart] < dfTestY
                          && dfTestY <= psObject->padfY[iEdge+nVertStart] ) )
                {
                    /* Rule #2:
                     * Test if edge-ray intersection is on the right from the test point (dfTestY,dfTestY)
                     */
                    double const intersect = 
                        ( psObject->padfX[iEdge+nVertStart]
                          + ( dfTestY - psObject->padfY[iEdge+nVertStart] ) 
                          / ( psObject->padfY[iNext+nVertStart] - psObject->padfY[iEdge+nVertStart] )
                          * ( psObject->padfX[iNext+nVertStart] - psObject->padfX[iEdge+nVertStart] ) );

                    if (intersect  < dfTestX)
                    {
                        bInner = !bInner;
                    }
                }    
            }
        } /* for iCheckRing */

/* -------------------------------------------------------------------- */
/*      Determine the current order of this ring so we will know if     */
/*      it has to be reversed.                                          */
/* -------------------------------------------------------------------- */
        nVertStart = psObject->panPartStart[iOpRing];

        if( iOpRing == psObject->nParts-1 )
            nVertCount = psObject->nVertices - psObject->panPartStart[iOpRing];
        else
            nVertCount = psObject->panPartStart[iOpRing+1] 
                - psObject->panPartStart[iOpRing];

        if (nVertCount < 2)
            continue;

        dfSum = psObject->padfX[nVertStart] * (psObject->padfY[nVertStart+1] - psObject->padfY[nVertStart+nVertCount-1]);
        for( iVert = nVertStart + 1; iVert < nVertStart+nVertCount-1; iVert++ )
        {
            dfSum += psObject->padfX[iVert] * (psObject->padfY[iVert+1] - psObject->padfY[iVert-1]);
        }

        dfSum += psObject->padfX[iVert] * (psObject->padfY[nVertStart] - psObject->padfY[iVert-1]);

/* -------------------------------------------------------------------- */
/*      Reverse if necessary.                                           */
/* -------------------------------------------------------------------- */
        if( (dfSum < 0.0 && bInner) || (dfSum > 0.0 && !bInner) )
        {
            int   i;

            bAltered++;
            for( i = 0; i < nVertCount/2; i++ )
            {
                double dfSaved;

                /* Swap X */
                dfSaved = psObject->padfX[nVertStart+i];
                psObject->padfX[nVertStart+i] = 
                    psObject->padfX[nVertStart+nVertCount-i-1];
                psObject->padfX[nVertStart+nVertCount-i-1] = dfSaved;

                /* Swap Y */
                dfSaved = psObject->padfY[nVertStart+i];
                psObject->padfY[nVertStart+i] = 
                    psObject->padfY[nVertStart+nVertCount-i-1];
                psObject->padfY[nVertStart+nVertCount-i-1] = dfSaved;

                /* Swap Z */
                if( psObject->padfZ )
                {
                    dfSaved = psObject->padfZ[nVertStart+i];
                    psObject->padfZ[nVertStart+i] = 
                        psObject->padfZ[nVertStart+nVertCount-i-1];
                    psObject->padfZ[nVertStart+nVertCount-i-1] = dfSaved;
                }

                /* Swap M */
                if( psObject->padfM )
                {
                    dfSaved = psObject->padfM[nVertStart+i];
                    psObject->padfM[nVertStart+i] = 
                        psObject->padfM[nVertStart+nVertCount-i-1];
                    psObject->padfM[nVertStart+nVertCount-i-1] = dfSaved;
                }
            }
        }
    }

    return bAltered;
}
