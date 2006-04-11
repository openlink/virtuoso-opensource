/*
 * @(#) rnd.h 12.1.1.3@(#)
 * 
 * rnd.h -- header file for use withthe portable random number generator
 * provided by Frank Stephens of Unisys
 */

/* function protypes */
long            NextRand(long);
long            UnifInt(long, long, long);
double          UnifReal(double, double, long);
double          Exponential(double, long);

static long     nA = 16807;     /* the multiplier */
static long     nM = 2147483647;/* the modulus == 2^31 - 1 */
static long     nQ = 127773;    /* the quotient nM / nA */
static long     nR = 2836;      /* the remainder nM % nA */

static double   dM = 2147483647.0;

/*
 * macros to control RNG and assure reproducible multi-stream
 * runs without the need for seed files. Keep track of invocations of RNG
 * and always round-up to a known per-row boundary.
 */
/* 
 * preferred solution, but not initializing correctly
 */
#define VSTR_MAX(len)	(long)(len / 5 + (len % 5 == 0)?0:1 + 1)
#define	MAX_STREAM	3
seed_t	Seed[MAX_STREAM] =
{
    {AUTHOR, 1,          0,	1},					/* I_TITLE_SD	0 */
    {AUTHOR, 46831694,   0, 1},					/* A_LNAME_SD	1 */
    {AUTHOR, 1841581359, 0, 1}					/* A_BIO_SD		2 */
};
/*
 * UNUSED SEED VALUES
 *
    {NONE,   1193163244, 0, 1},					
    {NONE,   727633698,  0, 1},					
    {NONE,   933588178,  0, 1},					
    {NONE,   804159733,  0, 0},	
    {NONE,  1671059989, 0, 0},     
    {NONE,  1051288424, 0, 0},     
    {NONE,  1961692154, 0, 0},     
    {NONE,  1227283347, 0, 1},				    
    {NONE,  1171034773, 0, 1},					
    {NONE,  276090261,  0, 0},  
	{NONE,  1066728069, 0, 1},					
    {NONE,   209208115,  0, 0},        
    {NONE,   554590007,  0, 0},        
    {NONE,   721958466,  0, 0},        
    {NONE,   1371272478, 0, 0},        
    {NONE,   675466456,  0, 0},        
    {NONE,   1808217256, 0, 0},      
    {NONE,   2095021727, 0, 0},      
    {NONE,   1769349045, 0, 0},      
    {NONE,   904914315,  0, 0},      
    {NONE,   373135028,  0, 0},      
    {NONE,   717419739,  0, 0},      
    {NONE,   1095462486, 0, 0},   
    {NONE,   881155353,  0, 9},      
    {NONE,   1489529863, 0, 1},      
    {NONE,   1521138112, 0, 3},      
    {NONE,   298370230,  0, 1},      
    {NONE,   1140279430, 0, 1},      
    {NONE,   1335826707, 0, 0},     
    {NONE,   706178559,  0, 9},      
    {NONE,   110356601,  0, 1},      
    {NONE,   884434366,  0, 3},      
    {NONE,   962338209,  0, 1},      
    {NONE,   1341315363, 0, 0},     
    {NONE,   709314158,  0, 92},      
    {NONE,  591449447,  0, 1},      
    {NONE,   431918286,  0, 1},      
    {NONE,  851767375,  0, 1},      
    {NONE, 606179079,  0, 0},      
    {NONE, 1500869201, 0, 0},      
    {NONE,  1434868289, 0, 1},      
    {NONE,   263032577,  0, 1},      
    {NONE,   753643799,  0, 1},      
    {NONE,   202794285,  0, 1},      
    {NONE,   715851524,  0, 1}       

*	END OF UNUSED VALUES
*
*/
