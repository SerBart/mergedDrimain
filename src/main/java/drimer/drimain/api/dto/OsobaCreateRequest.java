package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;

/**
 * Request DTO for creating new Osoba (Person).
 * Validates person information and optional login credentials.
 */
@Data
@Schema(description = "Request to create a new person/employee")
public class OsobaCreateRequest {
    
    @Size(min = 3, max = 50, message = "Login musi zawierać od 3 do 50 znaków")
    @Pattern(regexp = "^[a-zA-Z0-9._-]*$", message = "Login może zawierać tylko litery, cyfry, kropki, myślniki i podkreślenia")
    private String login;
    
    @Size(min = 8, max = 255, message = "Hasło musi zawierać od 8 do 255 znaków")
    private String haslo;

    @NotBlank(message = "Imię i nazwisko są wymagane")
    @Size(min = 3, max = 255, message = "Imię i nazwisko muszą zawierać od 3 do 255 znaków")
    private String imieNazwisko;

    @Size(max = 50, message = "Rola nie może przekraczać 50 znaków")
    private String rola;

    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;
}