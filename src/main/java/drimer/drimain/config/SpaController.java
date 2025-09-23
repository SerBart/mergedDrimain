package drimer.drimain.config;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
public class SpaController {
    // Forward all non-API routes to index.html so Flutter SPA works on refresh/deep link
    @RequestMapping(value = {
            "/", "/raporty", "/raporty/**",
            "/harmonogramy", "/harmonogramy/**",
            "/przeglady", "/przeglady/**",
            "/login"
    })
    public String forward() {
        return "forward:/index.html";
    }
}