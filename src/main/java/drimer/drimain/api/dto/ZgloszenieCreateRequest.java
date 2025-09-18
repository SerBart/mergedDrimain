package drimer.drimain.api.dto;

import drimer.drimain.model.enums.ZgloszeniePriorytet;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class ZgloszenieCreateRequest {
    private String typ;
    private String imie;
    private String nazwisko;
    private String tytul; // New field
    private String status;
    private ZgloszeniePriorytet priorytet = ZgloszeniePriorytet.NORMALNY; // New priority field with default
    private String opis;
    private LocalDateTime dataGodzina;
    private Long dzialId; // New field
    private Long autorId; // New field  
    private String photoBase64; // opcjonalnie
}