package drimer.drimain.api.dto;

import lombok.Data;
import java.time.LocalDate;
import java.util.List;

@Data
public class RaportCreateRequest {
    private Long maszynaId;
    private String typNaprawy;
    private String opis;
    private Long osobaId;
    private String status;          // MUSI istnieć jeśli wywołujesz req.getStatus()
    private LocalDate dataNaprawy;
    private String czasOd;
    private String czasDo;
    private List<PartUsageDTO> partUsages;
}