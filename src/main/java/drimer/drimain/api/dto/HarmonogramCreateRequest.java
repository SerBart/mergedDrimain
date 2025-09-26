package drimer.drimain.api.dto;

import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.model.enums.HarmonogramOkres;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class HarmonogramCreateRequest {
    @NotNull
    private LocalDate data;
    
    private String opis;
    
    private Long maszynaId;
    
    private Long osobaId;
    
    private Long dzialId;

    private HarmonogramOkres frequency;

    private StatusHarmonogramu status;

    private Integer durationMinutes;
}