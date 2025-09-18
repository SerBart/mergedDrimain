package drimer.drimain.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class RedirectSwaggerController {

    /**
     * NOTE: Redirect from /swagger-ui to the full Swagger UI path
     */
    @GetMapping("/swagger-ui")
    public String redirectToSwaggerUi() {
        return "redirect:/swagger-ui/index.html";
    }
}