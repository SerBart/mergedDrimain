package drimer.drimain.model;

import jakarta.persistence.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.*;
import java.util.stream.Collectors;

@Entity
@Table(name = "users")
public class User implements UserDetails {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(unique = true, nullable = false)
    private String username;
    @Column(unique = true, nullable = false)
    private String email;
    @Column(nullable = false)
    private String password;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "user_roles",
            joinColumns = @JoinColumn(name = "user_id"),
            inverseJoinColumns = @JoinColumn(name = "role_id"))
    private Set<Role> roles = new HashSet<>();

    // New: department assignment
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dzial_id")
    private Dzial dzial;

    // New: per-user modules access (simple string set)
    @ElementCollection
    @CollectionTable(name = "user_modules", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "module")
    private Set<String> modules = new HashSet<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    @Override public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    @Override public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }

    public void addRole(Role role) { if (role != null) roles.add(role); }
    public void clearRoles() { roles.clear(); }

    // New getters/setters
    public Dzial getDzial() { return dzial; }
    public void setDzial(Dzial dzial) { this.dzial = dzial; }

    public Set<String> getModules() { return modules; }
    public void setModules(Set<String> modules) { this.modules = modules != null ? modules : new HashSet<>(); }

    // UserDetails
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream()
                .map(r -> (GrantedAuthority) r::getName)
                .collect(Collectors.toSet());
    }
    @Override public boolean isAccountNonExpired() { return true; }
    @Override public boolean isAccountNonLocked() { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled() { return true; }

}