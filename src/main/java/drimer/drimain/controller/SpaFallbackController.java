package drimer.drimain.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * SPA fallback — zwraca index.html dla wszystkich tras frontendowych Flutter.
 * Regex [^.]* = ścieżka bez kropki → nie pasuje do plików statycznych (.js, .css, .png itp.)
 */
@Controller
public class SpaFallbackController {

    @GetMapping({
            "/{path:[^.]*}",
            "/{path:[^.]*}/{p2:[^.]*}",
            "/{path:[^.]*}/{p2:[^.]*}/{p3:[^.]*}",
            "/{path:[^.]*}/{p2:[^.]*}/{p3:[^.]*}/{p4:[^.]*}"
    })
    public String spa() {
        return "forward:/index.html";
    }
}
