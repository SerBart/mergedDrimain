package drimer.drimain.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Simple redirect controller to make Swagger UI easier to access.
 * Redirects /swagger-ui to /swagger-ui/index.html
 */
@Controller
public class RedirectSwaggerController {

    @GetMapping("/swagger-ui")
    public String redirectToSwaggerUi() {
        return "redirect:/swagger-ui/index.html";
    }
}