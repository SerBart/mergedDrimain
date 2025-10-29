package drimer.drimain.api.dto;

import lombok.Data;

import java.util.Set;

@Data
public class UserDTO {
    private Long id;
    private String username;
    private Set<String> roles; // Role names for simplicity

    // Email dodany do ekspozycji w panelu admina
    private String email;

    // New: department info
    private Long dzialId;
    private String dzialNazwa;

    // New: per-user modules
    private Set<String> modules;
    // Note: password field intentionally excluded for security

    // Explicit accessors for compatibility
    public Long getDzialId() { return dzialId; }
    public void setDzialId(Long dzialId) { this.dzialId = dzialId; }
    public String getDzialNazwa() { return dzialNazwa; }
    public void setDzialNazwa(String dzialNazwa) { this.dzialNazwa = dzialNazwa; }
    public Set<String> getModules() { return modules; }
    public void setModules(Set<String> modules) { this.modules = modules; }
}