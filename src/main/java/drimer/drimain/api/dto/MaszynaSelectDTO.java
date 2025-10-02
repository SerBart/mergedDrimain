package drimer.drimain.api.dto;

public class MaszynaSelectDTO {
    private Long id;
    private String name;   // alias nazwy
    private String label;  // alias do wyświetlania
    private String nazwa;  // oryginalne pole domenowe

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public String getNazwa() { return nazwa; }
    public void setNazwa(String nazwa) { this.nazwa = nazwa; }
}

