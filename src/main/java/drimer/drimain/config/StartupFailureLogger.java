package drimer.drimain.config;

import org.springframework.boot.context.event.ApplicationFailedEvent;
import org.springframework.context.ApplicationListener;

import java.io.PrintWriter;
import java.io.StringWriter;

/**
 * Logs full startup failure cause to STDOUT/STDERR even if the context fails very early.
 */
public class StartupFailureLogger implements ApplicationListener<ApplicationFailedEvent> {
    @Override
    public void onApplicationEvent(ApplicationFailedEvent event) {
        Throwable t = event.getException();
        if (t != null) {
            System.err.println("[STARTUP-ERROR] Application failed to start. Dumping root cause:");
            Throwable root = t;
            while (root.getCause() != null) root = root.getCause();
            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            root.printStackTrace(pw);
            pw.flush();
            System.err.println(sw.toString());
            System.err.flush();
        } else {
            System.err.println("[STARTUP-ERROR] Application failed to start (no exception available)");
        }
    }
}

