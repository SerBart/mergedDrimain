package drimer.drimain.api.dto;

import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.model.enums.HarmonogramOkres;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDate;

/**
 * Request DTO for creating new Harmonogram (Schedule).
 * Validates schedule information including date and duration.
 */
@Data
@Schema(description = "Request to create a new schedule")
public class HarmonogramCreateRequest {
    
    @NotNull(message = "Data jest wymagana")
    @FutureOrPresent(message = "Data nie może być w przeszłości")
    private LocalDate data;
    
    @Size(max = 1000, message = "Opis nie może przekraczać 1000 znaków")
    private String opis;
    
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
    
    @Positive(message = "ID osoby musi być dodatnie")
    private Long osobaId;
    
    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;

    private HarmonogramOkres frequency;

    private StatusHarmonogramu status;

    @Positive(message = "Czas trwania musi być dodatni")
    @Max(value = 1440, message = "Czas trwania nie może przekraczać 1440 minut (24 godziny)")
    private Integer durationMinutes;
}