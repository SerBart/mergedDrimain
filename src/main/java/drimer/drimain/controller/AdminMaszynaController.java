package drimer.drimain.controller;

import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Dzial;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.HarmonogramRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.repository.PartRepository;
import drimer.drimain.repository.InstructionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/admin/maszyny")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminMaszynaController {

    private final MaszynaRepository maszynaRepository;
    private final DzialRepository dzialRepository;
    private final RaportRepository raportRepository;
    private final HarmonogramRepository harmonogramRepository;
    private final ZgloszenieRepository zgloszenieRepository;
    private final PartRepository partRepository;
    private final InstructionRepository instructionRepository;

    @GetMapping
    public List<SimpleMaszynaDTO> list() {
        return maszynaRepository.findAll().stream().map(m -> {
            SimpleMaszynaDTO dto = new SimpleMaszynaDTO();
            dto.setId(m.getId());
            dto.setNazwa(m.getNazwa());
            return dto;
        }).collect(Collectors.toList());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SimpleMaszynaDTO create(@RequestBody Map<String, Object> body) {
        String nazwa = (String) body.get("nazwa");
        Number dzId = (Number) body.get("dzialId");
        if (nazwa == null || nazwa.trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Brak nazwy maszyny");
        }
        if (dzId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Brak dzialId");
        }
        Dzial dzial = dzialRepository.findById(dzId.longValue())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Dzial nie znaleziony"));
        Maszyna m = new Maszyna();
        m.setNazwa(nazwa.trim());
        m.setDzial(dzial);
        maszynaRepository.save(m);
        SimpleMaszynaDTO dto = new SimpleMaszynaDTO();
        dto.setId(m.getId());
        dto.setNazwa(m.getNazwa());
        return dto;
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Maszyna m = maszynaRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Maszyna nie znaleziona"));

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
            throw new ResponseStatusException(HttpStatus.CONFLICT, msg);
        }
        try {
            maszynaRepository.delete(m);
        } catch (DataIntegrityViolationException ex) {
            // Fallback, gdyby jakieś ukryte FK nadal blokowało
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Nie można usunąć maszyny z powodu powiązań w bazie.");
        }
    }
}
