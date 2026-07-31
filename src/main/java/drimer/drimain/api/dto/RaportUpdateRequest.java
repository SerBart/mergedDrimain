package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDate;
import java.util.List;

/**
 * Request DTO for updating Raport (Report).
 * Allows partial updates with optional fields.
 */
@Data
@Schema(description = "Request to update an existing repair report")
public class RaportUpdateRequest {
    
    @Size(min = 3, max = 100, message = "Typ naprawy musi zawierać od 3 do 100 znaków")
    private String typNaprawy;
    
    @Size(min = 10, max = 2000, message = "Opis musi zawierać od 10 do 2000 znaków")
    private String opis;
    
    @Size(min = 2, max = 50, message = "Status musi zawierać od 2 do 50 znaków")
    private String status;
    
    @PastOrPresent(message = "Data naprawy nie może być w przyszłości")
    private LocalDate dataNaprawy;
    
    @Pattern(regexp = "^([0-1][0-9]|2[0-3]):[0-5][0-9]$", message = "Czas musi być w formacie HH:mm")
    private String czasOd;
    
    @Pattern(regexp = "^([0-1][0-9]|2[0-3]):[0-5][0-9]$", message = "Czas musi być w formacie HH:mm")
    private String czasDo;
    
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
    
    @Positive(message = "ID osoby musi być dodatnie")
    private Long osobaId;
    
    @Valid
    private List<PartUsageDTO> partUsages;
}