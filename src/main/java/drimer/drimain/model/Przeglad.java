package drimer.drimain.model;

import drimer.drimain.model.enums.StatusPrzegladu;
import drimer.drimain.model.enums.TypPrzegladu;
import jakarta.persistence.*;

import java.time.LocalDate;

@Entity
@Table(name = "przeglady")
public class Przeglad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private LocalDate data;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private TypPrzegladu typ;

    @Column(length = 1000)
    private String opis;

    @ManyToOne
    @JoinColumn(name = "maszyna_id")
    private Maszyna maszyna;

    @ManyToOne
    @JoinColumn(name = "osoba_id")
    private Osoba osoba;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private StatusPrzegladu status = StatusPrzegladu.PLANOWANY;

    public Long getId() { return id; }
    public LocalDate getData() { return data; }
    public void setData(LocalDate data) { this.data = data; }
    public TypPrzegladu getTyp() { return typ; }
    public void setTyp(TypPrzegladu typ) { this.typ = typ; }
    public String getOpis() { return opis; }
    public void setOpis(String opis) { this.opis = opis; }
    public Maszyna getMaszyna() { return maszyna; }
    public void setMaszyna(Maszyna maszyna) { this.maszyna = maszyna; }
    public Osoba getOsoba() { return osoba; }
    public void setOsoba(Osoba osoba) { this.osoba = osoba; }
    public StatusPrzegladu getStatus() { return status; }
    public void setStatus(StatusPrzegladu status) { this.status = status; }
}