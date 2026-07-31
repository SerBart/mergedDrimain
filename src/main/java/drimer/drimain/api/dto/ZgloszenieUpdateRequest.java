package drimer.drimain.api.dto;

import drimer.drimain.model.enums.ZgloszeniePriorytet;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;

/**
 * Request DTO for updating Zgloszenie (Issue).
 * Allows partial updates with optional fields and validation.
 */
@Data
@Schema(description = "Request to update an existing issue/zgloszenie")
public class ZgloszenieUpdateRequest {
    
    @Size(min = 2, max = 50, message = "Typ musi zawierać od 2 do 50 znaków")
    private String typ;
    
    @Size(min = 2, max = 100, message = "Imię musi zawierać od 2 do 100 znaków")
    private String imie;
    
    @Size(min = 2, max = 100, message = "Nazwisko musi zawierać od 2 do 100 znaków")
    private String nazwisko;
    
    @Size(min = 5, max = 255, message = "Tytuł musi zawierać od 5 do 255 znaków")
    private String tytul;
    
    @Size(min = 2, max = 50, message = "Status musi zawierać od 2 do 50 znaków")
    private String status;
    
    private ZgloszeniePriorytet priorytet;
    
    @Size(min = 10, max = 2000, message = "Opis musi zawierać od 10 do 2000 znaków")
    private String opis;
    
    @Positive(message = "ID działu musi być dodatnie")
    private Long dzialId;
    
    @Positive(message = "ID autora musi być dodatnie")
    private Long autorId;
    
    @Pattern(regexp = "^(?i)data:image/(png|jpeg|jpg|gif);base64,[A-Za-z0-9+/=]*$", 
             message = "Zdjęcie musi być w formacie base64 (PNG, JPEG, GIF)")
    private String photoBase64;
    
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
    
    @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?Z?$", 
             message = "Data musi być w formacie ISO-8601")
    private String acceptedAt;
    
    @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?Z?$", 
             message = "Data musi być w formacie ISO-8601")
    private String completedAt;
}