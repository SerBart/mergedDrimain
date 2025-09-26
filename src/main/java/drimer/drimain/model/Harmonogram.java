package drimer.drimain.model;

import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.model.enums.HarmonogramOkres;
import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "harmonogramy")
public class Harmonogram {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDate data;

    private String opis;

    @ManyToOne
    @JoinColumn(name = "maszyna_id")
    private Maszyna maszyna;

    @ManyToOne
    @JoinColumn(name = "osoba_id")
    private Osoba osoba;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dzial_id")
    private Dzial dzial;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 40)
    private StatusHarmonogramu status = StatusHarmonogramu.PLANOWANE;

    @Column(name = "duration_minutes")
    private Integer durationMinutes; // czas trwania w minutach

    @Enumerated(EnumType.STRING)
    @Column(name = "frequency", length = 20)
    private HarmonogramOkres frequency;

    // Gettery / settery
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public LocalDate getData() { return data; }
    public void setData(LocalDate data) { this.data = data; }

    public String getOpis() { return opis; }
    public void setOpis(String opis) { this.opis = opis; }

    public Maszyna getMaszyna() { return maszyna; }
    public void setMaszyna(Maszyna maszyna) { this.maszyna = maszyna; }

    public Osoba getOsoba() { return osoba; }
    public void setOsoba(Osoba osoba) { this.osoba = osoba; }
    public Dzial getDzial() { return dzial; }
    public void setDzial(Dzial dzial) { this.dzial = dzial; }
    public StatusHarmonogramu getStatus() { return status; }
    public void setStatus(StatusHarmonogramu status) { this.status = status; }

    public Integer getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(Integer durationMinutes) { this.durationMinutes = durationMinutes; }
    public HarmonogramOkres getFrequency() { return frequency; }
    public void setFrequency(HarmonogramOkres frequency) { this.frequency = frequency; }
}