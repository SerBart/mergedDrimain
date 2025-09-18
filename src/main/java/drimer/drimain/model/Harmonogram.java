package drimer.drimain.model;

import drimer.drimain.model.enums.StatusHarmonogramu;
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

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 40)
    private StatusHarmonogramu status = StatusHarmonogramu.PLANOWANE;

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

    public StatusHarmonogramu getStatus() { return status; }
    public void setStatus(StatusHarmonogramu status) { this.status = status; }
}