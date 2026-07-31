package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SekcjaCreateRequest {
    @NotBlank
    private String nazwa;

    @NotNull
    private Long maszynaId;
}

