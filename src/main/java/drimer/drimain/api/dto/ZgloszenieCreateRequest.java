package drimer.drimain.api.dto;

import drimer.drimain.model.enums.ZgloszeniePriorytet;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * Request DTO for creating new Zgloszenie (Issue).
 * Validates all required fields to prevent invalid data entry.
 */
@Data
@Schema(description = "Request to create a new issue/zgloszenie")
public class ZgloszenieCreateRequest {
    
    @NotBlank(message = "Typ zgłoszenia jest wymagany")
    @Size(min = 2, max = 50, message = "Typ musi zawierać od 2 do 50 znaków")
    private String typ;
    
    @NotBlank(message = "Imię jest wymagane")
    @Size(min = 2, max = 100, message = "Imię musi zawierać od 2 do 100 znaków")
    private String imie;
    
    @NotBlank(message = "Nazwisko jest wymagane")
    @Size(min = 2, max = 100, message = "Nazwisko musi zawierać od 2 do 100 znaków")
    private String nazwisko;
    
    @NotBlank(message = "Tytuł zgłoszenia jest wymagany")
    @Size(min = 5, max = 255, message = "Tytuł musi zawierać od 5 do 255 znaków")
    private String tytul;
    
    @NotBlank(message = "Status jest wymagany")
    @Size(min = 2, max = 50, message = "Status musi zawierać od 2 do 50 znaków")
    private String status;
    
    @NotNull(message = "Priorytet jest wymagany")
    private ZgloszeniePriorytet priorytet = ZgloszeniePriorytet.NORMALNY;
    
    @NotBlank(message = "Opis zgłoszenia jest wymagany")
    @Size(min = 10, max = 2000, message = "Opis musi zawierać od 10 do 2000 znaków")
    private String opis;
    
    @NotNull(message = "Data i godzina są wymagane")
    private LocalDateTime dataGodzina;
    
    @NotNull(message = "ID działu jest wymagane")
    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;
    
    @Positive(message = "ID sekcji musi być dodatnie")
    private Long sekcjaId;
    
    private Long autorId;
    
    @Pattern(regexp = "^(?i)data:image/(png|jpeg|jpg|gif);base64,[A-Za-z0-9+/=]*$", 
             message = "Zdjęcie musi być w formacie base64 (PNG, JPEG, GIF)")
    private String photoBase64;
    
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
}