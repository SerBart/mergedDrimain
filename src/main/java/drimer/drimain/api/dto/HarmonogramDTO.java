package drimer.drimain.api.dto;

import drimer.drimain.model.enums.HarmonogramOkres;
import drimer.drimain.model.enums.StatusHarmonogramu;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
public class HarmonogramDTO {
    private Long id;
    private LocalDate data;
    private String opis;
    private SimpleMaszynaDTO maszyna;
    private SimpleOsobaDTO osoba;
    private StatusHarmonogramu status;
    private Integer durationMinutes;
    private HarmonogramOkres frequency;
    private SimpleDzialDTO dzial;
    private String seriesId;
    private LocalDate planEndDate;
    private List<String> zalaczniki;
}