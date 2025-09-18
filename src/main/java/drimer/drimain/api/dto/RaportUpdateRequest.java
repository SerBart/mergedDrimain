package drimer.drimain.api.dto;

import lombok.Data;
import java.time.LocalDate;
import java.util.List;

@Data
public class RaportUpdateRequest {
    private String typNaprawy;
    private String opis;
    private String status;
    private LocalDate dataNaprawy;
    private String czasOd;
    private String czasDo;
    private Long maszynaId;
    private Long osobaId;
    private List<PartUsageDTO> partUsages;
}