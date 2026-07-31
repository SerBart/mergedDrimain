package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;

/**
 * Request DTO for creating new Part (Część).
 * Validates part information including quantity constraints.
 */
@Data
@Schema(description = "Request to create a new part/piece")
public class PartCreateRequest {
    
    @NotBlank(message = "Nazwa części jest wymagana")
    @Size(min = 2, max = 255, message = "Nazwa musi zawierać od 2 do 255 znaków")
    private String nazwa;
    
    @NotBlank(message = "Kod części jest wymagany")
    @Size(min = 2, max = 100, message = "Kod musi zawierać od 2 do 100 znaków")
    @Pattern(regexp = "^[A-Z0-9\\-_]+$", message = "Kod może zawierać tylko duże litery, cyfry, myślniki i podkreślenia")
    private String kod;
    
    @NotBlank(message = "Kategoria części jest wymagana")
    @Size(min = 2, max = 100, message = "Kategoria musi zawierać od 2 do 100 znaków")
    private String kategoria;
    
    @NotNull(message = "Ilość jest wymagana")
    @Min(value = 0, message = "Ilość nie może być ujemna")
    @Max(value = 999999, message = "Ilość nie może przekraczać 999999")
    private Integer ilosc;
    
    @NotNull(message = "Minimalna ilość jest wymagana")
    @Min(value = 0, message = "Minimalna ilość nie może być ujemna")
    @Max(value = 999999, message = "Minimalna ilość nie może przekraczać 999999")
    private Integer minIlosc;
    
    @NotBlank(message = "Jednostka miary jest wymagana")
    @Size(min = 1, max = 50, message = "Jednostka musi zawierać od 1 do 50 znaków")
    private String jednostka;
}