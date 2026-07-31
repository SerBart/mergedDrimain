package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * Request DTO for token refresh.
 * Validates refresh token.
 */
@Data
@Schema(description = "Request to refresh authentication token")
public class RefreshRequest {
    
    @NotBlank(message = "Refresh token jest wymagany")
    private String refreshToken;
}