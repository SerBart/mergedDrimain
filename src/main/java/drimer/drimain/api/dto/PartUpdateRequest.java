package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Request DTO for updating Part (Część).
 * Allows partial updates with optional fields.
 */
@Data
@Schema(description = "Request to update an existing part")
public class PartUpdateRequest {
    
    @Size(min = 2, max = 255, message = "Nazwa musi zawierać od 2 do 255 znaków")
    private String nazwa;
    
    @Size(min = 2, max = 100, message = "Kod musi zawierać od 2 do 100 znaków")
    @Pattern(regexp = "^[A-Z0-9\\-_]*$", message = "Kod może zawierać tylko duże litery, cyfry, myślniki i podkreślenia")
    private String kod;
    
    @Size(min = 2, max = 100, message = "Kategoria musi zawierać od 2 do 100 znaków")
    private String kategoria;
    
    @Min(value = 0, message = "Minimalna ilość nie może być ujemna")
    @Max(value = 999999, message = "Minimalna ilość nie może przekraczać 999999")
    private Integer minIlosc;
    
    @Size(min = 1, max = 50, message = "Jednostka musi zawierać od 1 do 50 znaków")
    private String jednostka;
    
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;

    private LocalDate dataZakupu;

    private LocalDate dataRealizacji;

    @DecimalMin(value = "0.00", message = "Cena nie może być ujemna")
    @Digits(integer = 10, fraction = 2, message = "Cena może mieć maksymalnie 2 miejsca po przecinku")
    private BigDecimal cena;
}