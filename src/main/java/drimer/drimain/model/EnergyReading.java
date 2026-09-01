package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "energy_readings", indexes = {
        @Index(name = "idx_energy_readings_maszyna_recorded_at", columnList = "maszyna_id, recorded_at"),
        @Index(name = "idx_energy_readings_device_id", columnList = "device_id"),
        @Index(name = "idx_energy_readings_recorded_at", columnList = "recorded_at")
})
@Getter
@Setter
public class EnergyReading {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "maszyna_id", nullable = false)
    private Maszyna maszyna;

    @Column(name = "device_id", nullable = false, length = 120)
    private String deviceId;

    @Column(name = "recorded_at", nullable = false)
    private LocalDateTime recordedAt;

    @Column(name = "power_kw", precision = 12, scale = 3)
    private BigDecimal powerKw;

    @Column(name = "energy_kwh_total", precision = 14, scale = 3)
    private BigDecimal energyKwhTotal;

    @Column(name = "voltage_v", precision = 10, scale = 2)
    private BigDecimal voltageV;

    @Column(name = "current_a", precision = 10, scale = 2)
    private BigDecimal currentA;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        final LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (recordedAt == null) {
            recordedAt = now;
        }
    }
}

