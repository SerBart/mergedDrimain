package drimer.drimain.api.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class PartDTO {
    private Long id;
    private String nazwa;
    private String kod;
    private String opis;
    private String kategoria;
    private Integer ilosc;
    private Integer minIlosc;
    private String jednostka;
    private Long maszynaId;
    private String maszynaNazwa;
    private LocalDate dataZakupu;
    private LocalDate dataRealizacji;
    private BigDecimal cena;
}