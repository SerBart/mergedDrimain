package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class MaszynaCreateRequest {
    @NotBlank
    private String nazwa;
    private Long dzialId;
}