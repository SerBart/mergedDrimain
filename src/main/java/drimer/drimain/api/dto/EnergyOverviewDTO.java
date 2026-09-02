package drimer.drimain.api.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
public class EnergyOverviewDTO {
    private String scopeType;
    private String scopeLabel;
    private int zakresDni;
    private int bucketMinutes;
    private OffsetDateTime generatedAt;
    private BigDecimal totalPowerKw = BigDecimal.ZERO;
    private BigDecimal todayEnergyKwh = BigDecimal.ZERO;
    private BigDecimal peakPower1hKw = BigDecimal.ZERO;
    private BigDecimal peakPower8hKw = BigDecimal.ZERO;
    private BigDecimal peakPower24hKw = BigDecimal.ZERO;
    private BigDecimal peakPower3dKw = BigDecimal.ZERO;
    private BigDecimal peakPower7dKw = BigDecimal.ZERO;
    private BigDecimal peakPower30dKw = BigDecimal.ZERO;
    private long activeMachines;
    private long totalMachines;
    private List<EnergyMachineSummaryDTO> machines = new ArrayList<>();
}

