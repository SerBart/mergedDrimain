package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.util.List;

/**
 * Request DTO for creating new Instruction.
 * Validates instruction information and associated parts.
 */
@Data
@Schema(description = "Request to create a new instruction")
public class InstructionCreateRequest {
    
    @NotBlank(message = "Tytuł instrukcji jest wymagany")
    @Size(min = 5, max = 255, message = "Tytuł musi zawierać od 5 do 255 znaków")
    private String title;
    
    @NotBlank(message = "Opis instrukcji jest wymagany")
    @Size(min = 20, max = 5000, message = "Opis musi zawierać od 20 do 5000 znaków")
    private String description;
    
    @NotNull(message = "ID maszyny jest wymagane")
    @Positive(message = "ID maszyny musi być dodatnie")
    private Long maszynaId;
    
    @Valid
    private List<InstructionPartRef> parts;

    /**
     * Inner DTO for instruction parts reference.
     */
    @Data
    @Schema(description = "Reference to a part used in instruction")
    public static class InstructionPartRef {
        
        @NotNull(message = "ID części jest wymagane")
        @Positive(message = "ID części musi być dodatnie")
        private Long partId;
        
        @NotNull(message = "Ilość jest wymagana")
        @Positive(message = "Ilość musi być dodatnia")
        private Integer ilosc;
    }
}

