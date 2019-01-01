/*
 *  bif_audio.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#include "bif_audio_tags.h"


#define URN	"http://www.openlinksw.com/schemas/audio#"

typedef unsigned int word;
typedef unsigned char byte;

typedef struct
  {
    int indent;
    char *pool;
    size_t length;
    size_t limit;
    int type;
  } stream;


#ifdef __GNUC__
static void out_printf (stream *out, const char *format, ...)
    __attribute__((format (printf, 2, 3)));
#endif


static void
out_init (stream *out, int type)
{
  memset (out, 0, sizeof (stream));
  out->type = type;
  out->limit = 1024;
  out->pool = (char *) malloc (out->limit);
}


static int
out_assure (stream *out, size_t length)
{
  char *pool;
  int ret = 0;

  if (out->pool == NULL)
    return -1;
  if (out->length + length > out->limit)
    {
      length += out->limit;
      while (out->limit < length)
	out->limit <<= 1;
      if ((pool = (char *) realloc (out->pool, out->limit)) == NULL)
	{
	  free (out->pool);
	  ret = -1;
	}

      out->pool = pool;
    }

  return ret;
}


static void
out_write (stream *out, const void *ptr, size_t length)
{
  if (out_assure (out, length) == 0)
    {
      memcpy (out->pool + out->length, ptr, length);
      out->length += length;
    }
}


static void
out_putc (stream *out, int c)
{
  if (out_assure (out, 1) == 0)
    out->pool[out->length++] = c;
}


static char *
out_finish (stream *out)
{
  char *data;

  out_putc (out, 0);
  data = out->pool;
  out->pool = NULL;

  return data;
}


static void
out_printf (stream *out, const char *format, ...)
{
  char line[512];
  va_list ap;

  va_start (ap, format);
  vsnprintf (line, sizeof (line), format, ap);
  va_end (ap);
  line[sizeof (line) - 1] = 0;
  out_write (out, line, strlen (line));
}


/*
 encoding value:
    iso8859-1 = 0
    utf16/ucs2 with BOM = 1
    utf16-be without BOM = 2 (id3v2.4 only)
    utf8 = 3 (id3v2.4 only)
*/
static void
xml_value (stream *out, const void *content, size_t length, int encoding)
{
  const byte *dp = (const byte *) content;
  int len, i, first;
  char ustr[3];
  wchar_t c = 0;

  if (encoding == 1 || encoding == 2)
    length >>= 1;

  while (length-- > 0)
    {
      switch (encoding)
	{
	case 0:
	  c = *dp++;
	  break;
	case 3:
	  c = *dp++;
	  break;
	case 1:
	  c = (dp[0] << 8) | dp[1];
	  dp += 2;
	  if (c == 0xFEFF)
	    {
	      /* big-endian */
	      encoding = 2;
	      continue;
	    }
	  else if (c == 0xFFFE)
	    {
	      /* little-endian */
	      encoding = -2;
	      continue;
	    }
	  break;
	case 2:
	  c = (dp[0] << 8) | dp[1];
	  dp += 2;
	  break;
	case -2:
	  c = (dp[1] << 8) | dp[0];
	  dp += 2;
	  break;
	}
      /* ucs-2 => utf-8 */
      if (c >= 0x80 && encoding != 3)
	{
	  if (c < 0x800)
	    {
	      len = 2;
	      first = 0xC0;
	    }
	  else
	    {
	      len = 3;
	      first = 0xE0;
	    }
	  for (i = len - 1; i > 0; i--)
	    {
	      ustr[i] = (c & 0x3F) | 0x80;
	      c >>= 6;
	    }
	  ustr[0] = c | first;
	  out_write (out, ustr, len);
	  continue;
	}
      switch (c)
	{
	case '&':
	  out_write (out, "&amp;", 5);
	  break;
	case '<':
	  out_write (out, "&lt;", 4);
	  break;
	case '>':
	  out_write (out, "&gt;", 4);
	  break;
	case 0:
	  break;
	default:
	  out_putc (out, c);
	  break;
	}
    }
}


