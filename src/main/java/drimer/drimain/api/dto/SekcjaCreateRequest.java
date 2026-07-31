package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Request DTO for creating new Sekcja (Section).
 * Validates section information and department assignment.
 */
@Data
@Schema(description = "Request to create a new section")
public class SekcjaCreateRequest {
    
    @NotBlank(message = "Nazwa sekcji jest wymagana")
    @Size(min = 2, max = 255, message = "Nazwa musi zawierać od 2 do 255 znaków")
    private String nazwa;

    @NotNull(message = "ID działu jest wymagane")
    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;
}

