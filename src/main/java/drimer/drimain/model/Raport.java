package drimer.drimain.model;

import drimer.drimain.model.enums.RaportStatus;
import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "raporty")
public class Raport {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "maszyna_id")
    private Maszyna maszyna;

    private String typNaprawy;

    @Column(length = 4000)
    private String opis;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "osoba_id")
    private Osoba osoba;

    @Enumerated(EnumType.STRING)
    @Column(length = 40)
    private RaportStatus status;

    private LocalDate dataNaprawy;
    private LocalTime czasOd;
    private LocalTime czasDo;

    @OneToMany(mappedBy = "raport", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<PartUsage> partUsages = new LinkedHashSet<>();

    // Gettery / settery (jak poprzednio) + dla statusu
    public Long getId() { return id; }
    public Maszyna getMaszyna() { return maszyna; }
    public void setMaszyna(Maszyna maszyna) { this.maszyna = maszyna; }
    public String getTypNaprawy() { return typNaprawy; }
    public void setTypNaprawy(String typNaprawy) { this.typNaprawy = typNaprawy; }
    public String getOpis() { return opis; }
    public void setOpis(String opis) { this.opis = opis; }
    public Osoba getOsoba() { return osoba; }
    public void setOsoba(Osoba osoba) { this.osoba = osoba; }
    public RaportStatus getStatus() { return status; }
    public void setStatus(RaportStatus status) { this.status = status; }
    public LocalDate getDataNaprawy() { return dataNaprawy; }
    public void setDataNaprawy(LocalDate dataNaprawy) { this.dataNaprawy = dataNaprawy; }
    public LocalTime getCzasOd() { return czasOd; }
    public void setCzasOd(LocalTime czasOd) { this.czasOd = czasOd; }
    public LocalTime getCzasDo() { return czasDo; }
    public void setCzasDo(LocalTime czasDo) { this.czasDo = czasDo; }
    public Set<PartUsage> getPartUsages() { return partUsages; }
    public void setPartUsages(Set<PartUsage> partUsages) {
        this.partUsages.clear();
        if (partUsages != null) partUsages.forEach(this::addPartUsage);
    }
    public void addPartUsage(PartUsage pu) { pu.setRaport(this); this.partUsages.add(pu); }
    public void removePartUsage(PartUsage pu) { pu.setRaport(null); this.partUsages.remove(pu); }
}