package drimer.drimain;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration;

@SpringBootApplication
public class DriMainApplication {
	public static void main(String[] args) {
		SpringApplication.run(DriMainApplication.class, args);
	}
}
