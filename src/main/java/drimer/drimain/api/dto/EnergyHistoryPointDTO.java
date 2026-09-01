package drimer.drimain.api.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class EnergyHistoryPointDTO {
    private OffsetDateTime recordedAt;
    private BigDecimal powerKw;
    private BigDecimal energyKwhTotal;
    private BigDecimal voltageV;
    private BigDecimal currentA;
    private String deviceId;
}

