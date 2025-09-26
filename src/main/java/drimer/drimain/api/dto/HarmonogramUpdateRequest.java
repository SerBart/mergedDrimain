package drimer.drimain.api.dto;

import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.model.enums.HarmonogramOkres;
import lombok.Data;

import java.time.LocalDate;

@Data
public class HarmonogramUpdateRequest {
    private LocalDate data;
    private String opis;
    private Long maszynaId;
    private Long osobaId;
    private StatusHarmonogramu status;
    private Integer durationMinutes;
    private Long dzialId;
    private HarmonogramOkres frequency;
}