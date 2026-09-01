package drimer.drimain.api.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class EnergyMachineSummaryDTO {
    private Long maszynaId;
    private String maszynaNazwa;
    private Long dzialId;
    private String dzialNazwa;
    private String deviceId;
    private OffsetDateTime lastRecordedAt;
    private BigDecimal powerKw;
    private BigDecimal energyKwhTotal;
    private BigDecimal todayEnergyKwh;
    private long readingsCount;
}

