package drimer.drimain.api.dto;

import drimer.drimain.model.enums.StatusHarmonogramu;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class HarmonogramCreateRequest {
    @NotNull
    private LocalDate data;
    
    private String opis;
    
    @NotNull
    private Long maszynaId;
    
    @NotNull
    private Long osobaId;
    
    private StatusHarmonogramu status;
}