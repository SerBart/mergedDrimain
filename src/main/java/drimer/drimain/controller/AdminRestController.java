package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.*;
import drimer.drimain.repository.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Admin REST Controller for managing system entities (dzialy, maszyny, osoby, users)
 * All endpoints require ADMIN role
 */
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminRestController {

    private final DzialRepository dzialRepository;
    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    // ========== DZIALY ==========
    
    @GetMapping("/dzialy")
    public List<DzialDTO> getDzialy() {
        return dzialRepository.findAll().stream()
                .map(this::toDzialDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/dzialy")
    @ResponseStatus(HttpStatus.CREATED)
    public DzialDTO createDzial(@Valid @RequestBody DzialCreateRequest req) {
        Dzial dzial = new Dzial();
        dzial.setNazwa(req.getNazwa());
        dzialRepository.save(dzial);
        return toDzialDto(dzial);
    }

    @PutMapping("/dzialy/{id}")
    public DzialDTO updateDzial(@PathVariable Long id, @Valid @RequestBody DzialCreateRequest req) {
        Dzial dzial = dzialRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
        dzial.setNazwa(req.getNazwa());
        dzialRepository.save(dzial);
        return toDzialDto(dzial);
    }

    @DeleteMapping("/dzialy/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteDzial(@PathVariable Long id) {
        // TODO: Add validation to prevent deletion if dzial has related maszyny
        dzialRepository.deleteById(id);
    }

    // ========== MASZYNY ==========
    
    @GetMapping("/maszyny")
    public List<MaszynaDTO> getMaszyny() {
        return maszynaRepository.findAll().stream()
                .map(this::toMaszynaDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/maszyny")
    @ResponseStatus(HttpStatus.CREATED)
    public MaszynaDTO createMaszyna(@Valid @RequestBody MaszynaCreateRequest req) {
        Maszyna maszyna = new Maszyna();
        maszyna.setNazwa(req.getNazwa());
        
        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            maszyna.setDzial(dzial);
        }
        
        maszynaRepository.save(maszyna);
        return toMaszynaDto(maszyna);
    }

    @PutMapping("/maszyny/{id}")
    public MaszynaDTO updateMaszyna(@PathVariable Long id, @Valid @RequestBody MaszynaCreateRequest req) {
        Maszyna maszyna = maszynaRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));
        
        maszyna.setNazwa(req.getNazwa());
        
        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            maszyna.setDzial(dzial);
        }
        
        maszynaRepository.save(maszyna);
        return toMaszynaDto(maszyna);
    }

    @DeleteMapping("/maszyny/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteMaszyna(@PathVariable Long id) {
        // TODO: Add validation to prevent deletion if maszyna has related zgloszenia/harmonogramy
        maszynaRepository.deleteById(id);
    }

    // ========== OSOBY ==========
    
    @GetMapping("/osoby")
    public List<OsobaDTO> getOsoby() {
        return osobaRepository.findAll().stream()
                .map(this::toOsobaDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/osoby")
    @ResponseStatus(HttpStatus.CREATED)
    public OsobaDTO createOsoba(@Valid @RequestBody OsobaCreateRequest req) {
        // TODO: Add password encoding/hashing for osoby if needed
        Osoba osoba = new Osoba();
        osoba.setLogin(req.getLogin());
        osoba.setHaslo(req.getHaslo()); // TODO: Consider encrypting this
        osoba.setImieNazwisko(req.getImieNazwisko());
        osoba.setRola(req.getRola());
        
        osobaRepository.save(osoba);
        return toOsobaDto(osoba);
    }

    @PutMapping("/osoby/{id}")
    public OsobaDTO updateOsoba(@PathVariable Long id, @Valid @RequestBody OsobaCreateRequest req) {
        Osoba osoba = osobaRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Osoba not found"));
        
        osoba.setLogin(req.getLogin());
        if (req.getHaslo() != null && !req.getHaslo().trim().isEmpty()) {
            osoba.setHaslo(req.getHaslo()); // TODO: Consider encrypting this
        }
        osoba.setImieNazwisko(req.getImieNazwisko());
        osoba.setRola(req.getRola());
        
        osobaRepository.save(osoba);
        return toOsobaDto(osoba);
    }

    @DeleteMapping("/osoby/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOsoba(@PathVariable Long id) {
        // TODO: Add validation to prevent deletion if osoba has related zgloszenia/harmonogramy
        osobaRepository.deleteById(id);
    }

    // ========== USERS (SECURITY) ==========
    
    @GetMapping("/users")
    public List<UserDTO> getUsers() {
        return userRepository.findAll().stream()
                .map(this::toUserDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/users")
    @ResponseStatus(HttpStatus.CREATED)
    public UserDTO createUser(@Valid @RequestBody UserCreateRequest req) {
        User user = new User();
        user.setUsername(req.getUsername());
        user.setPassword(passwordEncoder.encode(req.getPassword()));
        
        // TODO: Implement role assignment - need to look up Role entities by name
        if (req.getRoles() != null && !req.getRoles().isEmpty()) {
            Set<Role> roles = req.getRoles().stream()
                    .map(roleName -> roleRepository.findByName(roleName)
                            .orElseThrow(() -> new IllegalArgumentException("Role not found: " + roleName)))
                    .collect(Collectors.toSet());
            user.setRoles(roles);
        }
        
        userRepository.save(user);
        return toUserDto(user);
    }

    @PutMapping("/users/{id}")
    public UserDTO updateUser(@PathVariable Long id, @Valid @RequestBody UserCreateRequest req) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        
        user.setUsername(req.getUsername());
        
        // Only update password if provided
        if (req.getPassword() != null && !req.getPassword().trim().isEmpty()) {
            user.setPassword(passwordEncoder.encode(req.getPassword()));
        }
        
        // TODO: Implement role assignment update
        if (req.getRoles() != null) {
            Set<Role> roles = req.getRoles().stream()
                    .map(roleName -> roleRepository.findByName(roleName)
                            .orElseThrow(() -> new IllegalArgumentException("Role not found: " + roleName)))
                    .collect(Collectors.toSet());
            user.setRoles(roles);
        }
        
        userRepository.save(user);
        return toUserDto(user);
    }

    @DeleteMapping("/users/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteUser(@PathVariable Long id) {
        userRepository.deleteById(id);
    }

    // ========== MAPPER METHODS ==========
    
    private DzialDTO toDzialDto(Dzial dzial) {
        DzialDTO dto = new DzialDTO();
        dto.setId(dzial.getId());
        dto.setNazwa(dzial.getNazwa());
        return dto;
    }

    private MaszynaDTO toMaszynaDto(Maszyna maszyna) {
        MaszynaDTO dto = new MaszynaDTO();
        dto.setId(maszyna.getId());
        dto.setNazwa(maszyna.getNazwa());
        
        if (maszyna.getDzial() != null) {
            dto.setDzial(toDzialDto(maszyna.getDzial()));
        }
        
        return dto;
    }

    private OsobaDTO toOsobaDto(Osoba osoba) {
        OsobaDTO dto = new OsobaDTO();
        dto.setId(osoba.getId());
        dto.setLogin(osoba.getLogin());
        dto.setImieNazwisko(osoba.getImieNazwisko());
        dto.setRola(osoba.getRola());
        // Password intentionally excluded
        return dto;
    }

    private UserDTO toUserDto(User user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setRoles(user.getRoles().stream()
                .map(Role::getName)
                .collect(Collectors.toSet()));
        // Password intentionally excluded
        return dto;
    }
}