package drimer.drimain.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Schema(description = "Request sent from Raspberry Pi with energy meter reading")
public class EnergyReadingIngestRequest {

    @NotNull(message = "ID maszyny jest wymagane")
    private Long maszynaId;

    @NotBlank(message = "deviceId jest wymagane")
    @Size(max = 120, message = "deviceId nie może przekraczać 120 znaków")
    private String deviceId;

    @NotNull(message = "recordedAt jest wymagane")
    private OffsetDateTime recordedAt;

    @NotNull(message = "powerKw jest wymagane")
    @PositiveOrZero(message = "powerKw nie może być ujemne")
    private BigDecimal powerKw;

    @NotNull(message = "energyKwhTotal jest wymagane")
    @PositiveOrZero(message = "energyKwhTotal nie może być ujemne")
    private BigDecimal energyKwhTotal;

    @PositiveOrZero(message = "voltageV nie może być ujemne")
    private BigDecimal voltageV;

    @PositiveOrZero(message = "currentA nie może być ujemne")
    private BigDecimal currentA;
}


