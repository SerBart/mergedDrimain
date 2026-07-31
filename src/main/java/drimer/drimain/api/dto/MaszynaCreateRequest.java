package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Request DTO for creating new Maszyna (Machine).
 * Validates machine information and department assignment.
 */
@Data
@Schema(description = "Request to create a new machine")
public class MaszynaCreateRequest {
    
    @NotBlank(message = "Nazwa maszyny jest wymagana")
    @Size(min = 2, max = 255, message = "Nazwa musi zawierać od 2 do 255 znaków")
    private String nazwa;
    
    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;
    
    @Positive(message = "ID sekcji musi być dodatnie")
    private Long sekcjaId;
}