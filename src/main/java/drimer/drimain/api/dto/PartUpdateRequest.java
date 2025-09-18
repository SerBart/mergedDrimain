package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class PartUpdateRequest {
    private String nazwa;
    private String kod;
    private String kategoria;
    private Integer minIlosc;
    private String jednostka;
}