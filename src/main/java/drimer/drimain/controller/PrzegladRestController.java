package drimer.drimain.controller;

import drimer.drimain.api.dto.PrzegladCreateRequest;
import drimer.drimain.api.dto.PrzegladDTO;
import drimer.drimain.api.dto.PrzegladUpdateRequest;
import drimer.drimain.api.mapper.PrzegladMapper;
import drimer.drimain.model.Przeglad;
import drimer.drimain.model.enums.StatusPrzegladu;
import drimer.drimain.model.enums.TypPrzegladu;
import drimer.drimain.repository.PrzegladRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/przeglady")
@RequiredArgsConstructor
public class PrzegladRestController {

    private final PrzegladRepository przegladRepository;
    private final PrzegladMapper przegladMapper;

    @GetMapping
    public List<PrzegladDTO> list(@RequestParam Optional<LocalDate> start,
                                  @RequestParam Optional<LocalDate> end,
                                  @RequestParam Optional<String> typ,
                                  @RequestParam Optional<String> status) {
        List<Przeglad> src = (start.isPresent() && end.isPresent())
                ? przegladRepository.findByDataBetween(start.get(), end.get())
                : przegladRepository.findAll();

        return src.stream()
                .filter(p -> typ
                        .map(t -> {
                            try { return p.getTyp() == TypPrzegladu.valueOf(t); } catch (Exception e) { return false; }
                        })
                        .orElse(true))
                .filter(p -> status
                        .map(s -> {
                            try { return p.getStatus() == StatusPrzegladu.valueOf(s); } catch (Exception e) { return false; }
                        })
                        .orElse(true))
                .map(przegladMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public PrzegladDTO get(@PathVariable Long id) {
        Przeglad p = przegladRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Przeglad not found"));
        return przegladMapper.toDto(p);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public PrzegladDTO create(@Valid @RequestBody PrzegladCreateRequest req,
                              Authentication authentication) {
        Przeglad p = new Przeglad();
        p.setData(req.getData());
        p.setOpis(req.getOpis());
        przegladMapper.applyCreateDefaults(p, req);
        przegladMapper.updateEntity(p, toUpdate(req));
        przegladRepository.save(p);
        return przegladMapper.toDto(p);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public PrzegladDTO update(@PathVariable Long id,
                              @Valid @RequestBody PrzegladUpdateRequest req,
                              Authentication authentication) {
        Przeglad p = przegladRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Przeglad not found"));
        przegladMapper.updateEntity(p, req);
        przegladRepository.save(p);
        return przegladMapper.toDto(p);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public void delete(@PathVariable Long id, Authentication authentication) {
        przegladRepository.deleteById(id);
    }

    private PrzegladUpdateRequest toUpdate(PrzegladCreateRequest req) {
        PrzegladUpdateRequest u = new PrzegladUpdateRequest();
        u.setData(req.getData());
        u.setTyp(req.getTyp());
        u.setOpis(req.getOpis());
        u.setMaszynaId(req.getMaszynaId());
        u.setOsobaId(req.getOsobaId());
        u.setStatus(req.getStatus());
        return u;
    }
}