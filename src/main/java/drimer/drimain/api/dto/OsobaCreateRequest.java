package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class OsobaCreateRequest {
    @NotBlank
    private String login;
    
    @NotBlank
    private String haslo;
    
    private String imieNazwisko;
    private String rola;
}