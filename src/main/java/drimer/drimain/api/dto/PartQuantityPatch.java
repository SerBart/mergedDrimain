package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * PATCH DTO for updating part quantity.
 * Allows incrementing or decrementing quantity by delta.
 */
@Data
@Schema(description = "Request to update part quantity by delta")
public class PartQuantityPatch {
    
    @NotNull(message = "Delta (zmiana ilości) jest wymagana")
    private Integer delta;
}