package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class DzialCreateRequest {
    @NotBlank
    private String nazwa;
}