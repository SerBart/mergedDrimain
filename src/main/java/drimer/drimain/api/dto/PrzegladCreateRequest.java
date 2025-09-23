package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class PrzegladCreateRequest {
    @NotNull
    private LocalDate data;

    @NotNull
    private String typ; // enum name

    @Size(max = 1000)
    private String opis;

    private Long maszynaId;
    private Long osobaId;

    private String status; // enum name
}