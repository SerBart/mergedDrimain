package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class OsobaDTO {
    private Long id;
    private String login;
    private String imieNazwisko;
    private String rola;
    // Note: password field intentionally excluded for security
}