package drimer.drimain.api.dto;

import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
public class RaportDTO {
    private Long id;
    private SimpleMaszynaDTO maszyna;
    private String typNaprawy;
    private String opis;
    private String status; // nazwa enum
    private LocalDate dataNaprawy;
    private String czasOd;
    private String czasDo;
    private SimpleOsobaDTO osoba;
    private List<PartUsageDTO> partUsages;
}