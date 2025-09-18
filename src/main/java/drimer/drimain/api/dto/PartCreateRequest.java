package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class PartCreateRequest {
    private String nazwa;
    private String kod;
    private String kategoria;
    private Integer ilosc;
    private Integer minIlosc;
    private String jednostka;
}