#if 0
static void
xml_binary_data (stream *out, const void *value, int length)
{
  static char b2a[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const byte *sp = (const byte *) value;
  int count = 0;
  word w;

  while (length > 0)
    {
      if (length >= 3)
	{
	  w = (sp[0] << 16) | (sp[1] << 8) | sp[2];
	  out_putc (out, b2a[(w >> 18) & 0x3F]);
	  out_putc (out, b2a[(w >> 12) & 0x3F]);
	  out_putc (out, b2a[(w >> 6) & 0x3F]);
	  out_putc (out, b2a[w & 0x3F]);
	  length -= 3;
	  if (++count == 19)
	    {
	      out_putc (out, '\n');
	      count = 0;
	    }
	}
      else
	{
	  w = sp[0] << 16;
	  if (length == 2)
	    w |= (sp[1] << 8);
	  out_putc (out, b2a[(w >> 18) & 0x3F]);
	  out_putc (out, b2a[(w >> 12) & 0x3F]);
	  out_putc (out, length == 1 ? '=' : b2a[(w >> 6) & 0x3F]);
	  out_putc (out, '=');
	  length = 0;
	}
      sp += 3;
    }
}
#endif


static void
xml_key_value (stream *out, const char *key, const char *value, int length, int encoding)
{
  if (length <= 0)
    length = (int) strlen ((const char *) value);
  if (out->type == 1)
    {
      out_printf (out, "<N3 N3S=\"http://local.virt/this\" N3P=\"" URN "%s\">", key);
      xml_value (out, value, length, encoding);
      out_printf (out, "</N3>\n");
    }
  else
    {
      out_printf (out, "  <%s>", key);
      xml_value (out, value, length, encoding);
      out_printf (out, "</%s>\n", key);
    }
}

/*************************/

static const char *id3_genres[148] = {
  "Blues", "Classic Rock", "Country", "Dance",
  "Disco", "Funk", "Grunge", "Hip-Hop",
  "Jazz", "Metal", "New Age", "Oldies",
  "Other", "Pop", "R&B", "Rap",
  "Reggae", "Rock", "Techno", "Industrial",
  "Alternative", "Ska", "Death Metal", "Pranks",
  "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop",
  "Vocal", "Jazz+Funk", "Fusion", "Trance",
  "Classical", "Instrumental", "Acid", "House",
  "Game", "Sound Clip", "Gospel", "Noise",
  "Alt. Rock", "Bass", "Soul", "Punk",
  "Space", "Meditative", "Instrumental Pop", "Instrumental Rock",
  "Ethnic", "Gothic", "Darkwave", "Techno-Industrial",
  "Electronic", "Pop-Folk", "Eurodance", "Dream",
  "Southern Rock", "Comedy", "Cult", "Gangsta Rap",
  "Top 40", "Christian Rap", "Pop/Funk", "Jungle",
  "Native American", "Cabaret", "New Wave", "Psychedelic",
  "Rave", "Showtunes", "Trailer", "Lo-Fi",
  "Tribal", "Acid Punk", "Acid Jazz", "Polka",
  "Retro", "Musical", "Rock & Roll", "Hard Rock",
  "Folk", "Folk/Rock", "National Folk", "Swing",
  "Fast-Fusion", "Bebob", "Latin", "Revival",
  "Celtic", "Bluegrass", "Avantgarde", "Gothic Rock",
  "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
  "Big Band", "Chorus", "Easy Listening", "Acoustic",
  "Humour", "Speech", "Chanson", "Opera",
  "Chamber Music", "Sonata", "Symphony", "Booty Bass",
  "Primus", "Porn Groove", "Satire", "Slow Jam",
  "Club", "Tango", "Samba", "Folklore",
  "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
  "Duet", "Punk Rock", "Drum Solo", "A Cappella",
  "Euro-House", "Dance Hall", "Goa", "Drum & Bass",
  "Club-House", "Hardcore", "Terror", "Indie",
  "BritPop", "Negerpunk", "Polsk Punk", "Beat",
  "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover",
  "Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
  "Thrash Metal", "Anime", "Jpop", "Synthpop"
};


static int
disect_id3v1 (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  char title[30 + 1];
  char artist[30 + 1];
  char album[30 + 1];
  char year[4 + 1];
  char comment[30 + 1];
  char buffer[30 + 1];
  int genre;
  int trackNumber;

  if (length < 128)
    return -1;
  dp += length - 128;

  if (dp[0] != 'T' || dp[1] != 'A' || dp[2] != 'G')
    return -1;
  dp += 3;

  memcpy (title, dp, 30); title[30] = '\0'; dp += 30;
  memcpy (artist, dp, 30); artist[30] = '\0'; dp += 30;
  memcpy (album, dp, 30); album[30] = '\0'; dp += 30;
  memcpy (year, dp, 4); year[4] = '\0'; dp += 4;
  memcpy (buffer, dp, 30); buffer[30] = '\0'; dp += 30;
  if (buffer[28] == 0 && buffer[29] != 0)
    {
      memcpy (comment, buffer, 28);
      comment[28] = 0;
      trackNumber = buffer[29];
    }
  else
    {
      memcpy (comment, buffer, 31);
      trackNumber = 0;
    }
  genre = dp[0];
  if (genre < 0 || genre > 147)
    genre = 12; /* Other */

  if (rtrim (title))
    xml_key_value (out, "Title", title, -1, 0);
  if (rtrim (artist))
    xml_key_value (out, "Artist", artist, -1, 0);
  if (rtrim (album))
    xml_key_value (out, "Album", album, -1, 0);
  if (rtrim (year))
    xml_key_value (out, "Year", year, -1, 0);
  if (rtrim (comment))
    xml_key_value (out, "Comment", comment, -1, 0);
  if (trackNumber)
    {
      sprintf (buffer, "%d", trackNumber);
      xml_key_value (out, "TrackNumber", buffer, -1, 0);
    }
  xml_key_value (out, "Genre", id3_genres[genre], -1, 0);

  return 0;
}

/*************************/

typedef struct tag_descriptor_s tag_descriptor_t;

typedef struct tag_decoder_params_s tag_decoder_params_t;

typedef void (*tag_decoder_t) (tag_decoder_params_t *params);

struct tag_descriptor_s
  {
    word idtag4;			/* 4 byte tag */
    word idtag3;			/* 3 byte tag for ID3v2.2 */
    tag_decoder_t decoder;		/* function that can parse the frame */
    const char *xml_tag;		/* recommended XML tag */
  };

struct tag_decoder_params_s
  {
    stream *out;			/* output stream */
    byte version;			/* id3 version */
    tag_descriptor_t *descriptor;	/* original descriptor */
    const byte *content;		/* frame data */
    size_t length;			/* frame length */
  };

#define def_decoder(X)	static void X (tag_decoder_params_t *params)

def_decoder (decode_TEXT);
def_decoder (decode_TXXX);
def_decoder (decode_WXXX);
def_decoder (decode_URL);
def_decoder (decode_COMM);

static tag_descriptor_t id3v2_descriptors[] = {
  { tag_COMM, tag_COM,	decode_COMM, "Comment"},

  { tag_TALB, tag_TAL,	decode_TEXT, "Album" },			/**/
  { tag_TBPM, tag_TBP,	decode_TEXT, "Bpm" },
  { tag_TCMP, tag_TCP,	decode_TEXT, "Compilation" },
  { tag_TCOM, tag_TCM,	decode_TEXT, "Composer" },		/**/
  { tag_TCON, tag_TCO,	decode_TEXT, "Genre" },
  { tag_TCOP, tag_TCR,	decode_TEXT, "Copyright" },		/**/
  { tag_TDAT, tag_TDA,	decode_TEXT, "DateRecorded" },		/* v2.3.0 */
  { tag_TDEN, 0,	decode_TEXT, "EncodingTimestamp" },	/* v2.4.0 */
  { tag_TDLY, tag_TDY,	decode_TEXT, "PlaylistDelayMilliseconds" },
  { tag_TDOR, 0,	decode_TEXT, "OriginalReleaseTimestamp" },/* v2.4.0 */
  { tag_TDRC, 0,	decode_TEXT, "RecordingTimestamp" },	/* v2.4.0 */
  { tag_TDRL, 0,	decode_TEXT, "ReleaseTimestamp" },	/* v2.4.0 */
  { tag_TDTG, 0,	decode_TEXT, "TaggingTimestamp" },	/* v2.4.0 */
  { tag_TENC, tag_TEN,	decode_TEXT, "Encoder" },		/**/
  { tag_TEXT, tag_TXT,	decode_TEXT, "Lyricist" },
  { tag_TFLT, tag_TFT,	decode_TEXT, "FileType" },
  { tag_TIME, tag_TIM,	decode_TEXT, "TimeRecorded" },		/* v2.3.0 */
  { tag_TIPL, tag_IPL,	decode_TEXT, "InvolvedPeople" },	/* v2.4.0 */
  { tag_TIT1, tag_TT1,	decode_TEXT, "Grouping" },
  { tag_TIT2, tag_TT2,	decode_TEXT, "Title" },			/**/
  { tag_TIT3, tag_TT3,	decode_TEXT, "Subtitle" },
  { tag_TKEY, tag_TKE,	decode_TEXT, "InitialKey" },
  { tag_TLAN, tag_TLA,	decode_TEXT, "Languages" },
  { tag_TLEN, tag_TLE,	decode_TEXT, "LengthMilliseconds" },
  { tag_TMCL, 0,	decode_TEXT, "MusicianCreditsList" },	/* v2.4.0 */
  { tag_TMED, tag_TMT,	decode_TEXT, "MediaType" },
  { tag_TMOO, 0,	decode_TEXT, "Mood" },			/* v2.4.0 */
  { tag_TOAL, tag_TOT,	decode_TEXT, "OriginalSourceTitle" },
  { tag_TOFN, tag_TOF,	decode_TEXT, "OriginalFileName" },
  { tag_TOLY, tag_TOL,	decode_TEXT, "OriginalLyricist" },
  { tag_TOPE, tag_TOA,	decode_TEXT, "OriginalArtist" },	/**/
  { tag_TORY, tag_TOR,	decode_TEXT, "OriginalReleaseYear" },	/* v2.3.0 */
  { tag_TOWN, 0,	decode_TEXT, "FileOwnerName" },
  { tag_TPE1, tag_TP1,	decode_TEXT, "Artist" },		/**/
  { tag_TPE2, tag_TP2,	decode_TEXT, "Accompaniment" },
  { tag_TPE3, tag_TP3,	decode_TEXT, "Conductor" },
  { tag_TPE4, tag_TP4,	decode_TEXT, "RemixedBy" },
  { tag_TPOS, tag_TPA,	decode_TEXT, "DiscNumber" },
  { tag_TPRO, 0,	decode_TEXT, "ProducedNotice" },	/* v2.4.0 */
  { tag_TPUB, tag_TPB,	decode_TEXT, "Publisher" },		/**/
  { tag_TRCK, tag_TRK,	decode_TEXT, "TrackNumber" },		/**/
  { tag_TRDA, tag_TRD,	decode_TEXT, "RecordingDates" },	/* v2.3.0 */
  { tag_TRSN, 0,	decode_TEXT, "InternetRadioStationName" },
  { tag_TRSO, 0,	decode_TEXT, "InternetRadioStationOwner" },
  { tag_TSIZ, tag_TSI,	decode_TEXT, "FileSizeExcludingTag" },	/* v2.3.0 */
  { tag_TSOA, 0,	decode_TEXT, "AlbumSortOrder" },	/* v2.4.0 */
  { tag_TSOP, 0,	decode_TEXT, "ArtistSortOrder" },	/* v2.4.0 */
  { tag_TSOT, 0,	decode_TEXT, "TitleSortOrder" },	/* v2.4.0 */
  { tag_TSRC, tag_TRC,	decode_TEXT, "ISRC" },
  { tag_TSSE, tag_TSS,	decode_TEXT, "EncoderSettings" },
  { tag_TSST, 0, 	decode_TEXT, "SetSubtitle" },		/* v2.4.0 */
  { tag_TXXX, tag_TXX,	decode_TXXX, "UserDefined" },
  { tag_TYER, tag_TYE,	decode_TEXT, "Year" },			/* v2.3.0 */

  { tag_USLT, tag_ULT,  decode_COMM, "Lyrics" },

  { tag_WCOM, tag_WCM,	decode_URL,  "CommercialInfoUrl" },
  { tag_WCOP, tag_WCP,	decode_URL,  "CopyrightUrl" },
  { tag_WOAF, tag_WAF,	decode_URL,  "AudioFileUrl" },
  { tag_WOAR, tag_WAR,	decode_URL,  "ArtistUrl" },
  { tag_WOAS, tag_WAS,	decode_URL,  "AudioSourceUrl" },
  { tag_WORS, 0,	decode_URL,  "InternetRadioStationUrl" },
  { tag_WPAY, 0,	decode_URL,  "PaymentUrl" },
  { tag_WPUB, tag_WPB,	decode_URL,  "PublisherUrl" },

  { tag_WXXX, 0,	decode_WXXX, "Url"}
};

#define ISFHID(X)	((X) >= '0' && (X) <= 'Z')


static word
read_u2 (const byte *data)
{
  return (data[0] << 8) | data[1];
}


static word
read_u3 (const byte *data)
{
  return (data[0] << 16) | (data[1] << 8) | data[2];
}


static word
read_u4 (const byte *data)
{
  return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
}


static word
read_u4_sync (const byte *data)
{
  return ((data[0] & 0x7F) << 21) | ((data[1] & 0x7F) << 14) |
      ((data[2] & 0x7F) << 7) | (data[3] & 0x7F);
}


static word
read_u4_le (const byte *data)
{
  return (data[3] << 24) | (data[2] << 16) | (data[1] << 8) | data[0];
}


static int
tag_descriptor_cmp (const void *a, const void *b)
{
  tag_descriptor_t *pa = (tag_descriptor_t *) a;
  tag_descriptor_t *pb = (tag_descriptor_t *) b;

  return pa->idtag4 - pb->idtag4;
}


static const byte *
skip_str (const byte *content, const byte *ep, int encoding)
{
  if (encoding >= 1 && encoding <= 2)
    {
      ep--;
      while (content < ep && content[0] && content[1])
	content += 2;
      return content + 2;
    }
  else
    {
      while (content < ep && *content)
	content++;
      return content + 1;
    }
}


def_decoder (decode_TEXT)
{
  /* encoding[1] text */
  if (params->length > 1)
    xml_key_value (params->out, params->descriptor->xml_tag,
	(const char *) (params->content + 1), params->length - 1, params->content[0]);
}
def_decoder (decode_TXXX)
{
  /* encoding[1] shortdesc 00 text */
  int encoding = params->content[0];
  const byte *ep = params->content + params->length;
  const byte *dp = skip_str (params->content + 1, ep, encoding);
  if (dp < ep)
    xml_key_value (params->out, params->descriptor->xml_tag,
	(const char *) dp, ep - dp, encoding);
}
def_decoder (decode_COMM)
{
  /* encoding[1] language[3] shortdesc 00 comments */
  int encoding = params->content[0];
  const byte *ep = params->content + params->length;
  const byte *dp = skip_str (params->content + 4, ep, encoding);
  if (dp < ep)
    xml_key_value (params->out, params->descriptor->xml_tag,
	(const char *) dp, ep - dp, encoding);
}
def_decoder (decode_URL)
{
  xml_key_value (params->out, params->descriptor->xml_tag,
      (const char *) params->content, params->length, 0);
}
def_decoder (decode_WXXX)
{
  /* encoding[1] description 00 url */
  int encoding = params->content[0];
  const byte *ep = params->content + params->length;
  const byte *dp = skip_str (params->content + 1, ep, encoding);
  if (dp < ep)
    xml_key_value (params->out, params->descriptor->xml_tag,
	(const char *) dp, ep - dp, encoding);
}

static void
emit_tag_data (
    stream *out, int version, word id, const byte *content, size_t length)
{
  tag_descriptor_t *fp, key;
  tag_decoder_params_t params;
  size_t nelems;

  nelems = sizeof (id3v2_descriptors) / sizeof (tag_descriptor_t);

  params.version = version;
  params.descriptor = NULL;
  params.out = out;
  params.content = content;
  params.length = length;

  if (version != 2)
    {
      key.idtag4 = id;
      params.descriptor = (tag_descriptor_t *) bsearch (
	  &key,
	  id3v2_descriptors,
	  nelems,
	  sizeof (tag_descriptor_t),
	  tag_descriptor_cmp);
    }
  else
    {
      for (fp = id3v2_descriptors; nelems; fp++, nelems--)
	{
	  if (fp->idtag3 == id)
	    {
	      params.descriptor = fp;
	      break;
	    }
	}
    }

  if (params.descriptor)
    params.descriptor->decoder (&params);
}


static int
disect_id3v2_2 (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  const byte *ep;
  word h_size;
  byte h_minor;
  word h_flags;
  int h_unsynced;
  int h_compressed;
  word f_id;
  word f_size;
  const byte *f_data;

  /* header */
  if (length < 32 || read_u4 (dp) != tag_ID3v22)
    return -1;
  h_minor = dp[4];
  h_flags = dp[5];
  h_size = read_u4_sync (dp + 6);
  if (h_size > length - 10)
    return -1;
  dp += 10;
  ep = dp + h_size;

  /* parse flags */
  h_unsynced = (h_flags & 0x80) ? 1 : 0;
  h_compressed = (h_flags & 0x40) ? 1 : 0;

  if (h_unsynced || h_compressed)
    return -1;

  while (dp + 6 < ep)
    {
      /* frame header */
      if (!ISFHID (dp[0]) || !ISFHID (dp[1]) || !ISFHID (dp[2]))
	break;

      f_id = read_u3 (dp);
      f_size = read_u3 (dp + 3);
      dp += 6;

      if (dp + f_size >= ep)
	break;
      f_data = dp;
      dp += f_size;

      emit_tag_data (out, 2, f_id, f_data, f_size);
    }

  return 0;
}


static int
disect_id3v2_3 (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  const byte *ep;
  word h_size;
  byte h_minor;
  word h_flags;
  int h_unsynced;
  int h_extheader;
  int h_experimental;
  word f_id;
  word f_size;
  word f_flags;
  const byte *f_data;

  /* header */
  if (length < 32 || read_u4 (dp) != tag_ID3v23)
    return -1;
  h_minor = dp[4];
  h_flags = dp[5];
  h_size = read_u4_sync (dp + 6);
  if (h_size > length - 10)
    return -1;
  dp += 10;
  ep = dp + h_size;

  /* parse flags */
  h_unsynced = (h_flags & 0x80) ? 1 : 0;
  h_extheader = (h_flags & 0x40) ? 1 : 0;
  h_experimental = (h_flags & 0x20) ? 1 : 0;

  if (h_unsynced)
    return -1;

  /* skip extended header */
  if (h_extheader)
    {
      word e_size = read_u4 (dp);
      if (e_size != 6 && e_size != 10)
	return -1;
      dp += 4 + e_size;
    }

  while (dp + 10 < ep)
    {
      /* frame header */
      if (!ISFHID (dp[0]) || !ISFHID (dp[1]) || !ISFHID (dp[2]) || !ISFHID (dp[3]))
	break;

      f_id = read_u4 (dp);
      f_size = read_u4 (dp + 4); /* XXX sync in v4, unsync in v3 */
      f_flags = read_u2 (dp + 8);
      dp += 10;

      if (dp + f_size >= ep)
	break;
      f_data = dp;
      dp += f_size;
      /* ignore encrypted or compressed frames */
      if ((f_flags & 0x00C0) == 0)
	emit_tag_data (out, 3, f_id, f_data, f_size);
    }

  return 0;
}


static int
disect_id3v2_4 (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  const byte *ep;
  word h_size;
  byte h_minor;
  word h_flags;
  int h_unsynced;
  int h_extheader;
  int h_experimental;
  int h_footer;
  word f_id;
  word f_size;
  word f_flags;
  const byte *f_data;

  /* header */
  if (length < 32 || read_u4 (dp) != tag_ID3v24)
    return -1;
  h_minor = dp[4];
  h_flags = dp[5];
  h_size = read_u4_sync (dp + 6);
  if (h_size > length - 10)
    return -1;
  dp += 10;
  ep = dp + h_size;

  /* parse flags */
  h_unsynced = (h_flags & 0x80) ? 1 : 0;
  h_extheader = (h_flags & 0x40) ? 1 : 0;
  h_experimental = (h_flags & 0x20) ? 1 : 0;
  h_footer = (h_flags & 0x10) ? 1 : 0;

  if (h_unsynced)
    return -1;

  /* skip extended header */
  if (h_extheader)
    {
      word e_size = read_u4_sync (dp);
      if (e_size < 6)
	return -1;
      dp += e_size;
    }

  while (dp + 10 < ep)
    {
      /* frame header */
      if (!ISFHID (dp[0]) || !ISFHID (dp[1]) || !ISFHID (dp[2]) || !ISFHID (dp[3]))
	break;

      f_id = read_u4 (dp);
      f_size = read_u4_sync (dp + 4); /* XXX sync in v4, unsync in v3 */
      f_flags = read_u2 (dp + 8);
      dp += 10;

      if (dp + f_size >= ep)
	break;
      f_data = dp;
      dp += f_size;
      /* ignore encrypted or compressed frames */
      if ((f_flags & 0x000C) == 0)
	emit_tag_data (out, 4, f_id, f_data, f_size);
    }

  return 0;
}

/*************************/

/* a rather small & stupid mp4 container parser
 * only walks the subtree I'm really interested in
 * skipping all other tags
 */

typedef struct mp4_atom_s
  {
    struct mp4_atom_s *parent;
    word length;
    word tag;
    const byte *data;
  } mp4_atom_t;

typedef struct
  {
    word parent;
    word *set;
  } mp4_investigate_t;

static word inv_root[] = { tag_moov, tag_ftyp, tag_udta, 0};
static word inv_moov[] = { tag_udta, 0 };
static word inv_udta[] = { tag_cprt, tag_meta, tag_Ccpy, tag_Cdes, tag_Cnam, tag_Ccmt, tag_Cprd, 0 };
static word inv_meta[] = { tag_hdlr, tag_ilst, 0 };
static word inv_ilst[] = {
    tag_Cnam, tag_CART, tag_Cwrt, tag_Calb, tag_Cday, tag_Ctoo, tag_Ccmt, tag_Cgen,
    tag_Cgrp, tag_Clyr, tag_trkn, tag_disk, tag_gnre, tag_cpil, tag_tmpo, tag_covr, tag_aART,
    tag_cprt, tag_rtng, tag_apID,
    0
};
static word inv_data_only[] = { tag_data, 0 };

static mp4_investigate_t mp4_investigates[] =
  {
    { tag_root, inv_root },
    { tag_moov, inv_moov },
    { tag_udta, inv_udta },
    { tag_meta, inv_meta },
    { tag_ilst, inv_ilst },
    { tag_Cnam, inv_data_only },
    { tag_CART, inv_data_only },
    { tag_Cwrt, inv_data_only },
    { tag_Calb, inv_data_only },
    { tag_Cday, inv_data_only },
    { tag_Ctoo, inv_data_only },
    { tag_Ccmt, inv_data_only },
    { tag_Cgen, inv_data_only },
    { tag_Cgrp, inv_data_only },
    { tag_trkn, inv_data_only },
    { tag_disk, inv_data_only },
    { tag_gnre, inv_data_only },
    { tag_cpil, inv_data_only },
    { tag_tmpo, inv_data_only },
    { tag_covr, inv_data_only },
    { tag_apID, inv_data_only },
    { tag_aART, inv_data_only },
    { tag_cprt, inv_data_only },
    { tag_rtng, inv_data_only },

    { 0, NULL }
  };


static const byte *
mp4_read_atom (mp4_atom_t *atom, const byte *dp, const byte *ep)
{
  word length;

  /* need 8 header bytes */
  if (dp + 8 >= ep)
    return NULL;

  length = read_u4 (dp);

  if (length == 0)
    length = ep - dp;
  else if (length < 8 || dp + length > ep)
    return NULL;
  /* BTW length==1 is a 64 bit record. no use here */

  atom->tag = read_u4 (dp + 4);
  atom->data = dp + 8;
  atom->length = length - 8;

  return dp + length;
}


static int
mp4_set_contains (word *set, word tag)
{
  while (*set && *set != tag)
    set++;
  return *set == 0 ? -1 : 0;
}

static void
disect_mp4 (stream *out, mp4_atom_t *atom, size_t apos, int level)
{
  mp4_investigate_t *pinv;
  mp4_atom_t child;
  const byte *dp, *ep, *np;

  dp = atom->data;
  ep = dp + atom->length;

  /* analyze data tags a bit deeper */
  if (atom->tag == tag_data && atom->length > 8)
    {
      /* skip VersionAndFlags+reserved */
      atom->data += 8;
      atom->length -= 8;

      switch (atom->parent->tag)
	{
	case tag_Cnam: /* name tag_TIT2 */
	  xml_key_value (out, "Title", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_CART: /* artist tag_TPE1 */
	  xml_key_value (out, "Artist", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Cwrt: /* writer tag_TCOM */
	  xml_key_value (out, "Composer", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Calb: /* album tag_TALB */
	  xml_key_value (out, "Album", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Cday: /* date tag_TYER */
	  if (atom->length >= 4)
	    xml_key_value (out, "Year", (const char *) atom->data, 4, 3);
	  break;
	case tag_Ctoo: /* tool tag_TENC */
	  xml_key_value (out, "Encoder", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Ccmt: /* comment tag_COMM */
	  xml_key_value (out, "Comment", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Cgen: /* customgenre tag_TCON */
	  xml_key_value (out, "Genre", (const char *) atom->data, atom->length, 3);
	  break;
        case tag_Clyr:  /* lyrics tag_USLT */
	  xml_key_value (out, "Lyrics", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_Cgrp: /* grouping tag_TIT1 */
	  xml_key_value (out, "Grouping", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_trkn: /* tracknumber tag_TRCK */
	  if (atom->length >= 6)
	    {
	      word lo = read_u2 (atom->data + 2);
	      word hi = read_u2 (atom->data + 4);
	      char buffer[20];
	      if (hi)
		sprintf (buffer, "%u/%u", lo, hi);
	      else
		sprintf (buffer, "%u", lo);
	      xml_key_value (out, "TrackNumber", buffer, -1, 0);
	    }
	  break;
	case tag_disk: /* discnumber tag_TPOS */
	  if (atom->length >= 6)
	    {
	      word lo = read_u2 (atom->data + 2);
	      word hi = read_u2 (atom->data + 4);
	      char buffer[20];
	      if (hi)
		sprintf (buffer, "%u/%u", lo, hi);
	      else
		sprintf (buffer, "%u", lo);
	      xml_key_value (out, "DiscNumber", buffer, -1, 0);
	    }
	  break;
	case tag_gnre: /* genre tag_TCON */
	  if (atom->length >= 2)
	    {
	      int genre = read_u2 (atom->data) - 1;
	      if (genre >= 0 && genre <= 147)
		xml_key_value (out, "Genre", id3_genres[genre], -1, 0);
	    }
	  break;
	case tag_apID: /* ? tag_TOWN */
	  xml_key_value (out, "FileOwnerName", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_cprt: /* copyright tag_TCOP */
	  xml_key_value (out, "Copyright", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_aART: /* albumartist tag_? */
	  xml_key_value (out, "AlbumArtist", (const char *) atom->data, atom->length, 3);
	  break;
	case tag_cpil: /* compilation tag_TCMP */
	  if (atom->length > 0 && atom->data[0])
	    xml_key_value (out, "Compilation", "yes", -1, 0);
	  break;
	case tag_tmpo: /* tempo tag_TBPM */
	  if (atom->length >= 2)
	    {
	      word tmpo = read_u2 (atom->data);
	      char buffer[20];
	      if (tmpo)
		{
		  sprintf (buffer, "%u", tmpo);
		  xml_key_value (out, "Bpm", buffer, -1, 0);
		}
	    }
	  break;
	/* case tag_covr: // cover tag_APIC */
	/* case tag_rtng: // rating tag_? */
	}

      /* just in case */
      atom->data -= 8;
      atom->length += 8;
      return;
    }
  else if (atom->tag == tag_meta)
    {
      dp += 4; /* skip VersionAndFlags */
    }

  /* see if we happen to look at a container we're interested in */
  for (pinv = mp4_investigates; pinv->set; pinv++)
    if (pinv->parent == atom->tag)
      break;

  if (pinv->set != NULL && level < 10)
    {
      /* yep read children */
      while ((np = mp4_read_atom (&child, dp, ep)) != NULL)
	{
	  /* if it's a child we want to investigate, recurse */
	  if (mp4_set_contains (pinv->set, child.tag) == 0)
	    {
	      child.parent = atom;
	      disect_mp4 (out, &child, apos + dp - atom->data, level + 1);
	    }

	  dp = np;
	}
    }
}

/*************************/

typedef struct ogg_ctx_s
  {
    word serial;
    word seq;
    const byte *end_ptr;
  } ogg_ctx_t;


static int
ogg_check_header (ogg_ctx_t *ctx, const byte *dp)
{
  byte rev;
  byte flags;
  word serial;
  word seq;
  byte nsegs;

  if (dp + 27 >= ctx->end_ptr)
    return -1;

  /* capture_pattern */
  if (read_u4 (dp) != tag_OggS)
    return -1;
  dp += 4;

  /* stream_structure_version */
  rev = *dp++;
  if (rev != 0)
    return -1;

  /* header_type_flag */
  flags = *dp++;

  dp += 8; /* skip gpos */

  /* bitstream_serial_number - only handle 1 logical stream */
  serial = read_u4_le (dp);
  dp += 4;
  if (ctx->serial == 0)
    ctx->serial = serial;
  else if (ctx->serial != serial)
    return -1;

  /* page_sequence_number (consecutive) */
  seq = read_u4_le (dp);
  dp += 4;
  if (ctx->seq != seq)
    return -1;

  /* crc */
  dp += 4;

  /* number_page_segments */
  nsegs = *dp++;
  if (dp + nsegs >= ctx->end_ptr)
    return -1;

  return 0;
}


static void
ogg_comment_packet (stream *out, const byte *dp, const byte *ep)
{
  char *k, *v;
  char *nm;
  word numentries;
  word strlength;

  /* vendor */
  strlength = read_u4_le (dp);
  dp += 4 + strlength;

  /* user comment list */
  if (dp + 4 < ep)
    {
      numentries = read_u4_le (dp);
      dp += 4;
      while (numentries-- > 0 && dp + 4 < ep)
	{
	  strlength = read_u4_le (dp);
	  dp += 4;
	  k = v = (char *) dp;
	  dp += strlength;
	  if (dp >= ep)
	    break;
	  while (strlength-- > 0 && *v != '=')
	    v++;
	  if (*v != '=' && strlength == 0)
	    continue;
	  *v++ = 0;
	  nm = NULL;
	  if (!stricmp (k, "title")) nm = "Title"; /* tag_TIT2 */
	  else if (!stricmp (k, "artist")) nm = "Artist"; /* tag_TPE1 */
	  else if (!stricmp (k, "album")) nm = "Album"; /* tag_TALB */
	  else if (!stricmp (k, "tracknumber")) nm = "TrackNumber"; /* tag_TRCK */
	  else if (!stricmp (k, "discnumber")) nm = "DiscNumber"; /* tag_TPOS */
	  else if (!stricmp (k, "composer")) nm = "Composer"; /* tag_TCOM */
	  else if (!stricmp (k, "genre")) nm = "Genre"; /* tag_TCON */
	  else if (!stricmp (k, "date")) nm = "Year"; /* tag_TYER */
	  else if (!stricmp (k, "encoder")) nm = "EncodedBy"; /* tag_TENC */
	  else if (!stricmp (k, "grouping")) nm = "Grouping"; /* tag_TIT1 */
	  else if (!stricmp (k, "comment")) nm = "Comment"; /* tag_COMM */
	  else if (!stricmp (k, "lyrics")) nm = "Lyrics"; /* tag_USLT */
	  else if (!stricmp (k, "tempo")) nm = "Bpm"; /* tag_TBPM */
	  else if (!stricmp (k, "isrc")) nm = "ISRC"; /* tag_TSRC */
	  else if (!stricmp (k, "performer")) nm = "Conductor"; /* tag_TPE3 */
	  else if (!stricmp (k, "copyright")) nm = "Copyright"; /* tag_TCOP */
	  if (nm)
	    xml_key_value (out, nm, v, strlength, 3);
	}
    }
}


static int
ogg_packet_analyzer (stream *out, const byte *dp, size_t length)
{
  /* we're only interested in type 1 & 3 packets at the beginning
   * of the file, so this is safe */
  if (length < 8 || memcmp (dp + 1, "vorbis", 6))
    return 0;

  /* comment packet */
  if (dp[0] == 3 && length > 48)
    {
      dp += 7; /* "\003vorbis" */

      ogg_comment_packet (out, dp, dp + length);

      /* all done - do not continue */
      return 0;
    }

  return 1;
}


static int
disect_ogg (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  const byte *sp;
  int nsegs;
  int first;
  int last;
  const byte *sep;
  byte size;
  size_t thislen;
  size_t prevlen;
  size_t required;
  size_t maxlen;
  byte *npool;
  byte *pool;
  ogg_ctx_t ctx;

  memset (&ctx, 0, sizeof (ctx));
  ctx.end_ptr = dp + length;

  first = 1;
  last = 0;
  pool = NULL;
  maxlen = 0;
  prevlen = 0;

  while (!last && ogg_check_header (&ctx, dp) == 0)
    {
      ctx.seq++;

      if (first)
	{
	  /* require BOS */
	  if ((dp[5] & 2) == 0)
	    return -1;
	  first = 0;
	}

      last = (dp[5] & 4) != 0;	/* last page? */

      sp = dp + 26;		/* offset segment table */
      nsegs = *sp++;
      dp = sep = sp + nsegs;	/* at data of first packet */

      thislen = 0;
      while (sp < sep)
	{
	  size = *sp++;
	  thislen += size;
	  /* last segment in packet or last segment in table */
	  if (size < 255 || sp == sep)
	    {
	      /* append segment data to packet data, but limit to ~256k */
	      required = prevlen + thislen;
	      if (required > maxlen)
		{
		  if (required > 256000 ||
		      (npool = (byte *) realloc (pool, required)) == NULL)
		    {
		      /* exit loops */
		      last = 1;
		      break;
		    }
		  pool = npool;
		  maxlen = required;
		}
	      memcpy (pool + prevlen, dp, thislen);
	      prevlen += thislen;

	      /* if last segment in page, check if current packet continues
	       * on the next page */
	      if (last ||
		  sp < sep ||
		  ogg_check_header (&ctx, dp + thislen) == -1 ||
		  (dp[thislen + 5] & 1) == 0)
		{
		  if (ogg_packet_analyzer (out, pool, prevlen) == 0)
		    {
		      last = 1;
		      break;
		    }
		  prevlen = 0;
		}

	      dp += thislen;
	      thislen = 0;
	    }
	}
    }

  if (pool)
    free (pool);

  return 0;
}


static int
disect_flac (stream *out, const void *data, size_t length)
{
  const byte *dp = (const byte *) data;
  const byte *ep = dp + length;
  word blkhdr;
  word blklen;
  byte last;
  byte type;

  if (read_u4 (dp) != tag_fLaC)
    return -1;
  dp += 4;

  while (dp + 4 < ep)
    {
      /* METADATA_BLOCK_HEADER */
      blkhdr = read_u4 (dp);
      dp += 4;
      last = blkhdr >> 31;
      type = (blkhdr >> 24) & 0x7F;
      blklen = blkhdr & 0xFFFFFF;

      if (type == 4) /* VORBIS_COMMENT */
	ogg_comment_packet (out, dp, dp + blklen);

      /* METADATA_BLOCK_DATA */
      dp += blklen;

      if (last)
	break;
    }

  return 0;
}

/*************************/

static void
disect (stream *out, const byte *data, size_t length)
{
  mp4_atom_t atom;

  if (length < 16)
    return;

  if (mp4_read_atom (&atom, data, data + length) != NULL &&
      atom.tag == tag_ftyp)
    {
      atom.parent = NULL;
      atom.tag = tag_root;
      atom.data = data;
      atom.length = length;
      disect_mp4 (out, &atom, 0, 0);
      return;
    }

  switch (read_u4 (data))
    {
    case tag_OggS:
      disect_ogg (out, data, length);
      break;
    case tag_fLaC:
      disect_flac (out, data, length);
      break;
    case tag_ID3v22:
      disect_id3v2_2 (out, data, length);
      break;
    case tag_ID3v23:
      disect_id3v2_3 (out, data, length);
      break;
    case tag_ID3v24:
      disect_id3v2_4 (out, data, length);
      break;
    default:
      disect_id3v1 (out, data, length);
      break;
    }
}


static char *
audio_to_xml (const byte *data, size_t length, int type)
{
  stream out;

  out_init (&out, type);

  out_printf (&out, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
  if (type != 1)
    out_printf (&out, "<metadata>\n");
  disect (&out, data, length);
  if (type != 1)
    out_printf (&out, "</metadata>\n");

  return out_finish (&out);
}


caddr_t
bif_audio_to_xml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t data = bif_string_arg (qst, args, 0, "audio_to_xml");
  long length = bif_long_arg (qst, args, 1, "audio_to_xml");
  long type = bif_long_arg (qst, args, 2, "audio_to_xml");
  char *result;
  caddr_t res;

  result = audio_to_xml ((const byte *) data, length, (int) type);
  if (result)
    {
      res = box_dv_short_string (result);
      free (result);
    }
  else
    res = NEW_DB_NULL;
  return res;
}


void
bif_audio_init (void)
{
  bif_define ("audio_to_xml", bif_audio_to_xml);
}
