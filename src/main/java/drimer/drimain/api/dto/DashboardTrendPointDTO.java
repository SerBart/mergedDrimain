package drimer.drimain.api.dto;

import lombok.Data;

import java.time.LocalDate;

@Data
public class DashboardTrendPointDTO {
    private LocalDate date;
    private long count;
}

