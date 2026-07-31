package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Request DTO for user authentication (login).
 * Validates username and password credentials.
 */
@Data
@Schema(description = "Request for user authentication")
public class AuthRequest {
    
    @NotBlank(message = "Nazwa użytkownika jest wymagana")
    @Size(min = 3, max = 50, message = "Nazwa użytkownika musi zawierać od 3 do 50 znaków")
    private String username;
    
    @NotBlank(message = "Hasło jest wymagane")
    @Size(min = 6, max = 255, message = "Hasło musi zawierać od 6 do 255 znaków")
    private String password;
}