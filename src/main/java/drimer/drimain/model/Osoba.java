package drimer.drimain.model;

import jakarta.persistence.*;

@Entity
@Table(name = "osoby")
public class Osoba {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String login;
    private String haslo;
    private String imieNazwisko;
    private String rola;

    public Osoba() {}

    public Osoba(String login, String haslo, String rola) {
        this.login = login;
        this.haslo = haslo;
        this.rola = rola;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) { this.id = id; }

    public String getLogin() { return login; }

    public void setLogin(String login) { this.login = login; }

    public String getHaslo() { return haslo; }

    public void setHaslo(String haslo) { this.haslo = haslo; }

    // === GET/SET ImieNazwisko (OPCJA 1 – jedno pole w bazie) ===
    public String getImieNazwisko() {
        return imieNazwisko;
    }

    public void setImieNazwisko(String imieNazwisko) {
        this.imieNazwisko = (imieNazwisko == null) ? null : imieNazwisko.trim();
    }
    // === KONIEC ===

    public String getRola() { return rola; }

    public void setRola(String rola) { this.rola = rola; }
}