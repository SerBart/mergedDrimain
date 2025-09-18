package drimer.drimain.api.controller;

import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;

@RestController
@RequestMapping("/api/meta")
public class MetaController {

    @GetMapping("/statusy/raporty")
    public List<String> raportStatuses() {
        return Arrays.stream(RaportStatus.values()).map(Enum::name).toList();
    }

    @GetMapping("/statusy/zgloszenia")
    public List<String> zgloszenieStatuses() {
        return Arrays.stream(ZgloszenieStatus.values()).map(Enum::name).toList();
    }
}