#include <stdio.h>
#include <stdlib.h> 
#include <string.h>

typedef unsigned int uint;
typedef unsigned char byte;
typedef int bool;

#define true 1
#define false 0
#define null 0
#define TABSIZE 4

#define CRLF  0
#define UNIX  1
#define MAC   2

typedef struct
{
    bool pushed;
    int tabs;
    int curcol;
    int lastcol;
    int maxcol;
    int curline;
    int pushed_char;
    uint size;
    uint length;
    char *buf;
    FILE *fp;
} Stream;

int tabsize = TABSIZE;
int endline = CRLF;
bool tabs = false;

/*
 Memory allocation functions vary from one environment to
 the next, and experience shows that wrapping the local
 mechanisms up provides for greater flexibility and allows
 out of memory conditions to be detected in one place.
*/
void *MemAlloc(unsigned int size)
{
    void *p;

    p = malloc(size);

    if (!p)
    {
        fprintf(stderr, "***** Out of memory! *****\n");
        exit(1);
    }

    return p;
}

void *MemRealloc(void *old, unsigned int size)
{
    void *p;

    p = realloc(old, size);

    if (!p)
    {
        fprintf(stderr, "***** Out of memory! *****\n");
        return NULL;
    }

    return p;
}

void MemFree(void *p)
{
    free(p);
    p = null;
}

Stream *NewStream(FILE *fp)
{
    Stream *in;

    in = (Stream *)MemAlloc(sizeof(Stream));
    memset(in, 0, sizeof(Stream));
    in->fp = fp;
    return in;
}

void FreeStream(Stream *in)
{
    if (in->buf)
        MemFree(in->buf);

    MemFree(in);
}

void AddByte(Stream *in, uint c)
{
    if (in->size + 1 >= in->length)
    {
        while (in->size + 1 >= in->length)
        {
            if (in->length == 0)
                in->length = 8192;
            else
                in->length = in->length * 2;
        }

        in->buf = (char *)MemRealloc(in->buf, in->length*sizeof(char));
    }

    in->buf[in->size++] = (char)c;
    in->buf[in->size] = '\0';  /* debug */
}



/*
  Read a character from a stream, keeping track
  of lines, columns etc. This is used for parsing
  markup and plain text etc. A single level
  pushback is allowed with UngetChar(c, in).
  Returns EndOfStream if there's nothing more to read.
*/
int ReadChar(Stream *in)
{
    uint c;

    if (in->pushed)
    {
        in->pushed = false;

        if (in->pushed_char == '\n')
            in->curline--;

        return in->pushed_char;
    }

    in->lastcol = in->curcol;

    /* expanding tab ? */
    if (in->tabs > 0)
    {
        in->curcol++;
        in->tabs--;
        return ' ';
    }
    
    /* Else go on with normal buffer: */
    for (;;)
    {
        c = getc(in->fp);

        /* end of file? */
        if (c == EOF)
            break;

        /* coerce \r\n  and isolated \r as equivalent to \n : */
        if (c == '\r')
        {
            c = getc(in->fp);

            if (c != '\n')
                ungetc(c, in->fp);

            c = '\n';
        }

        if (c == '\n')
        {
            if (in->maxcol < in->curcol)
                in->maxcol = in->curcol;

            in->curcol = 1;
            in->curline++;
            break;
        }

        if (c == '\t')
        {
            if (tabs)
              in->curcol += tabsize - ((in->curcol - 1) % tabsize);
            else /* expand to spaces */
            {
                in->tabs = tabsize - ((in->curcol - 1) % tabsize) - 1;
                in->curcol++;
                c = ' ';
            }

            break;
        }

        if (c == '\033')
            break;

        /* strip control characters including '\r' */

        if (0 < c && c < 32)
            continue;

        in->curcol++;
        break;
    }

    return c;
}

Stream  *ReadFile(FILE *fin)
{
    int c;
    Stream *in  = NewStream(fin);

    while ((c = ReadChar(in)) >= 0)
        AddByte(in, (uint)c);

    return in;
}

void WriteFile(Stream *in, FILE *fout)
{
    int i, c;
    char *p;

    i = in->size;
    p = in->buf;

    while (i--)
    {
        c = *p++;

        if (c == '\n')
        {
            if (endline == CRLF)
            {
                putc('\r', fout);
                putc('\n', fout);
            }
            else if (endline == UNIX)
                putc('\n', fout);
            else /* Macs which use CR */
                putc('\r', fout);

            continue;
        }

        putc(c, fout);
    }
}

void HelpText(FILE *errout, char *prog)
{
    fprintf(errout, "%s: file1 file2 ...\n", prog);
    fprintf(errout, "Utility to expand tabs and ensure consistent line ends\n");
    fprintf(errout, "options for tab2space vers: 14th December 1998\n");
    fprintf(errout, "  -t8             set tabs to 8 (default is 4)\n");
    fprintf(errout, "  -crlf           set line ends to CRLF (default)\n");
    fprintf(errout, "  -unix or -lf    set line ends to LF (Unix)\n");
    fprintf(errout, "  -cr             set line ends to CR (Macs)\n");
    fprintf(errout, "  -tabs           preserve tabs, e.g. for Makefile\n");
    fprintf(errout, "  -help or -h     display this hekp message\n");
    fprintf(errout, "\nNote this utility doesn't map spaces to tabs!\n");
}

int main(int argc, char **argv)
{
    char *file, *prog;
    FILE *fin, *fout;
    Stream *in;

    prog = argv[0];

    while (argc > 0)
    {
        if (argc > 1 && argv[1][0] == '-')
        {
            if (strcmp(argv[1], "-help") == 0 || argv[1][1] == 'h')
            {
                HelpText(stdout, prog);
                return 1;
            }

            if (strcmp(argv[1], "-t") == 0)
            {
                sscanf(argv[1]+2, "%d", &tabsize);
                --argc;
                ++argv;
                continue;
            }

            if (strcmp(argv[1], "-unix") == 0 ||
                strcmp(argv[1], "-lf") == 0)
            {
                endline = UNIX;
                --argc;
                ++argv;
                continue;
            }

            if (strcmp(argv[1], "-crlf") == 0)
            {
                endline = CRLF;
                --argc;
                ++argv;
                continue;
            }

            if (strcmp(argv[1], "-cf") == 0)
            {
                endline = MAC;
                --argc;
                ++argv;
                continue;
            }

            if (strcmp(argv[1], "-tabs") == 0)
            {
                tabs = true;
                --argc;
                ++argv;
                continue;
            }

            --argc;
            ++argv;
            continue;
        }

        if (argc > 1)
        {
            file = argv[1];
            fin = fopen(file, "rb");
        }
        else
        {
            fin = stdin;
            file = "stdin";
        }

        if (fin != null)
        {
            in = ReadFile(fin);

            if (fin != stdin)
                fclose(fin);

            if (argc > 0)
            {
                file = argv[1];
                fout = fopen(file, "wb");
            }
            else
            {
                fout = stdin;
                file = "stdin";
            }

            if (fout)
            {
                WriteFile(in, fout);
                fclose(fout);
            }
            else
                fprintf(stderr, "%s - can't open \"%s\" for writing\n", prog, file);

            FreeStream(in);

        }
        else
            fprintf(stderr, "%s - can't open \"%s\" for reading\n", prog, file);

        --argc;
        ++argv;

        if (argc <= 1)
            break;
    }

    return 0;
}

