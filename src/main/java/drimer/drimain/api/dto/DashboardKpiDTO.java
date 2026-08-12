package drimer.drimain.api.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@Data
public class DashboardKpiDTO {
    private long zgloszeniaDzisNowe;
    private long zgloszeniaDzisWToku;
    private long zgloszeniaDzisZamkniete;

    private long raportyDzis;
    private long raporty7Dni;

    private double sredniCzasRozwiazaniaGodziny;

    private long maszynyWPrzestoju;
    private long maszynyWPracy;
    private long maszynyRazem;

    private Map<String, Long> topTypyZgloszen = new LinkedHashMap<>();
    private Map<String, Long> zgloszeniaByStatus = new LinkedHashMap<>();
    private Map<String, Long> raportyByStatus = new LinkedHashMap<>();

    private LocalDateTime lastUpdated;
}

