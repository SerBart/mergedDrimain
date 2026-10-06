package drimer.drimain.model;

import drimer.drimain.model.enums.HarmonogramOkres;
import drimer.drimain.model.enums.StatusHarmonogramu;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.Set;

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
    private Integer durationMinutes;

    @Enumerated(EnumType.STRING)
    @Column(name = "frequency", length = 20)
    private HarmonogramOkres frequency;

    @Column(name = "series_id", length = 64)
    private String seriesId;

    @Column(name = "plan_end_date")
    private LocalDate planEndDate;

    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(name = "harmonogram_zalaczniki", joinColumns = @JoinColumn(name = "harmonogram_id"))
    @Column(name = "sciezka_zalacznika", columnDefinition = "TEXT")
    private Set<String> zalaczniki = new LinkedHashSet<>();

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

    public String getSeriesId() { return seriesId; }
    public void setSeriesId(String seriesId) { this.seriesId = seriesId; }

    public LocalDate getPlanEndDate() { return planEndDate; }
    public void setPlanEndDate(LocalDate planEndDate) { this.planEndDate = planEndDate; }

    public Set<String> getZalaczniki() { return zalaczniki; }
    public void setZalaczniki(Set<String> zalaczniki) { this.zalaczniki = zalaczniki; }
}
