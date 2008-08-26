package benchmark.tools;

import java.util.Locale;

public class TestTimeSlicing {
	static int thread;
	static Long time;
	public static void main( String args [] ) {
		time = System.nanoTime();
        new MyThread(1).start(); 
        new MyThread(2).start(); 
        new MyThread(3).start(); 
        new MyThread(4).start(); 
    }
	
	public static synchronized void doThis(int nr) {
		if(nr!=thread) {
			thread = nr;
			Long newTime = System.nanoTime();
			time = newTime;
			System.out.println("Thread " + nr + ": " + String.format(Locale.US, "%.6f",time/1000000000.0) + "s");;
		}
	}
} 
 
class MyThread extends Thread { 
    int nr; 
 
    MyThread ( int nr ) { 
        this.nr = nr; 
    } 
 
    public void run() { 
        while ( true ) {
        	TestTimeSlicing.doThis(nr);
        	yield();
        }
    } 
} 