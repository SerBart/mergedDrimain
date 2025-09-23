package drimer.drimain.api.dto;

import lombok.Data;

import java.time.LocalDate;

@Data
public class PrzegladDTO {
    private Long id;
    private LocalDate data;
    private String typ; // enum name
    private String opis;
    private SimpleMaszynaDTO maszyna;
    private SimpleOsobaDTO osoba;
    private String status; // enum name
}