package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.*;
import drimer.drimain.repository.*;
import drimer.drimain.security.ModulesCatalog;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
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
    // Nowe repozytoria do walidacji zależności maszyny
    private final RaportRepository raportRepository;
    private final HarmonogramRepository harmonogramRepository;
    private final ZgloszenieRepository zgloszenieRepository;
    private final PartRepository partRepository;
    private final InstructionRepository instructionRepository;

    // ========== META: MODULES (kafelki) ==========
    @GetMapping("/modules")
    public List<String> getModulesCatalog() {
        return ModulesCatalog.ALLOWED;
    }

    // ========== DZIALY ==========
    
    @GetMapping("/dzialy")
    @Transactional(readOnly = true)
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
        dzialRepository.deleteById(id);
    }

    // ========== MASZYNY ==========
    
    @GetMapping("/maszyny")
    @Transactional(readOnly = true)
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
    public ResponseEntity<?> deleteMaszyna(@PathVariable Long id) {
        var opt = maszynaRepository.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("message", "Maszyna nie znaleziona"));
        }
        long raportCount = raportRepository.countByMaszyna_Id(id);
        long harmCount = harmonogramRepository.countByMaszyna_Id(id);
        long zglCount = zgloszenieRepository.countByMaszyna_Id(id);
        long partCount = partRepository.countByMaszyna_Id(id);
        long instrCount = instructionRepository.countByMaszyna_Id(id);
        if (raportCount > 0 || harmCount > 0 || zglCount > 0 || partCount > 0 || instrCount > 0) {
            String msg = String.format(
                "Nie można usunąć. Powiązane: raporty=%d, harmonogramy=%d, zgłoszenia=%d, części=%d, instrukcje=%d",
                raportCount, harmCount, zglCount, partCount, instrCount
            );
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("message", msg));
        }
        try {
            maszynaRepository.deleteById(id);
            return ResponseEntity.noContent().build();
        } catch (DataIntegrityViolationException ex) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("message", "Nie można usunąć maszyny z powodu powiązań w bazie."));
        }
    }

    // ========== OSOBY ==========
    
    @GetMapping("/osoby")
    @Transactional(readOnly = true)
    public List<OsobaDTO> getOsoby() {
        return osobaRepository.findAll().stream()
                .map(this::toOsobaDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/osoby")
    @ResponseStatus(HttpStatus.CREATED)
    public OsobaDTO createOsoba(@Valid @RequestBody OsobaCreateRequest req) {
        Osoba osoba = new Osoba();
        // login/hasło opcjonalne
        if (req.getLogin() != null && !req.getLogin().isBlank()) osoba.setLogin(req.getLogin());
        if (req.getHaslo() != null && !req.getHaslo().isBlank()) osoba.setHaslo(req.getHaslo());
        osoba.setImieNazwisko(req.getImieNazwisko());
        osoba.setRola(req.getRola());
        if (req.getDzialId() != null) {
            Dzial dz = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            osoba.setDzial(dz);
        }
        osobaRepository.save(osoba);
        return toOsobaDto(osoba);
    }

    @PutMapping("/osoby/{id}")
    public OsobaDTO updateOsoba(@PathVariable Long id, @Valid @RequestBody OsobaCreateRequest req) {
        Osoba osoba = osobaRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Osoba not found"));
        if (req.getLogin() != null) osoba.setLogin(req.getLogin());
        if (req.getHaslo() != null && !req.getHaslo().trim().isEmpty()) {
            osoba.setHaslo(req.getHaslo());
        }
        if (req.getImieNazwisko() != null) osoba.setImieNazwisko(req.getImieNazwisko());
        osoba.setRola(req.getRola());
        if (req.getDzialId() != null) {
            Dzial dz = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            osoba.setDzial(dz);
        } else {
            osoba.setDzial(null);
        }
        osobaRepository.save(osoba);
        return toOsobaDto(osoba);
    }

    @DeleteMapping("/osoby/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOsoba(@PathVariable Long id) {
        osobaRepository.deleteById(id);
    }

    // ========== USERS (SECURITY) ==========
    
    @GetMapping("/users")
    @Transactional(readOnly = true)
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
        user.setEmail(req.getEmail());

        if (req.getRoles() != null && !req.getRoles().isEmpty()) {
            Set<Role> roles = req.getRoles().stream()
                    .map(roleName -> roleRepository.findByName(roleName)
                            .orElseThrow(() -> new IllegalArgumentException("Role not found: " + roleName)))
                    .collect(Collectors.toSet());
            user.setRoles(roles);
        }

        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            user.setDzial(dzial);
        }

        if (req.getModules() != null) {
            user.setModules(ModulesCatalog.normalizeAndFilter(req.getModules()));
        }

        userRepository.save(user);
        return toUserDto(user);
    }

    @PutMapping("/users/{id}")
    public UserDTO updateUser(@PathVariable Long id, @Valid @RequestBody UserCreateRequest req) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        
        user.setUsername(req.getUsername());
        user.setEmail(req.getEmail());

        if (req.getPassword() != null && !req.getPassword().trim().isEmpty()) {
            user.setPassword(passwordEncoder.encode(req.getPassword()));
        }
        
        if (req.getRoles() != null) {
            Set<Role> roles = req.getRoles().stream()
                    .map(roleName -> roleRepository.findByName(roleName)
                            .orElseThrow(() -> new IllegalArgumentException("Role not found: " + roleName)))
                    .collect(Collectors.toSet());
            user.setRoles(roles);
        }

        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            user.setDzial(dzial);
        } else {
            user.setDzial(null);
        }

        if (req.getModules() != null) {
            user.setModules(ModulesCatalog.normalizeAndFilter(req.getModules()));
        } else {
            user.setModules(Set.of());
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
        if (osoba.getDzial() != null) {
            dto.setDzialId(osoba.getDzial().getId());
            dto.setDzialNazwa(osoba.getDzial().getNazwa());
        }
        return dto;
    }

    private UserDTO toUserDto(User user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setRoles(user.getRoles().stream()
                .map(Role::getName)
                .collect(Collectors.toSet()));
        dto.setEmail(user.getEmail());
        if (user.getDzial() != null) {
            dto.setDzialId(user.getDzial().getId());
            dto.setDzialNazwa(user.getDzial().getNazwa());
        }
        dto.setModules(user.getModules());
        return dto;
    }

    // ========== BASIC ERROR HANDLERS ==========
    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public String handleIllegalArgument(IllegalArgumentException ex) {
        return ex.getMessage();
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public String handleOther(Exception ex) {
        return ex.getMessage() == null ? "Internal server error" : ex.getMessage();
    }
}
