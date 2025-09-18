package drimer.drimain.api.dto;

import drimer.drimain.model.enums.StatusHarmonogramu;
import lombok.Data;

import java.time.LocalDate;

@Data
public class HarmonogramDTO {
    private Long id;
    private LocalDate data;
    private String opis;
    private SimpleMaszynaDTO maszyna;
    private SimpleOsobaDTO osoba;
    private StatusHarmonogramu status;
}