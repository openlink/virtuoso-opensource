 
#include "cdjpeg.h"		/* Common decls for cjpeg/djpeg applications */ 
#include "jversion.h"		/* for version message */ 
#include <math.h> 
#include <time.h> 
#include "../gd-1.7.2/gd.h" 
#include "../gd-1.7.2/gdfontg.h" 
 
void jpgImageChar(gdFontPtr f, int x, int y, int c, int color); 
void jpgImageString(gdFontPtr f, int x, int y, unsigned char *s, int color); 
 
// This is a hack exposing image data 
unsigned char **rows;  
int dim; 
 
int main (int argc, char **argv) 
{ 
	struct jpeg_compress_struct cinfo; 
	struct jpeg_error_mgr jerr; 
	int k, i, j; 
	FILE * outfile; 
 
	// To calculate random location 
	int xdelta, ydelta; 
	int xspace, yspace; 
	int xloc, yloc; 
 
	 
	if(argc != 3) { 
		printf("Usage: %s <size of image in k> <image name>.jpg\n", argv[0]); 
		exit(0); 
	} 
	 
	k = atoi(argv[1]); 
	if(k<0) 
		k=1; 
	 
	/* Create output image. */ 
	dim = (int)sqrt( ((k*1024)-1130)/2 ); 
	printf("size ~= %d bytes, dimension = %d\n", k*1024, dim); 
 
	rows = malloc(sizeof(char*)*dim); 
	if(rows == NULL) { 
		printf("Error... Not enough memory...\n"); 
		exit(1); 
	} 
 
	for(i=0; i<dim; i++) { 
		rows[i] = malloc(dim*3*sizeof(char)); 
		if(rows[i] == NULL) { 
			printf("Error... Not enough memory...\n"); 
			exit(1); 
		} 
	} 
	//row_pointer = malloc(dim*3*sizeof(char)); 
 
	/* Initialize the JPEG compression object with default error handling. */ 
	cinfo.err = jpeg_std_error(&jerr); 
	jpeg_create_compress(&cinfo); 
	 
	/* Specify data destination for compression */ 
	if((outfile = fopen(argv[2], "wb")) == NULL) { 
		printf("Can't open file...\n"); 
		exit(1); 
	} 
	jpeg_stdio_dest(&cinfo, outfile); 
	 
	/* Initialize JPEG parameters. 
	* Much of this may be overridden later. 
	* In particular, we don't yet know the input file's color space, 
	* but we need to provide some value for jpeg_set_defaults() to work. 
	*/ 
	 
	cinfo.in_color_space = JCS_RGB; /* arbitrary guess */ 
	//cinfo.out_color_space = JCS_RGB; 
	cinfo.image_width = dim; 
	cinfo.image_height = dim; 
	cinfo.input_components = 3; 
	jpeg_set_defaults(&cinfo); 
	jpeg_set_quality(&cinfo, 100, TRUE); 
    srand( (unsigned)time( NULL ) ); 
 
 
	/* Start compressor */ 
	jpeg_start_compress(&cinfo, TRUE); 
	 
	/* Generate data */ 
	 
	for(j=0; j<dim; j++) { 
		int position; 
		for(i=0; i<dim; i++) { 
			position = i * 3; 
			rows[j][position] = (char)rand()%256; 
			rows[j][position+1] = (char)rand()%256; 
			rows[j][position+2] = (char)rand()%256; 
		} 
	} 
 
	// Figure out random locaiton 
	xspace = dim - strlen(argv[2]) * gdFontGiant->w; 
	yspace = dim - gdFontGiant->h; 
	xloc = rand()%xspace; 
	yloc = rand()%yspace; 
 
	jpgImageString(gdFontGiant, xloc, yloc, (unsigned char *)argv[2], 255); 
 
	xloc = rand()%xspace; 
	yloc = rand()%yspace; 
	jpgImageString(gdFontGiant, xloc, yloc, (unsigned char *)argv[2], 0); 
 
	/* Write to jpeg */ 
	while (cinfo.next_scanline < cinfo.image_height) { 
		(void) jpeg_write_scanlines(&cinfo, &rows[cinfo.next_scanline], 1); 
	} 
 
 
	/* Finish compression and release memory */ 
	jpeg_finish_compress(&cinfo); 
	jpeg_destroy_compress(&cinfo); 
	 
	if (outfile != stdout) 
		fclose(outfile); 
	 
	/* All done. */ 
	exit(jerr.num_warnings ? EXIT_WARNING : EXIT_SUCCESS); 
	return 0;			/* suppress no-return-value warnings */ 
} 
 
// Copied from GD for font support 
 
void jpgImageChar(gdFontPtr f, int x, int y, int c, int color) 
{ 
	int cx, cy; 
	int px, py; 
	int fline; 
	cx = 0; 
	cy = 0; 
	if ((c < f->offset) || (c >= (f->offset + f->nchars))) { 
		return; 
	} 
	fline = (c - f->offset) * f->h * f->w; 
	for (py = y; (py < (y + f->h)); py++) { 
		for (px = x; (px < (x + f->w)); px++) { 
			if (py>=dim || px>=dim) 
				break; 
			if (f->data[fline + cy * f->w + cx]) { 
				rows[py][px*3] = (unsigned char)color; 
				rows[py][px*3+1] = (unsigned char)color; 
				rows[py][px*3+2] = (unsigned char)color; 
			} 
			cx++; 
		} 
		cx = 0; 
		cy++; 
	} 
} 
 
void jpgImageString(gdFontPtr f, int x, int y, unsigned char *s, int color) 
{ 
	int i; 
	int l; 
	l = strlen((char *)s); 
	for (i=0; (i<l); i++) { 
		jpgImageChar(f, x, y, s[i], color); 
		x += f->w; 
	} 
}
