package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class OsobaCreateRequest {
    // login i hasło opcjonalne
    private String login;
    private String haslo;

    // wymagane imię i nazwisko do listy wybieralnej
    @NotBlank
    private String imieNazwisko;

    private String rola;

    // nowe: przypisanie do działu
    private Long dzialId;
}