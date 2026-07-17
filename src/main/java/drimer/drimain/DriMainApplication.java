package drimer.drimain;

import drimer.drimain.config.StartupFailureLogger;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DriMainApplication {
	public static void main(String[] args) {
		SpringApplication app = new SpringApplication(DriMainApplication.class);
		app.addListeners(new StartupFailureLogger());
		app.run(args);
	}
}
