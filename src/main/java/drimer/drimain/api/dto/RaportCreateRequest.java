package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDate;
import java.util.List;

/**
 * Request DTO for creating new Raport (Report).
 * Validates repair information and associated parts usage.
 */
@Data
@Schema(description = "Request to create a new repair report")
public class RaportCreateRequest {
    
    @NotNull(message = "ID maszyny jest wymagane")
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
    
    @NotBlank(message = "Typ naprawy jest wymagany")
    @Size(min = 3, max = 100, message = "Typ naprawy musi zawierać od 3 do 100 znaków")
    private String typNaprawy;
    
    @NotBlank(message = "Opis naprawy jest wymagany")
    @Size(min = 10, max = 2000, message = "Opis musi zawierać od 10 do 2000 znaków")
    private String opis;
    
    @NotNull(message = "ID osoby jest wymagane")
    @Positive(message = "ID osoby musi być dodatnie")
    private Long osobaId;
    
    @NotBlank(message = "Status jest wymagany")
    @Size(min = 2, max = 50, message = "Status musi zawierać od 2 do 50 znaków")
    private String status;
    
    @NotNull(message = "Data naprawy jest wymagana")
    @PastOrPresent(message = "Data naprawy nie może być w przyszłości")
    private LocalDate dataNaprawy;
    
    @NotBlank(message = "Czas od jest wymagany")
    @Pattern(regexp = "^([0-1][0-9]|2[0-3]):[0-5][0-9]$", message = "Czas musi być w formacie HH:mm")
    private String czasOd;
    
    @NotBlank(message = "Czas do jest wymagany")
    @Pattern(regexp = "^([0-1][0-9]|2[0-3]):[0-5][0-9]$", message = "Czas musi być w formacie HH:mm")
    private String czasDo;
    
    @Valid
    private List<PartUsageDTO> partUsages;
}