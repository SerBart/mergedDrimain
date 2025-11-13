package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class OsobaDTO {
    private Long id;
    private String login;
    private String imieNazwisko;
    private String rola;
    // Dodatkowe informacje o dziale osoby (opcjonalne)
    private Long dzialId;
    private String dzialNazwa;
}