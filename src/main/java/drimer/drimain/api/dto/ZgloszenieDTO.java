package drimer.drimain.api.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.model.enums.ZgloszeniePriorytet;

import java.time.LocalDateTime;

/**
 * DTO dla encji Zgloszenie.
 * dataGodzina jako LocalDateTime – Jackson serializuje do ISO (konfiguracja domyślna) lub wg @JsonFormat.
 */
public class ZgloszenieDTO {

    private Long id;
    private String typ;
    private String imie;
    private String nazwisko;
    private String tytul; // New field
    private ZgloszenieStatus status;
    private ZgloszeniePriorytet priorytet; // New priority field
    private String opis;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime dataGodzina;

    // New auditing fields
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime updatedAt;

    // New relation fields
    private Long dzialId;
    private String dzialNazwa;
    private Long autorId;
    private String autorUsername;

    private boolean hasPhoto; // NOWE POLE

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getTyp() { return typ; }
    public void setTyp(String typ) { this.typ = typ; }

    public String getImie() { return imie; }
    public void setImie(String imie) { this.imie = imie; }

    public String getNazwisko() { return nazwisko; }
    public void setNazwisko(String nazwisko) { this.nazwisko = nazwisko; }

    public String getTytul() { return tytul; }
    public void setTytul(String tytul) { this.tytul = tytul; }

    public ZgloszenieStatus getStatus() { return status; }
    public void setStatus(ZgloszenieStatus status) { this.status = status; }

    public ZgloszeniePriorytet getPriorytet() { return priorytet; }
    public void setPriorytet(ZgloszeniePriorytet priorytet) { this.priorytet = priorytet; }

    public String getOpis() { return opis; }
    public void setOpis(String opis) { this.opis = opis; }

    public LocalDateTime getDataGodzina() { return dataGodzina; }
    public void setDataGodzina(LocalDateTime dataGodzina) { this.dataGodzina = dataGodzina; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public Long getDzialId() { return dzialId; }
    public void setDzialId(Long dzialId) { this.dzialId = dzialId; }

    public String getDzialNazwa() { return dzialNazwa; }
    public void setDzialNazwa(String dzialNazwa) { this.dzialNazwa = dzialNazwa; }

    public Long getAutorId() { return autorId; }
    public void setAutorId(Long autorId) { this.autorId = autorId; }

    public String getAutorUsername() { return autorUsername; }
    public void setAutorUsername(String autorUsername) { this.autorUsername = autorUsername; }

    public boolean isHasPhoto() { return hasPhoto; }
    public void setHasPhoto(boolean hasPhoto) { this.hasPhoto = hasPhoto; }
}