package benchmark.tools;

import java.util.Locale;

public class TestTimeSlicing {
	static int thread;
	static Long time;
	public static void main( String args [] ) {
		time = System.nanoTime();
		MyThread t = new MyThread(1);
        t.setPriority(1);
        t.start();
        MyThread t2 = new MyThread(2);
        t2.setPriority(1);
        t2.start();
        MyThread t3 = new MyThread(3);
        t3.setPriority(10);
        t3.start();
    }

	public static synchronized void doThis(int nr, MyThread t) {
		if(nr!=thread) {
			thread = nr;
			Long newTime = System.nanoTime();
			time = newTime;
			System.out.println("Thread " + nr + ": " + String.format(Locale.US, "%.6f",time/1000000000.0) + "s " + t.getPriority());
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
        	TestTimeSlicing.doThis(nr, this);
//        	yield();
        }
    }
} 