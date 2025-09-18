package drimer.drimain.api.dto;

import drimer.drimain.model.enums.ZgloszeniePriorytet;
import lombok.Data;

@Data
public class ZgloszenieUpdateRequest {
    private String typ;
    private String imie;
    private String nazwisko;
    private String tytul; // New field
    private String status;
    private ZgloszeniePriorytet priorytet; // New priority field  
    private String opis;
    private Long dzialId; // New field
    private Long autorId; // New field
    private String photoBase64; // opcjonalnie
}