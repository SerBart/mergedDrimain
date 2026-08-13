package drimer.drimain.api.dto;

import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Data
public class DashboardKpiDTO {
    private int zakresDni;
    private LocalDate okresOd;
    private LocalDate okresDo;

    private long zgloszeniaWOkresieNowe;
    private long zgloszeniaWOkresieWToku;
    private long zgloszeniaWOkresieZamkniete;

    private long raportyWOkresie;
    private long zgloszeniaWPoprzednimOkresie;
    private long raportyWPoprzednimOkresie;
    private double zgloszeniaZmianaProcent;
    private double raportyZmianaProcent;

    private List<DashboardTrendPointDTO> zgloszeniaTrend = new ArrayList<>();
    private List<DashboardTrendPointDTO> raportyTrend = new ArrayList<>();

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

