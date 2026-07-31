package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.util.Set;

/**
 * Request DTO for creating new user.
 * Enforces strong password requirements and validates all required fields.
 */
@Data
@Schema(description = "Request to create a new user account")
public class UserCreateRequest {
    
    @NotBlank(message = "Nazwa użytkownika jest wymagana")
    @Size(min = 3, max = 50, message = "Nazwa użytkownika musi zawierać od 3 do 50 znaków")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", message = "Nazwa użytkownika może zawierać tylko litery, cyfry, kropki, myślniki i podkreślenia")
    private String username;
    
    @NotBlank(message = "Hasło jest wymagane")
    @Size(min = 8, max = 255, message = "Hasło musi zawierać co najmniej 8 znaków")
    @Pattern(regexp = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]*$",
            message = "Hasło musi zawierać co najmniej jedną dużą literę, małą literę, cyfrę i znak specjalny (@$!%*?&)")
    private String password;

    @NotBlank(message = "Email jest wymagany")
    @Email(message = "Email musi być prawidłowym adresem email",
            regexp = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
    private String email;

    private Set<String> roles;

    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;

    private Set<String> modules;
}