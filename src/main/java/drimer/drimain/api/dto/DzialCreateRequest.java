package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Request DTO for creating new Dzial (Department).
 * Validates department name.
 */
@Data
@Schema(description = "Request to create a new department")
public class DzialCreateRequest {
    
    @NotBlank(message = "Nazwa działu jest wymagana")
    @Size(min = 2, max = 255, message = "Nazwa musi zawierać od 2 do 255 znaków")
    private String nazwa;
}