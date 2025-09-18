package drimer.drimain.model;

import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.model.enums.ZgloszeniePriorytet;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Encja zgłoszenia.
 * Dodano metodę validate() używaną ręcznie w kontrolerze.
 */
@Entity
@Table(name = "zgloszenia")
public class Zgloszenie {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank(message = "Typ jest wymagany")
    @Size(max = 100, message = "Typ może mieć maksymalnie 100 znaków")
    private String typ;

    @NotBlank(message = "Imię jest wymagane")
    @Size(max = 50, message = "Imię może mieć maksymalnie 50 znaków")
    private String imie;

    @NotBlank(message = "Nazwisko jest wymagane")
    @Size(max = 50, message = "Nazwisko może mieć maksymalnie 50 znaków")
    private String nazwisko;

    @Size(max = 200, message = "Tytuł może mieć maksymalnie 200 znaków")
    private String tytul;

    @NotNull(message = "Status jest wymagany")
    @Enumerated(EnumType.STRING)
    private ZgloszenieStatus status;

    @NotNull(message = "Priorytet jest wymagany")
    @Enumerated(EnumType.STRING)
    private ZgloszeniePriorytet priorytet = ZgloszeniePriorytet.NORMALNY;

    @NotBlank(message = "Opis jest wymagany")
    @Size(min = 10, max = 2000, message = "Opis musi mieć od 10 do 2000 znaków")
    @Column(length = 2000)
    private String opis;

    @Column(name = "data_godzina")
    private LocalDateTime dataGodzina;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dzial_id")
    private Dzial dzial;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "autor_id")
    private User autor;

    @OneToMany(mappedBy = "zgloszenie", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Attachment> attachments = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
        if (dataGodzina == null) {
            dataGodzina = createdAt;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Gettery / Settery (bez zmian)
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTyp() { return typ; }
    public void setTyp(String typ) { this.typ = typ; }
    public String getImie() { return imie; }
    public void setImie(String imie) { this.imie = imie; }
    public String getNazwisko() { return nazwisko; }
    public void setNazwisko(String nazwisko) { this.nazwisko = nazwisko; }
    public ZgloszenieStatus getStatus() { return status; }
    public void setStatus(ZgloszenieStatus status) { this.status = status; }
    public ZgloszeniePriorytet getPriorytet() { return priorytet; }
    public void setPriorytet(ZgloszeniePriorytet priorytet) { this.priorytet = priorytet; }
    public String getOpis() { return opis; }
    public void setOpis(String opis) { this.opis = opis; }
    public LocalDateTime getDataGodzina() { return dataGodzina; }
    public void setDataGodzina(LocalDateTime dataGodzina) { this.dataGodzina = dataGodzina; }
    public String getTytul() { return tytul; }
    public void setTytul(String tytul) { this.tytul = tytul; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    public Dzial getDzial() { return dzial; }
    public void setDzial(Dzial dzial) { this.dzial = dzial; }
    public User getAutor() { return autor; }
    public void setAutor(User autor) { this.autor = autor; }
    public List<Attachment> getAttachments() { return attachments; }
    public void setAttachments(List<Attachment> attachments) { this.attachments = attachments; }
    public void addAttachment(Attachment attachment) {
        attachment.setZgloszenie(this);
        this.attachments.add(attachment);
    }
    public void removeAttachment(Attachment attachment) {
        attachment.setZgloszenie(null);
        this.attachments.remove(attachment);
    }

    public void validate() {
        if (imie == null || imie.isBlank()) throw new IllegalArgumentException("Imię jest wymagane");
        if (nazwisko == null || nazwisko.isBlank()) throw new IllegalArgumentException("Nazwisko jest wymagane");
        if (typ == null || typ.isBlank()) throw new IllegalArgumentException("Typ jest wymagany");
        if (opis == null || opis.isBlank()) throw new IllegalArgumentException("Opis jest wymagany");
        if (opis.length() < 10) throw new IllegalArgumentException("Opis musi mieć co najmniej 10 znaków");
        if (dataGodzina == null) throw new IllegalArgumentException("Data i godzina są wymagane");
    }
}