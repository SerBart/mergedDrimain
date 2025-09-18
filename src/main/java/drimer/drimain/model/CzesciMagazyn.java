package drimer.drimain.model;

import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "czesci_magazyn")
public class CzesciMagazyn {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String nazwa;             // Nazwa produktu
    private String numerKatalogowy;   // Kod produktu / numer katalogowy
    private String dostawca;          // Dostawca
    private String producent;         // Producent
    private Integer ilosc;            // Liczba sztuk
    private LocalDate dataDodania;    // Data dostawy

    // Gettery i settery
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getNazwa() { return nazwa; }
    public void setNazwa(String nazwa) { this.nazwa = nazwa; }

    public String getNumerKatalogowy() { return numerKatalogowy; }
    public void setNumerKatalogowy(String numerKatalogowy) { this.numerKatalogowy = numerKatalogowy; }

    public String getDostawca() { return dostawca; }
    public void setDostawca(String dostawca) { this.dostawca = dostawca; }

    public String getProducent() { return producent; }
    public void setProducent(String producent) { this.producent = producent; }

    public Integer getIlosc() { return ilosc; }
    public void setIlosc(Integer ilosc) { this.ilosc = ilosc; }

    public LocalDate getDataDodania() { return dataDodania; }
    public void setDataDodania(LocalDate dataDodania) { this.dataDodania = dataDodania; }
}